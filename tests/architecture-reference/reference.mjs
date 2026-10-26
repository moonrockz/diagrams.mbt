import { chromium } from '../../apps/site/node_modules/playwright/index.mjs';
import {createServer} from 'node:http';
import {readFile,readdir,writeFile,mkdir} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
const root=resolve(import.meta.dirname), corpus=resolve(root,'../architecture-corpus');
const docs=await readFile(corpus+'/upstream/architecture.md','utf8');
await mkdir(corpus+'/docs',{recursive:true});
let ordinal=0;
for(const match of docs.matchAll(/```[^\n]*\n([\s\S]*?)```/g)) {
 const source=match[1];if(!source.includes('architecture-beta'))continue;
 await writeFile(corpus+'/docs/'+String(++ordinal).padStart(2,'0')+'.mmd',source.trimEnd()+'\n');
}
const server=createServer(async(req,res)=>{try{const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname);if(name==='/'){res.end('<!doctype html><title>Architecture reference</title>');return}const path=resolve(root,'.'+name);if(!path.startsWith(root+'/node_modules/')){res.writeHead(404).end();return}res.setHeader('Content-Type',extname(path)==='.json'?'application/json':'text/javascript');res.end(await readFile(path))}catch{res.writeHead(404).end()}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;
try {
 browser=await chromium.launch({headless:true});const page=await browser.newPage();const url='http://127.0.0.1:'+server.address().port;
 await page.route('**/*',route=>route.request().url().startsWith(url+'/')?route.continue():route.abort());await page.goto(url);
 await page.evaluate(async()=>{window.mermaid=(await import('/node_modules/mermaid/dist/mermaid.esm.min.mjs')).default;window.mermaid.initialize({startOnLoad:false,securityLevel:'strict'})});
 const fixtures=[];
 for(const dir of ['docs','cases'])for(const file of (await readdir(corpus+'/'+dir)).sort())if(file.endsWith('.mmd')) {
  const source=await readFile(corpus+'/'+dir+'/'+file,'utf8');
  const normalized=await page.evaluate(async source=>{try{const diagram=await window.mermaid.mermaidAPI.getDiagramFromText(source);const db=diagram.db;return{accepted:true,groups:db.getGroups().map(({id,icon,title,in:parent})=>({id,icon:icon??null,label:title??id,parent:parent??null})),services:db.getServices().map(({id,icon,iconText,title,in:parent})=>({id,icon:icon??null,iconText:iconText??null,label:title??id,parent:parent??null})),junctions:db.getJunctions().map(({id,in:parent})=>({id,parent:parent??null})),edges:db.getEdges().map(e=>({source:e.lhsId,target:e.rhsId,sourceSide:e.lhsDir,targetSide:e.rhsDir,sourceGroup:!!e.lhsGroup,targetGroup:!!e.rhsGroup,sourceHead:!!e.lhsInto,targetHead:!!e.rhsInto,label:e.title??null})),alignments:db.getLayoutHints(),title:db.getDiagramTitle(),accTitle:db.getAccTitle(),accDescription:db.getAccDescription()}}catch(error){return{accepted:false,errorName:error.name,message:error.message}}},source);
  fixtures.push({name:dir+'/'+file,source,normalized});
 }
 const canonicalFile=resolve(root,'../architecture-acceptance/__snapshot__/canonical.json');
 if(process.argv.includes('--canonical')) {
  const canonical=new Map(JSON.parse(await readFile(canonicalFile,'utf8')));
  for(const fixture of fixtures.filter(f=>f.normalized.accepted)) {const source=canonical.get(fixture.name);if(!source)throw Error('Missing canonical '+fixture.name);await page.evaluate(async source=>{await window.mermaid.mermaidAPI.getDiagramFromText(source)},source)}
 }
 const output=JSON.stringify({reference:'mermaid@12.2.0',configuration:{securityLevel:'strict'},normalizations:['Database values only; no diagram renderer or layout is used.','Absent labels use authored ID. Undefined values normalize to null.','Every documentation fence containing architecture-beta and every cases/*.mmd input is included.'],fixtures},null,2)+'\n';
 const target=corpus+'/reference.json';if(process.argv.includes('--check')){if(await readFile(target,'utf8')!==output)throw Error('Architecture reference differs')}else await writeFile(target,output);
 console.log('Independent architecture fixtures: '+fixtures.length+', accepted: '+fixtures.filter(f=>f.normalized.accepted).length);
} finally {if(browser)await browser.close();await new Promise(r=>server.close(r))}
