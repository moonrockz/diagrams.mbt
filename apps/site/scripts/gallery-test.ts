import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const flowcharts = JSON.parse(await readFile('tests/flowchart-gallery-acceptance/__snapshot__/flowchart-gallery.json','utf8')) as [string,string,string][];
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
const root = pathToFileURL(resolve('_gallery/index.html')).href;
const browser = await chromium.launch({ headless: true });
const errors: string[] = [], external: string[] = [];
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
      else assert.ok((await stat(fileURLToPath(url))).isFile());
    }
    const images = await page.locator('img').evaluateAll(async nodes => {
      for (const node of nodes) { node.loading = 'eager'; await node.decode(); if (!node.naturalWidth || !node.naturalHeight) throw new Error('Empty gallery image'); }
      return nodes.map(node => node.getAttribute('src')!);
    });
    assert.equal(images.length, 120 + expanded.filter(([name,mime]) => mime === 'image/svg+xml' && /-(light|dark)\.svg$/.test(name)).length + flowcharts.filter(([name,mime]) => mime === 'image/svg+xml' && /-(light|dark)\.svg$/.test(name)).length);
    for (const [name,mime] of [...flowcharts, ...expanded]) if (mime === 'image/svg+xml' && /-(light|dark)\.svg$/.test(name)) assert.ok(images.includes(name));
    for (const file of images) {
      const svg = await readFile(fileURLToPath(new URL(file, root)), 'utf8');
      await page.evaluate(svg => {
        const doc = new DOMParser().parseFromString(svg, 'image/svg+xml');
        if (doc.querySelector('parsererror, script, foreignObject')) throw new Error('Invalid or active static SVG');
      }, svg);
    }
    assert.equal(new Set(references.filter(reference => reference.endsWith(".bpmn"))).size, 7 + expanded.filter(([name]) => name.endsWith('.bpmn')).length);
    const players = references.filter(reference => reference.endsWith('.html'));
    assert.equal(players.length, 46 + expanded.filter(([,mime]) => mime === 'text/html').length + flowcharts.filter(([,mime]) => mime === 'text/html').length);
    assert.equal(new Set(references.filter(reference => reference.endsWith('.puml'))).size, 7 + expanded.filter(([name]) => name.endsWith('.puml')).length + flowcharts.filter(([name]) => name.endsWith('.puml')).length);
    assert.equal(new Set(references.filter(reference => reference.endsWith('.mmd'))).size, 6 + expanded.filter(([name]) => name.endsWith('.mmd')).length + flowcharts.filter(([name]) => name.endsWith('.mmd')).length);
    for (const file of players) {
      await page.goto(new URL(file, root).href);
      await page.locator('[data-motion-ready="true"]').waitFor();
      assert.equal(await page.locator('.motion-overlay').count(), 0);
      await page.getByRole('button', { name: 'Step', exact: true }).click();
      assert.equal(await page.locator('[data-diagram-viewer]').getAttribute('data-playing'), 'false');
    }
    await page.close();
  }
  assert.deepEqual(external, []); assert.deepEqual(errors, []);
  console.log('Gallery: original artifact baseline and expanded sources, fixed-theme SVGs, offline players and links verified in both preferences; three additional distinct sources per family.');
} finally { await browser.close(); }
