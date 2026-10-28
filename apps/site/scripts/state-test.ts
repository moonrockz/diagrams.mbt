// Qualify committed native-state artifacts without a library or site build.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { chromium, type Page } from 'playwright';

type Row = [string, string, string];
const rows = JSON.parse(await readFile('tests/state-gallery-acceptance/__snapshot__/state-gallery.json','utf8')) as Row[];
const artifacts = new Map(rows.map(([name,,text]) => [name,text]));
const hostileRows = JSON.parse(await readFile('tests/state-gallery-acceptance/__snapshot__/hostile-state.json','utf8')) as Row[];
const browser = await chromium.launch({ headless:true });
const errors:string[] = [], requests:string[] = [];
async function open(html:string, colorScheme:'light'|'dark', reducedMotion:'reduce'|'no-preference'='no-preference') {
  const page = await browser.newPage({ viewport:{width:1600,height:1000},colorScheme,reducedMotion,acceptDownloads:true });
  page.on('pageerror',error => errors.push(error.message));
  page.on('console',message => { if(message.type()==='error') errors.push(message.text()); });
  await page.route('**/*',route => { requests.push(route.request().url()); return route.abort(); });
  await page.setContent(html);
  return page;
}
async function seek(page:Page,time:number) {
  await page.locator('[data-control="seek"]').evaluate((element,time) => {
    const input=element as HTMLInputElement; input.value=String(time); input.dispatchEvent(new Event('input',{bubbles:true}));
  },time);
}
async function download(page:Page) {
  const state = () => page.locator('[data-diagram-viewer]').evaluate(element => ({
    position:(element as HTMLElement).dataset.position,
    speed:(element as HTMLElement).dataset.speed,
    playing:(element as HTMLElement).dataset.playing,
    route:(element as HTMLElement).dataset.route,
    connection:(element as HTMLElement).dataset.connection,
    reachable:(element as HTMLElement).dataset.reachable,
    occurrences:[...element.querySelectorAll('.motion-overlay')].map(overlay=>[(overlay as HTMLElement).dataset.key,(overlay as HTMLElement).dataset.ordinal]),
  }));
  const before=await state();
  const pending=page.waitForEvent('download');
  await page.getByRole('button',{name:'Download SVG',exact:true}).click();
  const stream=await (await pending).createReadStream();
  const chunks:Buffer[]=[];
  for await(const chunk of stream!) chunks.push(Buffer.from(chunk));
  const after=await state();
  assert.equal(after.speed,before.speed,'export changes speed');
  assert.equal(after.playing,before.playing,'export changes playback');
  assert.equal(after.route,before.route,'export changes route selection');
  assert.equal(after.connection,before.connection,'export changes connection selection');
  assert.equal(after.reachable,before.reachable,'export changes reachability selection');
  if(before.playing==='false') {
    assert.equal(after.position,before.position,'export changes position');
    assert.deepEqual(after.occurrences,before.occurrences,'export changes repeated occurrence');
  }
  return Buffer.concat(chunks).toString();
}
try {
  assert.equal(rows.length,48);
  assert.equal(rows.filter(([,mime])=>mime==='image/svg+xml').length,21);
  assert.equal(rows.filter(([,mime])=>mime==='text/html').length,21);
  for(const [name,mime,source] of rows) {
    if(mime==='text/plain') continue;
    for(const theme of ['light','dark'] as const) {
      if(mime==='image/svg+xml') {
        const page=await open('',theme);
        await page.evaluate(({source,name})=>{
          const xml=new DOMParser().parseFromString(source,'image/svg+xml');
          if(xml.querySelector('parsererror,script,foreignObject,image,iframe,animate,set')) throw Error('Invalid or active state SVG: '+name);
          const svg=document.importNode(xml.documentElement,true) as unknown as SVGSVGElement;
          document.body.append(svg);
          if(!svg.querySelector('title')||!svg.querySelector('desc')) throw Error('Missing accessibility fields: '+name);
          const ids=[...svg.querySelectorAll('[id]')].map(element=>element.id);
          if(ids.length!==new Set(ids).size) throw Error('Duplicate IDs: '+name);
          for(const element of svg.querySelectorAll('*')) for(const attribute of element.attributes) {
            if(/^on/i.test(attribute.name)) throw Error('Executable attribute');
            if(/href$/i.test(attribute.name)&&!attribute.value.startsWith('#')) throw Error('External SVG reference');
            for(const match of attribute.value.matchAll(/url\(([^)]+)\)/g)) if(!match[1].startsWith('#')||!document.getElementById(match[1].slice(1))) throw Error('Invalid paint reference');
          }
          for(const element of svg.querySelectorAll('text')) {
            if(parseFloat(getComputedStyle(element).fontSize)<11) throw Error('Small state text');
            const box=element.getBBox(),view=svg.viewBox.baseVal;
            if(box.x<view.x-1||box.y<view.y-1||box.x+box.width>view.x+view.width+1||box.y+box.height>view.y+view.height+1) throw Error('State text outside view: '+element.textContent);
          }
          if(/-(light|dark)\.svg$/.test(name)&&(svg.querySelector('style')||/var\(/.test(source))) throw Error('Fixed SVG contains adaptive CSS');
        },{source,name});
        await page.screenshot({path:`_build/${name}-${theme}.png`,fullPage:true});
        await page.close();
        continue;
      }
      const page=await open(source,theme);
      const root=page.locator('[data-diagram-viewer]');
      await page.locator('[data-motion-ready="true"]').waitFor();
      assert.equal(await root.getAttribute('data-playing'),'false');
      assert.equal(await page.locator('.motion-overlay,.motion-visit').count(),0);
      const config=await page.locator('script[data-motion-data]').evaluate(element=>JSON.parse(element.textContent!));
      assert.equal(config.kind,'state');
      assert.equal(await page.evaluate(()=>Boolean((globalThis as any).stateAttack)),false);
      assert.equal(config.plan.steps.length,4);
      assert.equal(config.plan.steps[0].key,config.plan.steps[1].key);
      assert.ok(config.paths.length>0);
      await page.evaluate(()=>{
        const root=document.querySelector('[data-diagram-viewer]')!;
        const config=JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);
        for(const binding of config.paths) {
          const path=document.getElementById(binding.id);
          const group=[...root.querySelectorAll('.state-connection[data-state-id]')].find(element=>element.getAttribute('data-state-id')===binding.connection);
          if(!path||!group||path.getAttribute('d')!==group.querySelector('path')?.getAttribute('d')) throw Error('State motion differs from drawn path');
        }
      });
      const canonical=artifacts.get(name.replace(/\.html$/,'.svg'))!;
      await page.getByRole('button',{name:'Play',exact:true}).focus();
      await page.keyboard.press('Space');
      await page.waitForFunction(()=>Number(document.querySelector('[data-diagram-viewer]')!.getAttribute('data-position'))>40);
      assert.equal(await download(page),canonical);
      assert.equal(await root.getAttribute('data-playing'),'true');
      await page.getByRole('button',{name:'Pause',exact:true}).click();
      await seek(page,1250);
      assert.equal(await root.getAttribute('data-position'),'1250');
      await page.locator('[data-control="speed"]').selectOption('2');
      assert.equal(await root.getAttribute('data-position'),'1250');
      assert.equal(await page.locator('.motion-overlay').first().getAttribute('data-ordinal'),'1');
      assert.equal(await download(page),canonical);
      assert.equal(await root.getAttribute('data-position'),'1250');

      const maskedKey=await page.evaluate(()=>{
        const config=JSON.parse(document.querySelector('script[data-motion-data]')!.textContent!);
        return config.paths.find((p:any)=>document.getElementById(p.id)?.hasAttribute('mask'))?.key;
      });
      if(name.includes('curved-')) assert.ok(maskedKey,'curved state fixture must exercise an underpass');
      if(name.includes('elbow-plain-')) assert.equal(maskedKey,undefined);
      const edge=config.graph.edges.find((item:any)=>item.kind==='state'&&item.source!==item.target&&!item.reversed&&(!maskedKey||item.occurrence===maskedKey));
      assert.ok(edge);
      await page.locator('[data-control="from"]').selectOption(edge.target);
      await page.locator('[data-control="to"]').selectOption(edge.source);
      await page.locator('[data-control="direction"]').selectOption('reverse');
      await page.getByRole('button',{name:'Show route',exact:true}).click();
      assert.ok(JSON.parse((await root.getAttribute('data-route'))!).length>0);
      await seek(page,250);
      const overlay=page.locator('.motion-overlay').first();
      assert.equal(await overlay.getAttribute('data-reversed'),'true');
      await overlay.evaluate(element=>{
        const root=document.querySelector('[data-diagram-viewer]')!;
        const config=JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);
        const binding=config.paths.find((item:any)=>item.key===(element as SVGGElement).dataset.key);
        const path=document.getElementById(binding.id) as unknown as SVGPathElement;
        const expected=path.getPointAtLength(path.getTotalLength()*.75);
        const circle=element.querySelector('circle')!;
        if(Math.abs(Number(circle.getAttribute('cx'))-expected.x)>.01||Math.abs(Number(circle.getAttribute('cy'))-expected.y)>.01) throw Error('Reverse state route moves in wrong direction');
      });
      await overlay.evaluate(element=>{
        const root=document.querySelector('[data-diagram-viewer]')!;
        const config=JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);
        const binding=config.paths.find((item:any)=>item.key===(element as SVGGElement).dataset.key);
        const path=document.getElementById(binding.id)!;
        for(const name of ['mask','clip-path']) if(element.getAttribute(name)!==path.getAttribute(name)) throw Error('State overlay loses crossing separation: '+name);
        if(element.querySelector('path')?.getAttribute('d')!==path.getAttribute('d')) throw Error('State overlay loses connector curve');
      });
      assert.equal(await download(page),canonical);
      await page.getByRole('button',{name:'Show reachability',exact:true}).click();
      assert.ok(await page.locator('.motion-selected').count()>0);
      await page.getByRole('button',{name:'Reset view',exact:true}).click();
      await page.getByRole('button',{name:'Show connection',exact:true}).click();
      await seek(page,250);
      assert.equal(await page.locator('.motion-overlay').count(),1);
      await page.getByRole('button',{name:'Reset view',exact:true}).click();
      await seek(page,2250);
      assert.equal(await page.locator('.motion-overlay').count(),1);
      assert.equal(await page.locator('.motion-visit').count(),1);
      assert.equal(await download(page),canonical);
      assert.equal(await root.getAttribute('data-position'),'2250');
      assert.equal(await download(page),canonical);
      await page.emulateMedia({media:'print'});
      assert.equal(await page.locator('.motion-controls').evaluate(element=>getComputedStyle(element).display),'none');
      assert.ok(await page.locator('svg .state-node').count()>0);
      await page.emulateMedia({media:'screen'});
      await page.getByRole('button',{name:'Reset view',exact:true}).click();
      await page.getByRole('button',{name:'Play',exact:true}).click();
      await page.evaluate(()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'));});
      const position=await root.getAttribute('data-position');
      await page.waitForTimeout(80);
      assert.equal(await root.getAttribute('data-position'),position);
      await page.close();
    }
    if(mime==='text/html') {
      const page=await open(source,'dark','reduce');
      await page.getByRole('button',{name:'Play',exact:true}).click();
      assert.equal(await page.locator('[data-diagram-viewer]').getAttribute('data-playing'),'false');
      await page.getByRole('button',{name:'Step',exact:true}).click();
      assert.ok(Number(await page.locator('[data-diagram-viewer]').getAttribute('data-position'))>0);
      await page.close();
    }
  }
  assert.equal(hostileRows.length,4);
  const hostileArtifacts=new Map(hostileRows.map(([name,,text])=>[name,text]));
  for(const [name,mime,source] of hostileRows) {
    if(mime!=='text/html') continue;
    for(const theme of ['light','dark'] as const) {
      const page=await open(source,theme);
      await page.locator('[data-motion-ready="true"]').waitFor();
      assert.equal(await page.evaluate(()=>Boolean((globalThis as any).stateAttack)),false,'source label executed');
      assert.ok((await page.locator('svg').textContent())?.includes('</script><script>globalThis.stateAttack=true</script>'));
      await page.getByRole('button',{name:'Step',exact:true}).click();
      assert.ok(Number(await page.locator('[data-diagram-viewer]').getAttribute('data-position'))>0);
      assert.equal(await download(page),hostileArtifacts.get(name.replace(/\.html$/,'.svg')));
      assert.equal(await page.evaluate(()=>Boolean((globalThis as any).stateAttack)),false);
      await page.close();
    }
  }
  // Distinct prefixes allow two state diagrams to share an ordinary host page.
  const inline=await open('', 'light');
  const inlineSources=rows.filter(([name,mime])=>mime==='image/svg+xml'&&name.endsWith('-light.svg')).slice(0,2).map(([, ,svg])=>svg);
  await inline.setContent(inlineSources.join(''));
  const inlineIds=await inline.locator('[id]').evaluateAll(elements=>elements.map(element=>element.id));
  assert.equal(inlineIds.length,new Set(inlineIds).size,'inline state prefixes collide');
  await inline.close();
  assert.deepEqual(errors,[]);assert.deepEqual(requests,[]);
  console.log('Qualified Mermaid and PlantUML state SVG, offline scenarios, reverse paths, node visits, controls, reduced motion, print and exact canonical exports in both themes.');
} catch(error) { console.error({errors,requests}); throw error; }
finally { await browser.close(); }
