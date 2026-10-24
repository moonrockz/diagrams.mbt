// Standalone XML, resolved paint colours and adaptive theme behavior. MoonBit
// snapshot tests compare these exact SVG bytes on every supported backend.
import { chromium } from 'playwright';
import { readdir, readFile } from 'node:fs/promises';
import { strict as assert } from 'node:assert';

const corpus = 'tests/acceptance/__snapshot__/svg';
const files = (await readdir(corpus)).filter(f => f.endsWith('.svg')).sort().map(f => `${corpus}/${f}`);
assert.equal(files.length, 114, '38 corpus diagrams in all three modes');
files.push(...['simple', 'rich-adaptive', 'rich-dark', 'rich-light', 'namespaced', 'half-arrows-light'].map(f => `pkgs/diagrams-svg/__snapshot__/${f}.svg`));

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
        // Half-arrow upper/lower are page coordinates, including reversed
        // senders, right-to-left receivers and the return leg of self-messages.
        for (const group of svg.querySelectorAll('.message')) {
          const line = group.querySelector<SVGPathElement>('.m-line')!;
          for (const [end, field] of [['start', 'sender'], ['end', 'receiver']]) {
            const head = group.getAttribute(`data-${field}-head`)!;
            if (!head.includes('half-')) continue;
            const length = line.getTotalLength();
            const p = line.getPointAtLength(end === 'start' ? 0 : length);
            const q = line.getPointAtLength(end === 'start' ? 1 : length - 1);
            const direction = p.x > q.x ? 1 : -1;
            const ref = line.getAttribute(`marker-${end}`)!;
            const marker = svg.querySelector<SVGMarkerElement>(`[id="${ref.slice(5, -1)}"]`)!;
            const box = marker.querySelector('path')!.getBBox();
            const ys = [box.y * direction, (box.y + box.height) * direction];
            const upper = head.includes('half-upper-');
            if (upper ? Math.max(...ys) > 0 || Math.min(...ys) >= 0 : Math.min(...ys) < 0 || Math.max(...ys) <= 0) {
              throw new Error(`${field} ${head} painted on the wrong side`);
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
  // Distinct inline diagrams must resolve each marker in their own tree.
  const inline = await Promise.all(['01-light', '23-light'].map(f => readFile(`${corpus}/${f}.svg`, 'utf8')));
  await page.setContent(inline.join(''));
  assert.equal(await page.evaluate(() => {
    const ids = [...document.querySelectorAll('[id]')].map(n => n.id);
    if (new Set(ids).size !== ids.length) return false;
    return [...document.querySelectorAll('svg')].every(svg => [...svg.querySelectorAll('.m-line')].every(line =>
      ['marker-start', 'marker-end'].every(attr => {
        const ref = line.getAttribute(attr);
        return !ref || document.getElementById(ref.slice(5, -1))?.ownerSVGElement === svg;
      })));
  }), true, 'inline SVGs retain their own marker shapes and colours');

  // CSS must also stay within each SVG when two palettes share a page.
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.setContent((await readFile('pkgs/diagrams-svg/__snapshot__/simple.svg', 'utf8')) +
    (await readFile('pkgs/diagrams-svg/__snapshot__/custom-adaptive.svg', 'utf8')));
  assert.deepEqual(await page.locator('.bg').evaluateAll(nodes => nodes.map(n => getComputedStyle(n).fill)),
    ['rgb(2, 6, 23)', 'rgb(16, 24, 32)']);

  // A caller prefix permits independent overrides of an identical diagram.
  await page.setContent((await readFile('pkgs/diagrams-svg/__snapshot__/simple.svg', 'utf8')) +
    (await readFile('pkgs/diagrams-svg/__snapshot__/namespaced.svg', 'utf8')));
  await page.evaluate(() => {
    const roots = document.querySelectorAll('svg');
    roots[0].setAttribute('data-theme', 'dark'); roots[1].setAttribute('data-theme', 'light');
  });
  assert.deepEqual(await page.locator('.bg').evaluateAll(nodes => nodes.map(n => getComputedStyle(n).fill)),
    ['rgb(2, 6, 23)', 'rgb(244, 245, 247)']);
  assert.deepEqual(requests, [], 'all SVGs render without network requests');
  console.log(`Verified ${files.length} standalone SVGs in both browser preferences, including root overrides and text contrast.`);
} finally {
  await browser.close();
}
