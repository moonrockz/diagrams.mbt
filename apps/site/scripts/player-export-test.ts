// Real generated-player UI -> compiled portable-library worker. Independent
// decoder coverage complements the portable-byte fixtures in raster-test.ts.
import assert from 'node:assert/strict';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { chromium, type Download, type Locator, type Page } from 'playwright';

type Player = [string, string, ...unknown[]];
const players = JSON.parse(await readFile('tests/animation-acceptance/__snapshot__/players.json', 'utf8')) as Player[];
const fixture = players.find(row => row[0] === 'swimlane-scenario')![1];
for (const asset of ['player.js', 'viewer.js', 'raster-runtime.generated.js', 'player.css', 'viewer.css']) {
  assert.ok(fixture.includes(await readFile(`pkgs/diagrams-animated/assets/${asset}`, 'utf8')), `Regenerate current-commit player snapshots first: ${asset}`);
}
const rootSelector = '[data-diagram-viewer]';
const control = (root: Locator, name: string) => root.locator(`[data-control="${name}"]`);
const browser = await chromium.launch();
const errors: string[] = [], requests: string[] = [];
const directory = resolve('_build/player-export');
await mkdir(directory, { recursive: true });

function documentWithRoots(two = false, blockedStorage = false) {
  const body = fixture.match(/<body>([\s\S]*)<\/body>/)![1];
  const head = fixture.match(/<head>([\s\S]*)<\/head>/)![1];
  const prepare = `<script>${blockedStorage ? `Object.defineProperty(window, 'localStorage', { get() { throw new DOMException('Storage blocked', 'SecurityError'); } });` : ''}Element.prototype.requestFullscreen = async function(){throw new Error('Fullscreen denied')};</script>`;
  const first = body.replace('<main class="diagram-viewer"', '<main id="one" class="diagram-viewer"');
  const adjacent = players.find(row => row[0] === 'prefix-b')![1].match(/<body>([\s\S]*)<\/body>/)![1];
  const second = adjacent.replace('<main class="diagram-viewer"', '<main id="two" class="diagram-viewer"');
  return `<!doctype html><html lang="en"><head>${head}${prepare}</head><body>${first}${two ? second : ''}</body></html>`;
}
async function open(name: string, html: string, width = 1024, preference: 'light' | 'dark' = 'light') {
  const file = resolve(directory, `${name}.html`);
  await writeFile(file, html);
  const context = await browser.newContext({ viewport: { width, height: 1000 }, colorScheme: preference, acceptDownloads: true, offline: true });
  const page = await context.newPage();
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => { if (/^https?:/.test(request.url())) requests.push(request.url()); });
  await page.goto(pathToFileURL(file).href);
  await page.locator(`${rootSelector}[data-motion-ready="true"]`).first().waitFor();
  return page;
}
async function seek(root: Locator, time: number) {
  await control(root, 'seek').evaluate((element, time) => {
    (element as HTMLInputElement).value = String(time); element.dispatchEvent(new Event('input', { bubbles: true }));
  }, time);
}
async function state(root: Locator) {
  return root.evaluate(element => ({
    theme: element.getAttribute('data-viewer-resolved-theme'), playing: element.getAttribute('data-playing'), position: element.getAttribute('data-position'), speed: element.getAttribute('data-speed'),
    route: element.getAttribute('data-route'), active: element.getAttribute('data-active'), connection: element.getAttribute('data-connection'),
    transform: element.querySelector('.diagram-viewer__content')!.getAttribute('style'),
    canonical: JSON.parse(element.querySelector('script[data-motion-data]')!.textContent!).canonical,
  }));
}
async function downloaded(download: Download) {
  assert.equal(await download.failure(), null);
  return readFile((await download.path())!);
}
async function installRecorder(page: Page) {
  await page.evaluate(() => {
    const original = window.DiagramsRaster.export;
    window.__libraryExport = original;
    window.__exportRequests = [];
    window.__exportSettled = 0;
    window.__rendering = 0;
    window.DiagramsRaster.export = request => {
      const { signal, onProgress, ...serializable } = request;
      window.__exportRequests.push(structuredClone(serializable));
      return original({ ...request, onProgress: value => {
        if (typeof value === 'object' && value.phase === 'rendering') window.__rendering++;
        onProgress?.(value);
      } }).finally(() => { window.__exportSettled++; });
    };
  });
}
async function compareWithDirect(page: Page, bytes: Buffer, requestIndex: number, format: string) {
  const direct = await page.evaluate(async requestIndex => {
    const request = window.__exportRequests[requestIndex];
    const data = JSON.parse(document.querySelector('#one script[data-motion-data]')!.textContent!);
    if (request.svg !== data.canonical || JSON.stringify(request.fonts) !== JSON.stringify(JSON.parse(data.raster_fonts))) throw new Error('UI did not submit canonical SVG and its explicit per-artifact font data');
    const result = await window.__libraryExport(request);
    let binary = ''; for (const byte of result.bytes) binary += String.fromCharCode(byte);
    return { bytes: btoa(binary), mediaType: result.mediaType, width: result.width, height: result.height, format: request.format };
  }, requestIndex);
  assert.equal(direct.format, format);
  assert.deepEqual(bytes, Buffer.from(direct.bytes, 'base64'), `UI ${format} download differs from direct compiled-library conversion`);
  assert.equal(direct.mediaType, `image/${format}`);
  if (format === 'gif') {
    const decoded = await page.evaluate(async encoded => {
      if (typeof ImageDecoder !== 'function' || !await ImageDecoder.isTypeSupported('image/gif')) throw new Error('Locked Chromium lacks GIF ImageDecoder');
      const decoder = new ImageDecoder({ data: Uint8Array.from(atob(encoded), character => character.charCodeAt(0)), type: 'image/gif' });
      await decoder.tracks.ready; await decoder.completed;
      const frames = decoder.tracks.selectedTrack!.frameCount, loops = decoder.tracks.selectedTrack!.repetitionCount;
      const stamps: number[] = [], checksums: number[] = [];
      for (let i = 0; i < frames; i++) {
        const { image } = await decoder.decode({ frameIndex: i });
        stamps.push(image.duration!);
        const pixels = new Uint8Array(image.allocationSize({ format: 'RGBA' })); await image.copyTo(pixels, { format: 'RGBA' });
        let checksum = 2166136261; for (const value of pixels) checksum = Math.imul(checksum ^ value, 16777619);
        checksums.push(checksum); image.close();
      }
      decoder.close(); return { frames, loops, stamps, changed: new Set(checksums).size };
    }, bytes.toString('base64'));
    assert.ok(decoded.frames > 1 && decoded.changed > 1, 'GIF must contain decoded moving frames');
    assert.ok(decoded.stamps.every(value => value > 0));
    assert.equal(decoded.loops, 2);
  } else {
    const decoded = await page.evaluate(async ({ encoded, type }) => {
      const image = await createImageBitmap(new Blob([Uint8Array.from(atob(encoded), character => character.charCodeAt(0))], { type }));
      const size = [image.width, image.height]; image.close(); return size;
    }, { encoded: bytes.toString('base64'), type: direct.mediaType });
    assert.deepEqual(decoded, [direct.width, direct.height]);
  }
}
async function exportImage(page: Page, root: Locator, format: 'png' | 'jpeg' | 'gif', afterSubmit?: () => Promise<void>) {
  await control(root, 'raster-format').selectOption(format);
  const index = await page.evaluate(() => window.__exportRequests.length);
  const result = page.waitForEvent('download');
  await control(root, 'raster-export').click();
  if (afterSubmit) await afterSubmit();
  const download = await result;
  assert.ok(download.suggestedFilename().endsWith(format === 'jpeg' ? '.jpg' : `.${format}`));
  const bytes = await downloaded(download);
  await page.waitForFunction(() => !document.querySelector('#one [data-control="raster-form"]')!.hasAttribute('aria-busy'));
  await compareWithDirect(page, bytes, index, format);
  return index;
}
try {

  const page = await open('offline-exports', documentWithRoots());
  const root = page.locator('#one');
  let downloads = 0; page.on('download', () => downloads++);
  await installRecorder(page);
  await control(root, 'raster-width').fill('120');
  await control(root, 'raster-background').fill('#f8f0e8');
  await control(root, 'raster-format').selectOption('jpeg');
  await control(root, 'raster-quality').fill('80');
  await control(root, 'raster-format').selectOption('gif');
  await control(root, 'gif-rate').fill('4');
  await control(root, 'gif-loop').selectOption('repeat');
  await control(root, 'gif-repeats').fill('2');
  await root.locator('[aria-label="Zoom in"]').click();
  await root.locator('.diagram-viewer__viewport').focus(); await page.keyboard.press('ArrowLeft');
  await control(root, 'speed').selectOption('1.5'); await seek(root, 350);
  const paused = await state(root);
  for (const format of ['png', 'jpeg', 'gif'] as const) {
    const theme = format === 'png' ? 'dark' : 'light';
    await root.evaluate((root, theme) => root.setAttribute('data-viewer-theme', theme), theme);
    await page.waitForFunction(theme => document.querySelector('#one')!.getAttribute('data-viewer-resolved-theme') === theme, theme);
    await control(root, 'raster-format').selectOption(format);
    const before = await state(root);
    const index = await exportImage(page, root, format);
    assert.deepEqual(await state(root), before, `${format} export changed paused playback or viewport`);
    if (format === 'gif') {
      const steps = await page.evaluate(index => window.__exportRequests[index].plan.steps, index);
      assert.equal(steps[0].key, steps[1].key); assert.equal(steps[0].start_ms, steps[1].start_ms);
      assert.equal(steps[1].reversed, true); assert.ok(steps[0].groups.length);
    }
  }
  await control(root, 'from').selectOption('A'); await control(root, 'to').selectOption('C'); await control(root, 'route').click();
  await seek(root, 400);
  const routed = await state(root);
  const routeIndex = await exportImage(page, root, 'gif');
  const selected = await page.evaluate(index => window.__exportRequests[index].plan, routeIndex);
  assert.equal(selected.mode, 'finite'); assert.equal(selected.duration_ms, '2000');
  assert.deepEqual(selected.steps.map(step => step.key), JSON.parse(routed.route!));
  assert.equal(selected.steps.length, 2); assert.deepEqual(await state(root), routed);

  // Capture submitted format even while the editable UI changes during export.
  await control(root, 'speed').selectOption('0.25'); await control(root, 'play').click();
  await page.waitForFunction(() => Number(document.querySelector('#one')!.getAttribute('data-position')) > 420);
  const playing = await state(root);
  await control(root, 'raster-width').fill('512');
  await exportImage(page, root, 'png', async () => {
    await root.evaluate(root => {
      if (!root.querySelector('[data-control="raster-form"]')!.hasAttribute('aria-busy')) throw new Error('Format race must occur while conversion is pending');
      const format = root.querySelector<HTMLSelectElement>('[data-control="raster-format"]')!; format.value = 'jpeg'; format.dispatchEvent(new Event('change', { bubbles: true }));
    });
  });
  const continued = await state(root);
  assert.equal(continued.playing, 'true'); assert.ok(Number(continued.position) >= Number(playing.position));
  assert.equal(continued.speed, playing.speed); assert.equal(continued.route, playing.route); assert.equal(continued.transform, playing.transform); assert.equal(continued.canonical, playing.canonical);
  await control(root, 'play').click();

  // Cancel a running compiled GIF worker; it must never offer a partial file.
  await control(root, 'raster-format').selectOption('gif'); await control(root, 'raster-width').fill('320'); await control(root, 'gif-rate').fill('100');
  const cancelledState = await state(root);
  const beforeCancel = downloads;
  const rendering = await page.evaluate(() => window.__rendering);
  await control(root, 'raster-export').click();
  await page.waitForFunction(rendering => window.__rendering > rendering, rendering);
  await control(root, 'raster-cancel').click();
  await page.waitForFunction(() => document.querySelector('#one [data-control="raster-status"]')!.textContent === 'Export cancelled.');
  assert.equal(downloads, beforeCancel);
  assert.deepEqual(await state(root), cancelledState);
  assert.equal(await control(root, 'raster-export').isEnabled(), true);

  // Native form validation, a library budget failure, SVG availability, recovery.
  await control(root, 'raster-format').selectOption('png'); await control(root, 'raster-width').fill('0');
  const calls = await page.evaluate(() => window.__exportRequests.length);
  await control(root, 'raster-export').click();
  assert.equal(await page.evaluate(() => window.__exportRequests.length), calls); assert.equal(downloads, beforeCancel);
  await control(root, 'raster-width').fill('16384'); await control(root, 'raster-export').click();
  await page.waitForFunction(() => document.querySelector('#one [data-control="raster-status"]')!.textContent!.startsWith('Export failed:'));
  assert.equal(downloads, beforeCancel);
  const svgDownload = page.waitForEvent('download'); await control(root, 'download').click();
  assert.equal((await downloaded(await svgDownload)).toString(), paused.canonical);
  await control(root, 'raster-width').fill('120'); await exportImage(page, root, 'png');
  assert.match((await control(root, 'raster-status').textContent())!, /^Downloaded PNG, 120 × [1-9]\d* pixels\.$/);
  assert.equal(downloads, 7);
  console.log('Actual player exports: six PNG/JPEG/GIF downloads match the original compiled-library worker; SVG remains exact, decoded GIFs move, and playback/route/viewport, pending format race, cancellation and recovery pass on offline file://.');
  await page.context().close();
  // Style only documented root variables/parts. Generic pointer, focus and native
  // fullscreen mechanics are covered in viewer-test.ts rather than duplicated.
  for (const width of [360, 768, 1440]) {
    const page = await open(`layout-${width}`, documentWithRoots(true, true), width, 'dark');
    const one = page.locator('#one'), two = page.locator('#two');
    assert.equal(await one.getAttribute('data-viewer-resolved-theme'), 'dark');
    await one.evaluate(root => { root.setAttribute('data-viewer-theme', 'light'); root.setAttribute('style', '--diagram-viewer-bg:#f0e2e8;--diagram-viewer-surface:#e0c0d0;--diagram-viewer-accent:#b01070;--diagram-viewer-ink:#302030;--diagram-viewer-control-radius:13px;--diagram-viewer-font:serif;--diagram-viewer-space:1rem'); });
    await page.waitForFunction(() => document.querySelector('#one')!.getAttribute('data-viewer-resolved-theme') === 'light');
    assert.equal(await two.getAttribute('data-viewer-resolved-theme'), 'dark');
    assert.equal(await one.evaluate(root => getComputedStyle(root).backgroundColor), 'rgb(240, 226, 232)');
    assert.equal(await control(one, 'play').evaluate(element => getComputedStyle(element).backgroundColor), 'rgb(176, 16, 112)');
    assert.equal(await control(one, 'play').evaluate(element => getComputedStyle(element).borderRadius), '13px');
    assert.equal(await one.evaluate(root => getComputedStyle(root).fontFamily), 'serif');
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, `${width}px player overflow`);
    const smallTargets = await one.locator('button, select, input').evaluateAll(elements => elements.flatMap(element => {
      if (!(element as HTMLElement).getClientRects().length) return [];
      const target = (element as HTMLInputElement).type === 'checkbox' ? element.closest('label')! : element;
      const box = target.getBoundingClientRect(); return box.width < 44 || box.height < 44 ? [`${element.getAttribute('data-control') || element.getAttribute('aria-label')}: ${box.width}x${box.height}`] : [];
    }));
    assert.deepEqual(smallTargets, [], `${width}px touch targets`);
    for (const part of ['header', 'viewport', 'content', 'toolbar', 'playback', 'timeline', 'status', 'exploration', 'export']) assert.ok(await one.locator(`.diagram-viewer__${part}`).count(), `Missing public ${part} hook`);
    await one.locator('[aria-label="Fullscreen"]').click(); await page.getByRole('dialog').waitFor();
    assert.equal(await two.evaluate(root => (root as HTMLElement).inert), true);
    assert.equal(await one.locator('.diagram-viewer__viewport').evaluate(element => getComputedStyle(element).backgroundColor), 'rgb(224, 192, 208)');
    await page.keyboard.press('Escape'); assert.equal(await two.evaluate(root => (root as HTMLElement).inert), false);
    await one.evaluate(root => root.setAttribute('data-viewer-theme', 'dark'));
    await page.waitForFunction(() => document.querySelector('#one')!.getAttribute('data-viewer-resolved-theme') === 'dark');
    await one.evaluate(root => root.setAttribute('data-viewer-theme', 'system'));
    await page.emulateMedia({ colorScheme: 'light' });
    await page.waitForFunction(() => document.querySelector('#one')!.getAttribute('data-viewer-resolved-theme') === 'light');
    await page.context().close();
  }

  assert.deepEqual(errors, []); assert.deepEqual(requests, []);
  console.log('Shared player: real offline/file PNG/JPEG/GIF downloads equal direct compiled library bytes; decoded moving GIFs, selected/repeated/concurrent schedules, paused/playing state, submitted-format race, cancellation, failure/SVG/recovery, public skins, instance isolation, responsive targets and theme/storage policies passed.');
} finally { await browser.close(); }
