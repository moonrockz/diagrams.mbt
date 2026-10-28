import { chromium } from '../../apps/site/node_modules/playwright/index.mjs';
import { createServer } from 'node:http';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
const root = resolve(import.meta.dirname, '../swimlane-reference');
const corpus = resolve(root, '../corpus/mermaid-flowcharts');
const server = createServer(async (req, res) => {
  try {
    const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (name === '/') { res.end('<!doctype html><title>Reference parser</title>'); return; }
    const path = resolve(root, '.' + name);
    if (!path.startsWith(root + '/node_modules/')) { res.writeHead(404).end(); return; }
    res.setHeader('Content-Type', extname(path) === '.json' ? 'application/json' : 'text/javascript');
    res.end(await readFile(path));
  } catch { res.writeHead(404).end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
let browser;
try {
  browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  const url = 'http://127.0.0.1:' + server.address().port;
  await page.route('**/*', route => route.request().url().startsWith(url + '/') ? route.continue() : route.abort());
  await page.goto(url);
  await page.evaluate(async () => {
    window.mermaid = (await import('/node_modules/mermaid/dist/mermaid.esm.min.mjs')).default;
    window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', flowchart: { inheritDir: false }, maxEdges: 50000 });
  });
  const files = [];
  for (const dir of ['docs','cases']) for (const file of (await readdir(corpus+'/'+dir)).sort()) if (file.endsWith('.mmd')) files.push(dir+'/'+file);
  const results = [];
  const bootstrap = process.argv.includes("--bootstrap");
  const canonical = bootstrap ? new Map() : new Map(JSON.parse(await readFile(resolve(root,'../flowchart-mermaid-acceptance/__snapshot__/canonical.json'),'utf8')));
  for (const name of files) {
    const source = await readFile(corpus+'/'+name, 'utf8');
    const parse = async source => page.evaluate(async source => {
      const diagram = await window.mermaid.mermaidAPI.getDiagramFromText(source);
      const db = diagram.db;
      function decodeLabel(value) {
        const textarea=document.createElement('textarea');
        textarea.innerHTML=String(value).replace(/ﬂ°°/g,'&#').replace(/ﬂ°/g,'&').replace(/¶ß/g,';').replace(/<br\s*\/?\s*>/gi,'\n');
        return textarea.value;
      }
      return {
        direction: db.getDirection(),
        nodes: [...db.getVertices()].filter(([id]) => !db.getSubGraphs().some(g => g.id===id)).map(([id,n]) => ({id, label:decodeLabel(n.text??id), shape:n.img?'image':n.icon?'icon':n.type??'square', labelType:n.labelType??'text',labelKind:String(n.text??'').includes('<')?'html':n.labelType==='markdown'?'markdown':'text'})),
        edges: db.getEdges().map(e=>({source:e.start,target:e.end,label:decodeLabel(e.text??''),type:e.type,style:e.stroke,length:e.length,id:e.id??null})),
        groups: db.getSubGraphs().map(g=>({id:g.id,label:g.title,direction:g.dir??null,members:g.nodes}))
      };
    }, source);
    let normalized;
    try { normalized = await parse(source); }
    catch (error) {
      results.push({name,source,accepted:false,error:String(error.message).split('\n')[0]});
      continue;
    }
    if (!bootstrap && canonical.has(name)) {
      const roundtrip = await parse(canonical.get(name));
      const semantic = value => ({ ...value, nodes: value.nodes.map(({labelType, ...node}) => node) });
      if (JSON.stringify(semantic(normalized)) !== JSON.stringify(semantic(roundtrip))) throw new Error('Canonical native semantics differ: ' + name);
    } else if (!bootstrap) throw new Error('Missing canonical source: ' + name);
    results.push({name, source, accepted:true, normalized});
  }
  const refusals=JSON.parse(await readFile(corpus+'/extensions/oracle-refusals.json','utf8'));
  const refusalResults=[];
  for (const fixture of refusals) {
    const source=await readFile(corpus+'/'+fixture.source,'utf8');
    const outcome=await page.evaluate(async source => {
      try { await window.mermaid.mermaidAPI.getDiagramFromText(source); return {accepted:true}; }
      catch(error) { return {accepted:false,name:error.name??'Error'}; }
    },source);
    if (outcome.accepted || !String(outcome.name).includes(fixture.errorNameContains)) throw new Error('Pinned refusal differs: '+fixture.source+' '+JSON.stringify(outcome));
    refusalResults.push({...fixture,input:source,errorName:outcome.name});
  }
  const output=JSON.stringify({reference:'mermaid@12.2.0',configuration:{securityLevel:'strict',inheritDir:false,maxEdges:50000},normalizations:['Node shape aliases are normalized separately by MoonBit.','Mermaid entity placeholders are decoded through browser entities; HTML line breaks project to newline text.','CST, canonical whitespace, diagnostics and layout have independent assertions.','Generated and explicit edge IDs use the pinned database policy, including grouped-endpoint ID placement.','Database group-reference vertices project to group identities, not duplicate model nodes.'],fixtures:results,refusals:refusalResults},null,2)+'\n';
  const target=corpus+'/reference.json';
  if (process.argv.includes('--check')) {
    if (await readFile(target,'utf8')!==output) throw new Error('Reference fixtures differ; run mise run flowchart-mermaid-corpus:reference');
  } else await writeFile(target,output);
  console.log((bootstrap?'Parsed source inputs for canonical bootstrap: ':'Qualified source and canonical native diagrams: ')+results.length+'; pinned refusals: '+refusals.length);
} finally {
  if (browser) await browser.close();
  await new Promise(r=>server.close(r));
}
