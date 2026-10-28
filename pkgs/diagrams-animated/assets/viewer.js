(() => {
  'use strict';
  function enhance(root) {
    if (root.dataset.viewerReady) return;
    const viewport = root.querySelector('.diagram-viewer__viewport');
    const content = viewport?.querySelector('.diagram-viewer__content');
    const image = content?.querySelector('svg, img');
    if (!image) return;
    root.dataset.viewerReady = 'true';
    root.classList.add('diagram-viewer');
    const scheme = matchMedia('(prefers-color-scheme: dark)');
    let documentThemeChanged = false;
    function resolveTheme() {
      let preference = root.dataset.viewerTheme;
      if (!['light', 'dark', 'system'].includes(preference)) {
        const applied = document.documentElement.dataset.theme;
        if (applied === 'light' || applied === 'dark') preference = applied;
        else if (documentThemeChanged) preference = 'system';
        else {
          try { preference = localStorage.getItem('site-theme'); } catch { preference = 'system'; }
        }
      }
      root.dataset.viewerResolvedTheme = preference === 'light' || preference === 'dark' ? preference : scheme.matches ? 'dark' : 'light';
    }
    scheme.addEventListener('change', resolveTheme);
    window.addEventListener('storage', event => { if (event.key === 'site-theme') resolveTheme(); });
    new MutationObserver(resolveTheme).observe(root, { attributes: true, attributeFilter: ['data-viewer-theme'] });
    new MutationObserver(() => { documentThemeChanged = true; resolveTheme(); }).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    resolveTheme();
    viewport.tabIndex = 0;
    viewport.setAttribute('aria-label', viewport.getAttribute('aria-label') || 'Diagram viewport. Zoom in to pan with arrow keys or drag.');
    const toolbar = document.createElement('div');
    toolbar.className = 'diagram-viewer__toolbar';
    toolbar.setAttribute('role', 'group');
    toolbar.setAttribute('aria-label', 'Diagram view');
    function button(name, text, action) {
      const element = document.createElement('button');
      element.type = 'button'; element.textContent = text;
      element.setAttribute('aria-label', name); element.title = name;
      element.addEventListener('click', event => { event.preventDefault(); event.stopPropagation(); action(); });
      toolbar.append(element); return element;
    }
    let scale = 1, x = 0, y = 0, width = 0, height = 0, drag = null, suppressClick = false;
    let modal = false, expanded = false, closed = false, priorFocus = null, oldOverflow = '', oldRole = null, oldModal = null;
    const inerted = new Map();
    let priorScrollX = 0, priorScrollY = 0;
    function render() {
      const boundX = Math.max(0, (width * scale - viewport.clientWidth) / 2 + 48);
      const boundY = Math.max(0, (height * scale - viewport.clientHeight + 56) / 2 + 48);
      x = Math.max(-boundX, Math.min(boundX, x)); y = Math.max(-boundY, Math.min(boundY, y));
      content.style.transform = `translate(-50%, -50%) translate(${x}px, ${y}px) scale(${scale})`;
      viewport.dataset.viewerScale = String(scale);
      zoomOut.disabled = scale <= .25; zoomIn.disabled = scale >= 8;
      label.textContent = `${Math.round(scale * 100)}%`;
      viewport.classList.toggle('diagram-viewer__viewport--pannable', scale > 1);
    }
    function zoom(factor) { scale = Math.max(.25, Math.min(8, Math.round(scale * factor * 10000) / 10000)); render(); }
    const zoomOut = button('Zoom out', '−', () => zoom(1 / 1.25));
    const label = document.createElement('output'); label.setAttribute('aria-label', 'Diagram scale'); toolbar.append(label);
    const zoomIn = button('Zoom in', '+', () => zoom(1.25));
    button('Fit diagram', 'Fit', () => { scale = 1; x = y = 0; measure(); });
    const fullscreen = button('Fullscreen', 'Fullscreen', () => { void toggleFullscreen(); });
    viewport.append(toolbar);
    function measure() {
      const box = image.viewBox?.baseVal;
      const naturalWidth = box?.width || image.naturalWidth || Number(image.getAttribute('width')) || 640;
      const naturalHeight = box?.height || image.naturalHeight || Number(image.getAttribute('height')) || 480;
      const fit = Math.min(Math.max(1, viewport.clientWidth - 24) / naturalWidth, Math.max(1, viewport.clientHeight - 80) / naturalHeight);
      width = naturalWidth * fit; height = naturalHeight * fit;
      content.style.width = `${width}px`; content.style.height = `${height}px`; render();
    }
    function finish() {
      if (closed) return;
      closed = true;
      modal = false; expanded = false;
      viewport.classList.remove('diagram-viewer__viewport--expanded');
      fullscreen.textContent = 'Fullscreen'; fullscreen.setAttribute('aria-label', 'Fullscreen');
      if (oldRole === null) viewport.removeAttribute('role'); else viewport.setAttribute('role', oldRole);
      if (oldModal === null) viewport.removeAttribute('aria-modal'); else viewport.setAttribute('aria-modal', oldModal);
      for (const [element, value] of inerted) element.inert = value;
      inerted.clear();
      document.body.style.overflow = oldOverflow;
      measure(); priorFocus?.focus({ preventScroll: true });
      window.scrollTo({ left: priorScrollX, top: priorScrollY, behavior: 'instant' });
    }
    function openModal() {
      modal = true;
      viewport.classList.add('diagram-viewer__viewport--expanded');
      viewport.setAttribute('role', 'dialog'); viewport.setAttribute('aria-modal', 'true');
      document.body.style.overflow = 'hidden';
      for (let branch = viewport; branch.parentElement; branch = branch.parentElement) {
        for (const sibling of branch.parentElement.children) if (sibling !== branch && sibling instanceof HTMLElement) {
          inerted.set(sibling, sibling.inert); sibling.inert = true;
        }
      }
      measure(); fullscreen.focus({ preventScroll: true });
    }
    async function toggleFullscreen() {
      if (expanded) {
        if (document.fullscreenElement === viewport) { try { await document.exitFullscreen(); } catch { finish(); } }
        else finish();
        return;
      }
      expanded = true; closed = false; priorFocus = document.activeElement;
      priorScrollX = window.scrollX; priorScrollY = window.scrollY;
      oldOverflow = document.body.style.overflow; oldRole = viewport.getAttribute('role'); oldModal = viewport.getAttribute('aria-modal');
      fullscreen.textContent = 'Exit'; fullscreen.setAttribute('aria-label', 'Exit fullscreen');
      if (viewport.requestFullscreen) {
        try { await viewport.requestFullscreen(); measure(); fullscreen.focus({ preventScroll: true }); return; } catch { /* Keep an offline fallback when fullscreen is denied. */ }
      }
      if (!closed) openModal();
    }
    document.addEventListener('fullscreenchange', () => {
      if (expanded && !modal && document.fullscreenElement !== viewport) finish();
      else if (document.fullscreenElement === viewport) measure();
    });
    viewport.addEventListener('keydown', event => {
      if (event.key === 'Escape' && modal) { event.preventDefault(); event.stopPropagation(); finish(); return; }
      if (event.key === 'Tab' && modal) {
        const items = [...viewport.querySelectorAll('button:not(:disabled), [href], input:not(:disabled), select:not(:disabled), [tabindex="0"]')].filter(element => !element.hidden);
        const first = items[0], last = items.at(-1);
        if (event.shiftKey && (document.activeElement === first || document.activeElement === viewport)) { event.preventDefault(); last?.focus(); }
        else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
      }
      if (event.target !== viewport || scale <= 1) return;
      const directions = { ArrowLeft: [40, 0], ArrowRight: [-40, 0], ArrowUp: [0, 40], ArrowDown: [0, -40] };
      if (directions[event.key]) { event.preventDefault(); const [dx, dy] = directions[event.key]; x += dx; y += dy; render(); }
    });
    viewport.addEventListener('pointerdown', event => {
      if (scale <= 1 || !event.isPrimary || event.button !== 0 || event.target.closest('button, a, input, select, textarea, [contenteditable]')) return;
      if (window.getSelection()?.toString()) return;
      suppressClick = false;
      drag = { id: event.pointerId, startX: event.clientX, startY: event.clientY, x, y, moved: false };
      viewport.setPointerCapture(event.pointerId); viewport.focus({ preventScroll: true });
    });
    viewport.addEventListener('pointermove', event => {
      if (!drag || event.pointerId !== drag.id) return;
      const dx = event.clientX - drag.startX, dy = event.clientY - drag.startY;
      if (!drag.moved && Math.hypot(dx, dy) < 5) return;
      drag.moved = true; x = drag.x + dx; y = drag.y + dy; render();
    });
    function release(event) {
      if (!drag || event.pointerId !== drag.id) return;
      const id = drag.id; suppressClick = drag.moved; drag = null;
      if (viewport.hasPointerCapture(id)) viewport.releasePointerCapture(id);
    }
    viewport.addEventListener('click', event => {
      if (suppressClick && !event.target.closest('button')) { event.preventDefault(); event.stopPropagation(); suppressClick = false; }
    }, true);
    viewport.addEventListener('pointerup', release); viewport.addEventListener('pointercancel', release); viewport.addEventListener('lostpointercapture', release);
    image.addEventListener('dragstart', event => event.preventDefault());
    image.addEventListener('load', measure);
    new ResizeObserver(measure).observe(viewport);
    measure();
  }
  window.DiagramViewport = { enhance };
  document.querySelectorAll('[data-diagram-viewer]').forEach(enhance);
})();
