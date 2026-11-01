"""Render real desktop menu calls and click private mock controls; no Linux actions."""
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
from test_responsive_ui import ROOT, SHELL, check, click, screen_cells

# Parse only literal display calls, never execute the desktop entry or its actions.
pages = []
page = None
for line in (ROOT / 'main-bazzite.sh').read_text().splitlines():
    stripped = line.strip()
    if stripped.startswith('draw_category_frame '):
        page = [shlex.split(stripped)]
    elif page is not None and stripped.startswith(('ui_panel_line ', 'ui_touch_button ')):
        if stripped.endswith("\\"):continue
        args = shlex.split(stripped)
        if args[1].isdigit():
            page.append(args)
    elif page is not None and stripped == 'ui_prompt':
        # Mutually exclusive pager branches reuse slots; retain one literal state.
        slots = {int(args[1]): args for args in page[1:]}
        pages.append(page[:1] + [slots[row] for row in sorted(slots)])
        page = None
check(len(pages) >= 25, 'Real desktop menus missing from compact coverage')
# The real dynamic plugin pager can contain eleven two-line logical slots.
pages.append([['draw_category_frame', 'games', 'PLUGINS', 'All entries']] +
             [['ui_touch_button', str(2+i*2), '', f'PLUGIN_{i}'] for i in range(11)])
# Adjacent warnings must retain distinct rows above explicit confirm/cancel controls.
pages.append([['draw_category_frame', 'advanced', 'RISK', 'Administrator permission required']] +
             [['ui_panel_line', str(7+i), '', text] for i, text in enumerate([
                 'RISK_ADMIN', 'RISK_DELETE', 'RISK_RESTART', 'RISK_SIGNATURE'])] +
             [['ui_touch_button', '13', '', 'CONFIRM'], ['ui_touch_button', '19', '', 'CANCEL']])
prefix = SHELL.split("draw_category_frame software '' ''")[0]
prefix = 'RENKIT_COMPACT_MENUS=1\n' + prefix
with tempfile.TemporaryDirectory(prefix='renkit-compact-') as directory:
    fixture = Path(directory) / 'page.sh'
    for columns, rows in [(124,21),(100,21),(70,21),(124,22),(124,23)]:
        for number, page in enumerate(pages):
            calls = '\n'.join(shlex.join(args) for args in page)
            controls = [(args[1],args[3]) for args in page if args[0]=='ui_touch_button']
            mappings = ' '.join(f'right:{row}-{int(row)+1}:item-{row}' for row,_ in controls)
            fixture.write_text(prefix + calls + '\nui_prompt\n' + r'''
[ "$UI_LAYOUT_USABLE" = 1 ] || exit 95
for row in "${!UI_LEFT_TOP[@]}"; do
 printf 'RECT|left|%s|%s|%s|%s|%s\n' "$row" "${UI_LEFT_TOP[row]}" "${UI_LEFT_BOTTOM[row]}" "${UI_LEFT_COL[row]}" "${UI_LEFT_WIDTH[row]}" >&2
done
for row in "${!UI_RIGHT_TOP[@]}"; do
 printf 'RECT|right|%s|%s|%s|%s|%s\n' "$row" "${UI_RIGHT_TOP[row]}" "${UI_RIGHT_BOTTOM[row]}" "${UI_RIGHT_COL[row]}" "${UI_RIGHT_WIDTH[row]}" >&2
done
for row in "${!UI_ROW_MAP[@]}"; do printf 'ROW|%s|%s\n' "$row" "${UI_ROW_MAP[row]}" >&2; done
''' + '\n'.join('choice="$(read_menu_choice '+mappings+')"; printf "RESULT=%s\\n" "$choice"' for _ in controls))
            env = dict(os.environ,UI_TEST_ROOT=str(ROOT),UI_TEST_MODE='render',MOCK_COLS=str(columns),MOCK_ROWS=str(rows))
            # First render supplies the exact physical rectangles for click injection.
            first = subprocess.run(['bash',str(fixture)],env=env,input=b'',capture_output=True,timeout=10)
            check(first.returncode in (0,1),f'Menu {number} failed at {columns}x{rows}: {first.stderr!r}')
            frame=first.stdout.decode();check('窗口太小' not in frame,'Compact menu blocked')
            cells=screen_cells(frame)
            rects={}
            occupied={'left':set(),'right':set()}
            note_rows={}
            for line in first.stderr.decode().splitlines():
                values=line.split('|')
                if values[0]=='ROW':note_rows[int(values[1])]=int(values[2]);continue
                check(values[0]=='RECT',f'Unexpected stderr {line}')
                _,region,logical,top,bottom,col,width=values
                top,bottom,col,width=map(int,(top,bottom,col,width))
                check(1<=top<=bottom<rows and col+width<=columns,f'Offscreen control {line}')
                area={(r,c) for r in range(top,bottom+1) for c in range(col,col+width)}
                check(not occupied[region]&area,f'Overlapping controls {line}')
                occupied[region]|=area
                rects[region,int(logical)]=(top,bottom,col,width)
            for args in page[1:]:
                if args[0]!='ui_panel_line':continue
                row=note_rows[int(args[1])]
                col=next((c for (r,c),v in cells.items() if r==row and v[0]==args[3][:1]),None)
                check(col is not None,f'Missing note {args[3]}')
                check(not any(r==row for r,_ in occupied['right']),f'Note overlaps button {args[3]}')
            data=b''
            for logical,label in controls:
                top,bottom,col,width=rects['right',int(logical)]
                # Check the final screen, not only that text was emitted then overwritten.
                lines=[''.join(cells.get((r,c),('',0))[0] for c in range(col,col+width)) for r in range(top,bottom+1)]
                check(any(label[:min(5,len(label))] in line for line in lines),f'Hidden label {label}: {lines}')
                data+=click(col+1,(top+bottom)//2)
            if controls:
                result=subprocess.run(['bash',str(fixture)],env=env,input=data,capture_output=True,timeout=10)
                check(result.returncode==0,f'Click fixture failed {result.stderr!r}')
                actual=re.findall(r'RESULT=(item-\d+)',result.stdout.decode())
                check(actual==['item-'+row for row,_ in controls],f'Wrong action {actual}')
    # An unsupported/dense page stays protected across idle size polls.
    env["MOCK_ROWS"]="21"
    fixture.write_text(prefix + "draw_category_frame advanced 'DENSE' ''\n" +
                       '\n'.join(f"ui_panel_line {r} '' NOTE_{r}" for r in range(2,22)) +
                       "\nui_prompt\n[ \"$UI_LAYOUT_USABLE\" = 0 ]\nui_redraw_if_resized || true\n[ \"$UI_LAYOUT_USABLE\" = 0 ]\n")
    result=subprocess.run(['bash',str(fixture)],env=env,input=b'',capture_output=True,timeout=10)
    check(result.returncode==0 and '窗口太小' in result.stdout.decode(),'Idle poll released dense-page guard')
print(f'PASS: {len(pages)} real/representative desktop pages at five 21–23-row sizes; all controls visible, nonoverlapping and clickable, adjacent warnings preserved')
