// Static UI analysis only: downloaded plugin code is parsed, never evaluated.
import fs from 'node:fs';
import {parse} from './vendor/acorn/acorn.mjs';

const visible = new Set(['children','label','description','title','tooltip','placeholder','text','strTitle','strDescription','strOKButtonText','strCancelButtonText','sOperationText','aria-label']);
const technical = /^(?:Steam|SteamOS|Steam Deck|Linux|Windows|Flatpak|LSFG-VK|Lossless Scaling|OptiScaler|FSR[234]?|DLSS|HDR|DXVK|FIFO|Mailbox|FPS|FP16|VSync|Vulkan|OpenGL|GPU|CPU|DLL|Proton|Wine|AppID|ID|OK|N\/A|[0-9.]+ \| FFX [0-9.]+ SDK)$/i;
export function human(s) {
  const t=s.trim();
  return t.length>1 && t.length<1800 && /[A-Za-z]{2}/.test(t) && !technical.test(t) &&
    !/[\u3400-\u9fff\u3040-\u30ff\uac00-\ud7af]/.test(t) &&
    !/(?:https?:\/\/|data:|[\\/][\w.-]+[\\/]|#[0-9a-f]{3,8}\b|[A-Z_]{3,}=|\$\{|\{[^}]*[:;]|@keyframes|!important|^[-\w.]+\.(?:dll|sh|py|json|xz|asi|png|zip)$)/i.test(t) &&
    !/^[\w.-]+$/.test(t) || ['Install','Uninstall','Settings','Enabled','Disabled','Enable','Disable','Remove','Delete','Cancel','Close','Save','Default','Loading','Installing','Uninstalling','Configured','Error','Ready','Name','Rename','Create','Reset','Apply','Copy','Browse','Open','Refresh','Off','On','Yes','No','Back','Manual','Automatic'].includes(t);
}
function walk(node, visit, parent=null) {
  if (!node || typeof node!=='object') return;
  if (typeof node.type==='string') visit(node,parent);
  for (const [key,value] of Object.entries(node)) {
    if (['start','end','loc'].includes(key)) continue;
    if (Array.isArray(value)) for (const child of value) walk(child,visit,node);
    else if (value && typeof value==='object') walk(value,visit,node);
  }
}
const keyOf=n=>n?.computed ? n.key?.value : (n.key?.name??n.key?.value);
function analyze(code) {
  const ast=parse(code,{ecmaVersion:'latest',sourceType:'module'});
  const bindings=new Map();const parents=new WeakMap();
  walk(ast,(n,parent)=>{parents.set(n,parent);if(n.type==='VariableDeclarator' && n.id.type==='Identifier' && n.init) bindings.set(n.id.name,n.init);});
  function texts(n,seen=new Set()) {
    if(!n || seen.has(n)) return [];
    seen=new Set(seen).add(n);
    switch(n.type) {
      case 'Literal': return typeof n.value==='string' && human(n.value) ? [n.value] : [];
      case 'TemplateLiteral': return n.quasis.map(q=>q.value.cooked).filter(s=>s && human(s));
      case 'Identifier': return texts(bindings.get(n.name),seen);
      case 'ConditionalExpression': return [...texts(n.consequent,seen),...texts(n.alternate,seen)];
      case 'LogicalExpression': case 'BinaryExpression': return [...texts(n.left,seen),...texts(n.right,seen)];
      case 'ArrayExpression': return n.elements.flatMap(x=>texts(x,seen));
      case 'MemberExpression': {
        const object=n.object.type==='Identifier' ? bindings.get(n.object.name) : null;
        const key=n.computed?n.property.value:n.property.name;
        if(object?.type==='ObjectExpression') return object.properties.filter(p=>keyOf(p)===key).flatMap(p=>texts(p.value,seen));
        return [];
      }
      case 'CallExpression':
        // Native i18n fallback values are display text; keys and call arguments stay intact.
        if(n.callee.type==='Identifier' && n.callee.name==='t' && n.arguments.length>=2) return texts(n.arguments[1],seen);
        return [];
      default:return [];
    }
  }
  const regions=new Map();const titles=[];const literals=[];
  function add(n) { const values=[...new Set(texts(n))]; if(values.length) regions.set(`${n.start}:${n.end}`,{start:n.start,end:n.end,values}); }
  walk(ast,n=>{
    if(n.type==='Literal' && typeof n.value==='string') literals.push(n.value);
    if(n.type==='Property' && !n.method) {
      const key=keyOf(n);
      const owner=parents.get(parents.get(n));
      const codeElement=owner?.type==='CallExpression' && ['style','script'].includes(owner.arguments[0]?.value);
      if(visible.has(key) && !codeElement && (key!=='children' || owner?.type==='CallExpression')) add(n.value);
      if(key==='titleView') titles.push(n.value);
    }
    if(n.type==='CallExpression' && n.callee.type==='MemberExpression' &&
       !n.callee.computed && n.callee.property.name==='createElement' && !['style','script'].includes(n.arguments[0]?.value)) n.arguments.slice(2).forEach(add);
  });
  return {ast,regions:[...regions.values()],titles,literals};
}

export function inspect(code) {
  const a=analyze(code);
  let officialChinese=false;
  let templateKeys=[];const chinese=[];
  walk(a.ast,n=>{
    if(n.type!=='VariableDeclarator' || n.id.type!=='Identifier' || n.init?.type!=='ObjectExpression') return;
    const pairs=n.init.properties.filter(p=>p.type==='Property' && typeof p.value?.value==='string');
    if(n.id.name==='template') templateKeys=pairs.map(keyOf);
    if(/^(?:zh|zh_cn|schinese)$/i.test(n.id.name)) chinese.push(pairs);
  });
  for(const pairs of chinese) {
    const keys=new Set(pairs.map(keyOf));
    if(templateKeys.length>=20 && templateKeys.every(k=>keys.has(k)) && pairs.filter(p=>/[\u3400-\u9fff]/.test(p.value.value)).length>=20) officialChinese=true;
  }
  return {strings:[...new Set(a.regions.flatMap(r=>r.values))].sort(),titles:a.titles.length,literals:a.literals,official_chinese:officialChinese};
}
export function localize(code,dictionary,runtime) {
  const a=analyze(code);
  if(a.regions.length<3 || a.titles.length!==1) throw Error('Unsupported frontend layout; keeping published version');
  const missing=[...new Set(a.regions.flatMap(r=>r.values))].filter(s=>!dictionary[s]);
  if(missing.length) throw Error(`Untranslated UI strings: ${JSON.stringify(missing)}`);
  // Only wrap complete UI expressions. Never change constants, identifiers, action values or backend calls.
  const edits=[];
  for(const r of a.regions) {
    edits.push({at:r.start,s:'RenkitFramegenZH.text('});
    edits.push({at:r.end,s:','+JSON.stringify(r.values)+')'});
  }
  const title=a.titles[0];
  edits.push({at:title.start,s:'RenkitFramegenZH.title('});
  edits.push({at:title.end,s:')'});
  // Reverse insertion preserves every upstream byte and nested expression order.
  edits.sort((a,b)=>b.at-a.at);
  let result=code;
  for(const e of edits) result=result.slice(0,e.at)+e.s+result.slice(e.at);
  result='const RenkitFramegenZH = '+runtime.trim()+'('+JSON.stringify(dictionary)+');\n'+result;
  const rebuilt=parse(result,{ecmaVersion:'latest',sourceType:'module'});
  rebuilt.body.shift();
  function clean(n) {
    if(!n || typeof n!=='object') return n;
    if(n.type==='CallExpression' && n.callee.type==='MemberExpression' &&
       n.callee.object?.name==='RenkitFramegenZH' && ['text','title'].includes(n.callee.property.name)) return clean(n.arguments[0]);
    if(Array.isArray(n)) return n.map(clean);
    return Object.fromEntries(Object.entries(n).filter(([k])=>!['start','end','raw'].includes(k)).map(([k,v])=>[k,clean(v)]));
  }
  if(JSON.stringify(clean(rebuilt))!==JSON.stringify(clean(a.ast))) throw Error('Non-UI code changed');
  return result;
}

if(process.argv[1] && import.meta.url===new URL('file://'+process.argv[1]).href) {
  const [mode,input,dictPath,runtimePath,output]=process.argv.slice(2);
  const code=fs.readFileSync(input,'utf8');
  if(mode==='inspect') process.stdout.write(JSON.stringify(inspect(code))+'\n');
  else if(mode==='build') fs.writeFileSync(output,localize(code,JSON.parse(fs.readFileSync(dictPath)),fs.readFileSync(runtimePath,'utf8')));
  else throw Error('Usage: framegen_ui.mjs inspect FILE | build FILE DICTIONARY RUNTIME OUTPUT');
}
