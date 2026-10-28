// Qualify current-commit stored artifacts. No workspace or site build occurs here.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { chromium, type Page } from 'playwright';

type Active = [number, string, string, string];
type Sample = [string, string, boolean, Active[]];
type Query = [string, string, string, string[]] | [];
type Player = [string, string, string, Sample[], Query];
const players = JSON.parse(await readFile('tests/animation-acceptance/__snapshot__/players.json', 'utf8')) as Player[];
const sequenceScenes = JSON.parse(await readFile('tests/acceptance/__snapshot__/scenes.json', 'utf8')) as [string, string, string, string][];
const bpmnScenes = JSON.parse(await readFile('tests/bpmn-acceptance/__snapshot__/scenes.json', 'utf8')) as [string, string, string, string][];
const runtime = await readFile('pkgs/diagrams-animated/assets/player.js', 'utf8');
const stylesheet = await readFile('pkgs/diagrams-animated/assets/player.css', 'utf8');
assert.equal(players.length, 27); assert.equal(sequenceScenes.length, 114); assert.equal(bpmnScenes.length, 12);
const browser = await chromium.launch();
const errors: string[] = [], requests: string[] = [];
async function page(html: string, preference: 'light' | 'dark' = 'light', reducedMotion: 'reduce' | 'no-preference' = 'no-preference') {
  const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, colorScheme: preference, reducedMotion, acceptDownloads: true });
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.route('**/*', route => { requests.push(route.request().url()); return route.abort(); });
  await page.setContent(html); await page.locator('[data-motion-ready="true"]').first().waitFor();
  return page;
}
async function seek(page: Page, milliseconds: number) {
  await page.locator('[data-control="seek"]').evaluate((element, value) => {
    const input = element as HTMLInputElement; input.value = String(value); input.dispatchEvent(new Event('input', { bubbles: true }));
  }, milliseconds);
}
async function position(page: Page) { return Number(await page.locator('[data-diagram-viewer]').getAttribute('data-position')); }
function player(name: string) { return players.find(entry => entry[0] === name)!; }
async function expectSamples(page: Page, samples: Sample[]) {
  for (const [time, elapsed, finished, expected] of samples) {
    await seek(page, Number(time));
    const actual = await page.locator('[data-diagram-viewer]').evaluate(root => ({
      time: root.getAttribute('data-position'), finished: root.getAttribute('data-finished'),
      overlays: [...root.querySelectorAll<SVGGElement>('.motion-overlay')].map(group => ({ ordinal: Number(group.dataset.ordinal), key: group.dataset.key, progress: Number(group.dataset.progress) })),
    }));
    assert.equal(actual.time, elapsed); assert.equal(actual.finished, String(finished));
    assert.deepEqual(actual.overlays.map(item => [item.ordinal, item.key]), expected.map(item => [item[0], item[1]]));
    actual.overlays.forEach((item, index) => assert.ok(Math.abs(item.progress - Number(expected[index][2]) / Number(expected[index][3])) < 1e-9));
    await page.locator('[data-diagram-viewer]').evaluate(root => {
      const config = JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);
      const svg = root.querySelector('svg')!;
      const paths = new Map([...svg.querySelectorAll<SVGPathElement>('path[id]')].map(path => [path.id, path]));
      for (const group of root.querySelectorAll<SVGGElement>('.motion-overlay')) {
        const binding = config.paths.find((binding: { key: string }) => binding.key === group.dataset.key);
        const path = paths.get(binding.id)!;
        for (const name of ['mask', 'clip-path']) {
          if (group.getAttribute(name) !== path.getAttribute(name)) throw new Error('Motion overlay loses crossing separation');
        }
        const dot = group.querySelector('circle')!;
        const p = path.getPointAtLength(path.getTotalLength() * (group.dataset.reversed === 'true' ? 1 - Number(group.dataset.progress) : Number(group.dataset.progress)));
        const actual = new DOMPoint(Number(dot.getAttribute('cx')), Number(dot.getAttribute('cy'))).matrixTransform(dot.getScreenCTM()!);
        const expected = new DOMPoint(p.x, p.y).matrixTransform(path.getScreenCTM()!);
        if (Math.abs(actual.x - expected.x) > .1 || Math.abs(actual.y - expected.y) > .1) throw new Error('Motion leaves its bound path/viewport');
      }
    });
  }
}
try {
  const xmlPage = await browser.newPage();
  for (const [name, mode, canonical, display] of [...sequenceScenes, ...bpmnScenes]) {
    await xmlPage.evaluate(({ canonical, display }) => {
      const parse = (source: string) => {
        const doc = new DOMParser().parseFromString(source, 'image/svg+xml');
        if (doc.querySelector('parsererror')) throw new Error('Invalid scene XML');
        const ids = [...doc.querySelectorAll('[id]')].map(node => node.id);
        if (ids.length !== new Set(ids).size) throw new Error('Scene IDs collide');
        for (const node of doc.querySelectorAll('*')) {
          if (['script', 'foreignObject', 'image', 'iframe', 'use', 'a'].includes(node.localName)) throw new Error('Active scene element');
          for (const attr of [...node.attributes]) {
            if (/^on/i.test(attr.name) || /href$/i.test(attr.name)) throw new Error('Active scene attribute');
            for (const match of attr.value.matchAll(/url\(([^)]+)\)/g)) if (!match[1].startsWith('#') || !doc.getElementById(match[1].slice(1))) throw new Error('Non-local scene reference');
          }
        }
        return doc;
      };
      const a = parse(canonical), b = parse(display);
      b.querySelectorAll('[data-motion-paths]').forEach(node => node.remove());
      function structure(node: Element): unknown {
        return [node.localName, [...node.attributes].map(attr => [attr.name, attr.value]),
          ['text', 'title', 'desc', 'style'].includes(node.localName) ? node.textContent : [...node.children].map(structure)];
      }
      if (JSON.stringify(structure(a.documentElement)) !== JSON.stringify(structure(b.documentElement))) throw new Error('Scene instrumentation changed canonical geometry/notation');
    }, { canonical, display }).catch(error => { throw new Error(`${name}/${mode}: ${error.message}`); });
  }
  await xmlPage.close();

  for (const [name, html, canonical, samples, expectedQuery] of players) {
    for (const preference of ['light', 'dark'] as const) {
      const view = await page(html, preference);
      assert.equal(await view.locator('.motion-overlay').count(), 0, `${name} starts still`);
      assert.equal(await view.locator('[data-diagram-viewer]').getAttribute('data-playing'), 'false');
      await view.evaluate(({ canonical, runtime, stylesheet }) => {
        const root = document.querySelector('[data-diagram-viewer]')!;
        const json = root.querySelector('script[data-motion-data]')!.textContent!;
        if (/[<&\u2028\u2029]/.test(json)) throw new Error('Unsafe script-context data');
        const data = JSON.parse(json);
        if (data.canonical !== canonical) throw new Error('Canonical data bytes differ');
        if (root.querySelector('script:not([type])')!.textContent !== runtime) throw new Error('Snapshot uses stale runtime');
        if (document.head.querySelector('style')!.textContent !== stylesheet) throw new Error('Snapshot uses stale stylesheet');
        const svg = root.querySelector('svg')!;
        const paths = new Map([...svg.querySelectorAll<SVGPathElement>('path[id]')].map(path => [path.id, path]));
        const bpmn = new Map([...svg.querySelectorAll<SVGGElement>('.bpmn-flow')].map(group => [group.getAttribute('data-id'), group.querySelector('path')]));
        const swimlanes = new Map([...svg.querySelectorAll<SVGGElement>('.swimlane-connection[data-swimlane-id]')].map(group => [group.getAttribute('data-swimlane-id'), group.querySelector('path')]));
        const messages = new Map([...svg.querySelectorAll<SVGGElement>('.message[data-index]')].map(group => [Number(group.getAttribute('data-index')), group.querySelector('.m-line')]));
        for (const binding of data.paths) {
          const path = paths.get(binding.id)!;
          const original = binding.kind === 'swimlane' ? swimlanes.get(binding.connection) : binding.kind === 'bpmn' ? bpmn.get(binding.connection) : messages.get(binding.index);
          if (!original || original.getAttribute('d') !== path.getAttribute('d')) throw new Error('Binding differs from actual rendered connection');
        }
        if ((globalThis as Record<string, unknown>).motionPwned) throw new Error('Source label executed');
      }, { canonical, runtime, stylesheet });
      assert.equal(await view.locator('[data-control="messages"]').isVisible(), name.startsWith("bpmn") || name.endsWith("limit") || name.startsWith("prefix"));
      await expectSamples(view, samples);
      if (expectedQuery.length) {
        const [from, to, outcome, keys] = expectedQuery;
        await view.locator('[data-control="from"]').selectOption(from); await view.locator('[data-control="to"]').selectOption(to);
        await view.getByRole('button', { name: 'Show route', exact: true }).click();
        const status = await view.locator('[role="status"]').textContent();
        if (outcome === 'found') assert.deepEqual(JSON.parse((await view.locator('[data-diagram-viewer]').getAttribute('data-route'))!), keys);
        else assert.match(status!, outcome === 'limit' ? /limit/i : /Unreachable/);
      }
      // Download while paused preserves both selected route and logical position.
      const before = await view.locator('[data-diagram-viewer]').evaluate(root => [root.getAttribute('data-position'), root.getAttribute('data-route'), root.getAttribute('data-playing')]);
      const pending = view.waitForEvent('download'); await view.getByRole('button', { name: 'Download SVG', exact: true }).click();
      const download = await pending, stream = await download.createReadStream(), chunks: Buffer[] = [];
      for await (const chunk of stream!) chunks.push(Buffer.from(chunk));
      assert.equal(Buffer.concat(chunks).toString('utf8'), canonical, `${name} downloads canonical bytes`);
      assert.deepEqual(await view.locator('[data-diagram-viewer]').evaluate(root => [root.getAttribute('data-position'), root.getAttribute('data-route'), root.getAttribute('data-playing')]), before);
      await view.emulateMedia({ media: 'print' });
      assert.equal(await view.locator('.motion-controls').evaluate(node => getComputedStyle(node).display), 'none');
      assert.equal(await view.locator('fieldset').evaluate(node => getComputedStyle(node).display), 'none');
      assert.ok(await view.locator('.motion-overlay').evaluateAll(nodes => nodes.every(node => getComputedStyle(node).display === 'none')));
      assert.ok(await view.locator('.motion-selected').evaluateAll(nodes => nodes.every(node => getComputedStyle(node).filter === 'none')));
      await view.close();
    }
  }

  // Physical motion, keyboard pause, seek and speed preserve the current timeline.
  for (const movingName of ['bpmn-default','swimlane-lr']) {
  const moving = await page(player(movingName)[1]);
  await moving.getByRole('button', { name: 'Play', exact: true }).focus(); await moving.keyboard.press('Space');
  await moving.waitForFunction(() => Number(document.querySelector('[data-diagram-viewer]')!.getAttribute('data-position')) > 100);
  const point = () => moving.locator('.motion-overlay circle').first().evaluate(dot => [dot.getAttribute('cx'),dot.getAttribute('cy')]);
  const p1 = await point();
  await moving.waitForTimeout(120); assert.notDeepEqual(await point(), p1);
  await moving.getByRole('button', { name: 'Pause', exact: true }).click(); const paused = await position(moving);
  await moving.waitForTimeout(100); assert.equal(await position(moving), paused);
  await seek(moving, 250); await moving.locator('[data-control="speed"]').selectOption('2'); assert.equal(await position(moving), 250);
  await moving.locator('[data-control="seek"]').focus(); await moving.keyboard.press('ArrowRight'); assert.equal(await position(moving), 251);
  await moving.getByRole('button', { name: 'Step', exact: true }).click(); assert.equal(await position(moving), 1000);
  await moving.getByRole('button', { name: 'Restart', exact: true }).click(); assert.equal(await position(moving), 0);
  await moving.getByRole('button', { name: 'Play', exact: true }).click(); await moving.waitForTimeout(100);
  await moving.evaluate(() => { Object.defineProperty(document, 'hidden', { configurable: true, get: () => true }); document.dispatchEvent(new Event('visibilitychange')); });
  const hidden = await position(moving); await moving.waitForTimeout(150); assert.equal(await position(moving), hidden);
  await moving.evaluate(() => { Object.defineProperty(document, 'hidden', { configurable: true, get: () => false }); document.dispatchEvent(new Event('visibilitychange')); });
  await moving.waitForFunction(old => Number(document.querySelector('[data-diagram-viewer]')!.getAttribute('data-position')) > old, hidden);
  const playingBeforeDownload = await position(moving);
  const liveDownload = moving.waitForEvent('download'); await moving.getByRole('button', { name: 'Download SVG', exact: true }).click();
  const liveStream=await (await liveDownload).createReadStream(), liveChunks:Buffer[]=[];
  for await (const chunk of liveStream!) liveChunks.push(Buffer.from(chunk));
  assert.equal(Buffer.concat(liveChunks).toString('utf8'),player(movingName)[2]);
  assert.equal(await moving.locator('[data-diagram-viewer]').getAttribute('data-playing'), 'true');
  assert.ok(await position(moving) >= playingBeforeDownload);
  await moving.close();
  }

  const reduced = await page(player('bpmn-default')[1], 'light', 'reduce');
  await reduced.getByRole('button', { name: 'Step', exact: true }).click(); assert.equal(await position(reduced), 1000);
  const still = await position(reduced); await reduced.waitForTimeout(150); assert.equal(await position(reduced), still);
  assert.equal(await reduced.locator('[data-diagram-viewer]').getAttribute('data-playing'), 'false'); await reduced.close();

  const routed = await page(player('bpmn-supplied')[1]);
  await routed.locator('[data-control="from"]').selectOption({ label: 'Prepare' });
  await routed.locator('[data-control="to"]').selectOption({ label: 'Supplier' });
  await routed.getByRole('button', { name: 'Show route', exact: true }).click(); assert.match((await routed.locator('[role="status"]').textContent())!, /Unreachable/);
  await routed.locator('[data-control="messages"]').check(); await routed.getByRole('button', { name: 'Show route', exact: true }).click();
  assert.equal(JSON.parse((await routed.locator('[data-diagram-viewer]').getAttribute('data-route'))!).length, 1);
  const base = await routed.locator('svg .bpmn-shape').evaluateAll(nodes => nodes.map(node => node.querySelector('.bpmn-bounds')!.outerHTML));
  await routed.getByRole('button', { name: 'Play', exact: true }).click(); await routed.waitForTimeout(100);
  await routed.locator('[data-control="to"]').selectOption({ label: 'Ready' }); await routed.getByRole('button', { name: 'Show route', exact: true }).click();
  assert.equal(await routed.locator('[data-diagram-viewer]').getAttribute('data-playing'), 'false');
  assert.deepEqual(await routed.locator('svg .bpmn-shape').evaluateAll(nodes => nodes.map(node => node.querySelector('.bpmn-bounds')!.outerHTML)), base);
  const selected = JSON.parse((await routed.locator('[data-diagram-viewer]').getAttribute('data-route'))!) as string[];
  const active = await routed.locator('.motion-overlay').evaluateAll(nodes => nodes.map(node => node.getAttribute('data-key')));
  assert.ok(active.length > 0 && active.every(key => selected.includes(key!)), 'route replacement removes old overlays');
  await routed.locator('[data-control="direction"]').selectOption('reverse'); await routed.getByRole('button', { name: 'Show reachability', exact: true }).click();
  assert.ok(JSON.parse((await routed.locator('[data-diagram-viewer]').getAttribute('data-reachable'))!).length > 1);
  await routed.close();

  const finite = await page(player('bpmn-concurrent')[1]);
  await seek(finite, 1500); await finite.getByRole('button', { name: 'Play', exact: true }).click();
  await finite.waitForFunction(() => document.querySelector('[data-diagram-viewer]')!.getAttribute('data-finished') === 'true');
  assert.equal(await position(finite), 1750); assert.equal(await finite.locator('.motion-overlay').count(), 0);
  assert.equal(await finite.locator('[data-diagram-viewer]').getAttribute('data-playing'), 'false'); await finite.close();

  const cycle = await page(player('bpmn-cyclic')[1]);
  await cycle.locator('[data-control="from"]').selectOption('A'); await cycle.getByRole('button', { name: 'Show reachability', exact: true }).click();
  assert.deepEqual(JSON.parse((await cycle.locator('[data-diagram-viewer]').getAttribute('data-reachable'))!), ['A', 'B', 'C', 'D']); await cycle.close();

  // Swimlane routes preserve orientation on the actual shared path, without
  // changing arrow markers. Unheaded connections remain an explicit choice.
  const swim = await page(player('swimlane-lr')[1]);
  await swim.locator('[data-control="from"]').selectOption('B'); await swim.locator('[data-control="to"]').selectOption('A');
  const markers = await swim.locator('.swimlane-connection').evaluateAll(nodes => nodes.map(node => node.outerHTML));
  await swim.getByRole('button', { name: 'Show route', exact: true }).click();
  await seek(swim, 250);
  assert.equal(await swim.locator('.motion-overlay').getAttribute('data-reversed'), 'true');
  await swim.locator('.motion-overlay').evaluate(group => {
    const root=group.closest('[data-diagram-viewer]')!;
    const data=JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);
    const binding=data.paths.find((binding: {key:string}) => binding.key === group.getAttribute('data-key'));
    const path=root.querySelector<SVGPathElement>(`[id="${binding.id}"]`)!;
    const expected=path.getPointAtLength(path.getTotalLength()*.75), dot=group.querySelector('circle')!;
    if (Math.abs(Number(dot.getAttribute('cx'))-expected.x)>.1 || Math.abs(Number(dot.getAttribute('cy'))-expected.y)>.1) throw new Error('Bidirectional return motion is not reversed');
  });
  assert.deepEqual(await swim.locator('.swimlane-connection').evaluateAll(nodes => nodes.map(node => node.outerHTML)),markers);
  await swim.locator('[data-control="from"]').selectOption('C');
  await swim.getByRole('button', { name: 'Show route', exact: true }).click();
  assert.match((await swim.locator('[role="status"]').textContent())!,/Unreachable/);
  await swim.locator('[data-control="undirected"]').check();
  await swim.getByRole('button', { name: 'Show route', exact: true }).click();
  assert.equal(JSON.parse((await swim.locator('[data-diagram-viewer]').getAttribute('data-route'))!).length,1);
  const parallelKey=await swim.locator('[data-diagram-viewer]').evaluate(root => JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!).paths.find((binding:{connection:string}) => binding.connection==='parallel').key);
  await swim.locator('[data-control="connection"]').selectOption(parallelKey);
  await swim.getByRole('button',{name:'Show connection',exact:true}).click();
  await seek(swim,250);
  assert.equal(await swim.locator('[data-diagram-viewer]').getAttribute('data-connection'),'parallel');
  assert.deepEqual(await swim.locator('.motion-overlay').evaluateAll(nodes => nodes.map(node => node.getAttribute('data-key'))),[parallelKey]);
  await swim.getByRole('button',{name:'Play',exact:true}).click();
  const selectedDownload=swim.waitForEvent('download'); await swim.getByRole('button',{name:'Download SVG',exact:true}).click();
  const selectedStream=await (await selectedDownload).createReadStream(), selectedChunks:Buffer[]=[];
  for await (const chunk of selectedStream!) selectedChunks.push(Buffer.from(chunk));
  assert.equal(Buffer.concat(selectedChunks).toString('utf8'),player('swimlane-lr')[2]);
  assert.equal(await swim.locator('[data-diagram-viewer]').getAttribute('data-connection'),'parallel');
  assert.ok(await position(swim)>=250);
  await swim.close();
  const identity=await page(player('swimlane-identity')[1]);
  await identity.locator('[data-control="from"]').selectOption('Handoff');
  await identity.getByRole('button',{name:'Show reachability',exact:true}).click();
  assert.equal(await identity.locator('.swimlane-lane.motion-selected').count(),1);
  assert.equal(await identity.locator('.swimlane-connection.motion-selected').count(),0);
  await identity.getByRole('button',{name:'Show connection',exact:true}).click();
  assert.equal(await identity.locator('.swimlane-lane.motion-selected').count(),0);
  assert.equal(await identity.locator('.swimlane-connection.motion-selected').count(),1);
  await identity.getByRole('button',{name:'Play',exact:true}).focus(); await identity.keyboard.press('Space');
  await identity.waitForFunction(() => Number(document.querySelector('[data-diagram-viewer]')!.getAttribute('data-position'))>50);
  await identity.keyboard.press('Space'); const identityPaused=await position(identity);
  await identity.waitForTimeout(80); assert.equal(await position(identity),identityPaused);
  assert.equal(await identity.locator('[data-diagram-viewer]').getAttribute('data-playing'),'false');
  await identity.close();
  const collapsed=await page(player('swimlane-collapsed')[1]);
  assert.equal(await collapsed.locator('[data-control="from"] option[value="Hidden"]').count(),0);
  await collapsed.locator('[data-control="from"]').evaluate(element => { const option=document.createElement('option'); option.value='Hidden'; option.textContent='Hidden'; element.append(option); });
  await collapsed.locator('[data-control="from"]').selectOption('Hidden');
  await collapsed.getByRole('button',{name:'Show route',exact:true}).click();
  assert.match((await collapsed.locator('[role="status"]').textContent())!,/Outside current view/); await collapsed.close();
  const swimReduced=await page(player('swimlane-lr')[1],'dark','reduce');
  await swimReduced.getByRole('button', {name:'Step',exact:true}).click();
  const swimStill=await position(swimReduced); await swimReduced.waitForTimeout(120); assert.equal(await position(swimReduced),swimStill); await swimReduced.close();

  const inline = await page(player('prefix-a')[1] + player('prefix-b')[1]);
  assert.equal(await inline.locator('[data-diagram-viewer]').count(), 2);
  await inline.locator('[data-diagram-viewer]').first().getByRole('button', { name: 'Step', exact: true }).click();
  assert.equal(await inline.locator('[data-diagram-viewer]').first().getAttribute('data-position'), '1000');
  assert.equal(await inline.locator('[data-diagram-viewer]').last().getAttribute('data-position'), '0');
  assert.ok(await inline.locator('svg [id]').evaluateAll(nodes => new Set(nodes.map(node => node.id)).size === nodes.length));
  await inline.close();
  // PlantUML players: path steps on actual connectors, row and term visits
  // without fake paths, controls, export and preserved trace highlights.
  const plantuml = JSON.parse(await readFile('tests/plantuml-acceptance/__snapshot__/plantuml-gallery.json', 'utf8')) as [string, string, string][];
  const plantumlPlayers = plantuml.filter(([, kind]) => kind === 'player');
  const plantumlSvg = new Map(plantuml.filter(([, kind]) => kind === 'svg').map(([name, , content]) => [name, content]));
  assert.ok(plantumlPlayers.length >= 10, 'PlantUML review players');
  for (const [name, , html] of plantumlPlayers) {
    for (const preference of ['light', 'dark'] as const) {
      const view = await page(html, preference);
      assert.equal(await view.locator('.motion-overlay').count(), 0, `${name} starts still`);
      assert.equal(await view.locator('.motion-visit').count(), 0, `${name} starts without visits`);
      const canonical = await view.locator('[data-diagram-viewer]').evaluate(root => JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!).canonical as string);
      await view.locator('[data-diagram-viewer]').evaluate((root, canonical) => {
        // The display copy has the canonical structure plus motion paths only.
        const structure = (node: Element): unknown => [node.localName, [...node.attributes].map(attr => [attr.name, attr.value]),
          ['text', 'title', 'desc', 'style', 'tspan'].includes(node.localName) ? node.textContent : [...node.children].map(structure)];
        const a = new DOMParser().parseFromString(canonical, 'image/svg+xml').documentElement;
        const b = root.querySelector('svg')!.cloneNode(true) as Element;
        b.querySelectorAll('[data-motion-paths]').forEach(node => node.remove());
        if (JSON.stringify(structure(a)) !== JSON.stringify(structure(b))) throw new Error('Display copy changes canonical geometry');
      }, canonical);
      const stored = plantumlSvg.get(name.replace(/\.html$/, '.svg'));
      if (stored) assert.equal(canonical, stored, `${name} canonical equals the direct render`);
      const plan = await view.locator('[data-diagram-viewer]').evaluate(root => {
        const data = JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);
        const svg = root.querySelector('svg')!;
        const paths = new Map([...svg.querySelectorAll<SVGPathElement>('path[id]')].map(path => [path.id, path]));
        for (const binding of data.paths) {
          const original = svg.querySelector(binding.kind === 'railroad' ? `.rr-connector[data-connector="${CSS.escape(binding.connection)}"]` : `.data-connector[data-member="${CSS.escape(binding.connection)}"]`);
          if (!original || original.getAttribute('d') !== paths.get(binding.id)!.getAttribute('d')) throw new Error('Binding differs from the drawn connector');
          if (paths.get(binding.id)!.getTotalLength() <= 0) throw new Error('Zero-length motion path');
        }
        return data.plan.steps.map((step: { start_ms: string; duration_ms: string; visit: boolean; key: string }) => [Number(step.start_ms), Number(step.duration_ms), step.visit, step.key]) as [number, number, boolean, string][];
      });
      const visit = plan.find(step => step[2]), path = plan.find(step => !step[2]);
      assert.ok(visit && path, `${name} has visits and connector steps`);
      await seek(view, visit![0] + Math.floor(visit![1] / 2));
      assert.equal(await view.locator('.motion-visit').count(), 1, `${name} highlights the visited term or row`);
      assert.equal(await view.locator('.motion-overlay').count(), 0, `${name} draws no path for a visit`);
      assert.ok(Math.abs(Number(await view.locator('.motion-visit').getAttribute('data-motion-progress')) - .5) < .01);
      // Export during a visit returns the canonical bytes and keeps the position.
      const before = await position(view);
      const pending = view.waitForEvent('download'); await view.getByRole('button', { name: 'Download SVG', exact: true }).click();
      const stream = await (await pending).createReadStream(), chunks: Buffer[] = [];
      for await (const chunk of stream!) chunks.push(Buffer.from(chunk));
      assert.equal(Buffer.concat(chunks).toString('utf8'), canonical, `${name} downloads canonical bytes`);
      assert.equal(await position(view), before);
      await seek(view, path![0] + Math.floor(path![1] / 2));
      assert.equal(await view.locator('.motion-overlay').count(), 1, `${name} animates the connector path`);
      assert.equal(await view.locator('.motion-visit').count(), 0);
      if (canonical.includes('rr-trace')) {
        assert.ok(await view.locator('.rr-trace').count() === 1, 'configured trace highlights stay in the canonical view');
        assert.equal(await view.locator('.rr-trace .motion-overlay').count(), 0, 'playback overlays stay separate from trace evidence');
      }
      await view.emulateMedia({ media: 'print' });
      await seek(view, visit![0] + 1);
      assert.ok(await view.locator('.motion-visit').evaluateAll(nodes => nodes.every(node => getComputedStyle(node).filter === 'none')));
      await view.close();
    }
  }
  const railroad = await page(plantumlPlayers.find(([name]) => name === 'regex-date-light.html')![2]);
  await railroad.getByRole('button', { name: 'Play', exact: true }).focus(); await railroad.keyboard.press('Space');
  await railroad.waitForFunction(() => Number(document.querySelector('[data-diagram-viewer]')!.getAttribute('data-position')) > 100);
  await railroad.keyboard.press('Space'); const stopped = await position(railroad);
  await railroad.waitForTimeout(100); assert.equal(await position(railroad), stopped, 'keyboard pause');
  await railroad.getByRole('button', { name: 'Restart', exact: true }).click(); assert.equal(await position(railroad), 0);
  await railroad.getByRole('button', { name: 'Step', exact: true }).click(); assert.ok(await position(railroad) > 0);
  const options = await railroad.locator('[data-control="from"] option').evaluateAll(nodes => nodes.map(node => (node as HTMLOptionElement).value));
  await railroad.locator('[data-control="from"]').selectOption(options[0]); await railroad.locator('[data-control="to"]').selectOption(options[options.length - 1]);
  await railroad.getByRole('button', { name: 'Show route', exact: true }).click();
  assert.match((await railroad.locator('[role="status"]').textContent())!, /Structural route|Unreachable/);
  await railroad.evaluate(() => { Object.defineProperty(document, 'hidden', { configurable: true, get: () => true }); document.dispatchEvent(new Event('visibilitychange')); });
  await railroad.getByRole('button', { name: 'Play', exact: true }).click(); const hiddenAt = await position(railroad);
  await railroad.waitForTimeout(120); assert.equal(await position(railroad), hiddenAt, 'hidden pages do not advance');
  await railroad.close();
  const reducedRailroad = await page(plantumlPlayers.find(([name]) => name === 'ebnf-arithmetic-dark.html')![2], 'dark', 'reduce');
  await reducedRailroad.getByRole('button', { name: 'Play', exact: true }).click();
  assert.equal(await reducedRailroad.locator('[data-diagram-viewer]').getAttribute('data-playing'), 'false');
  assert.ok(await position(reducedRailroad) > 0, 'reduced motion steps instead of playing');
  await reducedRailroad.close();
  const styled = JSON.parse(await readFile('tests/animation-acceptance/__snapshot__/connectors.json', 'utf8')) as [string, string, string, string][];
  assert.equal(styled.length, 30, 'all eight diagram kinds in each connector style and the six crossing comparisons');
  for (const [name, style, canonical, html] of styled) {
    for (const preference of ['light', 'dark'] as const) {
      const view = await page(html, preference);
      assert.equal(await view.locator('.motion-overlay').count(), 0, `${name}/${style} starts still`);
      await view.locator('[data-diagram-viewer]').evaluate(root => {
        const data = JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);
        const svg = root.querySelector('svg')!;
        const visible = [...svg.querySelectorAll<SVGPathElement>('path[data-connector-route]')];
        for (const binding of data.paths) {
          const motion = svg.querySelector<SVGPathElement>(`#${CSS.escape(binding.id)}`)!;
          if (!visible.some(path => path.getAttribute('d') === motion.getAttribute('d') && path.getAttribute('mask') === motion.getAttribute('mask'))) throw new Error('Styled motion differs from final canonical connector');
        }
      });
      const samples: string[][] = [];
      for (const time of [250, 750, 1250, 1750, 2250]) {
        await seek(view, time);
        assert.equal(await view.locator('.motion-overlay').count(), 1);
        await view.locator('[data-diagram-viewer]').evaluate(root => {
          const data = JSON.parse(root.querySelector('script[data-motion-data]')!.textContent!);
          const overlay = root.querySelector<SVGGElement>('.motion-overlay')!;
          const binding = data.paths.find((p: { key: string }) => p.key === overlay.dataset.key);
          const path = root.querySelector<SVGPathElement>(`#${CSS.escape(binding.id)}`)!;
          const progress = Number(overlay.dataset.progress);
          const expected = path.getPointAtLength(path.getTotalLength() * (overlay.dataset.reversed === 'true' ? 1 - progress : progress));
          const dot = overlay.querySelector('circle')!;
          if (Math.abs(Number(dot.getAttribute('cx')) - expected.x) > .1 || Math.abs(Number(dot.getAttribute('cy')) - expected.y) > .1) throw new Error('Styled forward/reverse motion leaves its path');
          if (overlay.querySelector('path')!.getAttribute('d') !== path.getAttribute('d')) throw new Error('Progress path differs from canonical geometry');
          const dashOffset = Number(overlay.querySelector('path')!.getAttribute('stroke-dashoffset'));
          const expectedOffset = (overlay.dataset.reversed === 'true' ? 1 : -1) * path.getTotalLength() * progress;
          if (Math.abs(dashOffset - expectedOffset) > .1) throw new Error('Progress dash moves against the resolved traversal direction');
          if (overlay.getAttribute('mask') !== path.getAttribute('mask')) throw new Error('Styled underpass mask lost');
        });
        samples.push(await view.locator('.motion-overlay circle').evaluate(dot => [dot.getAttribute('cx')!, dot.getAttribute('cy')!]));
      }
      assert.notDeepEqual(samples[0], samples[1], `${name}/${style} token moves`);
      assert.deepEqual(samples[0], samples[3], 'reverse traversal returns through the same point');
      assert.deepEqual(samples[1], samples[2], 'reverse traversal follows the visible path');
      assert.deepEqual(samples[0], samples[4], 'repeated occurrence retains geometry');
      assert.equal(await view.locator('.motion-overlay').getAttribute('data-ordinal'), '2', 'repeated occurrence keeps its ordinal');
      await view.locator('[data-control="speed"]').selectOption('2');
      const before = await position(view);
      const key = await view.locator('.motion-overlay').getAttribute('data-key');
      const pending = view.waitForEvent('download');
      await view.getByRole('button', { name: 'Download SVG', exact: true }).click();
      const stream = await (await pending).createReadStream(), chunks: Buffer[] = [];
      for await (const chunk of stream!) chunks.push(Buffer.from(chunk));
      assert.equal(Buffer.concat(chunks).toString('utf8'), canonical, `${name}/${style} exact canonical export`);
      assert.equal(await position(view), before);
      assert.equal(await view.locator('.motion-overlay').getAttribute('data-key'), key);
      assert.equal(await view.locator('[data-control="speed"]').inputValue(), '2');
      await view.emulateMedia({ media: 'print' });
      assert.ok(await view.locator('.motion-overlay').evaluateAll(nodes => nodes.every(node => getComputedStyle(node).display === 'none')));
      await view.close();
    }
  }
  console.log(`Verified ${styled.length} styled players in both preferences, with final-path identity, forward/reverse/repeated motion, masks, print and exact state-preserving exports.`);
  console.log(`Verified ${plantumlPlayers.length} PlantUML players in both preferences, including canonical/display identity, term and row visits, connector paths, export during a visit, trace preservation and print.`);
  assert.deepEqual(requests, [], 'standalone artifacts stay offline'); assert.deepEqual(errors, [], 'standalone artifacts have no browser errors');
  console.log(`Verified ${sequenceScenes.length + bpmnScenes.length} canonical/display scene pairs and ${players.length} offline players in both preferences, including pure samples, paths, controls, exploration, print and exact SVG downloads.`);
} finally { await browser.close(); }
