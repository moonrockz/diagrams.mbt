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
  // BPMN qualification reuses the current-head portable snapshots. Each JSON
  // entry owns a named SVG, so every symbol and marker is checked independently.
  const symbolFrames = JSON.parse(await readFile('tests/bpmn-acceptance/__snapshot__/symbols.json', 'utf8')) as [string, string, string][];
  const markerFrames = JSON.parse(await readFile('tests/bpmn-acceptance/__snapshot__/markers.json', 'utf8')) as [string, string, string][];
  assert.equal(symbolFrames.length, 117);
  assert.equal(markerFrames.length, 37);
  const viewFrames = JSON.parse(await readFile('tests/bpmn-acceptance/__snapshot__/views.json', 'utf8')) as [string, string, string][];
  assert.equal(viewFrames.length, 6);
  const automaticFrames = JSON.parse(await readFile('tests/bpmn-acceptance/__snapshot__/automatic.json', 'utf8')) as [string, string, string][];
  assert.equal(automaticFrames.length, 24);
  const minimal = await readFile('tests/bpmn-acceptance/__snapshot__/minimal.svg', 'utf8');
  for (const [name, mode, source] of [...symbolFrames, ...markerFrames, ...viewFrames, ...automaticFrames, ['minimal', 'adaptive', minimal]]) {
    for (const preference of ['dark', 'light'] as const) {
      await page.emulateMedia({ colorScheme: preference });
      await page.setContent('');
      await page.evaluate(({ source, mode, preference }) => {
        const xml = new DOMParser().parseFromString(source, 'image/svg+xml');
        if (xml.querySelector('parsererror')) throw new Error('Invalid BPMN XML');
        const svg = document.importNode(xml.documentElement, true) as unknown as SVGSVGElement;
        document.body.append(svg);
        if (svg.namespaceURI !== 'http://www.w3.org/2000/svg' || !svg.querySelector('title') || !svg.querySelector('desc')) throw new Error('Missing BPMN SVG accessibility');
        const ids = [svg.id, ...Array.from(svg.querySelectorAll('[id]'), n => n.id)];
        if (new Set(ids).size !== ids.length) throw new Error('Duplicate BPMN IDs');
        for (const node of svg.querySelectorAll('*')) {
          if (['script', 'foreignObject', 'image', 'use', 'a', 'iframe'].includes(node.localName)) throw new Error(`Active BPMN node ${node.localName}`);
          for (const attr of node.attributes) {
            if (/^on/i.test(attr.name) || /href$/i.test(attr.name)) throw new Error(`Active BPMN attribute ${attr.name}`);
            for (const match of attr.value.matchAll(/url\(([^)]+)\)/g)) {
              if (!match[1].startsWith('#') || !svg.querySelector(`[id="${match[1].slice(1)}"]`)) throw new Error(`Broken BPMN local reference ${match[1]}`);
            }
          }
        }
        const fixed = mode === 'dark' || mode === 'light';
        const background = svg.querySelector<SVGRectElement>(':scope > .bg')!;
        const expected = (fixed ? mode : preference) === 'dark' ? 'rgb(2, 6, 23)' : 'rgb(244, 245, 247)';
        if (getComputedStyle(background).fill !== expected) throw new Error('Incorrect BPMN palette');
        if (fixed && (svg.querySelector('style') || /var\(|@media/.test(source))) throw new Error('Fixed BPMN SVG contains adaptive CSS');
        if (!fixed) {
          for (const theme of ['dark', 'light']) {
            svg.setAttribute('data-theme', theme);
            const color = theme === 'dark' ? 'rgb(2, 6, 23)' : 'rgb(244, 245, 247)';
            if (getComputedStyle(background).fill !== color) throw new Error('BPMN root override failed');
          }
          svg.removeAttribute('data-theme');
        }
        const color = (value: string) => {
          const n = value.match(/[\d.]+/g)?.map(Number);
          if (!n || n.length < 3) throw new Error(`Unresolved BPMN color ${value}`);
          return [n[0], n[1], n[2], n[3] ?? 1];
        };
        const over = (top: number[], bottom: number[]) => top.slice(0, 3).map((v, i) => v * top[3] + bottom[i] * (1 - top[3])).concat(1);
        const luminance = (value: number[]) => value.slice(0, 3).map(v => {
          const c = v / 255; return c <= .03928 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4;
        }).reduce((sum, v, i) => sum + v * [.2126, .7152, .0722][i], 0);
        for (const text of svg.querySelectorAll<SVGTextElement>('text')) {
          const style = getComputedStyle(text);
          if (parseFloat(style.fontSize) < 11) throw new Error('BPMN text below 11 px');
          const box = text.getBBox();
          const point = new DOMPoint(box.x + box.width / 2, box.y + box.height / 2).matrixTransform(text.getScreenCTM()!);
          let behind = color(getComputedStyle(background).fill);
          for (const rect of svg.querySelectorAll<SVGRectElement>('rect')) {
            if (!(rect.compareDocumentPosition(text) & Node.DOCUMENT_POSITION_FOLLOWING)) continue;
            const fill = getComputedStyle(rect).fill;
            if (fill === 'none') continue;
            const local = point.matrixTransform(rect.getScreenCTM()!.inverse());
            const b = rect.getBBox();
            if (local.x >= b.x && local.x <= b.x + b.width && local.y >= b.y && local.y <= b.y + b.height) behind = over(color(fill), behind);
          }
          const ink = over(color(style.fill), behind);
          const a = luminance(ink), b = luminance(behind);
          const ratio = (Math.max(a, b) + .05) / (Math.min(a, b) + .05);
          if (ratio < 4.5) throw new Error(`BPMN text ${text.textContent} contrast ${ratio}`);
        }
        const viewport = svg.querySelector<SVGGElement>('.bpmn-viewport')!;
        const translation = viewport.transform.baseVal.consolidate()!.matrix;
        for (const shape of svg.querySelectorAll<SVGGElement>('.bpmn-shape')) {
          const bounds = shape.querySelector<SVGRectElement>(':scope > .bpmn-bounds')!;
          const b = bounds.getBBox();
          const matrix = svg.getScreenCTM()!.inverse().multiply(bounds.getScreenCTM()!);
          const point = new DOMPoint(b.x, b.y).matrixTransform(matrix);
          if (Math.abs(point.x - (Number(bounds.getAttribute('x')) + translation.e)) > .01 || Math.abs(point.y - (Number(bounds.getAttribute('y')) + translation.f)) > .01) throw new Error('BPMN viewport changes authored geometry');
        }
      }, { source, mode, preference }).catch(error => { throw new Error(`BPMN ${name}/${mode}/${preference}: ${error.message}`); });
    }
  }
  const inlineBpmn = JSON.parse(await readFile('tests/bpmn-acceptance/__snapshot__/inline.json', 'utf8')) as string[];
  await page.setContent(inlineBpmn.join(''));
  assert.equal(await page.evaluate(() => {
    const ids = [...document.querySelectorAll('[id]')].map(node => node.id);
    if (new Set(ids).size !== ids.length) return false;
    const roots = document.querySelectorAll<SVGSVGElement>('svg');
    roots[0].setAttribute('data-theme', 'dark'); roots[1].setAttribute('data-theme', 'light');
    return getComputedStyle(roots[0].querySelector('.bg')!).fill === 'rgb(2, 6, 23)' && getComputedStyle(roots[1].querySelector('.bg')!).fill === 'rgb(244, 245, 247)' && [...roots].every(svg => [...svg.querySelectorAll('path')].every(path => ['marker-start', 'marker-end'].every(attr => {
      const value = path.getAttribute(attr); return !value || document.getElementById(value.slice(5, -1))?.ownerSVGElement === svg;
    })));
  }), true, 'BPMN caller prefixes isolate IDs, markers and root theme overrides');
  assert.deepEqual(requests, [], 'BPMN SVG qualification remains offline');
  console.log(`Verified ${symbolFrames.length + markerFrames.length + viewFrames.length + automaticFrames.length + 1} BPMN SVG outputs in both preferences, including geometry, root overrides and contrast.`);
  // Swimlane qualification consumes the same current-renderer snapshots tested
  // on all backends. Measure browser text and real outline strokes independently.
  const swimlaneFrames = (await Promise.all(['shapes', 'directions', 'markers'].map(async name =>
    JSON.parse(await readFile(`pkgs/diagrams-svg/__snapshot__/swimlane-${name}.json`, 'utf8')) as [string, string, string][]))).flat();
  const registry = JSON.parse(await readFile('tests/corpus/mermaid-swimlanes/shape-coverage.json', 'utf8')) as { shortName: string; asset: boolean }[];
  assert.equal(swimlaneFrames.filter(([, mode]) => mode === 'dark').length, registry.filter(s => !s.asset).length + 5, 'every documented/legacy vector plus ellipse and four flow directions');
  for (const [name, mode, source] of swimlaneFrames) {
    for (const preference of ['dark', 'light'] as const) {
      await page.emulateMedia({ colorScheme: preference });
      await page.setContent('');
      await page.evaluate(({ source, mode, preference }) => {
        const xml = new DOMParser().parseFromString(source, 'image/svg+xml');
        if (xml.querySelector('parsererror')) throw new Error('Malformed swimlane XML');
        const svg = document.importNode(xml.documentElement, true) as unknown as SVGSVGElement;
        document.body.append(svg);
        if (svg.dataset.diagram !== 'swimlane' || !svg.querySelector('title') || !svg.querySelector('desc')) throw new Error('Missing swimlane accessibility');
        const roots = [svg.id, ...Array.from(svg.querySelectorAll('[id]'), n => n.id)];
        if (new Set(roots).size !== roots.length) throw new Error('Duplicate swimlane IDs');
        for (const element of svg.querySelectorAll('*')) {
          if (['script', 'foreignObject', 'image', 'use', 'a', 'iframe'].includes(element.localName)) throw new Error(`Active swimlane element ${element.localName}`);
          for (const attr of element.attributes) {
            if (/^on/i.test(attr.name) || /href$/i.test(attr.name)) throw new Error('Active swimlane attribute');
            for (const match of attr.value.matchAll(/url\(([^)]+)\)/g)) {
              if (!match[1].startsWith('#') || !svg.querySelector(`[id="${match[1].slice(1)}"]`)) throw new Error('Broken swimlane local marker');
            }
          }
        }
        const bg = svg.querySelector<SVGRectElement>(':scope > .bg')!;
        const expected = (['dark', 'light'].includes(mode) ? mode : preference) === 'light' ? 'rgb(244, 245, 247)' : 'rgb(2, 6, 23)';
        if (getComputedStyle(bg).fill !== expected) throw new Error('Wrong swimlane palette');
        if (mode !== 'adaptive' && (svg.querySelector('style') || /var\(|@media/.test(source))) throw new Error('Fixed swimlane includes adaptive CSS');
        if (mode === 'adaptive') {
          for (const theme of ['dark', 'light']) {
            svg.dataset.theme = theme;
            if (getComputedStyle(bg).fill !== (theme === 'dark' ? 'rgb(2, 6, 23)' : 'rgb(244, 245, 247)')) throw new Error('Swimlane root override ignored');
          }
          delete svg.dataset.theme;
        }
        const color = (value: string) => {
          const channels = value.match(/[\d.]+/g)?.map(Number);
          if (!channels || channels.length < 3) throw new Error(`Unresolved paint ${value}`);
          return [...channels.slice(0, 3), channels[3] ?? 1];
        };
        const over = (top: number[], bottom: number[]) => top.slice(0, 3).map((v, i) => v * top[3] + bottom[i] * (1 - top[3])).concat(1);
        const luminance = (c: number[]) => c.slice(0, 3).map(v => { const x = v / 255; return x <= .03928 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4; }).reduce((a, x, i) => a + x * [.2126, .7152, .0722][i], 0);
        const texts = [...svg.querySelectorAll<SVGTextElement>('text')];
        for (const text of texts) {
          const style = getComputedStyle(text), box = text.getBBox();
          if (parseFloat(style.fontSize) < 11) throw new Error('Swimlane text below 11 px');
          const point = new DOMPoint(box.x + box.width / 2, box.y + box.height / 2);
          let behind = color(getComputedStyle(bg).fill);
          for (const node of svg.querySelectorAll<SVGGeometryElement>('path, rect, ellipse, circle')) {
            if (node.closest('defs') || !(node.compareDocumentPosition(text) & Node.DOCUMENT_POSITION_FOLLOWING)) continue;
            const fill = getComputedStyle(node).fill;
            if (fill !== 'none' && node.isPointInFill(point)) behind = over(color(fill), behind);
          }
          const ink = over(color(style.fill), behind), a = luminance(ink), b = luminance(behind);
          if ((Math.max(a, b) + .05) / (Math.min(a, b) + .05) < 4.5) throw new Error(`Swimlane text contrast ${text.textContent}`);
          const owner = text.closest<SVGGElement>('.swimlane-node,.swimlane-group,.swimlane-lane');
          if (owner) {
            const boundary = owner.querySelector<SVGRectElement>(':scope > .swimlane-bounds')!.getBBox();
            // Person and braces have labels in reserved space next to their glyph.
            if (!['person', 'brace', 'brace-r'].includes(owner.dataset.shape!) && (box.x < boundary.x - 1 || box.y < boundary.y - 1 || box.x + box.width > boundary.x + boundary.width + 1 || box.y + box.height > boundary.y + boundary.height + 1)) throw new Error(`Swimlane label overflow ${text.textContent}`);
          }
        }
        const shape = (id: string) => [...svg.querySelectorAll<SVGGElement>('.swimlane-node,.swimlane-group,.swimlane-lane')].find(n => n.dataset.swimlaneId === id)!;
        for (const group of svg.querySelectorAll<SVGGElement>('.swimlane-connection')) {
          const path = group.querySelector<SVGPathElement>(':scope > path')!, length = path.getTotalLength();
          for (const [field, t] of [['displaySource', 0], ['displayTarget', length]] as const) {
            const endpoint = shape(group.dataset[field]!)!, outline = endpoint.querySelector<SVGPathElement>(':scope > .swimlane-outline')!;
            if (!outline.isPointInStroke(path.getPointAtLength(t))) throw new Error(`Swimlane route misses actual ${field} outline ${group.dataset.swimlaneId}`);
          }
          for (const text of texts) {
            const owner = text.dataset.labelOwner;
            if (group.dataset.swimlaneId === owner) continue;
            const box = text.getBBox();
            for (let t = 0; t <= length; t += 1) {
              const p = path.getPointAtLength(t);
              if (p.x > box.x - 1 && p.x < box.x + box.width + 1 && p.y > box.y - 1 && p.y < box.y + box.height + 1) throw new Error(`Swimlane route ${group.dataset.swimlaneId} intersects actual label ${owner}`);
            }
          }
        }
      }, { source, mode, preference }).catch(error => { throw new Error(`Swimlane ${name}/${mode}/${preference}: ${error.message}`); });
    }
  }
  const inlineSwimlanes = JSON.parse(await readFile('pkgs/diagrams-svg/__snapshot__/swimlane-inline.json', 'utf8')) as string[];
  await page.setContent(inlineSwimlanes.join(''));
  assert.equal(await page.evaluate(() => {
    const ids = [...document.querySelectorAll('[id]')].map(n => n.id);
    const roots = document.querySelectorAll<SVGSVGElement>('svg');
    roots[0].dataset.theme = 'dark'; roots[1].dataset.theme = 'light';
    return new Set(ids).size === ids.length && getComputedStyle(roots[0].querySelector('.bg')!).fill === 'rgb(2, 6, 23)' && getComputedStyle(roots[1].querySelector('.bg')!).fill === 'rgb(244, 245, 247)';
  }), true, 'swimlane prefixes and custom root overrides stay isolated');
  assert.deepEqual(requests, [], 'all swimlane SVG qualification remains offline');
  console.log(`Verified ${swimlaneFrames.length} swimlane SVGs in both preferences, including actual outline attachment, header clearance, inline isolation and contrast.`);
  // PlantUML regex, EBNF, JSON and YAML review outputs: standalone XML, local
  // references, fixed palettes, text contrast, and actual railroad attachment.
  const plantuml = JSON.parse(await readFile('tests/plantuml-acceptance/__snapshot__/plantuml-gallery.json', 'utf8')) as [string, string, string][];
  const plantumlSvgs = plantuml.filter(([, kind]) => kind === 'svg');
  assert.ok(plantumlSvgs.length >= 20, 'PlantUML review SVGs');
  for (const [name, , source] of plantumlSvgs) {
    for (const preference of ['dark', 'light'] as const) {
      await page.emulateMedia({ colorScheme: preference });
      await page.setContent('');
      await page.evaluate(({ source, name }) => {
        const xml = new DOMParser().parseFromString(source, 'image/svg+xml');
        if (xml.querySelector('parsererror')) throw new Error('Malformed XML');
        const svg = document.importNode(xml.documentElement, true) as unknown as SVGSVGElement;
        document.body.append(svg);
        if (!['regex', 'ebnf', 'data-tree'].includes(svg.dataset.diagram!) || !svg.querySelector('title') || !svg.querySelector('desc')) throw new Error('Missing PlantUML accessibility');
        const ids = [svg.id, ...Array.from(svg.querySelectorAll('[id]'), n => n.id)];
        if (new Set(ids).size !== ids.length) throw new Error('Duplicate IDs');
        for (const element of svg.querySelectorAll('*')) {
          if (['script', 'foreignObject', 'image', 'use', 'a', 'iframe', 'style'].includes(element.localName)) throw new Error(`Active or adaptive element ${element.localName} in fixed output`);
          for (const attr of element.attributes) {
            if (/^on/i.test(attr.name) || /href$/i.test(attr.name)) throw new Error('Active attribute');
            for (const match of attr.value.matchAll(/url\(([^)]+)\)/g)) {
              if (!match[1].startsWith('#') || !svg.querySelector(`[id="${match[1].slice(1)}"]`)) throw new Error('Broken local reference');
            }
          }
        }
        const bg = svg.querySelector<SVGRectElement>(':scope > .bg')!;
        const expected = name.includes('-dark') ? 'rgb(2, 6, 23)' : 'rgb(244, 245, 247)';
        if (getComputedStyle(bg).fill !== expected) throw new Error(`Wrong palette ${getComputedStyle(bg).fill}`);
        const color = (value: string) => {
          const channels = value.match(/[\d.]+/g)?.map(Number);
          if (!channels || channels.length < 3) throw new Error(`Unresolved paint ${value}`);
          return [...channels.slice(0, 3), channels[3] ?? 1];
        };
        const over = (top: number[], bottom: number[]) => top.slice(0, 3).map((v, i) => v * top[3] + bottom[i] * (1 - top[3])).concat(1);
        const luminance = (c: number[]) => c.slice(0, 3).map(v => { const x = v / 255; return x <= .03928 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4; }).reduce((a, x, i) => a + x * [.2126, .7152, .0722][i], 0);
        for (const text of svg.querySelectorAll<SVGTextElement>('text')) {
          const style = getComputedStyle(text), box = text.getBBox();
          if (parseFloat(style.fontSize) < 11) throw new Error('Text below 11 px');
          const point = new DOMPoint(box.x + box.width / 2, box.y + box.height / 2);
          let behind = color(getComputedStyle(bg).fill);
          for (const node of svg.querySelectorAll<SVGGeometryElement>('rect, path, circle')) {
            if (node.closest('defs') || !(node.compareDocumentPosition(text) & Node.DOCUMENT_POSITION_FOLLOWING)) continue;
            const fill = getComputedStyle(node).fill;
            if (fill !== 'none' && node.isPointInFill(point)) behind = over(color(fill), behind);
          }
          const ink = over(color(style.fill), behind), a = luminance(ink), b = luminance(behind);
          if ((Math.max(a, b) + .05) / (Math.min(a, b) + .05) < 4.5) throw new Error(`Text contrast ${text.textContent}`);
        }
        // Railroad connectors attach to a term edge, a start or end marker,
        // or another connector; none passes through a term label.
        const connectors = [...svg.querySelectorAll<SVGPathElement>('.rr-connector')];
        const ends = connectors.flatMap(path => [path.getPointAtLength(0), path.getPointAtLength(path.getTotalLength())]);
        const terms = [...svg.querySelectorAll<SVGGElement>('.rr-term')];
        const boxes = terms.map(term => term.querySelector<SVGGraphicsElement>('.rr-box, .rr-dot')!.getBBox());
        const markers = [...svg.querySelectorAll<SVGCircleElement>('.rr-start, .rr-end')].map(c => c.getBBox());
        // Constraint regions start and end on the inside of their frame.
        const regions = [...svg.querySelectorAll<SVGRectElement>('.rr-frame-box, .rr-lookaround > .rr-box')].map(r => r.getBBox());
        const near = (p: DOMPoint, b: DOMRect) => p.x >= b.x - 1.5 && p.x <= b.x + b.width + 1.5 && p.y >= b.y - 1.5 && p.y <= b.y + b.height + 1.5;
        for (const path of connectors) {
          if (path.getTotalLength() <= 0) throw new Error(`Zero-length connector ${path.dataset.connector}`);
          for (const p of [path.getPointAtLength(0), path.getPointAtLength(path.getTotalLength())]) {
            const shared = ends.filter(q => Math.abs(q.x - p.x) < .6 && Math.abs(q.y - p.y) < .6).length > 1;
            if (!shared && !boxes.some(b => near(p, b) && (Math.abs(p.x - b.x) < 1.5 || Math.abs(p.x - b.x - b.width) < 1.5 || path.dataset.constraint === 'true')) && !markers.some(b => near(p, b)) && !(path.dataset.constraint === 'true' && regions.some(b => p.x > b.x && p.x - b.x < 6 || b.x + b.width - p.x < 6 && p.x < b.x + b.width))) throw new Error(`Connector ${path.dataset.connector} is not attached`);
          }
          for (const term of terms) {
            if (term.dataset.role === 'assertion') continue;
            const label = term.querySelector<SVGTextElement>('.rr-label');
            if (!label) continue;
            const b = label.getBBox();
            for (let t = 0; t <= path.getTotalLength(); t += 2) {
              const p = path.getPointAtLength(t);
              if (p.x > b.x + 1 && p.x < b.x + b.width - 1 && p.y > b.y + 1 && p.y < b.y + b.height - 1) throw new Error(`Connector ${path.dataset.connector} crosses label ${label.textContent}`);
            }
          }
        }
        // Trace overlays use actual connector geometry and never move terms.
        for (const overlay of svg.querySelectorAll<SVGPathElement>('.rr-trace-path')) {
          const original = svg.querySelector<SVGPathElement>(`.rr-connector[data-connector="${CSS.escape(overlay.dataset.target!)}"]`);
          if (!original || original.getAttribute('d') !== overlay.getAttribute('d')) throw new Error('Trace overlay does not follow its connector');
        }
      }, { source, name }).catch(error => { throw new Error(`PlantUML ${name}/${preference}: ${error.message}`); });
    }
  }
  const inlinePlantuml = plantuml.find(([name]) => name === 'inline.html')![2];
  await page.setContent(inlinePlantuml);
  assert.equal(await page.evaluate(() => {
    const ids = [...document.querySelectorAll('[id]')].map(n => n.id);
    const roots = document.querySelectorAll<SVGSVGElement>('svg');
    roots[0].dataset.theme = 'dark'; roots[1].dataset.theme = 'light';
    const markersLocal = [...roots].every(svg => [...svg.querySelectorAll('path')].every(path => { const v = path.getAttribute('marker-end'); return !v || document.getElementById(v.slice(5, -1))?.ownerSVGElement === svg; }));
    return roots.length === 2 && new Set(ids).size === ids.length && markersLocal && getComputedStyle(roots[0].querySelector('.bg')!).fill === 'rgb(2, 6, 23)' && getComputedStyle(roots[1].querySelector('.bg')!).fill === 'rgb(244, 245, 247)';
  }), true, 'PlantUML prefixes isolate IDs, markers and theme overrides');
  assert.deepEqual(requests, [], 'PlantUML SVG qualification remains offline');
  console.log(`Verified ${plantumlSvgs.length} PlantUML SVGs in both preferences, including attachment, label clearance, trace overlay geometry and contrast.`);
  // Group 1 BPMN tracer: offline path overlay, paused startup and keyboard play/pause.
  const bpmnSvg = await readFile('tests/bpmn-acceptance/__snapshot__/minimal.svg', 'utf8');
  assert.equal(await page.evaluate(source => {
    const xml = new DOMParser().parseFromString(source, 'image/svg+xml');
    return xml.querySelector('parsererror, script, foreignObject') === null
      && xml.querySelectorAll('.bpmn-flow').length === 2
      && xml.querySelectorAll('.bpmn-shape[data-kind$="Event"] circle').length === 2;
  }, bpmnSvg), true);
  const html = await readFile('tests/bpmn-acceptance/__snapshot__/minimal.html', 'utf8');
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  const unexpected: string[] = [];
  await page.route('**/*', route => { unexpected.push(route.request().url()); return route.abort(); });
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.setContent(html);
  const play = page.getByRole('button', { name: 'Play', exact: true });
  assert.equal(await play.getAttribute('aria-pressed'), 'false');
  assert.equal(await page.locator('.motion-overlay').isVisible(), false);
  await play.focus();
  await page.keyboard.press('Enter');
  await page.getByRole('button', { name: 'Pause', exact: true }).waitFor();
  const dot = page.locator('.motion-overlay circle');
  const before = await dot.getAttribute('cx');
  await page.waitForFunction(x => document.querySelector('.motion-overlay circle')?.getAttribute('cx') !== x, before);
  assert.equal(await page.locator('.motion-overlay').evaluate(node => node.closest('.bpmn-viewport') !== null), true, 'overlay shares the translated viewport');
  const geometry = await page.locator('.motion-overlay path').getAttribute('d');
  assert.equal(geometry, 'M76 80 L140 80');
  await page.getByRole('button', { name: 'Pause', exact: true }).click();
  const paused = await dot.getAttribute('cx');
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  assert.equal(await dot.getAttribute('cx'), paused, 'pause retains the current position');
  assert.equal(await page.locator('[role="status"]').textContent(), 'Paused');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  assert.equal(await page.getByRole('button', { name: 'Play', exact: true }).getAttribute('aria-pressed'), 'false');
  assert.notEqual(await dot.getAttribute('cx'), paused, 'reduced motion allows explicit inspection');
  assert.deepEqual(unexpected, [], 'BPMN playback remains offline');
  assert.deepEqual(errors, [], 'BPMN playback has no browser errors');
  console.log('BPMN static XML and offline play/pause qualification passed');
} finally {
  await browser.close();
}
