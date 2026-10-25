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
assert.equal(players.length, 13); assert.equal(sequenceScenes.length, 114); assert.equal(bpmnScenes.length, 12);
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
        const dot = group.querySelector('circle')!;
        const p = path.getPointAtLength(path.getTotalLength() * Number(group.dataset.progress));
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
        const messages = new Map([...svg.querySelectorAll<SVGGElement>('.message[data-index]')].map(group => [Number(group.getAttribute('data-index')), group.querySelector('.m-line')]));
        for (const binding of data.paths) {
          const path = paths.get(binding.id)!;
          const original = binding.kind === 'bpmn' ? bpmn.get(binding.connection) : messages.get(binding.index);
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
  const moving = await page(player('bpmn-default')[1]);
  await moving.getByRole('button', { name: 'Play', exact: true }).focus(); await moving.keyboard.press('Space');
  await moving.waitForFunction(() => Number(document.querySelector('[data-diagram-viewer]')!.getAttribute('data-position')) > 100);
  const p1 = await moving.locator('.motion-overlay circle').first().getAttribute('cx');
  await moving.waitForTimeout(120); assert.notEqual(await moving.locator('.motion-overlay circle').first().getAttribute('cx'), p1);
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
  const liveDownload = moving.waitForEvent('download'); await moving.getByRole('button', { name: 'Download SVG', exact: true }).click(); await liveDownload;
  assert.equal(await moving.locator('[data-diagram-viewer]').getAttribute('data-playing'), 'true');
  assert.ok(await position(moving) >= playingBeforeDownload);
  await moving.close();

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

  const inline = await page(player('prefix-a')[1] + player('prefix-b')[1]);
  assert.equal(await inline.locator('[data-diagram-viewer]').count(), 2);
  await inline.locator('[data-diagram-viewer]').first().getByRole('button', { name: 'Step', exact: true }).click();
  assert.equal(await inline.locator('[data-diagram-viewer]').first().getAttribute('data-position'), '1000');
  assert.equal(await inline.locator('[data-diagram-viewer]').last().getAttribute('data-position'), '0');
  assert.ok(await inline.locator('svg [id]').evaluateAll(nodes => new Set(nodes.map(node => node.id)).size === nodes.length));
  await inline.close();
  assert.deepEqual(requests, [], 'standalone artifacts stay offline'); assert.deepEqual(errors, [], 'standalone artifacts have no browser errors');
  console.log(`Verified ${sequenceScenes.length + bpmnScenes.length} canonical/display scene pairs and ${players.length} offline players in both preferences, including pure samples, paths, controls, exploration, print and exact SVG downloads.`);
} finally { await browser.close(); }
