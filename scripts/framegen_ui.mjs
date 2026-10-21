// Static UI analysis only: downloaded plugin code is parsed, never evaluated.
import fs from 'node:fs';
import {parse} from './vendor/acorn/acorn.mjs';

const visible = new Set(['children','label','description','details','title','tooltip','placeholder','text','body','alt','strTitle','strDescription','strOKButtonText','strCancelButtonText','sOperationText','aria-label']);
const technical = /^(?:Steam|SteamOS|Steam Deck|Linux|Windows|Flatpak|LSFG-VK|Lossless Scaling|OptiScaler|FSR[234]?|DLSS|HDR|DXVK|FIFO|Mailbox|FPS|FP16|VSync|Vulkan|OpenGL|GPU|CPU|DLL|Proton|Wine|AppID|ID|OK|N\/A|[0-9.]+ \| FFX [0-9.]+ SDK)$/i;
export function human(s) {
  const t=s.trim();
  return t.length>1 && t.length<1800 && /[A-Za-z]{2}/.test(t) && !technical.test(t) &&
    !/[\u3400-\u9fff\u3040-\u30ff\uac00-\ud7af]/.test(t) &&
    !/(?:https?:\/\/|data:|[\\/][\w.-]+[\\/]|#[0-9a-f]{3,8}\b|[A-Z_]{3,}=|\$\{|\{[^}]*[:;]|@keyframes|!important|^[-\w.]+\.(?:dll|sh|py|json|xz|asi|png|zip)$)/i.test(t);
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
  const parents=new WeakMap(),scopes=new WeakMap();
  const rootScope={parent:null,bindings:new Map(),functions:new Map()};
  function index(n,scope,parent=null) {
    if(!n || typeof n!=='object') return;
    if(Array.isArray(n)) {n.forEach(child=>index(child,scope,parent));return;}
    parents.set(n,parent);
    if(n.type==='FunctionDeclaration' && n.id) scope.functions.set(n.id.name,n);
    if(n.type==='VariableDeclarator' && n.id.type==='Identifier') {
      scope.bindings.set(n.id.name,n.init);
      if(/Function/.test(n.init?.type??'')) scope.functions.set(n.id.name,n.init);
    }
    if(/Function/.test(n.type??'') || n.type==='BlockStatement') {
      scope={parent:scope,bindings:new Map(),functions:new Map()};
      for(const parameter of n.params??[]) walk(parameter,p=>{if(p.type==='Identifier') scope.bindings.set(p.name,null);});
    }
    scopes.set(n,scope);
    for(const [key,value] of Object.entries(n)) if(!['start','end','loc'].includes(key)) {
      if(Array.isArray(value)) value.forEach(child=>index(child,scope,n));
      else if(value && typeof value==='object') index(value,scope,n);
    }
  }
  index(ast,rootScope);
  function lookup(name,node,type='bindings') {
    for(let scope=scopes.get(node);scope;scope=scope.parent) {
      if(scope[type].has(name)) return scope[type].get(name);
      if(type==='functions' && scope.bindings.has(name)) return null;
    }
    return null;
  }
  function texts(n,seen=new Set()) {
    if(!n || seen.has(n)) return [];
    seen=new Set(seen).add(n);
    switch(n.type) {
      case 'Literal': return typeof n.value==='string' && human(n.value) ? [n.value] : [];
      case 'TemplateLiteral': return [...n.quasis.map(q=>q.value.cooked).filter(s=>s && human(s)),...n.expressions.flatMap(x=>texts(x,seen))];
      case 'Identifier': return texts(lookup(n.name,n),seen);
      case 'ConditionalExpression': return [...texts(n.consequent,seen),...texts(n.alternate,seen)];
      case 'LogicalExpression': case 'BinaryExpression': return [...texts(n.left,seen),...texts(n.right,seen)];
      case 'ArrayExpression': return n.elements.flatMap(x=>texts(x,seen));
      case 'MemberExpression': {
        const object=n.object.type==='Identifier' ? lookup(n.object.name,n) : null;
        const key=n.computed?n.property.value:n.property.name;
        if(object?.type==='ObjectExpression') return object.properties.filter(p=>keyOf(p)===key).flatMap(p=>texts(p.value,seen));
        return [];
      }
      case 'CallExpression':
        if(n.callee.type==='MemberExpression' && ['join','filter'].includes(n.callee.property?.name)) return texts(n.callee.object,seen);
        // Native i18n fallback values are display text; keys and call arguments stay intact.
        if(n.callee.type==='Identifier' && n.callee.name==='t' && n.arguments.length>=2) return texts(n.arguments[1],seen);
        if(n.callee.type==='Identifier' && lookup(n.callee.name,n,'functions')) {
          const fn=lookup(n.callee.name,n,'functions'), values=[];
          function returns(body) {
            if(!body || typeof body!=='object') return;
            if(body.type==='ReturnStatement') {values.push(...texts(body.argument,new Set(seen).add(n)));return;}
            if(/Function/.test(body.type??'')) return;
            for(const child of Object.values(body)) Array.isArray(child)?child.forEach(returns):returns(child);
          }
          if(!seen.has(fn)) {
            seen.add(fn);
            if(fn.body.type==='BlockStatement') returns(fn.body);
            else values.push(...texts(fn.body,seen));
          }
          return values;
        }
        return [];
      default:return [];
    }
  }
  function nativeText(n,seen=new Set()) {
    if(!n || seen.has(n)) return true;
    seen=new Set(seen).add(n);
    if(n.type==='CallExpression' && n.callee.type==='Identifier' && n.callee.name==='t' && n.arguments.length>=2) return true;
    if(n.type==='Identifier') return nativeText(lookup(n.name,n),seen);
    if(n.type==='ConditionalExpression') return nativeText(n.consequent,seen) && nativeText(n.alternate,seen);
    if(['LogicalExpression','BinaryExpression'].includes(n.type)) return nativeText(n.left,seen) && nativeText(n.right,seen);
    if(n.type==='ArrayExpression') return n.elements.every(x=>nativeText(x,seen));
    if(n.type==='TemplateLiteral') return !n.quasis.some(q=>human(q.value.cooked??'')) && n.expressions.every(x=>nativeText(x,seen));
    return texts(n).length===0;
  }
  const regions=new Map();const titles=[];const literals=[];const displayNames=[];const toasts=[];
  function add(n,message=false,shorthandKey=null) {
    const values=[...new Set(texts(n))];
    if(values.length || message) regions.set(`${n.start}:${n.end}`,{start:n.start,end:n.end,values,message:message && !values.length,shorthandKey,native:nativeText(n)});
  }
  walk(ast,n=>{
    if(n.type==='Literal' && typeof n.value==='string') literals.push(n.value);
    if(n.type==='Property' && !n.method && parents.get(n)?.type==='ObjectExpression') {
      const key=keyOf(n);
      const owner=parents.get(parents.get(n));
      const codeElement=owner?.type==='CallExpression' && ['style','script'].includes(owner.arguments[0]?.value);
      if(visible.has(key) && !codeElement && (key!=='children' || owner?.type==='CallExpression')) add(n.value,['description','body'].includes(key),n.shorthand?key:null);
      if(key==='titleView') titles.push(n.value);
    }
    if(n.type==='CallExpression' && n.callee.type==='MemberExpression' &&
       !n.callee.computed && n.callee.property.name==='createElement' && !['style','script'].includes(n.arguments[0]?.value)) n.arguments.slice(2).forEach(node=>add(node));
    if(n.type==='CallExpression' && n.callee.type==='Identifier' && n.callee.name==='definePlugin') {
      const fn=n.arguments[0];
      if(fn?.body?.type==='BlockStatement') for(const statement of fn.body.body) {
        if(statement.type==='ReturnStatement' && statement.argument?.type==='ObjectExpression') {
          for(const property of statement.argument.properties) if(keyOf(property)==='name') {add(property.value);displayNames.push(property.value);}
        }
      }
    }
    if(n.type==='CallExpression' && n.callee.type==='Identifier' && /^show(?:Success|Error)?Toast$/.test(n.callee.name)) n.arguments.forEach(node=>add(node));
    if(n.type==='CallExpression' && n.callee.type==='MemberExpression' && n.callee.property?.name==='toast' && n.arguments[0]?.type==='ObjectExpression') toasts.push(n.arguments[0]);
  });
  const apiPluginNames=[];const registrations=[];
  walk(ast,n=>{
    // @decky/api registers calls under this exact name, not the visible title.
    if(n.type!=='CallExpression' || n.callee.type!=='MemberExpression' ||
       n.callee.property.name!=='connect' || n.arguments.length<2) return;
    const name=n.arguments[1];
    registrations.push(name);
    if(name.type==='CallExpression' && name.callee.object?.name==='RenkitFramegenZH' &&
       name.callee.property?.name==='registration' && typeof name.arguments[1]?.value==='string') apiPluginNames.push(name.arguments[1].value);
    if(name.type==='Literal' && typeof name.value==='string') apiPluginNames.push(name.value);
    if(name.type==='MemberExpression' && name.object.type==='Identifier') {
      const object=lookup(name.object.name,name);
      const key=name.computed?name.property.value:name.property.name;
      if(object?.type==='ObjectExpression') {
        for(const p of object.properties) if(keyOf(p)===key && typeof p.value?.value==='string') apiPluginNames.push(p.value.value);
      }
    }
  });
  return {ast,regions:[...regions.values()],titles,literals,displayNames,registrations,toasts,apiPluginNames:[...new Set(apiPluginNames)]};
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
  // A full locale table alone does not prove the UI actually uses it. Direct
  // English labels outside native t() calls still require our display overlay.
  if(a.regions.some(r=>!r.native && r.values.some(s=>!['Decky LSFG-VK','Decky Framegen'].includes(s)))) officialChinese=false;
  return {strings:[...new Set(a.regions.flatMap(r=>r.values))].sort(),titles:a.titles.length,literals:a.literals,official_chinese:officialChinese,api_plugin_names:a.apiPluginNames};
}
export function localize(code,dictionary,runtime,registrationName=null) {
  const a=analyze(code);
  if(a.regions.length<3 || a.titles.length!==1) throw Error('Unsupported frontend layout; keeping published version');
  const missing=[...new Set(a.regions.flatMap(r=>r.values))].filter(s=>!dictionary[s]);
  if(missing.length) throw Error(`Untranslated UI strings: ${JSON.stringify(missing)}`);
  // Wrap UI expressions without changing constants, identifiers or action values.
  // The explicitly validated registration alias below is the only API-boundary mapping.
  const edits=[];
  for(const r of a.regions) {
    if(r.message) {
      edits.push({at:r.start,s:(r.shorthandKey?r.shorthandKey+':':'')+'RenkitFramegenZH.message('});
      edits.push({at:r.end,s:')'});
      continue;
    }
    edits.push({at:r.start,s:(r.shorthandKey?r.shorthandKey+':':'')+'RenkitFramegenZH.text('});
    edits.push({at:r.end,s:','+JSON.stringify(r.values)+')'});
  }
  const title=a.titles[0];
  edits.push({at:title.start,s:'RenkitFramegenZH.title('});
  edits.push({at:title.end,s:')'});
  for(const toast of a.toasts) {
    edits.push({at:toast.start,s:'RenkitFramegenZH.toast('});
    edits.push({at:toast.end,s:')'});
  }
  // Decky uses the manifest name for both sidebar text and Python routing.
  // Rename both ends together; the old failure renamed only plugin.json.
  if(registrationName) {
    if(!a.registrations.length || a.apiPluginNames.length!==1) throw Error('Ambiguous backend registration');
    for(const registration of a.registrations) {
      edits.push({at:registration.start,s:'RenkitFramegenZH.registration('});
      edits.push({at:registration.end,s:','+JSON.stringify(registrationName)+')'});
    }
    walk(a.ast,n=>{
      if(n.type==='Literal' && typeof n.value==='string' && n.value.startsWith('http://127.0.0.1:1337/plugins/'+a.apiPluginNames[0]+'/')) {
        edits.push({at:n.start,s:'RenkitFramegenZH.resource('});
        edits.push({at:n.end,s:','+JSON.stringify(a.apiPluginNames[0])+','+JSON.stringify(registrationName)+')'});
      }
    });
  }
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
       n.callee.object?.name==='RenkitFramegenZH' && ['text','title','registration','resource','message','toast'].includes(n.callee.property.name)) return clean(n.arguments[0]);
    if(Array.isArray(n)) return n.map(clean);
    return Object.fromEntries(Object.entries(n).filter(([k])=>!['start','end','raw','shorthand'].includes(k)).map(([k,v])=>[k,clean(v)]));
  }
  if(JSON.stringify(clean(rebuilt))!==JSON.stringify(clean(a.ast))) throw Error('Non-UI code changed');
  if(registrationName && JSON.stringify(inspect(result).api_plugin_names)!==JSON.stringify([registrationName])) throw Error('Backend registration alias mismatch');
  return result;
}

if(process.argv[1] && import.meta.url===new URL('file://'+process.argv[1]).href) {
  const [mode,input,dictPath,runtimePath,output,registrationName]=process.argv.slice(2);
  const code=fs.readFileSync(input,'utf8');
  if(mode==='inspect') process.stdout.write(JSON.stringify(inspect(code))+'\n');
  else if(mode==='build') fs.writeFileSync(output,localize(code,JSON.parse(fs.readFileSync(dictPath)),fs.readFileSync(runtimePath,'utf8'),registrationName));
  else throw Error('Usage: framegen_ui.mjs inspect FILE | build FILE DICTIONARY RUNTIME OUTPUT');
}
