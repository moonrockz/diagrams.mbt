(() => {
  document.querySelectorAll('article').forEach((card, index) => {
    const preview = card.querySelector(':scope > .pair');
    const source = card.querySelector(':scope > [data-gallery-source]');
    if (!preview || !source) return;
    card.dataset.galleryExample = '';
    const tabs = document.createElement('div');
    tabs.className = 'gallery-tabs';
    tabs.setAttribute('role', 'tablist');
    tabs.setAttribute('aria-label', (card.querySelector('h2, h3')?.textContent || 'Example') + ' inspection');
    const panels = [preview, source];
    const buttons = panels.map((panel, position) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = position ? 'Source' : 'Preview';
      button.id = `local-example-${index}-tab-${position}`;
      panel.id = `local-example-${index}-panel-${position}`;
      button.setAttribute('role', 'tab');
      button.setAttribute('aria-controls', panel.id);
      panel.setAttribute('role', 'tabpanel');
      panel.setAttribute('aria-labelledby', button.id);
      panel.tabIndex = 0;
      tabs.append(button);
      return button;
    });
    const select = (position, focus) => {
      panels.forEach((panel, i) => {
        panel.hidden = i !== position;
        buttons[i].setAttribute('aria-selected', String(i === position));
        buttons[i].tabIndex = i === position ? 0 : -1;
      });
      if (focus) buttons[position].focus();
    };
    buttons.forEach((button, i) => {
      button.addEventListener('click', () => select(i, false));
      button.addEventListener('keydown', event => {
        if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
        event.preventDefault();
        select(event.key === 'Home' ? 0 : event.key === 'End' ? 1 : 1 - i, true);
      });
    });
    source.open = true;
    source.querySelector('summary').hidden = true;
    const download = source.querySelector('a[download]');
    download.addEventListener('click', event => {
      event.preventDefault();
      const url = URL.createObjectURL(new Blob([source.querySelector('code').textContent], { type: 'text/plain;charset=utf-8' }));
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = download.getAttribute('href');
      anchor.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    });
    const copy = document.createElement('button');
    copy.type = 'button';
    copy.textContent = 'Copy source';
    const status = document.createElement('span');
    status.setAttribute('role', 'status');
    copy.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(source.querySelector('code').textContent);
        status.textContent = 'Source copied.';
      } catch {
        status.textContent = 'Copy unavailable. Select the source text or download it.';
      }
    });
    source.querySelector('p').append(' ', copy, ' ', status);
    preview.before(tabs);
    select(0, false);
  });
})();
