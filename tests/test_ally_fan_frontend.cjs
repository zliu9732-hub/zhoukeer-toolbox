const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(process.argv[2] || 'work/ally-source/index.js', 'utf8');
const section = source.slice(source.indexOf('const FAN_MODES = ['), source.indexOf('const CpuSettingsSection ='));
let success = false;
const toast = [];
const values = [];
let cursor = 0;
let effect;
let interval;
let modal;
let calls = 0;
const actual = { mode: 'performance', available: true, speed: 5300, speed2: 4400 };
const ctx = {
  window: { SP_REACT: { createElement: (type, props, ...children) => ({ type, props, children }) } },
  useState(initial) {
    const index = cursor++;
    if (!(index in values)) values[index] = index === 3 ? false : index === 6 ? actual : initial;
    return [values[index], value => { values[index] = typeof value === 'function' ? value(values[index]) : value; }];
  },
  useEffect(fn) { effect = fn; },
  setInterval(fn) { interval = fn; return 1; }, clearInterval() {},
  getPerformanceProfiles: async () => ({ profiles: {}, current: 'performance' }),
  getCurrentTdp: async () => ({ cpu_temp: 53, gpu_temp: 50 }),
  getFanInfo: async () => actual,
  getTdpSettings: async () => ({ tdp: 30, tdp_override: true }),
  setFanMode: async () => { calls++; return success; },
  toaster: { toast: t => toast.push(t.body) },
  DFL: new Proxy({}, { get: (_, key) => key === 'showModal' ? (node) => { modal = node; return { Close() {} }; } : key }),
  sectionStyle: {}, infoRowStyle: {}, labelStyle: {}, valueStyle: {},
  translateProfileName: x => x, console,
};
vm.createContext(ctx);
vm.runInContext(section + '\nthis.render = PerformanceSection;', ctx);
function find(node, type) {
  if (!node || typeof node !== 'object') return null;
  if (node.type === type) return node;
  for (const child of node.children || []) {
    const result = find(child, type);
    if (result) return result;
  }
  return null;
}
(async () => {
  let tree = ctx.render();
  const dropdown = find(tree, 'DropdownItem');
  assert.equal(dropdown.props.label, '风扇控制');
  assert.equal(dropdown.props.rgOptions.some(m => m.data === 'full'), false);
  assert.match(JSON.stringify(tree), /5300 RPM/);
  assert.match(JSON.stringify(tree), /4400 RPM/);
  await dropdown.props.onChange({ data: 'quiet', label: '安静' });
  assert.match(toast.pop(), /修改失败/);
  assert.equal(values[5], 'performance');
  assert.equal(values[7], false);
  success = true;
  await dropdown.props.onChange({ data: 'performance', label: '性能' });
  assert.match(toast.pop(), /已确认/);
  assert.equal(values[5], 'performance');
  effect();
  await new Promise(resolve => setImmediate(resolve));
  actual.mode = 'quiet';
  actual.speed2 = 3100;
  await interval();
  assert.equal(values[5], 'quiet');
  assert.equal(values[6].speed2, 3100);
  actual.full_speed_available = true;
  cursor = 0;
  tree = ctx.render();
  const fullDropdown = find(tree, 'DropdownItem');
  assert.equal(fullDropdown.props.rgOptions.some(m => m.data === 'full'), true);
  const beforeConfirm = calls;
  await fullDropdown.props.onChange({ data: 'full', label: '全速' });
  assert.equal(calls, beforeConfirm);
  assert.match(modal.props.strDescription, /均衡/);
  modal.props.onCancel();
  assert.equal(calls, beforeConfirm);
  await fullDropdown.props.onChange({ data: 'full', label: '全速' });
  actual.mode = 'full';
  modal.props.onOK();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(calls, beforeConfirm + 1);
  assert.match(toast.pop(), /100% 请求/);
  assert.equal(values[5], 'full');
  console.log('Frontend checks passed: dual RPM, failure feedback, actual-state refresh, periodic updates.');
})().catch(error => { console.error(error); process.exitCode = 1; });
