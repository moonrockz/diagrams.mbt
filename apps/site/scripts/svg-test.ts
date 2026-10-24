// Standalone XML, resolved paint colours and adaptive theme behavior. MoonBit
// snapshot tests compare these exact SVG bytes on every supported backend.
import { chromium } from 'playwright';
import { readdir, readFile } from 'node:fs/promises';
import { strict as assert } from 'node:assert';

const corpus = 'tests/acceptance/__snapshot__/svg';
const files = (await readdir(corpus)).filter(f => f.endsWith('.svg')).sort().map(f => `${corpus}/${f}`);
assert.equal(files.length, 114, '38 corpus diagrams in all three modes');
files.push(...['simple', 'rich-adaptive', 'rich-dark', 'rich-light'].map(f => `pkgs/diagrams-svg/__snapshot__/${f}.svg`));

const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  // No render can fetch a remote resource, even if a fixture includes hostile text.
  const requests: string[] = [];
  page.on('request', r => requests.push(r.url()));
  for (const file of files) {
    const source = await readFile(file, 'utf8');
    const fixed = /-(dark|light)\.svg$/.test(file);
    for (const preference of ['dark', 'light'] as const) {
      await page.emulateMedia({ colorScheme: preference });
      await page.setContent('');
      const result = await page.evaluate(({ source, fixed, preference, file }) => {
        const xml = new DOMParser().parseFromString(source, 'image/svg+xml');
        if (xml.querySelector('parsererror')) throw new Error(xml.documentElement.textContent ?? 'Invalid XML');
        const svg = document.importNode(xml.documentElement, true);
        document.body.append(svg);
        if (svg.localName !== 'svg' || svg.namespaceURI !== 'http://www.w3.org/2000/svg') throw new Error('Not SVG');
        for (const node of svg.querySelectorAll('*')) {
          if (['script', 'foreignObject', 'image', 'use', 'a'].includes(node.localName)) throw new Error(`Forbidden ${node.localName}`);
          for (const attr of node.attributes) {
            if (/^on/i.test(attr.name) || /href$/i.test(attr.name)) throw new Error(`Forbidden ${attr.name}`);
          }
        }
        if (!svg.querySelector('title') || !svg.querySelector('desc')) throw new Error('Missing accessibility text');
        const background = svg.querySelector('.bg')!;
        const readBackground = () => getComputedStyle(background).fill;
        const dark = 'rgb(2, 6, 23)', light = 'rgb(244, 245, 247)';
        const expected = fixed ? (file.endsWith('-light.svg') ? light : dark) : preference === 'light' ? light : dark;
        if (readBackground() !== expected) throw new Error(`Background ${readBackground()}, expected ${expected}`);
        if (fixed && (svg.querySelector('style') || /var\(|@media/.test(source))) throw new Error('Fixed SVG contains CSS');
        if (!fixed) {
          for (const [theme, color] of [['dark', dark], ['light', light]]) {
            svg.setAttribute('data-theme', theme);
            if (readBackground() !== color) throw new Error(`Override ${theme} ignored`);
          }
          svg.removeAttribute('data-theme');
        }
        for (const node of svg.querySelectorAll('*')) {
          for (const attr of node.attributes) {
            for (const match of attr.value.matchAll(/url\(([^)]+)\)/g)) {
              if (!match[1].startsWith('#')) throw new Error(`External reference ${match[1]}`);
              if (!svg.querySelector(`[id="${match[1].slice(1)}"]`)) throw new Error(`Missing marker ${match[1]}`);
            }
          }
        }
        const color = (s: string) => {
          const channels = s.match(/[\d.]+/g)?.map(Number);
          if (!channels || channels.length < 3) throw new Error(`Unresolved color ${s}`);
          return [channels[0], channels[1], channels[2], channels[3] ?? 1];
        };
        const over = (top: number[], bottom: number[]) => top.slice(0, 3).map((v, i) => v * top[3] + bottom[i] * (1 - top[3])).concat(1);
        const luminance = (c: number[]) => c.slice(0, 3).map(v => {
          const x = v / 255; return x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4;
        }).reduce((v, x, i) => v + x * [0.2126, 0.7152, 0.0722][i], 0);
        // Read paint in document order at a point inside each text block.
        // Opaque masks reset earlier band/tint layers just as they do on screen.
        for (const text of svg.querySelectorAll('text')) {
          const style = getComputedStyle(text);
          if (parseFloat(style.fontSize) < 11) throw new Error('Text below 11px');
          const span = text.querySelector('tspan')!;
          const x = Number(span.getAttribute('x')), y = Number(span.getAttribute('y')) - 4;
          let behind = color(readBackground());
          for (const rect of svg.querySelectorAll('rect')) {
            if (!(rect.compareDocumentPosition(text) & Node.DOCUMENT_POSITION_FOLLOWING)) continue;
            const rx = Number(rect.getAttribute('x')), ry = Number(rect.getAttribute('y'));
            if (x >= rx && x <= rx + Number(rect.getAttribute('width')) && y >= ry && y <= ry + Number(rect.getAttribute('height'))) {
              behind = over(color(getComputedStyle(rect).fill), behind);
            }
          }
          const ink = over(color(style.fill), behind);
          const a = luminance(ink), b = luminance(behind);
          const contrast = (Math.max(a, b) + .05) / (Math.min(a, b) + .05);
          if (contrast < 4.5) throw new Error(`${text.textContent?.trim()} contrast ${contrast}`);
        }
        return { texts: svg.querySelectorAll('text').length, paths: svg.querySelectorAll('path').length };
      }, { source, fixed, preference, file }).catch(e => { throw new Error(`${file}, ${preference}: ${e.message}`); });
      assert.ok(result.texts > 0, `${file}: visible labels`);
    }
  }
  assert.deepEqual(requests, [], 'all SVGs render without network requests');
  console.log(`Verified ${files.length} standalone SVGs in both browser preferences, including root overrides and text contrast.`);
} finally {
  await browser.close();
}
