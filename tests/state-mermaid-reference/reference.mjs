import { chromium } from '../../apps/site/node_modules/playwright/index.mjs';
import { createServer } from 'node:http';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
const root = resolve(import.meta.dirname, '../swimlane-reference');
const corpus = resolve(root, '../corpus/mermaid-states');
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
  const canonical = bootstrap ? new Map() : new Map(JSON.parse(await readFile(resolve(root,'../state-mermaid-acceptance/__snapshot__/canonical.json'),'utf8')));
  for (const name of files) {
    const source = await readFile(corpus+'/'+name, 'utf8');
    const parse = async source => page.evaluate(async source => {
      const diagram = await window.mermaid.mermaidAPI.getDiagramFromText(source);
      const db = diagram.db;
      const data=db.getData();
      const decode=value=>{const text=document.createElement('textarea');text.innerHTML=String(value);return text.value;};
      const regions=[{id:'root',owner:null,members:[]}];
      const ids=new Map(),childRegions=new Map(),regionMap=new Map([['root',regions[0]]]);
      const dividers=data.nodes.filter(n=>n.shape==='divider');
      for(const n of data.nodes.filter(n=>n.isGroup && !['divider','noteGroup'].includes(n.shape))) {
        const children=dividers.filter(d=>d.parentId===n.id);
        const names=(children.length?children:[null]).map((d,i)=>{const name=n.id+'::region-'+i;if(d)ids.set(d.id,name);regions.push({id:name,owner:n.id,members:[]});return name;});
        childRegions.set(n.id,names);
      }
      for(const r of regions)regionMap.set(r.id,r);
      const region=n=>n.parentId ? (ids.get(n.parentId)??(childRegions.get(n.parentId)?.[0]??'root')):'root';
      for(const n of data.nodes) {
        if(n.shape==='stateStart')ids.set(n.id,region(n)+'::initial');
        if(n.shape==='stateEnd')ids.set(n.id,region(n)+'::final');
      }
      const id=x=>ids.get(x)??x;
      const roles={stateStart:'Initial',stateEnd:'Final',choice:'Choice',fork:'Fork',join:'Join'};
      const stateNodes=data.nodes.filter(n=>!['divider','note','noteGroup'].includes(n.shape));
      const states=stateNodes.map(n=>({id:id(n.id),label:roles[n.shape]?id(n.id):decode(n.label??''),descriptions:(n.description??[]).map(decode),role:roles[n.shape]??(n.isGroup?'Composite':'Simple'),region:region(n)}));
      for(const n of states)regionMap.get(n.region)?.members.push(n.id);
      const notes=data.nodes.filter(n=>n.shape==='note').map(n=>{const e=data.edges.find(e=>e.start===n.id||e.end===n.id);const target=e?(e.start===n.id?e.end:e.start):null;return {target:id(target),text:decode(n.label),placement:n.position==='left of'?'left':'right'};});
      return {
        direction:data.direction,states,regions,
        transitions:data.edges.filter(e=>e.pattern!=='dashed').map(e=>({source:id(e.start),target:id(e.end),label:decode(e.label??'')})),notes,
        accessibilityTitle:db.getAccTitle(),accessibilityDescription:db.getAccDescription(),title:db.getDiagramTitle()
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
      const semantic = value => value;
      if (JSON.stringify(semantic(normalized)) !== JSON.stringify(semantic(roundtrip))) throw new Error('Canonical native semantics differ: ' + name);
    } else if (!bootstrap && !['cases/boundary-refusal.mmd'].includes(name)) throw new Error('Missing canonical source: ' + name);
    results.push({name, source, accepted:true, normalized});
  }
  const output=JSON.stringify({reference:'mermaid@12.2.0',configuration:{securityLevel:'strict',maxEdges:50000},normalizations:['Pinned database node/edge projection; generated divider and note IDs normalized by occurrence.','Labels retain pinned sanitization; source AST independently preserves raw text.','Source trivia, UTF-16 diagnostics, canonical bytes, model IDs and layout have separate portable checks.'],fixtures:results},null,2)+'\n';
  const target=corpus+'/reference.json';
  if (process.argv.includes('--check')) {
    if (await readFile(target,'utf8')!==output) throw new Error('Reference fixtures differ; run mise run state-mermaid-corpus:reference');
  } else await writeFile(target,output);
  console.log((bootstrap?'Parsed state sources: ':'Qualified source and canonical state diagrams: ')+results.length);
} finally {
  if (browser) await browser.close();
  await new Promise(r=>server.close(r));
}
