// Display localization only. No device state or control values are changed.
const gfgZh = __GFG_ZH__;
const gfgRules = [
  [/^(.+) FPS · (.+)$/, m => `${m[1]} 帧 · ${gfgText(m[2])}`],
  [/^OS: (.*)$/, m => `系统：${m[1]}`],
  [/^Packages: (.*)$/, m => `系统组件：${m[1]}`],
  [/^APU at (.+) C: the Governor lowers the limit$/, m => `温度达到 ${m[1]} °C，正在降低功耗上限。`],
  [/^battery below (.+) %: x3.75 allowed$/, m => `电量低于 ${m[1]}%，允许使用 ×3.75 补帧。`],
  [/^gamescopectl (.*): (.*)$/, m => `画面引擎设置失败。诊断详情：${m[1]}：${m[2]}`],
  [/^\[Errno (\d+)\] (Permission denied|No such file or directory|Read-only file system)(.*)$/, m => `${{ 'Permission denied':'权限不足','No such file or directory':'找不到文件或目录','Read-only file system':'系统当前禁止写入'}[m[2]]}（${m[1]}）${m[3]}`],
  [/^(.*) · (Autopilot|Battery|Balanced|Quality)$/, m => `${m[1]} · ${gfgText(m[2])}`],
  [/^(\d+(?:\.\d+)?) REAL$/, m => `${m[1]} 原生`],
  [/^App (\d+)$/, m => `游戏 ${m[1]}`],
  [/^now (.+)$/, m => `当前：${gfgText(m[1])}`],
  [/^Custom · (.*)$/, m => `自定义 · ${gfgText(m[1])}`],
  [/^EFFECTS · (\d+) ON$/, m => `画面效果 · 已开启 ${m[1]} 项`],
  [/^EFFECTS · NONE$/, () => '画面效果 · 未启用'],
  [/^The game is capped at (.+) FPS, generation fills (.+) Hz\.$/, m => `原生帧率限制为 ${m[1]} 帧，补帧后填满 ${m[2]} Hz 刷新率。`],
  [/^Generating · (.+)$/, m => `正在补帧 · ${m[1]}`],
  [/^(.+) GHz \((.+)%\)( · proven)?$/, m => `${m[1]} GHz（${m[2]}%）${m[3] ? ' · 已验证' : ''}`],
  [/^Full clock · (.*)$/, m => `不限制频率 · ${gfgText(m[1])}`],
  [/^(.+) GPU clock\/W · (\d+) A\/B$/, m => `显卡每瓦频率 ${m[1]} · 对比 ${m[2]} 次`],
  [/^(.+) FPS \(Auto, floor (.+)\)$/, m => `${m[1]} 帧（自动，最低 ${m[2]} 帧）`],
  [/^(.+) · rev (\d+)$/, m => `${gfgText(m[1])} · 修订 ${m[2]}`],
  [/^(.+) W of (.+) W$/, m => `${m[1]} W / 上限 ${m[2]} W`],
  [/^(.+) MHz cap · now (.+) MHz$/, m => `上限 ${m[1]} MHz · 当前 ${m[2]} MHz`],
  [/^Auto · (.+) MHz$/, m => `自动 · ${m[1]} MHz`],
  [/^SteamOS · (.+) rpm$/, m => `SteamOS · ${m[1]} 转/分`],
  [/^Saved to (.+)$/, m => `已保存至 ${m[1]}`],
  [/^(.+): done$/, m => `${gfgText(m[1])}：已完成`],
  [/^(.+) failed$/, m => `${gfgText(m[1])}失败`],
  [/^(\d+) checks? failed: see the list above$/, m => `${m[1]} 项检查未通过，请查看上方列表。`],
  [/^GFG Extreme · (.+)$/, m => `GFG Extreme · ${gfgText(m[1])}`],
  [/^Benchmark done\. (.*)$/, m => `测试完成。${m[1]}`],
  [/^point (.+) holds: locked$/, m => `${m[1]} 帧目标已稳定并锁定。`],
  [/^point (.+) did not hold; next try in (.+) s$/, m => `${m[1]} 帧目标未能保持，将在 ${m[2]} 秒后重试。`],
  [/^trying point (.+)$/, m => `正在尝试 ${m[1]} 帧目标。`],
  [/^measured: the game holds (.+) fps; locked (.+)$/, m => `已测得游戏可保持 ${m[1]} 帧，当前锁定 ${m[2]} 帧。`],
  [/^Autopilot power target: point (.+) needs (.+) W, over (.+) W -> (.+)$/, m => `${m[1]} 帧需要 ${m[2]} W，超过 ${m[3]} W 的省电目标，调整至 ${m[4]} 帧。`],
  [/^game fell to (.+) fps at full power: point (.+)$/, m => `最高功耗下游戏降至 ${m[1]} 帧，目标调整为 ${m[2]} 帧。`],
  [/^the game does not hold (.+) \(this mode's lowest point\) even at full power$/, m => `即使使用最高功耗，也无法保持本模式最低的 ${m[1]} 帧目标。`],
  [/^Plugin carries Gamescope KEDAVRA (.+)$/, m => `插件自带 Gamescope KEDAVRA ${m[1]}`],
  [/^Installed: (.+)$/, m => `已安装：${m[1]}`],
  [/^Installed Gamescope (.+), plugin carries (.+): press Reinstall and reboot$/, m => `当前引擎 ${m[1]}，插件自带 ${m[2]}。请重新安装引擎并重启。`],
  [/^Boot step: (.*)$/, m => `开机加载状态：${gfgText(m[1])}`],
  [/^gamescope pid (\d+): (.+)$/, m => `画面引擎进程 ${m[1]}：${m[2] === 'stock' ? '系统原版' : m[2]}`],
  [/^Engine status is (.+) s old$/, m => `引擎状态已超过 ${m[1]} 秒未更新。`],
  [/^(.+) not found: is this SteamOS Gaming Mode\?$/, m => `找不到 ${m[1]}，请确认正在 SteamOS 游戏模式运行。`],
  [/^Gamescope KEDAVRA would not start, missing libraries: (.+)$/, m => `引擎无法启动，缺少运行组件：${m[1]}`],
  [/^Gamescope KEDAVRA --version failed: (.*)$/, m => `引擎启动检查失败。诊断详情：${m[1]}`],
  [/^runtime has no lib\/(.+): the zip was built by an old version$/, m => `安装包缺少运行组件 ${m[1]}，请重新下载完整包。`],
  [/^the loader exited with code (-?\d+)$/, m => `运行组件检查退出，返回值 ${m[1]}。`],
  [/^unknown preset (.+)$/, m => `无法识别画面预设：${m[1]}`],
  [/^unknown convar (.+)$/, m => `无法识别引擎设置：${m[1]}`],
  [/^bad value for (.+)$/, m => `引擎设置 ${m[1]} 的值无效。`],
  [/^Could not change GSF Kedavra's settings: (.*)$/, m => `无法修改独立版引擎的设置：${gfgText(m[1])}`],
  [/^(.+) \(retry in (.+) s\)$/, m => `${gfgText(m[1])}（${m[2]} 秒后重试）`],
  [/^(get_state|get_catalog|set_profile|drop_game_profile|set_section|engine_install|engine_uninstall|reboot|diagnose|run_bench|save_report|start_capture|stop_capture|list_captures|get_logs|take_over): (.*)$/, m => `${gfgCalls[m[1]]}：${gfgText(m[2])}`],
  [/^(setcap|systemctl enable): (.*)$/, m => `${m[1] === 'setcap' ? '设置引擎权限失败' : '启用开机引擎失败'}。诊断详情：${m[2]}`]
];
const gfgCalls = {get_state:'读取运行状态失败',get_catalog:'读取画面效果失败',set_profile:'保存游戏设置失败',drop_game_profile:'恢复通用设置失败',set_section:'保存设置失败',engine_install:'安装引擎失败',engine_uninstall:'移除引擎失败',reboot:'重启失败',diagnose:'检查失败',run_bench:'显卡测试失败',save_report:'保存报告失败',start_capture:'开始记录失败',stop_capture:'停止记录失败',list_captures:'读取记录失败',get_logs:'读取日志失败',take_over:'接管引擎失败'};
function gfgText(value) {
  if (Array.isArray(value)) return value.map(gfgText);
  if (typeof value !== 'string' || !value) return value;
  if (Object.prototype.hasOwnProperty.call(gfgZh,value)) return gfgZh[value];
  for (const [rule,replace] of gfgRules) { const match=value.match(rule); if(match)return replace(match); }
  for(const key of Object.keys(gfgZh).filter(k=>k.length>=24 && /[ .:]/.test(k)).sort((a,b)=>b.length-a.length)) { if(value.startsWith(key))return gfgZh[key]+gfgText(value.slice(key.length)); }
  if(value.includes(' + '))return value.split(' + ').map(gfgText).join(' + ');
  if(value.includes('\n'))return value.split('\n').map(gfgText).join('\n');
  return value;
}
function gfgCapture(value) {
  if(typeof value==='string')return gfgText(value);
  if(Array.isArray(value))return value.length ? '记录文件：'+value.join('、') : '暂无记录。';
  if(!value)return '暂无记录。';
  if(value.summary){const s=value.summary;return `${s.pass ? '分析通过' : '分析未通过'} · ${s.rows ?? '—'} 条记录 · 帧时间偏差 P95 ${s.p95_ms ?? '—'} ms / P99 ${s.p99_ms ?? '—'} ms · 漏帧 ${s.missed_pct ?? '—'}%${value.report ? ' · 报告：'+value.report : ''}`;}
  if(value.path)return `正在记录 · 已进行 ${value.elapsed_s ?? 0} 秒 · ${value.path}`;
  if(value.ok===false)return '记录未完成。诊断详情：'+gfgText(value.log || value.error || '请重新尝试');
  return '记录已完成。'+(value.report ? '报告：'+value.report : '');
}
function gfgTitle(original) {
  __GFG_CREDIT_NODE__
}
