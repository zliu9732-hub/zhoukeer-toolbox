// Patch only rendering boundaries and the Decky display identity of a pinned release.
import fs from 'node:fs';
import {parse} from './vendor/acorn/acorn.mjs';
const [input, output, dataFile, runtimeFile, brand='signed']=process.argv.slice(2);
const source=fs.readFileSync(input,'utf8');
const ast=parse(source,{ecmaVersion:'latest',sourceType:'module'}), edits=[], counts={h:0,title:0,notify:0,capture:0,identity:0};
function edit(n,value){edits.push([n.start,n.end,value]);}
function walk(n,parent){
 if(!n||typeof n!=='object')return;
 if(n.type==='VariableDeclarator'&&n.id.name==='h'){
  const f=n.init; if(f.type!=='ArrowFunctionExpression'||f.body.type!=='CallExpression')throw Error('unexpected renderer');
  edit(f.body,'R.createElement(t,p,...c.map(value => t === "style" ? value : gfgText(value)))');counts.h++;
 }
 if(n.type==='Property'&&(n.key.name||n.key.value)==='titleView'){edit(n.value,'gfgTitle('+source.slice(n.value.start,n.value.end)+')');counts.title++;}
 if(n.type==='Property'&&(n.key.name||n.key.value)==='name'&&n.value.type==='Literal'&&n.value.value==='GFG Extreme'){
  edit(n.value,JSON.stringify('GFG Extreme 功耗与补帧'));counts.identity++;
 }
 if(n.type==='CallExpression'&&n.callee.type==='MemberExpression'&&n.callee.object.name==='toaster'&&n.callee.property.name==='toast'){
  const obj=n.arguments[0];for(const prop of obj.properties){if(['title','body'].includes(prop.key.name))edit(prop,`${prop.key.name}: gfgText(${source.slice(prop.value.start,prop.value.end)})`);}counts.notify++;
 }
 if(n.type==='ConditionalExpression'&&n.test.type==='BinaryExpression'&&n.test.operator==='==='&&n.test.left.type==='UnaryExpression'&&n.test.left.operator==='typeof'&&n.test.left.argument.name==='cap'){
  edit(n,'gfgCapture(cap)');counts.capture++;
 }
 for(const [k,v]of Object.entries(n))if(!['start','end'].includes(k)){if(Array.isArray(v))v.forEach(x=>walk(x,n));else if(v&&typeof v==='object')walk(v,n);}
}
walk(ast);
if(counts.h!==1||counts.title!==1||counts.notify!==1||counts.capture!==1||![1,2].includes(counts.identity))throw Error('UI patch layout changed: '+JSON.stringify(counts));
let result=source;edits.sort((a,b)=>b[0]-a[0]);let previous=source.length;
for(const [a,b,value]of edits){if(b>previous)throw Error('overlapping edits');result=result.slice(0,a)+value+result.slice(b);previous=a;}
let runtime=fs.readFileSync(runtimeFile,'utf8').replace('__GFG_ZH__',JSON.stringify(JSON.parse(fs.readFileSync(dataFile,'utf8'))));
const credit=brand==='signed'?'return window.SP_REACT.createElement("div", {style:{display:"flex",flexDirection:"column",gap:"2px"}}, window.SP_REACT.createElement("div", {style:{color:"#ffcc66",fontSize:"12px",fontWeight:"bold",lineHeight:"18px"}}, "RenAmamiya汉化"), original);':'return original;';
if(!['signed','plain'].includes(brand))throw Error('invalid credit mode');
runtime=runtime.replace('__GFG_CREDIT_NODE__',credit);
parse(runtime+'\n'+result,{ecmaVersion:'latest',sourceType:'module'});
fs.writeFileSync(output,runtime+'\n'+result);
console.log(JSON.stringify(counts));
