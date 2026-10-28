// Decode portable raster fixtures with Chromium, independently of MoonBit codecs.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { chromium } from 'playwright';

const fixtures = JSON.parse(await readFile('tests/raster-acceptance/__snapshot__/gif.json', 'utf8'));
const stillFixtures = JSON.parse(await readFile('tests/raster-acceptance/__snapshot__/still.json', 'utf8'));
const adapter = await readFile('pkgs/diagrams-animated/assets/raster.generated.js', 'utf8');
const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  const errors: string[] = [], requests: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('http://127.0.0.1:4777/', route => route.fulfill({ contentType: 'text/html', body: '<!doctype html><title>Raster decoder qualification</title>' }));
  await page.route('**/*', route => {
    if (route.request().url() === 'http://127.0.0.1:4777/') return route.fallback();
    requests.push(route.request().url()); return route.abort();
  });
  await page.goto('http://127.0.0.1:4777/');
  await page.evaluate(async fixtures => {
    const decode = async (source: string, type: string) => createImageBitmap(new Blob([Uint8Array.from(atob(source), char => char.charCodeAt(0))], { type }));
    for (const fixture of fixtures) {
      const canvas = document.createElement('canvas'); canvas.width = fixture.width; canvas.height = fixture.height;
      const context = canvas.getContext('2d', { willReadFrequently: true })!;
      const png = await decode(fixture.png, 'image/png');
      if (png.width !== fixture.width || png.height !== fixture.height) throw new Error(`${fixture.name}: PNG dimensions differ`);
      context.drawImage(png, 0, 0); png.close();
      const rgba = context.getImageData(0, 0, canvas.width, canvas.height).data;
      if (rgba[3] !== 0) throw new Error(`${fixture.name}: PNG corner lost requested transparency`);
      if (!rgba.some((value, index) => index % 4 === 3 && value > 0)) throw new Error(`${fixture.name}: PNG content is empty`);
      const jpeg = await decode(fixture.jpeg, 'image/jpeg');
      if (jpeg.width !== fixture.width || jpeg.height !== fixture.height) throw new Error(`${fixture.name}: JPEG dimensions differ`);
      context.clearRect(0, 0, canvas.width, canvas.height); context.drawImage(jpeg, 0, 0); jpeg.close();
      const corner = context.getImageData(0, 0, 1, 1).data;
      if ([248, 240, 232].some((value, channel) => Math.abs(value - corner[channel]) > 12) || corner[3] !== 255) throw new Error(`${fixture.name}: JPEG background differs`);
    }
  }, stillFixtures);
  const results = await page.evaluate(async fixtures => {
    if (typeof ImageDecoder !== 'function') throw new Error('Locked Chromium must provide an independent animated-image decoder');
    const bytes = (base64: string) => Uint8Array.from(atob(base64), char => char.charCodeAt(0));
    const canvas = document.createElement('canvas'), context = canvas.getContext('2d', { willReadFrequently: true })!;
    const results = [];
    for (const fixture of fixtures) {
      canvas.width = fixture.width; canvas.height = fixture.height;
      const decoder = new ImageDecoder({ data: bytes(fixture.gif), type: 'image/gif' });
      await decoder.tracks.ready;
      const track = decoder.tracks.selectedTrack!;
      if (track.frameCount !== fixture.samples.length) throw new Error(`${fixture.name}: frame count differs`);
      const pixels: Uint8ClampedArray[] = [];
      const durations: number[] = [];
      for (let i = 0; i < track.frameCount; i++) {
        const { image } = await decoder.decode({ frameIndex: i });
        if (image.displayWidth !== fixture.width || image.displayHeight !== fixture.height) throw new Error(`${fixture.name}: decoded dimensions differ`);
        durations.push(image.duration!);
        context.clearRect(0, 0, canvas.width, canvas.height); context.drawImage(image, 0, 0);
        pixels.push(context.getImageData(0, 0, canvas.width, canvas.height).data);
        image.close();
      }
      if (!durations.every((duration, i) => duration === fixture.samples[i].delay * 10000)) throw new Error(`${fixture.name}: centisecond delays differ`);
      if (!pixels.some(frame => frame.some((value, i) => value !== pixels[0][i]))) throw new Error(`${fixture.name}: all GIF frames are identical`);
      if (fixture.name === 'illustrative-forever') {
        if (track.repetitionCount !== Infinity) throw new Error('Illustrative GIF must loop forever');
        if (pixels[0].some((value, i) => value !== pixels.at(-1)![i])) throw new Error('Illustrative endpoint must sample the next period start');
      } else {
        const canonical = await createImageBitmap(new Blob([bytes(fixture.canonical_png)], { type: 'image/png' }));
        context.clearRect(0, 0, canvas.width, canvas.height); context.drawImage(canonical, 0, 0); canonical.close();
        const reference = context.getImageData(0, 0, canvas.width, canvas.height).data;
        const final = pixels.at(-1)!;
        for (let i = 0; i < reference.length; i += 4) {
          const expected = [(reference[i] >> 5) * 36, (reference[i + 1] >> 5) * 36, (reference[i + 2] >> 6) * 85, 255];
          if (expected.some((value, channel) => value !== final[i + channel])) throw new Error(`${fixture.name}: final view differs from independently decoded canonical PNG at pixel ${i / 4}`);
        }
      }
      const host = document.createElement('div'); host.innerHTML = fixture.svg; document.body.append(host);
      const svg = host.querySelector('svg')!;
      svg.style.width = `${fixture.width}px`; svg.style.height = `${fixture.height}px`;
      let checked = 0;
      for (let i = 0; i < fixture.samples.length; i++) for (const occurrence of fixture.samples[i].active) {
        if (!occurrence.target) continue;
        const path = svg.querySelector(`[id="${CSS.escape(occurrence.target.id)}"]`) as SVGPathElement;
        const progress = Number(occurrence.numerator) / Number(occurrence.denominator);
        const point = path.getPointAtLength(path.getTotalLength() * (occurrence.reversed ? 1 - progress : progress));
        if (Math.hypot(point.x - occurrence.target.x, point.y - occurrence.target.y) > .25) throw new Error(`${fixture.name}: pure GIF point leaves browser final curve`);
        const screen = new DOMPoint(point.x, point.y).matrixTransform(path.getCTM()!);
        let blue = false;
        for (let y = Math.max(0, Math.floor(screen.y) - 2); y <= Math.min(fixture.height - 1, Math.ceil(screen.y) + 2); y++) for (let x = Math.max(0, Math.floor(screen.x) - 2); x <= Math.min(fixture.width - 1, Math.ceil(screen.x) + 2); x++) {
          const offset = (y * fixture.width + x) * 4, frame = pixels[i];
          if (frame[offset + 2] > 200 && frame[offset] < 150 && frame[offset + 1] < 190) blue = true;
        }
        if (!blue && !occurrence.target.mask) throw new Error(`${fixture.name}: independently decoded moving region is absent at frame ${i}, ${screen.x},${screen.y}`);
        checked++;
      }
      host.remove();
      results.push({ name: fixture.name, frames: track.frameCount, repetitionCount: String(track.repetitionCount), durations, checked });
      decoder.close();
    }
    return results;
  }, fixtures);
  const byName = new Map(results.map(result => [result.name, result]));
  await page.addScriptTag({ content: adapter });
  const conversions = await page.evaluate(async ({ stills, animations }) => {
    const compare = (bytes: Uint8Array, encoded: string, name: string) => {
      const expected = atob(encoded);
      if (bytes.length !== expected.length || bytes.some((value, i) => value !== expected.charCodeAt(i))) throw new Error(`${name}: worker bytes differ from portable library fixture`);
    };
    let count = 0;
    for (const fixture of stills) for (const format of ['png', 'jpeg']) {
      const result = await window.DiagramsRaster.export({ svg: fixture.source, format, options: { theme: 'light', background: format === 'png' ? null : '#f8f0e8', quality: fixture.name === 'explicit-background' ? 100 : 80 } });
      compare(result.bytes, fixture[format], `${fixture.name}/${format}`);
      if (result.width !== fixture.width || result.height !== fixture.height) throw new Error('Worker result dimensions differ');
      count++;
    }
    for (const fixture of animations) {
      const loop = fixture.name === 'illustrative-forever' ? 'forever' : fixture.name === 'repeat-twice' ? 2 : 'once';
      const result = await window.DiagramsRaster.export({ svg: fixture.wire.canonical, animation: fixture.wire, format: 'gif', options: { width: 160, background: '#ffffff', frameRate: 10, loop } });
      compare(result.bytes, fixture.gif, fixture.name);
      count++;
    }
    const controller = new AbortController();
    let announce: () => void;
    const started = new Promise<void>(resolve => { announce = resolve; });
    const fixture = animations[0];
    const pending = window.DiagramsRaster.export({ svg: fixture.wire.canonical, animation: fixture.wire, format: 'gif', options: { width: 160, background: '#ffffff' }, signal: controller.signal,
      onProgress: value => { if (typeof value === 'object') announce(); } }).then(() => 'completed', error => error.name);
    await started; controller.abort();
    if (await pending !== 'AbortError') throw new Error('Cancellation offered a completed image');
    const invalid = await window.DiagramsRaster.export({ svg: stills[0].source, format: 'png', options: { width: 0 } }).then(() => false, () => true);
    if (!invalid) throw new Error('Invalid options produced a success payload');
    const mismatch = await window.DiagramsRaster.export({ svg: '<svg/>', format: 'gif', animation: fixture.wire }).then(() => false, () => true);
    if (!mismatch) throw new Error('Mismatched GIF source produced a success payload');
    const recovered = await window.DiagramsRaster.export({ svg: stills[0].source, format: 'png' });
    compare(recovered.bytes, stills[0].png, 'recovery');
    return count;
  }, { stills: stillFixtures, animations: fixtures });
  assert.equal(byName.get('finite-once')?.repetitionCount, '0');
  assert.equal(byName.get('repeat-twice')?.repetitionCount, '2');
  assert.deepEqual(errors, []); assert.deepEqual(requests, []);
  console.log(`Independent PNG/JPEG decoding passed for ${stillFixtures.length} fixtures; ${conversions} offline worker conversions match portable bytes, with cancellation and recovery. GIF decoding: ${JSON.stringify(results)}`);
} finally { await browser.close(); }
