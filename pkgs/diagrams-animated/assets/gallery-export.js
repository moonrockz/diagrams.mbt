(() => {
  'use strict';
  const style = document.createElement('style');
  style.textContent = '.diagram-viewer__export { padding: var(--dv-space); background: var(--dv-bg); border-top: 1px solid var(--dv-border); }\n.diagram-viewer__export summary { cursor: pointer; min-height: 44px; display: flex; align-items: center; }\n.diagram-viewer__export form { display: flex; flex-wrap: wrap; gap: var(--dv-space); padding-block: var(--dv-space); }\n.diagram-viewer__export label { display: flex; flex-direction: column; gap: .25rem; max-width: 100%; font-size: .875em; }\n.diagram-viewer__export :is(input,select,button) { min-height: 44px; max-width: 100%; color: var(--dv-ink); background: var(--dv-surface); border: 1px solid var(--dv-border); border-radius: var(--diagram-viewer-control-radius, .5rem); padding: .4rem; font: inherit; }\n.diagram-viewer__export input[type="checkbox"] { align-self: start; width: 44px; }\n.diagram-viewer__status { font-size: .875em; overflow-wrap: anywhere; }\n@media print { .diagram-viewer__export { display: none !important; } }\n';
  document.head.append(style);
  for (const root of document.querySelectorAll('[data-diagram-viewer]')) {
    const image = root.querySelector('.diagram-viewer__content img');
    if (!image || root.querySelector('.diagram-viewer__export')) continue;
    const panel = document.createElement('details');
    panel.className = 'diagram-viewer__export';
    const summary = document.createElement('summary');
    summary.textContent = 'Export image';
    const form = document.createElement('form');
    form.setAttribute('aria-label', 'Export image options');
    function field(name, type, value, attributes = {}) {
      const label = document.createElement('label');
      label.textContent = name;
      const input = document.createElement('input');
      Object.assign(input, {type, value}, attributes);
      label.append(input); form.append(label); return input;
    }
    const formatLabel = document.createElement('label');
    formatLabel.textContent = 'Format';
    const format = document.createElement('select'); format.setAttribute('aria-label', 'Format');
    for (const [value, text] of [['png', 'PNG'], ['jpeg', 'JPEG']]) {
      const option = document.createElement('option'); option.value = value; option.textContent = text; format.append(option);
    }
    formatLabel.append(format); form.append(formatLabel);
    const width = field('Width in pixels, blank for source size', 'number', '', { min: '1', max: '16384', step: '1' });
    const background = field('Background', 'color', '#ffffff');
    const alpha = field('Transparent PNG background', 'checkbox', ''); alpha.checked = true;
    const quality = field('JPEG quality', 'number', '90', { min: '1', max: '100', step: '1' });
    const button = document.createElement('button'); button.type = 'submit'; button.textContent = 'Download PNG';
    const cancel = document.createElement('button'); cancel.type = 'button'; cancel.textContent = 'Cancel export'; cancel.hidden = true;
    const status = document.createElement('p'); status.className = 'diagram-viewer__status'; status.setAttribute('role', 'status'); status.setAttribute('aria-live', 'polite');
    let controller = null;
    format.addEventListener('change', () => {button.textContent = `Download ${format.value.toUpperCase()}`; alpha.disabled = format.value === 'jpeg'; quality.disabled = format.value !== 'jpeg';});
    quality.disabled = true;
    cancel.addEventListener('click', () => controller?.abort());
    form.addEventListener('submit', async event => {
      event.preventDefault();
      if (controller || !form.reportValidity()) return;
      const selectedFormat = format.value;
      const options = {
        theme: root.dataset.rasterTheme || root.dataset.viewerResolvedTheme || 'light',
        background: selectedFormat === 'png' && alpha.checked ? null : background.value,
        quality: Number(quality.value),
        ...(width.value ? { width: Number(width.value) } : {}),
      };
      const job = new AbortController(); controller = job;
      button.disabled = true; cancel.hidden = false; panel.setAttribute('aria-busy', 'true'); status.textContent = 'Preparing image…';
      try {
        if (typeof window.DiagramsRaster?.export !== 'function') throw new Error('The configured image converter is unavailable. SVG downloads remain available.');
        const svg = root.querySelector('.diagram-viewer__canonical')?.content.textContent;
        if (!svg) throw new Error('Canonical SVG is unavailable. Regenerate the gallery with its checked source assets.');
        const result = await window.DiagramsRaster.export({
          svg, format: selectedFormat, options, signal: job.signal,
          onProgress: value => { if (controller === job && !job.signal.aborted) status.textContent = typeof value === 'number' ? `Exporting image: ${Math.round(value * 100)}%` : 'Exporting image…'; },
        });
        if (job.signal.aborted) throw new DOMException('Export cancelled', 'AbortError');
        const expected = selectedFormat === 'png' ? 'image/png' : 'image/jpeg';
        if (!result || result.mediaType !== expected || !(result.width > 0 && result.height > 0) || !result.bytes?.length) throw new Error('Image conversion returned no complete image.');
        const bytes = result.bytes instanceof Uint8Array ? result.bytes : Uint8Array.from(result.bytes);
        const url = URL.createObjectURL(new Blob([bytes], {type: result.mediaType}));
        const download = document.createElement('a'); download.href = url;
        download.download = `${root.dataset.rasterName || 'diagram'}.${selectedFormat === 'jpeg' ? 'jpg' : 'png'}`;
        document.body.append(download); download.click(); download.remove();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
        status.textContent = `Downloaded ${selectedFormat.toUpperCase()}, ${result.width} × ${result.height} pixels.`;
      } catch (error) {
        status.textContent = job.signal.aborted ? 'Export cancelled.' : `Export failed: ${error?.message || String(error)}`;
      } finally {
        controller = null; button.disabled = false; cancel.hidden = true; panel.removeAttribute('aria-busy');
      }
    });
    form.append(button, cancel); panel.append(summary, form, status); root.append(panel);
  }
})();
