import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, rm, stat, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { chromium, type Page, type Locator } from 'playwright';

const viewportOnly = process.argv.includes('--viewports-only');
const digest = (value: string | Buffer) => createHash('sha256').update(value).digest('hex');
const expected = new Map<string,string>();
const sourceDigests = new Map<string,string>();
for (const path of [
  'tests/plantuml-acceptance/__snapshot__/plantuml-gallery.json',
  'tests/zenuml-integration/__snapshot__/new-gallery.json',
  'tests/flowchart-gallery-acceptance/__snapshot__/flowchart-gallery.json',
  'tests/state-gallery-acceptance/__snapshot__/state-gallery.json',
  'tests/gallery-expansion-acceptance/__snapshot__/expanded-gallery.json',
]) for (const [name, media, content] of JSON.parse(await readFile(path, 'utf8')) as [string,string,string][]) {
  if (media !== 'text/html') expected.set(name, content);
}
for (const [name, , svg] of JSON.parse(await readFile('tests/animation-acceptance/__snapshot__/players.json', 'utf8')) as [string,string,string][]) if (name.startsWith('swimlane-')) expected.set(name + '.svg', svg);
for (const [name, theme, svg] of JSON.parse(await readFile('tests/bpmn-acceptance/__snapshot__/scenes.json', 'utf8')) as [string,string,string][]) expected.set('bpmn-' + name.replace('.bpmn/', '-') + '-' + theme + '.svg', svg);
expected.set('sequence-basic.mmd', await readFile('tests/corpus/mermaid-12.2.0/examples/01.mmd', 'utf8'));
for (const name of ['process-di', 'collaboration-di']) expected.set(name + '.bpmn', await readFile('tests/corpus/bpmn-render/' + name + '.bpmn', 'utf8'));
for (const name of ['activities','events','collaboration','di-views','choreography-conversation']) expected.set('document-' + name + '.bpmn', await readFile('tests/corpus/bpmn-model/' + name + '.bpmn', 'utf8'));
expected.set('swimlane-review.mmd', await readFile('tests/corpus/mermaid-swimlanes/cases/review.mmd', 'utf8'));
expected.set('icon-contact-sheet.svg', await readFile('tests/zenuml-integration/__snapshot__/icon-contact-sheet.svg', 'utf8'));

async function waitFor(check: () => Promise<boolean>, description: string) {
  for (let attempt = 0; attempt < 100; attempt++) { if (await check()) return; await new Promise(resolve => setTimeout(resolve, 20)); }
  assert.fail(description);
}
async function scale(view: Locator) { return Number(await view.getAttribute('data-viewer-scale')); }
function button(root: Locator, name: string) { return root.getByRole('button', {name, exact: true}); }
async function checkViewport(page: Page) {
  const roots = page.locator('[data-diagram-viewer]');
  const first = roots.first(), second = roots.nth(1);
  const viewport = first.locator('.diagram-viewer__viewport');
  const content = first.locator('.diagram-viewer__content');
  for (const width of [360, 768, 1440]) {
    await page.setViewportSize({width, height: 900});
    await button(first, 'Fit diagram').click();
    assert.equal(await scale(viewport), 1);
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `Gallery fits ${width}px`);
    for (const name of ['Fullscreen','Zoom in','Zoom out','Fit diagram']) {
      const bounds = await button(first, name).boundingBox();
      assert.ok(bounds && bounds.width >= 44 && bounds.height >= 44, `${name}: 44px target`);
    }
    if (width === 360) {
      await first.scrollIntoViewIfNeeded();
      const theme = await page.evaluate(() => matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      await page.screenshot({path: `_build/local-gallery-${theme}-360.png`});
    }
  }
  await button(first, 'Zoom in').click();
  assert.equal(await scale(viewport), 1.25);
  assert.equal(await scale(second.locator('.diagram-viewer__viewport')), 1);
  await viewport.focus();
  const before = await content.getAttribute('style');
  await viewport.press('ArrowLeft');
  assert.notEqual(await content.getAttribute('style'), before);
  const box = await viewport.boundingBox(); assert.ok(box);
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down(); await page.mouse.move(box.x + box.width / 2 + 35, box.y + box.height / 2 + 25, {steps: 4}); await page.mouse.up();
  assert.equal(page.url(), root);
  await button(first, 'Fullscreen').click();
  await waitFor(() => viewport.evaluate(node => document.fullscreenElement === node), 'Native fullscreen enters');
  await button(first, 'Exit fullscreen').click();
  await waitFor(() => button(first, 'Fullscreen').evaluate(node => node === document.activeElement), 'Native fullscreen restores focus');
  assert.equal(await scale(viewport), 1.25);
  await button(first, 'Fit diagram').click();
  const plus = await button(first, 'Zoom in');
  for (let i = 0; i < 20 && await plus.isEnabled(); i++) await plus.click();
  assert.equal(await scale(viewport), 8); assert.ok(await plus.isDisabled());
  const minus = await button(first, 'Zoom out');
  for (let i = 0; i < 30 && await minus.isEnabled(); i++) await minus.click();
  assert.equal(await scale(viewport), .25); assert.ok(await minus.isDisabled());
  await button(first, 'Fit diagram').click();
  await page.emulateMedia({media: 'print'});
  assert.equal(await content.evaluate(node => getComputedStyle(node).transform), 'none');
  assert.ok(!(await first.locator('.diagram-viewer__toolbar').isVisible()));
  await page.emulateMedia({media: 'screen'});
}


type ExportOptions = { theme: string; background: string | null; quality: number; width?: number };
type ExportResult = { bytes: number[] | Uint8Array; mediaType: string; width: number; height: number };
type RasterAPI = { export(input: { svg: string; format: string; options: ExportOptions; signal: AbortSignal; onProgress(value: number): void }): Promise<ExportResult> };

async function checkExports(page: Page) {
  const apiAvailable = await page.evaluate(() => typeof (window as Window & {DiagramsRaster?: RasterAPI}).DiagramsRaster?.export === 'function');
  if (viewportOnly && !apiAvailable) {
    assert.equal(await page.locator('[data-raster-unavailable]').count(), 1, 'Missing adapter is explicit in viewport-only output');
    return;
  }
  assert.ok(apiAvailable, 'Normal gallery qualification requires the supported raster library adapter');
  const roots = page.locator('[data-diagram-viewer]');
  assert.equal(await page.locator('.diagram-viewer__export').count(), await roots.count(), 'Every image offers PNG/JPEG options');
  if (viewportOnly) return;
  const first = roots.first(), viewport = first.locator('.diagram-viewer__viewport');
  await button(first, 'Zoom in').click();
  await viewport.focus(); await viewport.press('ArrowRight');
  const before = await first.locator('.diagram-viewer__content').getAttribute('style');
  const svg = await first.locator('.diagram-viewer__canonical').evaluate(node => (node as HTMLTemplateElement).content.textContent!);
  const theme = (await first.getAttribute('data-raster-theme'))!;
  await first.getByText('Export image', {exact: true}).click();
  await first.getByLabel('Width in pixels, blank for source size', {exact: true}).fill('96');
  let downloads = 0;
  page.on('download', () => downloads++);
  const sourceFetches: string[] = [];
  page.on('request', request => { if (request.resourceType() === 'fetch' && request.url().endsWith('.svg')) sourceFetches.push(request.url()); });
  await page.context().setOffline(true);
  for (const format of ['png','jpeg']) {
    await first.getByLabel('Format', {exact: true}).selectOption(format);
    if (format === 'jpeg') {
      await first.getByLabel('JPEG quality', {exact: true}).fill('78');
      await first.getByLabel('Background', {exact: true}).fill('#f8f0e8');
    }
    const options: ExportOptions = {theme, width: 96, quality: format === 'jpeg' ? 78 : 90, background: format === 'jpeg' ? '#f8f0e8' : null};
    const direct = await page.evaluate(async input => {
      const result = await (window as Window & {DiagramsRaster: RasterAPI}).DiagramsRaster.export({...input, signal: new AbortController().signal, onProgress() {}});
      return {...result, bytes: Array.from(result.bytes)};
    }, {svg, format, options});
    const download = page.waitForEvent('download');
    await button(first, 'Download ' + format.toUpperCase()).click();
    const file = await download;
    const path = await file.path(); assert.ok(path);
    const bytes = await readFile(path);
    assert.deepEqual(bytes, Buffer.from(direct.bytes), format + ': download equals direct supported-library result');
    const decoded = await page.evaluate(async data => {
      const image = await createImageBitmap(new Blob([new Uint8Array(data)]));
      return {width: image.width, height: image.height};
    }, [...bytes]);
    assert.deepEqual(decoded, {width: direct.width, height: direct.height});
    assert.equal(direct.width, 96);
    assert.equal(direct.mediaType, format === 'png' ? 'image/png' : 'image/jpeg');
    assert.ok((await first.locator('.diagram-viewer__status').textContent())!.startsWith('Downloaded'));
    assert.equal(await first.locator('.diagram-viewer__content').getAttribute('style'), before, 'Export retains zoom/pan');
  }
  assert.deepEqual(sourceFetches, [], 'Canonical SVG requires no fetch, including file use');
  await page.evaluate(() => {
    const host = window as Window & {DiagramsRaster: RasterAPI; originalGalleryExporter?: RasterAPI['export']};
    host.originalGalleryExporter = host.DiagramsRaster.export;
    host.DiagramsRaster.export = async () => { throw new Error('Gallery qualification failure'); };
  });
  await button(first, 'Download JPEG').click();
  await waitFor(async () => (await first.locator('.diagram-viewer__status').textContent())!.includes('Gallery qualification failure'), 'Export failure is accessible');
  assert.ok(await button(first, 'Download JPEG').isEnabled());
  await page.evaluate(() => {
    (window as Window & {DiagramsRaster: RasterAPI}).DiagramsRaster.export = ({signal}) => new Promise((_resolve, reject) => {
      signal.addEventListener('abort', () => reject(new DOMException('Cancelled', 'AbortError')), {once: true});
    });
  });
  await button(first, 'Download JPEG').click();
  assert.ok(await button(first, 'Download JPEG').isDisabled());
  await button(first, 'Cancel export').click();
  await waitFor(async () => (await first.locator('.diagram-viewer__status').textContent()) === 'Export cancelled.', 'Cancellation restores controls');
  assert.ok(await button(first, 'Download JPEG').isEnabled());
  assert.equal(downloads, 2, 'Failure/cancellation offers no partial download');
  await first.getByLabel('Format', {exact: true}).selectOption('png');
  await page.evaluate(() => {
    const host = window as Window & {DiagramsRaster: RasterAPI; originalGalleryExporter: RasterAPI['export']; releaseGalleryExport?: () => void; gallerySubmittedOptions?: {format: string; options: ExportOptions}};
    host.DiagramsRaster.export = input => {
      host.gallerySubmittedOptions = {format: input.format, options: {...input.options}};
      return new Promise<ExportResult>((resolve, reject) => {
        host.releaseGalleryExport = () => host.originalGalleryExporter(input).then(resolve, reject);
      });
    };
  });
  const raceDownload = page.waitForEvent('download');
  await button(first, 'Download PNG').click();
  await first.getByLabel('Format', {exact: true}).selectOption('jpeg');
  await first.getByLabel('Width in pixels, blank for source size', {exact: true}).fill('48');
  await first.getByLabel('Background', {exact: true}).fill('#334455');
  await first.getByLabel('JPEG quality', {exact: true}).fill('62');
  const submitted = await page.evaluate(() => {
    const host = window as Window & {releaseGalleryExport: () => void; gallerySubmittedOptions: {format: string; options: ExportOptions}};
    host.releaseGalleryExport();
    return host.gallerySubmittedOptions;
  });
  assert.equal(submitted.format, 'png');
  assert.equal(submitted.options.width, 96);
  assert.equal(submitted.options.background, null);
  const raceFile = await raceDownload;
  assert.ok(raceFile.suggestedFilename().endsWith('.png'), 'Changing options during export retains submitted format');
  await waitFor(async () => (await first.locator('.diagram-viewer__status').textContent())!.startsWith('Downloaded PNG, 96 ×'), 'Completion describes the submitted image');
  assert.equal(await first.locator('.diagram-viewer__content').getAttribute('style'), before);
  const src = await first.locator('img').getAttribute('src');
  assert.ok(await page.locator(`a[href="${src}"]`).first().isVisible(), 'Original SVG action remains usable');
  await page.evaluate(() => {
    const host = window as Window & {DiagramsRaster: RasterAPI; originalGalleryExporter?: RasterAPI['export']};
    host.DiagramsRaster.export = host.originalGalleryExporter!;
    delete host.originalGalleryExporter;
  });
  await page.context().setOffline(false);
}

async function qualifyEveryPreview(page: Page, panels: {file: string; svg: string | null; theme: string | null}[]) {
  const failures: string[] = [];
  for (const panel of panels) {
    try {
      const result = await page.evaluate(async input => {
        const image = await (window as Window & {DiagramsRaster: RasterAPI}).DiagramsRaster.export({svg: input.svg!, format: 'png', options: {theme: input.theme!, width: 16, quality: 90, background: null}, signal: new AbortController().signal, onProgress() {}});
        const bitmap = await createImageBitmap(new Blob([new Uint8Array(image.bytes)]));
        const size = {width: bitmap.width, height: bitmap.height}; bitmap.close();
        return {mediaType: image.mediaType, width: image.width, height: image.height, decoded: size};
      }, panel);
      assert.equal(result.mediaType, 'image/png');
      assert.deepEqual(result.decoded, {width: result.width, height: result.height});
    } catch (error) { failures.push(panel.file + ': ' + String(error)); }
  }
  assert.deepEqual(failures, [], 'Every local preview converts with its supplied offline font profile');
  return panels.length;
}

async function checkExpandedFallback(page: Page) {
  await page.addInitScript(() => { Element.prototype.requestFullscreen = () => Promise.reject(new DOMException('Denied', 'NotAllowedError')); });
  await page.goto(root);
  const first = page.locator('[data-diagram-viewer]').last();
  await first.evaluate(node => {
    (node as HTMLElement).style.setProperty('--diagram-viewer-accent', '#b4235a');
    (node as HTMLElement).style.setProperty('--diagram-viewer-toolbar-bg', '#fbe9f0');
  });
  await first.scrollIntoViewIfNeeded();
  const viewport = first.locator('.diagram-viewer__viewport');
  const priorScroll = await page.evaluate(() => scrollY);
  await button(first, 'Fullscreen').click();
  await waitFor(async () => await viewport.getAttribute('aria-modal') === 'true', 'Denied fullscreen opens modal');
  assert.equal(await viewport.getAttribute('role'), 'dialog');
  assert.equal(await page.evaluate(() => document.body.style.overflow), 'hidden');
  assert.equal(await first.locator('.diagram-viewer__toolbar').evaluate(node => getComputedStyle(node).backgroundColor), 'rgb(251, 233, 240)');
  await button(first, 'Exit fullscreen').press('Tab');
  assert.ok(await button(first, 'Zoom out').evaluate(node => node === document.activeElement));
  await button(first, 'Zoom out').press('Shift+Tab');
  assert.ok(await button(first, 'Exit fullscreen').evaluate(node => node === document.activeElement));
  await button(first, 'Exit fullscreen').press('Escape');
  assert.ok(await button(first, 'Fullscreen').evaluate(node => node === document.activeElement));
  assert.equal(await page.evaluate(() => document.body.style.overflow), '');
  const restoredScroll = await page.evaluate(() => scrollY);
  assert.ok(Math.abs(restoredScroll - priorScroll) <= 2, `Modal restores page scroll: expected ${priorScroll}, received ${restoredScroll}`);
}


const flowcharts = JSON.parse(await readFile('tests/flowchart-gallery-acceptance/__snapshot__/flowchart-gallery.json','utf8')) as [string,string,string][];
const states = JSON.parse(await readFile('tests/state-gallery-acceptance/__snapshot__/state-gallery.json','utf8')) as [string,string,string][];
const expanded = JSON.parse(await readFile('tests/gallery-expansion-acceptance/__snapshot__/expanded-gallery.json', 'utf8')) as [string,string,string][];
type GalleryEntry = { id: string; family: string; sources: { path: string }[] };
const manifest = JSON.parse(await readFile('site/gallery.json', 'utf8')) as { root: string; entries: GalleryEntry[] };
const baselineIDs = new Set(['sequence-basic','zenuml-symbols','architecture-cloud','bpmn-process','bpmn-collaboration','swimlane-review','flowchart-mermaid-review','flowchart-plantuml-modern','flowchart-plantuml-legacy','regex-date','regex-evidence','ebnf-arithmetic','ebnf-evidence','json-order','yaml-service']);
assert.ok(manifest.entries.length >= 45);
assert.equal(manifest.entries.filter(entry => baselineIDs.has(entry.id)).length, 15);
for (const family of ['sequence','ZenUML','architecture','BPMN','swimlane','flowchart','regex','EBNF','JSON','YAML']) {
  const familyEntries = manifest.entries.filter(entry => entry.family === family);
  const baselineSources = new Set(await Promise.all(familyEntries.filter(entry => baselineIDs.has(entry.id)).map(entry => readFile(resolve(manifest.root, entry.sources[0].path), 'utf8'))));
  const additionalSources = new Set(await Promise.all(familyEntries.filter(entry => !baselineIDs.has(entry.id)).map(entry => readFile(resolve(manifest.root, entry.sources[0].path), 'utf8'))));
  for (const source of baselineSources) additionalSources.delete(source);
  assert.ok(additionalSources.size >= 3, `${family}: at least three genuinely additional sources`);
}
const stateEntries = manifest.entries.filter(entry => entry.family === 'state');
assert.equal(stateEntries.length,6);
assert.equal(new Set(await Promise.all(stateEntries.map(entry => readFile(resolve(manifest.root,entry.sources[0].path),'utf8')))).size,6);
const root = pathToFileURL(resolve('_gallery/index.html')).href;
await rm('_build/local-gallery-qualification.json', {force: true});
const browser = await chromium.launch({ headless: true });
const errors: string[] = [], external: string[] = [];
let previewCount = 0, convertedPreviews = 0;
try {
  for (const preference of ['light', 'dark'] as const) {
    const page = await browser.newPage({ colorScheme: preference });
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    await page.route(/^https?:/, route => { external.push(route.request().url()); return route.abort(); });
    await page.goto(root);
    const references = await page.locator('a[href], img[src]').evaluateAll(nodes => nodes.map(node => node.getAttribute(node.tagName === 'IMG' ? 'src' : 'href')!));
    assert.ok(references.length >= 110);
    for (const reference of references) {
      const url = new URL(reference, root);
      assert.equal(url.protocol, 'file:');
      if (url.hash) assert.equal(await page.locator(`[id="${url.hash.slice(1)}"]`).count(), 1);
      else {
        const path = fileURLToPath(url);
        assert.ok((await stat(path)).isFile());
        if (/\.(svg|mmd|puml|bpmn)$/.test(reference)) {
          const bytes = await readFile(path);
          const baseline = expected.get(reference) ?? await readFile('tests/acceptance/__snapshot__/svg/' + reference, 'utf8');
          assert.equal(digest(bytes), digest(baseline), reference + ': checked source/static artifact digest');
          sourceDigests.set(reference, digest(bytes));
        }
      }
    }
    const images = await page.locator('img').evaluateAll(async nodes => {
      for (const node of nodes) { node.loading = 'eager'; await node.decode(); if (!node.naturalWidth || !node.naturalHeight) throw new Error('Empty gallery image'); }
      return nodes.map(node => node.getAttribute('src')!);
    });
    if (previewCount) assert.equal(images.length, previewCount); else previewCount = images.length;
    assert.equal(images.length, 120 + expanded.filter(([name,mime]) => mime === 'image/svg+xml' && /-(light|dark)\.svg$/.test(name)).length + flowcharts.filter(([name,mime]) => mime === 'image/svg+xml' && /-(light|dark)\.svg$/.test(name)).length + states.filter(([name,mime]) => mime === 'image/svg+xml' && /-(light|dark)\.svg$/.test(name)).length);
    for (const [name,mime] of [...flowcharts, ...expanded, ...states]) if (mime === 'image/svg+xml' && /-(light|dark)\.svg$/.test(name)) assert.ok(images.includes(name));
    assert.equal(await page.locator('[data-diagram-viewer][data-viewer-ready="true"]').count(), images.length, 'Every preview has an enhanced viewer');
    const canonicals = await page.locator('[data-diagram-viewer]').evaluateAll(nodes => nodes.map(node => ({file: node.querySelector('img')!.getAttribute('src')!, theme: node.getAttribute('data-raster-theme'), svg: (node.querySelector('.diagram-viewer__canonical') as HTMLTemplateElement).content.textContent, controls: [...node.querySelectorAll('.diagram-viewer__toolbar button')].map(button => button.getAttribute('aria-label'))})));
    for (const panel of canonicals) {
      assert.deepEqual(panel.controls, ['Zoom out','Zoom in','Fit diagram','Fullscreen']);
      assert.equal(panel.svg, await readFile(fileURLToPath(new URL(panel.file, root)), 'utf8'), panel.file + ': exact inert canonical SVG');
    }
    for (const file of images) {
      const svg = await readFile(fileURLToPath(new URL(file, root)), 'utf8');
      const expectedSVG = expected.get(file) ?? await readFile('tests/acceptance/__snapshot__/svg/' + file, 'utf8');
      assert.equal(digest(svg), digest(expectedSVG), file + ': checked SVG digest');
      sourceDigests.set(file, digest(svg));
      await page.evaluate(svg => {
        const doc = new DOMParser().parseFromString(svg, 'image/svg+xml');
        if (doc.querySelector('parsererror, script, foreignObject')) throw new Error('Invalid or active static SVG');
      }, svg);
    }
    assert.equal(new Set(references.filter(reference => reference.endsWith(".bpmn"))).size, 7 + expanded.filter(([name]) => name.endsWith('.bpmn')).length);
    const players = references.filter(reference => reference.endsWith('.html'));
    assert.equal(players.length, 46 + expanded.filter(([,mime]) => mime === 'text/html').length + flowcharts.filter(([,mime]) => mime === 'text/html').length + states.filter(([,mime]) => mime === 'text/html').length);
    assert.equal(new Set(references.filter(reference => reference.endsWith('.puml'))).size, 7 + expanded.filter(([name]) => name.endsWith('.puml')).length + flowcharts.filter(([name]) => name.endsWith('.puml')).length + states.filter(([name]) => name.endsWith('.puml')).length);
    assert.equal(new Set(references.filter(reference => reference.endsWith('.mmd'))).size, 6 + expanded.filter(([name]) => name.endsWith('.mmd')).length + flowcharts.filter(([name]) => name.endsWith('.mmd')).length + states.filter(([name]) => name.endsWith('.mmd')).length);
    if (!viewportOnly && preference === 'light') convertedPreviews = await qualifyEveryPreview(page, canonicals);
    await checkViewport(page);
    await checkExports(page);
    if (!viewportOnly) for (const file of players) {
      await page.goto(new URL(file, root).href);
      await page.locator('[data-motion-ready="true"]').waitFor();
      assert.equal(await page.locator('.motion-overlay').count(), 0);
      await page.getByRole('button', { name: 'Step', exact: true }).click();
      assert.equal(await page.locator('[data-diagram-viewer]').getAttribute('data-playing'), 'false');
    }
    await page.close();
  }
  const fallback = await browser.newPage({viewport: {width: 360, height: 900}});
  fallback.on('pageerror', error => errors.push(error.message));
  await fallback.route(/^https?:/, route => { external.push(route.request().url()); return route.abort(); });

  const touch = await browser.newPage({viewport: {width: 360, height: 900}, isMobile: true, hasTouch: true});
  touch.on('pageerror', error => errors.push(error.message));
  await touch.route(/^https?:/, route => { external.push(route.request().url()); return route.abort(); });
  await touch.goto(root);
  const first = touch.locator('[data-diagram-viewer]').first();
  await button(first, 'Zoom in').tap();
  const viewport = first.locator('.diagram-viewer__viewport');
  const content = first.locator('.diagram-viewer__content');
  await viewport.scrollIntoViewIfNeeded();
  const box = await viewport.boundingBox(); assert.ok(box);
  const beforeTouch = await content.getAttribute('style');
  await viewport.evaluate(node => node.addEventListener('pointercancel', () => node.setAttribute('data-qualification-cancelled', 'true'), {once: true}));
  const session = await touch.context().newCDPSession(touch);
  const point = {x: box.x + box.width / 2, y: box.y + box.height / 2};
  await session.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [point]});
  await session.send('Input.dispatchTouchEvent', {type: 'touchMove', touchPoints: [{x: point.x + 40, y: point.y + 20}]});
  await waitFor(async () => await content.getAttribute('style') !== beforeTouch, 'Touch move is rendered');
  await session.send('Input.dispatchTouchEvent', {type: 'touchCancel', touchPoints: []});
  assert.notEqual(await content.getAttribute('style'), beforeTouch, 'Touch pans enlarged images');
  assert.equal(await viewport.getAttribute('data-qualification-cancelled'), 'true');
  const afterCancel = await content.getAttribute('style');
  await touch.mouse.move(point.x + 65, point.y + 30);
  assert.equal(await content.getAttribute('style'), afterCancel, 'Pointer cancellation ends the drag');
  await button(first, 'Fit diagram').tap(); assert.equal(await scale(viewport), 1);
  await touch.close();
  const staticPage = await browser.newPage({javaScriptEnabled: false, viewport: {width: 360, height: 900}});
  await staticPage.goto(root);
  assert.ok(await staticPage.locator('img').count() > 100);
  assert.equal(await staticPage.locator('.diagram-viewer__toolbar, .diagram-viewer__export, button').count(), 0, 'No inactive controls without JavaScript');
  assert.ok(await staticPage.locator('a[href="01-dark.svg"]').isVisible());
  assert.ok(await staticPage.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await staticPage.close();
  await checkExpandedFallback(fallback);
  await fallback.close();
  for (const [file, hash] of sourceDigests) assert.equal(digest(await readFile(fileURLToPath(new URL(file, root)))), hash, file + ': source/static bytes retained after interaction');
  assert.deepEqual(external, []); assert.deepEqual(errors, []);
  await writeFile('_build/local-gallery-qualification.json', JSON.stringify({mode: viewportOnly ? 'viewport-only' : 'complete', previewCount, convertedPreviews, staticArtifactCount: sourceDigests.size, staticDigests: Object.fromEntries(sourceDigests), externalRequests: external, errors, viewport: true, fullscreen: ['native','modal'], pointer: ['mouse','touch','cancel'], keyboard: true, print: true, noScript: true, raster: !viewportOnly}, null, 2) + '\n');
  console.log(`Gallery: source/static digests, all preview viewports, offline file use, native/modal fullscreen, mouse/touch/keyboard, themes, print and no-script verified (${viewportOnly ? 'viewport-only review; raster qualification pending' : 'real PNG/JPEG downloads and offline players qualified'}).`);
} finally { await browser.close(); }
