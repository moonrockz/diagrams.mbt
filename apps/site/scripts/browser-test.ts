// The browser smoke test of the docs site (design D16). `moonx scripts/site.mbtx test` serves the
// built `_site/` with `scripts/serve-site.mbtx --no-watch --port 4174`, gives the origin in
// SITE_ORIGIN and the base path of the tree in SITE_BASE, and runs this file with the pinned Node.
// The checks cover client code that no other test runs: the islands and the Rabbita link capture.
import { chromium, type Page } from 'playwright';

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

await waitForSite(180_000);
const browser = await chromium.launch();
const errors: string[] = [];
try {
  const page = await browser.newPage();
  page.on('pageerror', (e) => errors.push(`${page.url()}: ${e.message}`));

  await page.goto(site);
  check((await page.title()) === 'diagrams.mbt', 'the landing page title is "diagrams.mbt"');

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
  const examples = [
    ['sequence-basic', 'sequence'], ['zenuml-symbols', 'ZenUML'], ['architecture-cloud', 'architecture'],
    ['bpmn-process', 'BPMN'], ['bpmn-collaboration', 'BPMN'], ['swimlane-review', 'swimlane'],
    ['regex-date', 'regex'], ['regex-evidence', 'regex'], ['ebnf-arithmetic', 'EBNF'],
    ['ebnf-evidence', 'EBNF'], ['json-order', 'JSON'], ['yaml-service', 'YAML'],
    ['flowchart-mermaid-review','flowchart'], ['flowchart-plantuml-modern','flowchart'], ['flowchart-plantuml-legacy','flowchart'],
  ];
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
    check(await cards.count() === 15, `${colorScheme}: original 12 plus three flowchart preview cards`);
    await specimen.getByRole('link', { name: 'BPMN', exact: true }).click();
    check(await cards.count() === 2, `${colorScheme}: family filter selects two BPMN examples`);
    const filter = specimen.getByRole('searchbox', { name: 'Filter examples', exact: true });
    await filter.fill('collaboration');
    check(await cards.count() === 1, `${colorScheme}: family and text filters combine`);
    check(await filter.evaluate(node => node === document.activeElement), `${colorScheme}: filtering retains focus`);
    await filter.fill('no-such-diagram-example');
    check(await cards.count() === 0, `${colorScheme}: empty results hide cards`);
    check(await specimen.getByText('No examples match these filters.', { exact: true }).isVisible(), `${colorScheme}: empty state visible`);
    await specimen.getByRole('button', { name: 'Reset filters', exact: true }).first().click();
    check(await cards.count() === 15, `${colorScheme}: reset restores all examples`);

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
console.log('site browser smoke test passed');
