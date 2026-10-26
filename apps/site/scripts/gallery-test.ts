import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

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
    assert.equal(images.length, 110);
    for (const file of images) {
      const svg = await readFile(fileURLToPath(new URL(file, root)), 'utf8');
      await page.evaluate(svg => {
        const doc = new DOMParser().parseFromString(svg, 'image/svg+xml');
        if (doc.querySelector('parsererror, script, foreignObject')) throw new Error('Invalid or active static SVG');
      }, svg);
    }
    assert.equal(new Set(references.filter(reference => reference.endsWith(".bpmn"))).size, 7);
    const players = references.filter(reference => reference.endsWith('.html'));
    assert.equal(players.length, 31);
    assert.equal(new Set(references.filter(reference => reference.endsWith('.puml'))).size, 7);
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
  console.log('Gallery: 110 fixed-theme SVGs, 7 BPMN XML and 7 PlantUML sources, 31 offline players and all links verified in both preferences.');
} finally { await browser.close(); }
