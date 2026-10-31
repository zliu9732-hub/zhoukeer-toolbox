// Test the real shipped frontend against React and a mocked Decky API; no device commands.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {parse} from '../scripts/vendor/acorn/acorn.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [originalDir,signedDir,plainDir,outDir]=process.argv.slice(2);
const before=fs.readFileSync(path.join(originalDir,'dist/index.js'),'utf8');
const signed=fs.readFileSync(path.join(signedDir,'dist/index.js'),'utf8');
const plain=fs.readFileSync(path.join(plainDir,'dist/index.js'),'utf8');
const inventory=JSON.parse(fs.readFileSync(path.join(root,'data/gfg_extreme_ui_inventory.json'),'utf8'));
const source=fs.readFileSync(path.join(root,'assets/gfg-extreme/source/frontend/src/app.js'),'utf8');
assert.equal(createHash('sha256').update(source).digest('hex'),inventory.frontend_source_sha256,'new upstream UI requires complete review');
const actualRows=[];
function inventoryWalk(n,parent){
 if(!n||typeof n!=='object')return;
 if(n.type==='Literal'&&typeof n.value==='string'&&/[A-Za-z]/.test(n.value))actualRows.push({line:n.loc.start.line,value:n.value,parent:parent?.type});
 if(n.type==='TemplateElement'&&/[A-Za-z]/.test(n.value.raw))actualRows.push({line:n.loc.start.line,template:n.value.raw,parent:parent?.type});
 for(const[k,v]of Object.entries(n))if(!['loc','start','end'].includes(k)){if(Array.isArray(v))v.forEach(x=>inventoryWalk(x,n));else if(v&&typeof v==='object')inventoryWalk(v,n);}
}
inventoryWalk(parse(source,{ecmaVersion:'latest',sourceType:'module',locations:true}));
assert.deepEqual(actualRows,inventory.frontend.map(({review,...row})=>{assert.ok(review);return row;}),'unreviewed literal or template fragment');

function normalized(text){
 const tree=parse(text,{ecmaVersion:'latest',sourceType:'module'});
 const i=tree.body.findIndex(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='manifest'));
 assert.ok(i>=0);tree.body=tree.body.slice(i);
 function clean(n){
  if(!n||typeof n!=='object')return n;
  if(Array.isArray(n))return n.map(clean);
  if(n.type==='CallExpression'&&n.callee.name==='gfgTitle')return clean(n.arguments[0]);
  if(n.type==='CallExpression'&&n.callee.name==='gfgCapture')return {displayCapture:true};
  if(n.type==='ConditionalExpression'&&n.test?.left?.operator==='typeof'&&n.test.left.argument?.name==='cap')return {displayCapture:true};
  if(n.type==='CallExpression'&&n.callee?.object?.name==='R'&&n.callee?.property?.name==='createElement'&&n.arguments.length===3)return {displayRenderer:true};
  if(n.type==='Property'&&['title','body'].includes(n.key?.name)&&n.value.type==='CallExpression'&&n.value.callee.name==='gfgText')return clean({...n,value:n.value.arguments[0],shorthand:true});
  if(n.type==='Literal'&&n.value==='GFG Extreme 功耗与补帧')n={...n,value:'GFG Extreme'};
  return Object.fromEntries(Object.entries(n).filter(([k])=>!['start','end','raw'].includes(k)).map(([k,v])=>[k,clean(v)]));
 }
 return clean(tree);
}
assert.deepEqual(normalized(signed),normalized(before),'non-display JS logic/RPCs/settings changed');
assert.deepEqual(normalized(plain),normalized(before),'plain package behavior differs');
assert.ok(signed.includes('RenAmamiya汉化'));
assert.ok(!/RenAmamiya|Renkit|renkit/i.test(plain),'plain frontend contains attribution');
const {build}=await import(process.env.RENKIT_TEST_ESBUILD||'esbuild');
const {chromium}=await import(process.env.RENKIT_TEST_PLAYWRIGHT||'playwright-core');
const react=await build({stdin:{contents:'import * as R from "react";import{createRoot}from"react-dom/client";window.SP_REACT=R;window.__createRoot=createRoot;',resolveDir:process.env.RENKIT_TEST_NODE_ROOT||root},bundle:true,format:'iife',write:false,define:{'process.env.NODE_ENV':'"production"'}});
const settings={profiles:{default:{name:'Default',fg:'auto',base_fps:45,objective:'autopilot',filters:{effects:['vibrance'],sharpen:'cas',sharpness:0.5,denoise:0.17,aa:'none'}}},hud:{enabled:true,position:'top-right',detail:'standard'},autopilot:{preference:'auto'},power:{enabled:true,split:true,gpu_clock:true},engine:{hdr:true,hdr_output:true},telemetry:{level:'standard'}};
const state={version:'3.0.10',codename:'',device:'Steam Deck OLED',settings,profiles:{active:'default',game_key:'app:1245620'},migration:{from:'2.1.6',steps:['Settings moved (backup kept)','MAKO removed, system restored']},coexist:{standalone:true,taken_over:false},capture:{},live:{game:true,app:1245620,refresh:90,objective:'balanced',live:{fps:90,real:30,pace:0.998},pilot:{phase:'locked',point:30,reason:'point 30 holds: locked'},policy:{state:'confirmed',epoch:412},engine:{state:'active',multiplier:3,cap_fps:30,auto:true,auto_floor:24,gpu_us_avg:2100,transfer:'sdr'},governor:{tdp_w:9.5,ceiling_w:15,draw_w:10.8,owned:true},sensors:{temp_c:68,cpu_top_core_pct:41,gpu_busy_pct:96,gpu_clock_mhz:1600,fan_rpm:3900},split:{phase:'hold',cap_khz:1800000,max_khz:3500000,measured:true,pairs:3,gain_pct:6.8},gpu_clock:{phase:'observe'}}};
const presets=[['off','Off'],['sharp','Sharp'],['vivid','Vivid'],['hdr','HDR look'],['cinema','Cinema'],['noir','Noir'],['retro','Retro'],['smooth','Smooth']].map(([id,name])=>({id,name,filters:id==='vivid'?{effects:['vibrance'],sharpen:'cas',aa:'none'}:{}}));
const effects=[['hdr_look','HDR Look'],['clarity','Clarity'],['levels_plus','Levels Plus'],['curves','Curves'],['vibrance','Vibrance'],['colourfulness','Colourfulness'],['technicolor','Technicolor'],['technicolor2','Technicolor 2'],['dpx','DPX'],['bleach_bypass','Bleach Bypass'],['noir','Noir'],['sepia','Sepia'],['monochrome','Monochrome'],['film_grain','Film Grain'],['vignette','Vignette'],['chromatic_aberration','Chromatic Aberration'],['cartoon','Cartoon'],['nostalgia','Nostalgia'],['deband','Deband']].map(([key,name])=>({key,name}));
const catalog={presets,effects};
const mock=`window.DFL={staticClasses:{Title:'title'},GamepadButton:{BUMPER_LEFT:5,BUMPER_RIGHT:6}};window.appStore={GetAppOverviewByAppID:()=>({display_name:'Elden Ring'})};window.__state=${JSON.stringify(state)};window.__catalog=${JSON.stringify(catalog)};window.__calls=[];window.__toasts=[];window.__connects=[];window.__error='';window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit={connect:(version,name)=>{window.__connects.push([version,name]);if(window.__fallback&&version===2)throw Error('mock API v1');return{_version:version,toaster:{toast:t=>window.__toasts.push(t)},callable:method=>async(...args)=>{window.__calls.push([method,args]);if(window.__error&&method==='get_state')throw Error(window.__error);if(method==='get_state')return window.__state;if(method==='get_catalog')return window.__catalog;if(method==='diagnose')return{checks:[{key:'bundle',ok:true,text:'Plugin carries Gamescope KEDAVRA 1.3.0'},{key:'libs',ok:true,text:'Libraries on this SteamOS: all found'},{key:'installed',ok:false,text:'Not installed'},{key:'unit',ok:true,text:'Boot step: enabled'},{key:'status',ok:false,text:'No engine status file'}]};if(method==='engine_install')return{ok:true,message:'Installed. Reboot the Deck: Gaming Mode will start with Gamescope KEDAVRA.'};if(method==='engine_uninstall')return{ok:true,message:'Removed. The stock Gamescope is active.'};if(method==='reboot')return{rebooting:true};if(method==='save_report')return{path:'/mock/report.zip'};if(method==='get_logs')return'原始诊断日志';if(method==='run_bench')return{ok:true,log:'0 failure'};if(method==='start_capture'){window.__state.capture={active:true};return{path:'/mock/trace.csv',elapsed_s:0};}if(method==='stop_capture'){window.__state.capture={active:false};return{ok:true,summary:{pass:true,rows:300,p95_ms:0.3,p99_ms:0.7,missed_pct:0.2},report:'/mock/trace.json'};}if(method==='list_captures')return['test.csv'];return{ok:true};}}}};`;
const browser=await chromium.launch({headless:true,...(process.env.RENKIT_TEST_CHROMIUM?{executablePath:process.env.RENKIT_TEST_CHROMIUM}:{})});
const errors=[];
function chinese(text){
 const remaining=text.replace(/GFG\s*·?\s*EXTREME|GFG Extreme|GFG|GSF Kedavra|Gamescope KEDAVRA|KEDAVRA|MAKO|Steam Deck OLED|Steam Deck|SteamOS|Steam|Elden Ring|RenAmamiya|HDR10|HDR|SDR|scRGB|PQ|CAS|DLS|FXAA|SMAA|CPU|GPU|GHz|MHz|FPS|P95|P99|L1|R1|A\/B|ms|Hz|\bW\b|\/mock\/[^\s·]+|test\.csv/g,'');
 assert.ok(!/[A-Za-z]{2,}/.test(remaining),'untranslated visible UI: '+remaining);
}
try{
 for(const [brand,text]of [['signed',signed],['plain',plain]]){
  const page=await browser.newPage({viewport:{width:360,height:1200},locale:'en-US',deviceScaleFactor:2});
  page.on('pageerror',e=>errors.push(String(e)));
  await page.setContent('<html><body style="margin:0;background:#000;color:white"><div id="title"></div><div id="root" style="width:360px"></div></body></html>');
  await page.addScriptTag({content:react.outputFiles[0].text});await page.addScriptTag({content:mock});if(brand==='plain')await page.evaluate(()=>window.__fallback=true);
  await page.addScriptTag({content:text.replace(/export\s*\{\s*app_default as default\s*\};/,'window.__plugin=app_default;')});
  await page.evaluate(()=>{const p=window.__plugin();window.__createRoot(document.getElementById('title')).render(p.titleView);window.__createRoot(document.getElementById('root')).render(p.content);});
  await page.waitForTimeout(150);
  assert.equal(await page.locator('#title').innerText().then(t=>t.includes('RenAmamiya')),brand==='signed');
  assert.equal((await page.evaluate(()=>window.__connects))[0][1],'GFG Extreme 功耗与补帧');
  if(brand==='signed')assert.equal(await page.getByText('RenAmamiya汉化',{exact:true}).evaluate(e=>getComputedStyle(e).color),'rgb(255, 204, 102)');
  for(const [i,label]of ['概览','画面','引擎','设置'].entries()){
   await page.locator('.tab').filter({hasText:label}).click();await page.waitForTimeout(80);
   chinese(await page.locator('body').innerText());
   if(outDir){fs.mkdirSync(outDir,{recursive:true});await page.screenshot({path:path.join(outDir,`${brand}-${i+1}.png`),fullPage:true});}
  }
  await page.getByText('重新安装',{exact:true}).click();await page.waitForTimeout(80);
  assert.ok((await page.locator('body').innerText()).includes('引擎已安装'));
  assert.ok((await page.evaluate(()=>window.__toasts)).every(t=>!t.body.includes('Installed.')));
  await page.locator('.lrow').filter({hasText:'运行检查'}).click();await page.waitForTimeout(80);chinese(await page.locator('body').innerText());
  await page.locator('.tab').filter({hasText:'概览'}).click();await page.locator('.tile').filter({hasText:'省电'}).click();
  assert.ok((await page.evaluate(()=>window.__calls)).some(([method,args])=>method==='set_profile'&&args[0]==='default'&&args[1].objective==='battery'));
  await page.locator('.tab').filter({hasText:'画面'}).click();await page.locator('.ftile').filter({hasText:'鲜艳'}).click();
  assert.ok((await page.evaluate(()=>window.__calls)).some(([method,args])=>method==='set_profile'&&args[1].filters==='vivid'));
  await page.locator('.echip').filter({hasText:'经典彩色胶片 2'}).click();
  assert.ok((await page.evaluate(()=>window.__calls)).some(([method,args])=>method==='set_profile'&&args[1].filters?.effects?.includes('technicolor2')));
  await page.locator('.tab').filter({hasText:'引擎'}).click();await page.getByText('开始记录',{exact:true}).click();await page.waitForTimeout(1100);
  assert.ok((await page.locator('body').innerText()).includes('正在记录'));
  await page.getByText('停止记录',{exact:true}).click();await page.waitForTimeout(80);chinese(await page.locator('body').innerText());
  // Exercise actual conditional branches, not only the happy-path dictionary.
  const variants=[
   {game:false,engine:{state:'off'},pilot:{phase:'measure'},split:{phase:'off'},policy:{state:'pending'}},
   {game:true,engine:{state:'waiting',transfer:'pq',cap_fps:40},pilot:{phase:'trial',point:40,reason:'trying point 40'},split:{phase:'free',reason:'real-frames-short'},policy:{state:'conflict'}},
   {game:true,engine:{state:'error',transfer:'scrgb'},pilot:{phase:'demote',point:24,reason:"the game does not hold 24 (this mode's lowest point) even at full power"},split:{phase:'free',reason:'settling'},policy:{state:'pending',epoch:45}}
  ];
  for(const variant of variants){
   await page.evaluate(v=>{window.__state={...window.__state,live:{...window.__state.live,...v},settings:{...window.__state.settings,profiles:{default:{...window.__state.settings.profiles.default,fg:'custom',filters:{effects:[],sharpen:'dls',aa:'smaa',denoise:0.2,sharpness:0.4}}},engine:{hdr_output:false}}};},variant);
   await page.waitForTimeout(1050);
   for(const label of ['概览','画面','引擎']){await page.locator('.tab').filter({hasText:label}).click();chinese(await page.locator('body').innerText());}
  }
  // Known backend errors translated at the render boundary; RPC identifiers stay intact.
  await page.evaluate(()=>window.__error='capture already running');await page.waitForTimeout(1050);chinese(await page.locator('body').innerText());
  await page.evaluate(()=>window.__error='');await page.waitForTimeout(1050);
  assert.ok((await page.evaluate(()=>window.__connects)).every(([,name])=>name==='GFG Extreme 功耗与补帧'));
  if(brand==='plain')assert.equal((await page.evaluate(()=>window.__connects)).length,2);
  await page.close();
 }
 assert.deepEqual(errors,[]);
 console.log('PASS: shipped frontends, all tabs, full effects, dynamic diagnostics, notifications, capture and unchanged RPC IDs');
}finally{await browser.close();}
