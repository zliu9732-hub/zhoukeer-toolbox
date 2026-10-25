// Validate the actual shipped frontend: full AST comparison and mocked UI/RPC.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {parse} from './vendor/acorn/acorn.mjs';

const [beforePath, afterPath] = process.argv.slice(2);
const before = fs.readFileSync(beforePath, 'utf8');
const after = fs.readFileSync(afterPath, 'utf8');
const NAME = '屏幕色彩（Screen Colors）';
const a = parse(before, {ecmaVersion: 'latest', sourceType: 'module'});
const b = parse(after, {ecmaVersion: 'latest', sourceType: 'module'});
const i18n = new Set(['DICT', 'LANG', 'detectLang', 't']);
a.body = a.body.filter(n => !i18n.has(n.id?.name) &&
    !(n.type === 'VariableDeclaration' && n.declarations.some(d => i18n.has(d.id.name))));
const index = b.body.findIndex(n => n.type === 'VariableDeclaration' && n.declarations.some(d => d.id.name === 'manifest'));
assert.ok(index > 0);
b.body = b.body.slice(index);
const oldError = '[@decky/api]: Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.';
const newError = '[@decky/api]: 无法连接插件商城：接口尚未初始化，请重启插件商城后再试。';
function clean(n) {
    if (!n || typeof n !== 'object') return n;
    if (Array.isArray(n)) return n.map(clean);
    if (n.type === 'CallExpression' && ['renkitScreenTitle','renkitScreenDetail'].includes(n.callee.name)) return clean(n.arguments[0]);
    if (n.type === 'Literal' && [NAME, newError].includes(n.value)) n = {...n, value: n.value === NAME ? 'Screen Colors' : oldError};
    return Object.fromEntries(Object.entries(n).filter(([k]) => !['start','end','raw'].includes(k)).map(([k,v]) => [k, clean(v)]));
}
assert.deepEqual(clean(b), clean(a), 'non-display code, RPCs, values or callbacks changed');

function runtime(language = 'zh-CN', fallback = false) {
    const calls = [], connects = [], timers = [];
    let states = [null, false], hook = 0;
    const jsx = (type, props) => ({type, props: props || {}});
    const context = vm.createContext({
        console: {warn() {}}, navigator: {language, languages: [language]},
        window: {__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit: {
            connect(version, name) {
                connects.push([version, name]);
                if (fallback && version === 2) throw new Error('mock old API');
                return {_version: version, callable: method => async (...args) => { calls.push([method, args]); return states[0]; }};
            }
        }},
        SP_REACT: {
            createContext: value => ({value}), createElement: jsx,
            useState: () => { const slot = hook++; return [states[slot], value => {states[slot] = typeof value === 'function' ? value(states[slot]) : value;}]; },
            useRef: value => ({current: value}), useEffect() {}
        },
        SP_JSX: {jsx, jsxs: jsx, Fragment: 'Fragment'},
        DFL: Object.fromEntries(['ButtonItem','DialogButton','Field','Focusable','PanelSection','PanelSectionRow','SliderField','ToggleField'].map(k => [k,k]).concat([['staticClasses',{Title:'title'}]])),
        setTimeout: fn => {timers.push(fn); return timers.length;}, clearTimeout() {}
    });
    vm.runInContext(after.replace('export { index as default };','globalThis.screenPlugin = index;'), context, {timeout: 1000});
    return {
        context, calls, connects, timers,
        render(state, advanced = false) { states = [state, advanced]; hook = 0; return vm.runInContext('ColorPanel()', context, {timeout: 1000}); },
        translate(key) { context.key = key; return vm.runInContext('t(key)', context); },
        detail(value) { context.detail = value; return vm.runInContext('renkitScreenDetail(detail)', context); }
    };
}
function nodes(node) {
    if (node == null || typeof node === 'boolean') return [];
    if (Array.isArray(node)) return node.flatMap(nodes);
    if (typeof node !== 'object') return [node];
    return [node, ...nodes(node.props?.children)];
}
function texts(node) {
    return nodes(node).flatMap(n => typeof n === 'string' ? [n] : ['title','label','description'].flatMap(k => typeof n.props?.[k] === 'string' ? [n.props[k]] : []));
}
const model = {
    supported: true, detail: '', active: 'native', presets: ['cine','vivo','comodo'],
    color: {saturation:100,vibrance:0,temperature:0,contrast:0,gamma:0,black:0,hue:0,gain_r:100,gain_g:100,gain_b:100},
    native: {saturation:100,vibrance:0,temperature:0,contrast:0,gamma:0,black:0,hue:0,gain_r:100,gain_g:100,gain_b:100},
    ranges: Object.fromEntries(['saturation','vibrance','temperature','contrast','gamma','black','hue','gain_r','gain_g','gain_b'].map(k => [k, [0,200]]))
};
for (const language of ['zh-CN','en-US','es-ES']) {
    for (const fallback of [false,true]) {
        const r = runtime(language, fallback);
        assert.ok(r.connects.length >= 1 && r.connects.every(c => c[1] === NAME));
        assert.equal(r.translate('field.gain_r'), '红色强度');
        assert.ok(texts(r.render(null)).includes('正在读取屏幕设置…'));
        for (const detail of ['sin probar','sin socket gamescope en /run/user/*/gamescope-*','socket=/run/user/1000/gamescope-0 version rc=1','unknown future error']) {
            const view = r.render({...model, supported:false, detail});
            const body = texts(view).join(' ');
            assert.ok(body.includes('请返回游戏模式后使用'));
            assert.ok(!/[A-Za-z]/.test(r.detail(detail)), 'backend UI detail not translated');
        }
        for (const active of ['native','custom','oled','cine','vivo','comodo']) {
            const view = r.render({...model, active}, true), strings = texts(view);
            for (const required of ['一键效果','当前效果','手动调整','进阶调整','色彩浓度','鲜艳程度','色温（偏暖／偏冷）','明暗对比','画面亮度','暗部深浅','色调','红色强度','绿色强度','蓝色强度','恢复原始色彩','分别调整颜色']) assert.ok(strings.includes(required), required);
            assert.equal(nodes(view).filter(n => n?.type === 'SliderField').length, 10);
            assert.ok(strings.some(s => s.includes(r.translate(['native','custom','oled'].includes(active) ? `active.${active}` : `preset.${active}`))));
            assert.ok(!strings.some(s => /^(Current|Native|Custom|Cinema|Vivid|Comfort|Presets|Manual adjustment|Advanced|Hue|Gain)/.test(s)));
        }
        const header = vm.runInContext('screenPlugin().titleView', r.context);
        assert.ok(texts(header).includes('RenAmamiya汉化'));
        assert.ok(texts(header).includes(NAME));
    }
}
const r = runtime(), view = r.render({...model,active:'custom'}, true);
const controls = nodes(view);
await controls.find(n => n?.type === 'DialogButton' && n.props.children === '鲜艳').props.onClick();
await controls.find(n => n?.type === 'ButtonItem' && n.props.children === '类 OLED 效果').props.onClick();
await controls.find(n => n?.type === 'ButtonItem' && n.props.children === '恢复原始色彩').props.onClick();
controls.find(n => n?.type === 'SliderField' && n.props.label === '红色强度').props.onChange(125);
r.timers.at(-1)();
await Promise.resolve();
assert.deepEqual(JSON.parse(JSON.stringify(r.calls)), [['apply_preset',['vivo']],['apply_oled_look',[]],['reset',[]],['set_color',[{gain_r:125}]]]);
console.log('PASS: Screen Colors complete UI states, both API branches, callbacks and non-display AST');
