// Static inventory and comparison only. Downloaded plugin code is never executed.
import fs from 'node:fs';
import {parse} from './vendor/acorn/acorn.mjs';
import {inspect as inspectUI, human} from './framegen_ui.mjs';

const guard='请通过 Renkit 安装/更新 ThemeHub 中文版，主题和设置会保留。';
const guards=[
  ['async function installFirmware(release, current) {', `\n    throw new Error(${JSON.stringify(guard)});`],
  ['const install = async (release) => {', `\n        setMessage(${JSON.stringify(guard)});\n        return;`],
];
const content='children: [RenkitThemeHubJSX.jsx(Panel, {}), RenkitThemeHubJSX.jsx(Diagnostics, {})]';
const signed='children: [RenkitThemeHubJSX.jsx("div", { style: { color: "#d9a441", fontSize: "14px", fontWeight: "bold", padding: "8px 12px" }, children: "RenAmamiya汉化" }), RenkitThemeHubJSX.jsx(Panel, {}), RenkitThemeHubJSX.jsx(Diagnostics, {})]';
function walk(node,visit) {
  if(!node || typeof node!=='object')return;
  if(node.type)visit(node);
  for(const [key,value]of Object.entries(node)) {
    if(['start','end'].includes(key))continue;
    if(Array.isArray(value))value.forEach(child=>walk(child,visit));
    else if(value && typeof value==='object')walk(value,visit);
  }
}
export function inspect(code) {
  const info=inspectUI(code),strings=new Set(info.strings),templates=new Map();
  if(info.titles!==1 || JSON.stringify(info.api_plugin_names)!==JSON.stringify(['ThemeHub']))throw Error('ThemeHub identity/layout changed');
  const ast=parse(code,{ecmaVersion:'latest',sourceType:'module'});
  walk(ast,node=>{
    // Data-driven option names are also rendered by the existing JSX adapter.
    if(node.type==='Property' && ['name','displayName','caption','hint'].includes(node.key?.name) && typeof node.value?.value==='string' && human(node.value.value))strings.add(node.value.value);
    if(node.type==='TemplateLiteral') {
      const parts=[];
      node.quasis.forEach((part,i)=>{parts.push(part.value.cooked??'');if(i<node.expressions.length)parts.push(null);});
      if(parts.some(part=>typeof part==='string' && strings.has(part)) && parts.every(part=>part===null || part.length<1800))templates.set(JSON.stringify(parts),parts);
    }
  });
  const {literals,...summary}=info;
  return {...summary,strings:[...strings].sort(),templates:[...templates.values()]};
}
export function verify(original,localized) {
  const ast=source=>parse(source,{ecmaVersion:'latest',sourceType:'module'});
  const before=ast(original),after=ast(localized);
  const first=before.body[0];
  if(first.type!=='VariableDeclaration' || first.declarations[0]?.id?.name!=='manifest')throw Error('ThemeHub frontend layout changed');
  const starts=after.body.filter(node=>node.type==='VariableDeclaration' && node.declarations[0]?.id?.name==='manifest');
  if(starts.length!==1)throw Error('ThemeHub frontend identity is ambiguous');
  let body=localized.slice(starts[0].start);
  for(const [anchor,insertion]of guards) {
    if(body.split(anchor+insertion).length!==2)throw Error('Missing translated updater guard');
    body=body.replace(anchor+insertion,anchor);
  }
  if(body.split(signed).length!==2)throw Error('Missing original Chinese attribution');
  body=body.replace(signed,content).replace(/\bRenkitThemeHubJSX\.(jsx|jsxs)\(/g,'SP_JSX.$1(');
  function clean(node) {
    if(!node || typeof node!=='object')return node;
    if(Array.isArray(node))return node.map(clean);
    return Object.fromEntries(Object.entries(node).filter(([key])=>!['start','end','raw'].includes(key)).map(([key,value])=>[key,clean(value)]));
  }
  if(JSON.stringify(clean(before))!==JSON.stringify(clean(ast(body))))throw Error('ThemeHub functional code changed');
  return true;
}
if(process.argv[1] && import.meta.url===new URL('file://'+process.argv[1]).href) {
  const [mode,input,output]=process.argv.slice(2),code=fs.readFileSync(input,'utf8');
  if(mode==='inspect')process.stdout.write(JSON.stringify(inspect(code))+'\n');
  else if(mode==='verify')verify(code,fs.readFileSync(output,'utf8'));
  else throw Error('Unsupported ThemeHub UI command');
}
