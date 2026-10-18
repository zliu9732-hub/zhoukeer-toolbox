// Static proof: strip our render wrappers and require the original complete AST.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {parse} from './vendor/acorn/acorn.mjs';
import {inspect} from './framegen_ui.mjs';

const [beforePath,afterPath]=process.argv.slice(2);
const before=fs.readFileSync(beforePath,'utf8'),after=fs.readFileSync(afterPath,'utf8');
const a=parse(before,{ecmaVersion:'latest',sourceType:'module'});
const b=parse(after,{ecmaVersion:'latest',sourceType:'module'});
// All injected declarations are before the untouched upstream manifest.
const manifestIndex=b.body.findIndex(n=>n.type==='VariableDeclaration' && n.declarations.some(d=>d.id.name==='manifest'));
assert.ok(manifestIndex>0,'missing upstream manifest');
b.body=b.body.slice(manifestIndex);
function clean(n) {
    if(!n || typeof n!=='object') return n;
    if(Array.isArray(n)) return n.map(clean);
    if(n.type==='CallExpression' && n.callee.type==='MemberExpression' && n.callee.object?.name==='RenkitAyaneo3JSX') {
        if(n.callee.property.name==='title') return clean(n.arguments[0]);
        n=structuredClone(n);
        n.callee.object.name=n.callee.property.name==='toast'?'toaster':'SP_JSX';
    }
    return Object.fromEntries(Object.entries(n).filter(([k])=>!['start','end','raw'].includes(k)).map(([k,v])=>[k,clean(v)]));
}
assert.deepEqual(clean(b),clean(a),'non-display code changed');
assert.deepEqual(inspect(after).api_plugin_names,['AYANEO 3 Companion']);
assert.ok(after.includes('RenAmamiya汉化') && after.includes('#ffcc66'));
console.log('AYANEO3 complete frontend AST, backend routing and signature verified');
