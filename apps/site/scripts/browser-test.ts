// The browser smoke test of the docs site (design D16). `moonx scripts/site.mbtx test` serves the
// built `_site/` with `scripts/serve-site.mbtx --no-watch --port 4174`, gives the origin in
// SITE_ORIGIN and the base path of the tree in SITE_BASE, and runs this file with the pinned Node.
// The checks cover client code that no other test runs: the islands and the Rabbita link capture.
import assert from 'node:assert/strict';
import { chromium, type Page, type Locator, type Download } from 'playwright';
import { mkdir, readFile } from 'node:fs/promises';
const portableStills = JSON.parse(await readFile('tests/raster-acceptance/__snapshot__/still.json', 'utf8')) as { name: string; source: string; png: string; jpeg: string }[];
const sequenceStill = portableStills.find(row => row.name === 'sequence')!;
const treeName = (process.env.SITE_BASE ?? '/diagrams.mbt/').includes('/next/') ? 'next' : 'root';
await mkdir('_build/handoff', { recursive: true });
let galleryConversions = 0, portableComparisons = 0;
const galleryInventory = JSON.parse(await readFile('site/gallery.json', 'utf8')).entries as { id: string; family: string }[];

const origin = process.env.SITE_ORIGIN ?? 'http://127.0.0.1:4174';
const base = process.env.SITE_BASE ?? '/diagrams.mbt/';
const site = `${origin}${base}`;
const overview = `${site}docs/design/overview/`;
const sequenceGuide = `${site}docs/guides/mermaid-sequence/`;
const failures: string[] = [];
const check = (ok: boolean, message: string) => {
  if (!ok) failures.push(message);
};

// The server compiles its script before it listens, so wait for the first answer.
async function waitForSite(timeoutMs: number) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    try {
      if ((await fetch(site)).ok) return;
    } catch {
      // Not listening yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`${site} did not answer in ${timeoutMs} ms`);
}

async function searchFor(page: Page, query: string) {
  await page.fill('#search-input', query);
  await page.waitForSelector('#site-search .search-results:not([hidden]) li', { timeout: 5000 });
}

// The path and the anchor of a URL. A search result of an API item ends with an anchor.
const pathAndHash = (url: string | URL) => {
  const u = new URL(url);
  return u.pathname + u.hash;
};


async function downloadBytes(download: Download) {
  assert.equal(await download.failure(), null);
  return readFile((await download.path())!);
}
async function recordGallery(page: Page) {
  await page.evaluate(() => {
    const original = window.DiagramsRaster.export;
    window.__galleryLibrary = original; window.__galleryRequests = []; window.__galleryRendering = 0;
    window.DiagramsRaster.export = request => {
      const { signal, onProgress, ...serializable } = request;
      window.__galleryRequests.push(structuredClone(serializable));
      return original({ ...request, onProgress: value => {
        if (typeof value === 'object' && value.phase === 'rendering') window.__galleryRendering++;
        onProgress?.(value);
      } });
    };
  });
}
async function galleryExport(page: Page, root: Locator, format: 'png' | 'jpeg', portable = false, race = false) {
  await root.getByRole('combobox', { name: 'Format', exact: true }).selectOption(format);
  const canonical = await root.locator('.diagram-viewer__canonical').evaluate((template: HTMLTemplateElement) => template.content.textContent!);
  const imageURL = await root.locator('.diagram-viewer__content img').evaluate((image: HTMLImageElement) => image.currentSrc || image.src);
  assert.equal(canonical, await (await page.request.get(imageURL)).text(), 'Selected preview and canonical export source differ');
  const index = await page.evaluate(() => window.__galleryRequests.length);
  const pending = page.waitForEvent('download');
  await root.getByRole('button', { name: `Download ${format.toUpperCase()}`, exact: true }).click();
  if (race) await root.evaluate(root => {
    if (!root.querySelector('.diagram-viewer__export')!.hasAttribute('aria-busy')) throw new Error('Option race must happen during a pending conversion');
    const select = root.querySelector<HTMLSelectElement>('select[aria-label="Format"]')!;
    select.value = 'png'; select.dispatchEvent(new Event('change', { bubbles: true }));
    const input = root.querySelector<HTMLInputElement>('input[type="number"]')!; input.value = '191'; input.dispatchEvent(new Event('input', { bubbles: true }));
  });
  const download = await pending;
  assert.ok(download.suggestedFilename().endsWith(format === 'png' ? '.png' : '.jpg'));
  const bytes = await downloadBytes(download);
  const direct = await page.evaluate(async index => {
    const request = window.__galleryRequests[index], result = await window.__galleryLibrary(request);
    let binary = ''; for (const byte of result.bytes) binary += String.fromCharCode(byte);
    return { bytes: btoa(binary), width: result.width, height: result.height, type: result.mediaType, request };
  }, index);
  assert.equal(direct.request.svg, canonical); assert.equal(direct.request.format, format);
  assert.equal(direct.request.options.theme, await root.getAttribute('data-viewer-resolved-theme'));
  assert.deepEqual(bytes, Buffer.from(direct.bytes, 'base64'), 'Published gallery download differs from direct compiled portable-library adapter');
  if (portable) {
    assert.equal(canonical.trimEnd(), sequenceStill.source.trimEnd());
    assert.deepEqual(bytes, Buffer.from(sequenceStill[format], 'base64'), 'Published gallery download differs from pinned four-target portable fixture');
    portableComparisons++;
  }
  const dimensions = await page.evaluate(async ({ bytes, type }) => {
    const image = await createImageBitmap(new Blob([Uint8Array.from(atob(bytes), c => c.charCodeAt(0))], { type }));
    const dimensions = [image.width, image.height]; image.close(); return dimensions;
  }, direct);
  assert.deepEqual(dimensions, [direct.width, direct.height]);
  assert.equal(direct.type, `image/${format}`);
  assert.match((await root.locator('[role="status"]').textContent())!, /^Downloaded (PNG|JPEG), [1-9]\d* × [1-9]\d* pixels\.$/);
  galleryConversions++;
}

await waitForSite(180_000);
const browser = await chromium.launch();
const errors: string[] = [];
try {
  const page = await browser.newPage();
  page.on('pageerror', (e) => errors.push(`${page.url()}: ${e.message}`));

  await page.goto(site);
  check((await page.title()) === 'diagrams.mbt', 'the landing page title is "diagrams.mbt"');

  for (const width of [360, 768, 1440]) for (const colorScheme of ['light', 'dark'] as const) {
    const landing = await browser.newPage({ viewport: { width, height: 900 }, colorScheme });
    landing.on('pageerror', error => errors.push(`${landing.url()}: ${error.message}`));
    await landing.goto(site);
    check(await landing.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${width}/${colorScheme}: landing fits the viewport`);
    check(await landing.locator('.brand-badge').evaluate((image: HTMLImageElement) => image.complete && image.naturalWidth > 0), `${width}/${colorScheme}: selected Lunar drafter badge loads`);
    check(await landing.locator('.family-preview img').evaluateAll(images => images.length >= 3 && images.every(image => (image as HTMLImageElement).complete && (image as HTMLImageElement).naturalWidth > 0)), `${width}/${colorScheme}: supported family previews load`);
    const links = await landing.locator('.primary-links a').evaluateAll(anchors => anchors.map(anchor => (anchor as HTMLAnchorElement).href));
    check(links.length === 4 && links.every(href => new URL(href).pathname.startsWith(base)), `${width}/${colorScheme}: primary links stay in the active tree`);
    for (const href of links) check((await landing.request.get(href)).ok(), `${width}/${colorScheme}: primary link resolves: ${href}`);
    check(await landing.locator('#diagram-families, #portable-output').count() === 2, `${width}/${colorScheme}: landing anchors remain available`);
    const logo = landing.locator('.site-header .brand img');
    check(await logo.evaluate((image: HTMLImageElement) => image.complete && image.naturalWidth > 0), `${width}/${colorScheme}: branded header icon loads`);
    check(await landing.locator('.site-header .brand').getAttribute('href') === base, `${width}/${colorScheme}: branded header stays in current tree`);
    const favicon = await landing.locator('link[rel="icon"]').getAttribute('href');
    check(favicon === `${base}assets/brand/icons/favicon.ico`, `${width}/${colorScheme}: configured favicon is tree scoped`);
    if (width === 1440 && colorScheme === 'light') {
      assert.deepEqual(await (await landing.request.get(new URL((await logo.getAttribute('src'))!, site).href)).body(), await readFile('docs/assets/brand/icons/logo-64.png'));
      assert.deepEqual(await (await landing.request.get(new URL(favicon!, site).href)).body(), await readFile('docs/assets/brand/icons/favicon.ico'));
      assert.deepEqual(await (await landing.request.get(`${site}assets/brand/diagrams-badge.png`)).body(), await readFile('docs/assets/brand/diagrams-badge.png'));
    }
    if (width === 360 || width === 1440) await landing.screenshot({ path: `_build/handoff/landing-final-${treeName}-${width}-${colorScheme}.png`, fullPage: true });
    await landing.close();
  }

  // Search: Enter and a click open the first result, and a query without a match says so.
  await searchFor(page, 'diagram');
  const first = await page.locator('.search-results li a').first().getAttribute('href');
  check(first !== null && first.startsWith(base), `the first result for "diagram" is below ${base}: ${first}`);
  await page.press('#search-input', 'Enter');
  await page.waitForURL((url) => pathAndHash(url) === first, { timeout: 5000 }).catch(() => {});
  check(pathAndHash(page.url()) === first, `Enter opens the first result ${first}, not ${page.url()}`);
  await page.goto(site);
  await searchFor(page, 'diagram');
  await page.locator('.search-results li a').first().click();
  await page.waitForURL((url) => pathAndHash(url) === first, { timeout: 5000 }).catch(() => {});
  check(pathAndHash(page.url()) === first, `a click opens the first result ${first}, not ${page.url()}`);
  await page.goto(site);
  await searchFor(page, 'zzzqqq');
  check((await page.textContent('.search-empty')) === 'No results', 'a query without a match shows "No results"');

  // Theme: the control cycles system, light, dark, and a stored choice paints from the start.
  const toggle = page.locator('.theme-toggle');
  const themes: string[][] = [];
  for (const theme of ['system', 'light', 'dark']) {
    await page.waitForSelector(`.theme-toggle[aria-label="Theme: ${theme}"]`, { timeout: 2000 }).catch(() => {});
    themes.push([
      (await toggle.getAttribute('aria-label')) ?? '',
      await page.evaluate(() => document.documentElement.dataset.theme ?? 'system'),
    ]);
    await toggle.click();
  }
  check(
    JSON.stringify(themes) ===
      JSON.stringify([['Theme: system', 'system'], ['Theme: light', 'light'], ['Theme: dark', 'dark']]),
    `the theme control cycles system, light, dark: ${JSON.stringify(themes)}`,
  );
  await page.evaluate(() => localStorage.setItem('site-theme', 'dark'));
  await page.goto(`${site}docs/`, { waitUntil: 'commit' });
  await page.waitForSelector('link[rel="stylesheet"]', { state: 'attached' });
  check(
    (await page.evaluate(() => document.documentElement.dataset.theme)) === 'dark',
    'a stored dark theme is set before the stylesheet loads',
  );
  await page.evaluate(() => localStorage.removeItem('site-theme'));

  // The implemented design overview and the rendered sequence guide.
  await page.goto(overview);
  check(
    (await page.locator('.status-banner').count()) === 0,
    'the implemented Design overview has no proposed-status banner',
  );
  check((await page.locator('figure.diagram svg').count()) > 0, 'the Design overview has a diagram as an SVG');
  await page.goto(sequenceGuide);
  const example = page.locator('.docs-article img[src$="sequence.svg"]');
  check((await example.count()) === 1, 'the sequence guide has its rendered SVG example');
  if ((await example.count()) === 1) {
    check(
      await example.evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth > 0),
      'the rendered sequence example loads',
    );
  }

  // The feed.
  const feed = await page.request.get(`${site}articles/atom.xml`);
  check(feed.ok(), 'the Atom feed is served');
  const parsed = await page.evaluate(
    (xml) => !new DOMParser().parseFromString(xml, 'application/xml').querySelector('parsererror'),
    await feed.text(),
  );
  check(parsed, 'the Atom feed parses as XML');

  // No horizontal scroll on a phone.
  const phone = await browser.newPage({ viewport: { width: 390, height: 844 } });
  phone.on('pageerror', (e) => errors.push(`${phone.url()}: ${e.message}`));
  for (const path of ['', 'docs/design/overview/', 'docs/guides/mermaid-sequence/']) {
    await phone.goto(`${site}${path}`);
    check(
      await phone.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
      `${base}${path} has no horizontal scroll at 390 px`,
    );
  }
  await phone.close();

  // The copy button of a code block.
  const copyContext = await browser.newContext({ permissions: ['clipboard-read', 'clipboard-write'] });
  const copyPage = await copyContext.newPage();
  copyPage.on('pageerror', (e) => errors.push(`${copyPage.url()}: ${e.message}`));
  await copyPage.goto(sequenceGuide);
  const block = copyPage.locator('.prose .code-block').first();
  const copy = block.locator('.copy-button');
  check((await copy.count()) === 1, 'a code block of the sequence guide has one copy button');
  if ((await copy.count()) === 1) {
    check((await copy.getAttribute('data-tooltip')) === 'Copy', 'the copy button tooltip says "Copy"');
    const code = (await block.locator('code').innerText()).replace(/\n$/, '');
    await copy.click();
    await copyPage.waitForSelector('.copy-button[data-tooltip="Copied"]', { timeout: 2000 }).catch(() => {});
    check((await copy.getAttribute('data-tooltip')) === 'Copied', 'the tooltip says "Copied" after a click');
    check(
      (await copyPage.evaluate(() => navigator.clipboard.readText())) === code,
      'the copy button puts the text of the code block on the clipboard',
    );
  }
  await copyContext.close();

  // Without JavaScript the docs page keeps its sidebar, its content and plain links.
  const plain = await browser.newContext({ javaScriptEnabled: false });
  const plainPage = await plain.newPage();
  await plainPage.goto(overview);
  check((await plainPage.locator('.docs-sidebar a').count()) > 0, 'without JavaScript the sidebar has links');
  check((await plainPage.locator('.docs-article h1').count()) === 1, 'without JavaScript the content shows');
  await plainPage.locator('.site-links a', { hasText: 'Articles' }).click();
  check(new URL(plainPage.url()).pathname === `${base}articles/`, 'without JavaScript a main link navigates');
  await plain.close();

  // Gallery keeps exact supplied artifact links and honest scope labels in every tree.
  await page.goto(site);
  check((await page.locator(`.hero a[href="${base}gallery/"]`).count()) === 1, 'landing links to the gallery');
  check((await page.locator(`.site-links a[href="${base}gallery/"]`).count()) === 1, 'primary navigation links to Gallery');
  const landingText = await page.locator('#content').innerText();
  check(landingText.includes('General PlantUML diagrams, Draw.io and Graphviz DOT are planned'), 'landing labels planned formats');
  check(landingText.includes('does not execute a process or simulate BPMN tokens'), 'landing states BPMN limits');
  check(landingText.includes('evidence supplied by an external engine'), 'landing states trace evidence provenance');
  const examples = galleryInventory.map(entry => [entry.id, entry.family]);
  await page.goto(`${site}gallery/`);
  check((await page.locator('#content a[href^="#"]').count()) >= 9, 'gallery has family navigation');
  for (const [id, family] of examples) {
    check((await page.locator(`#content a[href="${base}gallery/${id}/"]`).count()) === 1, `gallery lists ${id} (${family})`);
  }
  for (const [id] of examples) {
    await page.goto(`${site}gallery/${id}/`);
    check((await page.locator('#content a[download][href$=".svg"]').count()) > 0, `${id}: SVG download link available`);
    for (const link of await page.locator('#content a[download]').all()) {
      const href = await link.getAttribute('href');
      check(href !== null && (await page.request.get(new URL(href, site).href)).ok(), `${id}: download resolves ${href}`);
    }
  }
  for (const javaScriptEnabled of [true, false]) {
    for (const colorScheme of ['light', 'dark'] as const) {
      for (const width of [1440, 768, 360]) {
        const context = await browser.newContext({ javaScriptEnabled, colorScheme, reducedMotion: 'reduce', viewport: { width, height: 900 } });
        const galleryPage = await context.newPage();
        galleryPage.on('pageerror', (e) => errors.push(`${galleryPage.url()}: ${e.message}`));
        await galleryPage.goto(`${site}gallery/`);
        if (width === 360) {
          check(await galleryPage.locator('.gallery-card').first().evaluate(card => card.getBoundingClientRect().top < innerHeight), `${colorScheme}, JS=${javaScriptEnabled}: family navigation leaves the first preview in the narrow viewport`);
        }
        const indexCard = galleryPage.locator('.gallery-card').first();
        const indexSource = indexCard.locator('.gallery-source');
        if (javaScriptEnabled) {
          const preview = indexCard.getByRole('tab', {name: 'Preview', exact: true});
          const source = indexCard.getByRole('tab', {name: 'Source', exact: true});
          const other = galleryPage.locator('.gallery-card').nth(1);
          const viewer = indexCard.locator('[data-diagram-viewer]:visible').first();
          await viewer.getByRole('button', {name: 'Zoom in', exact: true}).click();
          await viewer.locator('.diagram-viewer__viewport').focus(); await galleryPage.keyboard.press('ArrowLeft');
          const content = await viewer.locator('.diagram-viewer__content').elementHandle();
          assert.ok(content);
          const transform = await content.evaluate(node => (node as HTMLElement).style.transform);
          for (let repeat = 0; repeat < 3; repeat++) {
            await preview.focus(); await preview.press('End');
            check(await source.getAttribute('aria-selected') === 'true', 'Index End selects Source');
            check(await source.evaluate(node => node === document.activeElement), 'Index focus follows selection');
            check(await other.getByRole('tab', {name: 'Preview', exact: true}).getAttribute('aria-selected') === 'true', 'Other card stays in Preview');
            check(await galleryPage.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `Index Source fits ${width}/${colorScheme}`);
            const download = indexSource.locator('a[download]').first();
            const href = await download.getAttribute('href');
            check(href !== null && href.startsWith(base), 'Index source URL remains tree scoped');
            if (href) check(await indexSource.locator('pre code').first().textContent() === await (await galleryPage.request.get(new URL(href, site).href)).text(), 'Index source equals original download');
            if (repeat === 0 && (width === 360 || width === 1440)) await indexCard.screenshot({ path: `_build/handoff/source-tabs-${treeName}-${width}-${colorScheme}.png` });
            await source.press('Home');
            await galleryPage.waitForFunction(({content, transform}) => content.isConnected && (content as HTMLElement).style.transform === transform, {content, transform});
          }
          const ids = await galleryPage.locator('[id]').evaluateAll(nodes => nodes.map(node => node.id));
          check(new Set(ids).size === ids.length, 'Index IDs are unique');
          await viewer.getByRole('button', {name: 'Fit diagram', exact: true}).click();
        } else {
          check(await indexSource.isVisible(), 'No-script index keeps original source readable');
          check(await indexCard.getByRole('tab').count() === 0, 'No-script index has no inactive tabs');
          const href = await indexSource.locator('a[download]').first().getAttribute('href');
          if (href) check(await indexSource.locator('pre code').first().textContent() === await (await galleryPage.request.get(new URL(href, site).href)).text(), 'No-script index source is exact');
        }
        for (const [id, family] of examples) {
          await galleryPage.goto(`${site}gallery/${id}/`);
          const label = `${id}, ${width}px, ${colorScheme}, JS=${javaScriptEnabled}`;
          check((await galleryPage.locator('.gallery-detail > .gallery-card-meta').textContent())?.replace(/\s+/g, ' ').includes(`Family: ${family}. Status: Implemented`) === true, `${label}: family and support label`);
          await galleryPage.locator('.gallery-preview img:visible').first().scrollIntoViewIfNeeded();
          for (const image of await galleryPage.locator('.gallery-preview img:visible').all()) {
            await image.scrollIntoViewIfNeeded();
            await image.evaluate((img: HTMLImageElement) => img.decode());
            check(await image.evaluate((img: HTMLImageElement) => img.naturalWidth > 0), `${label}: static preview loads`);
          }
          check(await galleryPage.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${label}: no clipped page content`);
          const downloads = galleryPage.locator('#content a[download]');
          check((await downloads.count()) > 0, `${label}: source download available`);
          for (const link of await galleryPage.locator('#content a').all()) {
            const href = await link.getAttribute('href');
            if (href?.startsWith('/')) check(href.startsWith(base), `${label}: ${href} remains in the current tree`);
          }
        }
        await galleryPage.goto(`${site}gallery/swimlane-review/`);
        if (javaScriptEnabled) {
          await galleryPage.keyboard.press('Tab');
          check(await galleryPage.locator('.skip-link').evaluate((link) => link === document.activeElement), 'keyboard starts at Skip to content');
          if (width <= 760) {
            await galleryPage.locator('.menu-toggle').focus();
            await galleryPage.keyboard.press('Enter');
            check(await galleryPage.locator('.site-links').isVisible(), 'keyboard opens narrow navigation');
            await galleryPage.keyboard.press('Enter');
            check(!(await galleryPage.locator('.site-links').isVisible()), 'keyboard closes narrow navigation');
          }
          await galleryPage.locator('.theme-toggle').focus();
          check(await galleryPage.locator('.theme-toggle').evaluate((button) => getComputedStyle(button).outlineStyle !== 'none'), 'keyboard theme control has visible focus');
        } else {
          check(await galleryPage.locator('.site-links').isVisible(), 'no-script primary navigation remains visible');
        }
        await context.close();
      }
    }
  }

  // The real consumer inherits its theme and specimen controls from the published toolkit.
  for (const colorScheme of ['light', 'dark'] as const) {
    const context = await browser.newContext({ colorScheme, viewport: { width: 1440, height: 1000 } });
    const specimen = await context.newPage();
    specimen.on('pageerror', error => errors.push(`${specimen.url()}: ${error.message}`));
    const expected = colorScheme === 'light'
      ? { background: 'rgb(249, 250, 251)', foreground: 'rgb(17, 24, 39)', accent: '#4f46e5' }
      : { background: 'rgb(15, 16, 20)', foreground: 'rgb(229, 231, 235)', accent: '#a5b4fc' };
    for (const route of ['', 'docs/', 'api/', 'gallery/']) {
      await specimen.goto(site + route);
      const palette = await specimen.evaluate(() => ({
        background: getComputedStyle(document.body).backgroundColor,
        foreground: getComputedStyle(document.body).color,
        accent: getComputedStyle(document.documentElement).getPropertyValue('--accent').trim(),
      }));
      check(JSON.stringify(palette) === JSON.stringify(expected), `${colorScheme} shared Smithy palette on ${route || 'landing'}`);
    }
    const cards = specimen.locator('.gallery-card:visible');
    check(await cards.count() === examples.length, `${colorScheme}: all qualified gallery preview cards`);
    const firstCard = specimen.locator('.gallery-card').first();
    await firstCard.getByRole('tab', {name: 'Source', exact: true}).click();
    await specimen.getByRole('link', { name: 'BPMN', exact: true }).click();
    check(await cards.count() === examples.filter(([,family]) => family === 'BPMN').length, `${colorScheme}: family filter selects all BPMN examples`);
    const filter = specimen.getByRole('searchbox', { name: 'Filter examples', exact: true });
    await filter.fill('Collaboration and message flows');
    check(await cards.count() === 1, `${colorScheme}: family and text filters combine`);
    check(await filter.evaluate(node => node === document.activeElement), `${colorScheme}: filtering retains focus`);
    await filter.fill('no-such-diagram-example');
    check(await cards.count() === 0, `${colorScheme}: empty results hide cards`);
    check(await specimen.getByText('No examples match these filters.', { exact: true }).isVisible(), `${colorScheme}: empty state visible`);
    await specimen.getByRole('button', { name: 'Reset filters', exact: true }).first().click();
    check(await cards.count() === examples.length, `${colorScheme}: reset restores all examples`);
    check(await firstCard.getByRole('tab', {name: 'Source', exact: true}).getAttribute('aria-selected') === 'true', 'Filtering retains independent tab state');

    await specimen.goto(`${site}gallery/sequence-basic/`);
    const tabs = specimen.getByRole('tablist', { name: 'Example inspection' });
    const previewTab = tabs.getByRole('tab', { name: 'Preview', exact: true });
    const sourceTab = tabs.getByRole('tab', { name: 'Source', exact: true });
    await previewTab.focus(); await previewTab.press('ArrowRight');
    check(await sourceTab.getAttribute('aria-selected') === 'true', `${colorScheme}: keyboard selects Source`);
    check(await sourceTab.evaluate(node => node === document.activeElement), `${colorScheme}: keyboard focus follows selected tab`);
    const source = specimen.locator('.gallery-source pre code').first();
    const download = specimen.locator('.gallery-source a[download]').first();
    const sourceURL = await download.getAttribute('href');
    check(sourceURL !== null, `${colorScheme}: source download is explicit`);
    if (sourceURL) {
      const raw = await (await specimen.request.get(new URL(sourceURL, site).href)).text();
      check(await source.textContent() === raw, `${colorScheme}: displayed source matches downloaded text exactly`);
    }
    const copy = specimen.getByRole('button', { name: /^Copy source:/ }).first();
    await specimen.evaluate(() => Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      writeText: () => Promise.reject(new DOMException('Denied by consumer browser qualification', 'NotAllowedError')),
    } }));
    await copy.click();
    check(await source.isVisible(), `${colorScheme}: denied clipboard retains selectable source`);
    check(await download.isVisible(), `${colorScheme}: denied clipboard retains source download`);
    await sourceTab.press('Home');
    check(await previewTab.getAttribute('aria-selected') === 'true', `${colorScheme}: Home returns to Preview`);
    await context.close();
  }

  // Exercise published Telescope's forms and the configured diagrams.mbt
  // library adapter; retain the distinction from the independently pinned
  // portable output fixtures used for the matching sequence specimen.
  for (const colorScheme of ['light', 'dark'] as const) {
    const context = await browser.newContext({ colorScheme, acceptDownloads: true, viewport: { width: 1024, height: 1000 } });
    const gallery = await context.newPage();
    gallery.on('pageerror', error => errors.push(`${gallery.url()}: ${error.message}`));
    const external: string[] = [];
    gallery.on('request', request => { if (new URL(request.url()).origin !== origin && /^https?:/.test(request.url())) external.push(request.url()); });
    await gallery.goto(`${site}gallery/`);
    await gallery.locator('.diagram-viewer__export').first().waitFor({ state: 'attached' });
    await recordGallery(gallery);
    const card = gallery.locator('.gallery-card').first(), other = gallery.locator('.gallery-card').nth(1);
    const root = card.locator('[data-diagram-viewer]:visible').first();
    await root.locator('summary').click();
    check(await other.locator('.diagram-viewer__export[open]').count() === 0, `${colorScheme}: opening export is isolated to selected gallery card`);
    await root.getByLabel('Background', { exact: true }).fill('#f8f0e8');
    await root.getByRole('combobox', { name: 'Format', exact: true }).selectOption('jpeg');
    await root.getByLabel('JPEG quality', { exact: true }).fill('80');
    await root.locator('[aria-label="Zoom in"]').click();
    await root.locator('.diagram-viewer__viewport').focus(); await gallery.keyboard.press('ArrowLeft');
    const content = await root.locator('.diagram-viewer__content').elementHandle();
    assert.ok(content);
    const transform = await content.getAttribute('style');
    await card.getByRole('tab', {name: 'Source', exact: true}).click();
    await card.getByRole('tab', {name: 'Preview', exact: true}).click();
    await gallery.waitForFunction(({content, transform}) => content.isConnected && content.getAttribute('style') === transform, {content, transform});
    await galleryExport(gallery, root, 'png', colorScheme === 'light');
    await galleryExport(gallery, root, 'jpeg', colorScheme === 'light');
    assert.equal(await root.locator('.diagram-viewer__content').getAttribute('style'), transform, 'Gallery export changes zoom/pan');
    assert.equal(await other.locator('.diagram-viewer__export[aria-busy]').count(), 0);
    assert.equal(await other.locator('.diagram-viewer__export [role="status"]').allTextContents().then(values => values.some(Boolean)), false);
    if (colorScheme === 'light') {
      // Options and suffix are captured before the converter awaits its worker.
      await root.getByLabel('Width in pixels, blank for source size', { exact: true }).fill('512');
      await galleryExport(gallery, root, 'jpeg', false, true);
      let offered = 0; gallery.on('download', () => offered++);
      await root.getByRole('combobox', { name: 'Format', exact: true }).selectOption('png');
      const width = root.getByLabel('Width in pixels, blank for source size', { exact: true });
      await width.fill('2048');
      const rendering = await gallery.evaluate(() => window.__galleryRendering);
      await root.getByRole('button', { name: 'Download PNG', exact: true }).click();
      await gallery.waitForFunction(rendering => window.__galleryRendering > rendering, rendering);
      await root.getByRole('button', { name: 'Cancel export', exact: true }).click();
      await gallery.waitForFunction(() => [...document.querySelectorAll('.diagram-viewer__export [role="status"]')].some(status => status.textContent === 'Export cancelled.'));
      assert.equal(offered, 0, 'Cancelled export offered a partial download');
      await width.fill('0');
      const count = await gallery.evaluate(() => window.__galleryRequests.length);
      await root.getByRole('button', { name: 'Download PNG', exact: true }).click();
      assert.equal(await gallery.evaluate(() => window.__galleryRequests.length), count, 'Invalid form reached conversion');
      await width.fill('16384'); await root.getByRole('button', { name: 'Download PNG', exact: true }).click();
      await gallery.waitForFunction(() => [...document.querySelectorAll('.diagram-viewer__export [role="status"]')].some(status => status.textContent?.startsWith('Export failed:')));
      assert.equal(offered, 0);
      const svgURL = await root.locator('.diagram-viewer__content img').getAttribute('src');
      assert.ok((await gallery.request.get(new URL(svgURL!, site).href)).ok(), 'Canonical SVG remains served after raster failure');
      await width.fill(''); await galleryExport(gallery, root, 'png', true);
    }
    await gallery.goto(`${site}gallery/sequence-basic/`); await recordGallery(gallery);
    if (colorScheme === 'light') {
      const svgLink = gallery.locator('#content a[download][href$=".svg"]').first();
      const href = new URL((await svgLink.getAttribute('href'))!, site).href;
      const pending = gallery.waitForEvent('download'); await svgLink.click();
      assert.deepEqual(await downloadBytes(await pending), await (await gallery.request.get(href)).body(), 'Original SVG download survives raster errors');
    }
    const detail = gallery.locator('[data-diagram-viewer]:visible').first();
    await detail.locator('summary').click(); await detail.getByLabel('Background', { exact: true }).fill('#f8f0e8');
    await galleryExport(gallery, detail, 'png', colorScheme === 'light');
    assert.deepEqual(external, [], 'Gallery export must not request external conversion resources');
    await context.close();
  }

  // One API page: the item anchor, a source link, and a search that opens an API item.
  const apiPage = `${site}api/moonrockz/diagrams/`;
  await page.goto(apiPage);
  check((await page.locator('[id="version"]').count()) === 1, 'the diagrams API page has the #version anchor');
  check(
    (await page.locator('.api-source a[href^="https://github.com/moonrockz/diagrams.mbt/blob/"]').count()) > 0,
    'the diagrams API page has a source link on GitHub',
  );
  const apiPhone = await browser.newPage({ viewport: { width: 390, height: 844 } });
  apiPhone.on('pageerror', (e) => errors.push(`${apiPhone.url()}: ${e.message}`));
  await apiPhone.goto(apiPage);
  check(
    await apiPhone.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
    `${base}api/moonrockz/diagrams/ has no horizontal scroll at 390 px`,
  );
  await apiPhone.close();

  check(errors.length === 0, `no page errors: ${errors.join('; ')}`);
} finally {
  await browser.close();
}

if (failures.length) {
  for (const f of failures) console.error(`FAIL: ${f}`);
  process.exit(1);
}
console.log(`Published Telescope0.5 ${treeName}: ${galleryInventory.length} entries, ${galleryInventory.length * 12} responsive detail cases, ${galleryConversions} real UI conversions match compiled-library bytes (${portableComparisons} also match four-target portable fixtures); branding/assets, root-scoped links, cancellation/error/recovery, option race, isolation, filters/tabs and landing screenshots passed.`);
