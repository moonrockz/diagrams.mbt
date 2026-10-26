// Stored standalone artifacts, qualified without rebuilding the workspace.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { chromium } from 'playwright';
const rows = JSON.parse(await readFile('tests/zenuml-integration/__snapshot__/new-gallery.json','utf8')) as [string,string,string][];
const mode=process.argv[2]??'all';
const browser=await chromium.launch();
const errors:string[]=[],requests:string[]=[];
const byName=new Map(rows.map(row=>[row[0],row[2]]));
async function open(source:string,theme:'dark'|'light',reduce=false) {
 const page=await browser.newPage({viewport:{width:1600,height:1000},colorScheme:theme,reducedMotion:reduce?'reduce':'no-preference',acceptDownloads:true});
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await page.route('**/*',route=>{requests.push(route.request().url());return route.abort()});
 await page.setContent(source);return page;
}
try {
 if(mode!=='animation') {
  for(const [name,mime,source] of rows) {
   if(mime!=='image/svg+xml')continue;
   for(const theme of ['dark','light'] as const) {
    const page=await open('',theme);
    await page.evaluate(({source,name})=>{
     const xml=new DOMParser().parseFromString(source,'image/svg+xml');if(xml.querySelector('parsererror'))throw Error('Invalid XML');
     const svg=document.importNode(xml.documentElement,true) as unknown as SVGSVGElement;document.body.append(svg);
     const ids=[...svg.querySelectorAll('[id]')].map(n=>n.id);if(ids.length!==new Set(ids).size)throw Error('Duplicate SVG IDs');
     if(!svg.querySelector('title')||!svg.querySelector('desc'))throw Error('Missing accessibility fields');
     for(const n of svg.querySelectorAll('*')) {
      if(['script','foreignObject','image','iframe','a','animate','set'].includes(n.localName))throw Error('Active SVG element');
      for(const a of n.attributes) {
       if(/^on/i.test(a.name))throw Error('Executable SVG attribute');
       if(/href$/i.test(a.name)) {if(n.localName!=='use'||!/^#[A-Za-z0-9_-]+$/.test(a.value)||!svg.querySelector(`[id="${a.value.slice(1)}"]`))throw Error('Invalid local symbol reference')}
       for(const m of a.value.matchAll(/url\(([^)]+)\)/g))if(!m[1].startsWith('#')||!svg.querySelector(`[id="${m[1].slice(1)}"]`))throw Error('Invalid paint reference');
      }
     }
     for(const use of svg.querySelectorAll('use')) {const b=use.getBBox();if(b.width<=0||b.height<=0)throw Error('Invisible symbol')}
     for(const text of svg.querySelectorAll('text')) {if(parseFloat(getComputedStyle(text).fontSize)<11)throw Error('Small text');const b=text.getBBox();const v=svg.viewBox.baseVal;if(b.x < -1 || b.y < -1 || b.x+b.width > v.width+1 || b.y+b.height>v.height+1)throw Error('Text outside SVG: '+text.textContent)}
     if(/-(dark|light)\.svg$/.test(name)&& (svg.querySelector('style')||/var\(/.test(source)))throw Error('Fixed SVG contains adaptive CSS');
    },{source,name});
    await page.screenshot({path:`_build/${name}-${theme}.png`,fullPage:true});await page.close();
   }
  }
  // Every frozen vector resolves, including symbols with local masks/gradients.
  const sheet=await open(await readFile('tests/zenuml-integration/__snapshot__/icon-contact-sheet.svg','utf8'),'light');
  assert.equal(await sheet.locator('use').count(),523);
  await sheet.locator('use').evaluateAll(nodes=>{for(const n of nodes){const b=(n as SVGUseElement).getBBox();if(b.width<=0||b.height<=0)throw Error('Invisible registry symbol')}});await sheet.close();
 }
 if(mode!=='static') {
  for(const [name,mime,html] of rows) {
   if(mime!=='text/html')continue;
   const canonical=byName.get(name.replace(/\.html$/,'.svg'))!;
   for(const theme of ['dark','light'] as const) {
    console.log('Qualifying',name,theme);const page=await open(html,theme);const root=page.locator('[data-diagram-viewer]');
    assert.equal(await root.getAttribute('data-playing'),'false');assert.equal(await page.locator('.motion-overlay').count(),0);
    const iconCount=await page.locator('svg use').count();
    assert.ok(await page.locator('svg use').evaluateAll(nodes=>nodes.every(n=>getComputedStyle(n).color==='rgb(17, 24, 39)')),'currentColor symbols retain dark ink on white backing in dark hosts');assert.ok(iconCount >= (name.startsWith('architecture-group-boundary') ? 4 : 5),'symbols present offline');
    const config=await page.locator('script[data-motion-data]').evaluate(n=>JSON.parse(n.textContent!));const steps=config.plan.steps;assert.ok(steps.length>0);
    await page.locator('[data-diagram-viewer]').evaluate(root=>{
      const config=JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);const svg=root.querySelector('svg')!;
      for(const binding of config.paths) {
        const actual=document.getElementById(binding.id)!;
        const group=config.kind==='architecture'?[...svg.querySelectorAll('.architecture-connection[data-id]')].find(n=>n.getAttribute('data-id')===binding.connection):[...svg.querySelectorAll('.message[data-index]')].find(n=>Number(n.getAttribute('data-index'))===binding.index);
        const original=group?.querySelector(config.kind==='architecture'?'path':'.m-line');
        if(!actual||!original||actual.getAttribute('d')!==original.getAttribute('d'))throw Error('Motion binding differs from actual authored path');
      }
    });
    if(name.startsWith('zenuml-exceptions')) {assert.equal(config.paths.length-steps.length,1,'unselected catch is visible but not played');assert.ok(await page.getByText('catch (busy)',{exact:true}).count()>0);assert.ok(await page.getByText('finally',{exact:true}).count()>0)}
    await page.getByRole('button',{name:'Play',exact:true}).focus();await page.keyboard.press('Space');
    await page.waitForFunction(()=>Number(document.querySelector('[data-diagram-viewer]')!.getAttribute('data-position'))>40);
    const pending=page.waitForEvent('download');await page.getByRole('button',{name:'Download SVG',exact:true}).click();const stream=await (await pending).createReadStream();const chunks:Buffer[]=[];for await(const c of stream!)chunks.push(Buffer.from(c));assert.equal(Buffer.concat(chunks).toString(),canonical);
    assert.equal(await root.getAttribute('data-playing'),'true');await page.getByRole('button',{name:'Pause',exact:true}).click();
    await page.locator('[data-control="seek"]').evaluate(n=>{const e=n as HTMLInputElement;e.value='500';e.dispatchEvent(new Event('input',{bubbles:true}))});
    await page.locator('.motion-overlay').evaluateAll(nodes=>{const root=document.querySelector('[data-diagram-viewer]')!;const config=JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);for(const n of nodes){const b=config.paths.find((b:any)=>b.key===(n as SVGGElement).dataset.key);const p=document.getElementById(b.id) as unknown as SVGPathElement;if(!p||p.getTotalLength()<=0)throw Error('Missing actual path')}});
    assert.equal(await page.locator('svg use').count(),iconCount);
    if(name.startsWith('architecture')) {
     assert.ok(await page.locator('[data-control="connection"]').isVisible());
     await page.getByRole('button',{name:'Show connection',exact:true}).click();await page.getByRole('button',{name:'Step',exact:true}).click();
     await page.locator('[data-control="seek"]').evaluate(n=>{const e=n as HTMLInputElement;e.value='500';e.dispatchEvent(new Event('input',{bubbles:true}))});
     assert.ok(await page.locator('.motion-overlay').count()>0);
     if(name.startsWith('architecture-cloud')) { await page.locator('[data-control="from"]').selectOption({label:'Database'});await page.locator('[data-control="to"]').selectOption({label:'API'});await page.getByRole('button',{name:'Show route',exact:true}).click();assert.ok(JSON.parse((await root.getAttribute('data-route'))!).length>0,'bidirectional reverse route'); }
    }
    await page.emulateMedia({media:'print'});assert.equal(await page.locator('.motion-controls').evaluate(n=>getComputedStyle(n).display),'none');assert.equal(await page.locator('svg use').count(),iconCount);await page.emulateMedia({media:'screen'});
    await page.getByRole('button',{name:'Play',exact:true}).click();await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'))});const before=await root.getAttribute('data-position');await page.waitForTimeout(80);assert.equal(await root.getAttribute('data-position'),before);await page.close();
   }
   const reduced=await open(html,'dark',true);await reduced.getByRole('button',{name:'Play',exact:true}).click();assert.equal(await reduced.locator('[data-diagram-viewer]').getAttribute('data-playing'),'false');await reduced.close();
  }
 }
 assert.deepEqual(errors,[]);assert.deepEqual(requests,[]);console.log('Qualified ZenUML symbols and architecture standalone SVG/offline playback, themes, keyboard, paths, print, reduced motion and canonical export');
} catch(error) {console.error({errors,requests});throw error} finally {await browser.close()}
