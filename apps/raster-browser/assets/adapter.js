(() => {
  'use strict';
  const compressedWorker = __DIAGRAMS_RASTER_WORKER__;
  const compressedFonts = __DIAGRAMS_RASTER_FONTS__;
  let fontPromise = null;
  let sourcePromise = null;
  const cancelled = () => new DOMException('Export cancelled', 'AbortError');
  function decode(value) { return Uint8Array.from(atob(value), character => character.charCodeAt(0)); }
  async function inflate(compressed) {
    if (typeof DecompressionStream !== 'function') throw new Error('This browser cannot load the offline raster converter. SVG downloads remain available.');
    const stream = new Blob([decode(compressed)]).stream().pipeThrough(new DecompressionStream('deflate'));
    return new Response(stream).text();
  }
  function workerSource() {
    if (!sourcePromise) sourcePromise = (async () => {
      return inflate(compressedWorker);
    })().catch(error => { sourcePromise = null; throw error; });
    return sourcePromise;
  }
  async function convert({ svg, format = 'png', options = {}, fonts, animation, plan, signal, onProgress }) {
    if (signal?.aborted) throw cancelled();
    if (typeof svg !== 'string' || !['png', 'jpeg', 'gif'].includes(format)) throw new Error('Supply generated SVG and choose PNG, JPEG or GIF.');
    let suppliedFonts = fonts || options.fonts;
    if (!suppliedFonts && compressedFonts) {
      if (!fontPromise) fontPromise = inflate(compressedFonts).then(JSON.parse).catch(error => { fontPromise = null; throw error; });
      suppliedFonts = await fontPromise;
    }
    if (!suppliedFonts) throw new Error('Explicit raster font data is missing. SVG downloads remain available.');
    onProgress?.(0);
    const source = await workerSource();
    if (signal?.aborted) throw cancelled();
    return new Promise((resolve, reject) => {
      let worker, url, finished = false;
      function cleanup() { worker?.terminate(); if (url) URL.revokeObjectURL(url); signal?.removeEventListener('abort', abort); }
      function fail(error) { if (finished) return; finished = true; cleanup(); reject(error); }
      function abort() { fail(cancelled()); }
      try {
        url = URL.createObjectURL(new Blob([source], { type: 'text/javascript' }));
        worker = new Worker(url);
        signal?.addEventListener('abort', abort, { once: true });
        if (signal?.aborted) { abort(); return; }
        worker.onerror = event => { event.preventDefault(); fail(new Error(event.message || 'Raster converter failed.')); };
        worker.onmessageerror = () => fail(new Error('Raster converter returned an unreadable result.'));
        worker.onmessage = event => {
          if (finished) return;
          const result = event.data;
          if (result.error) { fail(new Error(result.error)); return; }
          try {
            const bytes = decode(result.bytes);
            if (!bytes.length || !(result.width > 0 && result.height > 0)) throw new Error('Raster converter returned no complete image.');
            onProgress?.(1); finished = true; cleanup();
            resolve({ bytes, mediaType: result.mediaType, width: result.width, height: result.height });
          } catch (error) { fail(error); }
        };
        worker.postMessage({ svg, format, options, fonts: suppliedFonts, animation, plan });
        onProgress?.({ phase: 'rendering' });
      } catch (error) { fail(error); }
    });
  }
  window.DiagramsRaster = { export: convert, protocolVersion: 1 };
})();
