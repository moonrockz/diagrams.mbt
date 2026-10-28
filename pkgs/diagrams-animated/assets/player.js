(() => {
  'use strict';
  const root = document.currentScript.closest('[data-diagram-viewer]');
  if (!root || root.dataset.motionReady) return;
  root.dataset.motionReady = 'true';
  const data = JSON.parse(root.querySelector('script[data-motion-data]').textContent);
  const svg = root.querySelector('svg');
  const control = name => root.querySelector(`[data-control="${name}"]`);
  const play = control('play'), restart = control('restart'), step = control('step');
  const speedControl = control('speed'), seek = control('seek'), positionLabel = control('position');
  const status = control('status'), from = control('from'), to = control('to');
  const connectionControl=control('connection'), showConnection=control('show-connection');
  const undirectedKinds = control('undirected');
  const messageKinds = control('messages'), direction = control('direction');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const ns = 'http://www.w3.org/2000/svg';
  const elements = new Map([...svg.querySelectorAll('path[id]')].map(path => [path.id, path]));
  const bindings = new Map(data.paths.map(binding => [binding.key, { element: elements.get(binding.id), length: null }]));
  const nodeElements = new Map();
  const bpmnElements = new Map([...svg.querySelectorAll('.bpmn-shape')].map(element => [element.getAttribute('data-id'), element]));
  const connectionElements = new Map([...svg.querySelectorAll('.swimlane-connection[data-swimlane-id], .architecture-connection[data-id], .flowchart-connection[data-flowchart-id], .state-connection[data-state-id]')].map(element => [element.getAttribute('data-swimlane-id') ?? element.getAttribute('data-id') ?? element.getAttribute('data-flowchart-id') ?? element.getAttribute('data-state-id'),element]));
  const stateElements = new Map([...svg.querySelectorAll('.state-node[data-state-id], .state-group[data-state-id]')].map(element => [element.getAttribute('data-state-id'),element]));
  const flowchartElements = new Map([...svg.querySelectorAll('.flowchart-node[data-flowchart-id], .flowchart-group[data-flowchart-id], .flowchart-lane[data-flowchart-id]')].map(element => [element.getAttribute('data-flowchart-id'),element]));
  const swimlaneElements = new Map([...svg.querySelectorAll('.swimlane-node[data-swimlane-id], .swimlane-group[data-swimlane-id], .swimlane-lane[data-swimlane-id]')].map(element => [element.getAttribute('data-swimlane-id'), element]));
  const architectureElements = new Map([...svg.querySelectorAll('.architecture-service[data-id], .architecture-junction[data-id], .architecture-group[data-id]')].map(element => [element.getAttribute('data-id'),element]));
  const messageElements = new Map([...svg.querySelectorAll('.message[data-index]')].map(element => [Number(element.getAttribute('data-index')), element]));
  const frameElements = [...svg.querySelectorAll('rect.frame')];
  const byData = (selector, name) => new Map([...svg.querySelectorAll(selector)].map(element => [element.getAttribute(name), element]));
  const termElements = byData('.rr-term[data-term]', 'data-term'), rowElements = byData('.data-row[data-member]', 'data-member'), boxElements = byData('.data-box[data-node]', 'data-node');
  const visitKeys = new Set();
  for (const binding of data.node_bindings) {
    const element = binding.kind === 'state' ? stateElements.get(binding.id) : binding.kind === 'flowchart' ? flowchartElements.get(binding.id) : binding.kind === 'architecture' ? architectureElements.get(binding.id) : binding.kind === 'swimlane' ? swimlaneElements.get(binding.id) : binding.kind === 'bpmn' ? bpmnElements.get(binding.id) : binding.kind === 'message' ? messageElements.get(binding.index) : binding.kind === 'term' ? termElements.get(binding.id) : binding.kind === 'row' ? rowElements.get(binding.id) : binding.kind === 'box' ? boxElements.get(binding.id) : frameElements[binding.index];
    if (element) nodeElements.set(binding.endpoint, element);
    if (binding.kind === 'term' || binding.kind === 'row' || binding.kind === 'box' || ((binding.kind === 'flowchart' || binding.kind === 'state') && binding.endpoint !== binding.id)) visitKeys.add(binding.endpoint);
  }
  const structural = data.kind === 'regex' || data.kind === 'ebnf' || data.kind === 'data-tree';
  function decode(plan) {
    return { mode: plan.mode, duration: Number(plan.duration_ms), steps: plan.steps.map(item => ({ ordinal: item.ordinal, key: item.key, start: Number(item.start_ms), duration: Number(item.duration_ms), groups: item.groups, reversed: Boolean(item.reversed), visit: Boolean(item.visit) })) };
  }
  const authored = decode(data.plan);
  let plan = authored, position = 0, speed = 1, playing = false, previous = null, frame = null;
  const overlays = new Map(), highlights = new Set(), visits = new Map();
  function clearVisits() { for (const element of visits.values()) { element.classList.remove('motion-visit'); delete element.dataset.motionProgress; } visits.clear(); }
  function clearHighlights() { for (const element of highlights) element.classList.remove('motion-selected'); highlights.clear(); }
  function highlight(ids) { clearHighlights(); for (const id of ids) { const element = nodeElements.get(id); if (element) { element.classList.add('motion-selected'); highlights.add(element); } } }
  function clearOverlays() { for (const overlay of overlays.values()) overlay.group.remove(); overlays.clear(); clearVisits(); }
  function normalize(time) {
    if (plan.duration === 0) return 0;
    return plan.mode === 'illustrative' ? Math.max(0, time) % plan.duration : Math.max(0, Math.min(time, plan.duration));
  }
  function stopFrame() { if (frame !== null) cancelAnimationFrame(frame); frame = null; previous = null; }
  function state(message) {
    root.dataset.playing = String(playing);
    play.textContent = playing ? 'Pause' : 'Play'; play.setAttribute('aria-pressed', String(playing));
    play.disabled = plan.duration === 0; restart.disabled = plan.duration === 0; step.disabled = plan.duration === 0; seek.disabled = plan.duration === 0;
    status.textContent = message || (playing ? (plan.mode === 'finite' ? 'Playing explicit scenario' : 'Playing illustrative flow') : plan.mode === 'finite' && position >= plan.duration ? 'Finished' : reduced.matches ? 'Paused. Reduced motion: use Step or Position.' : 'Paused');
  }
  function makeOverlay(item) {
    const binding = bindings.get(item.key);
    if (!binding || !binding.element) throw new Error('Missing validated motion binding');
    if (binding.length === null) binding.length = binding.element.getTotalLength();
    const group = document.createElementNS(ns, 'g');
    group.setAttribute('class', 'motion-overlay'); group.setAttribute('aria-hidden', 'true'); group.dataset.ordinal = String(item.ordinal); group.dataset.key = item.key;
    // Apply the final connector's local separation to the entire overlay,
    // including the moving token. Copying only the path mask lets the token
    // repaint an underpass as a joined crossing.
    for (const name of ['mask', 'clip-path']) {
      const value = binding.element.getAttribute(name);
      if (value) group.setAttribute(name, value);
    }
    const path = document.createElementNS(ns, 'path'); path.setAttribute('d', binding.element.getAttribute('d'));
    path.setAttribute('fill', 'none'); path.setAttribute('stroke', data.accent); path.setAttribute('stroke-width', '3'); path.setAttribute('stroke-opacity', '.5'); path.setAttribute('stroke-dasharray', '12 8');
    const dot = document.createElementNS(ns, 'circle'); dot.setAttribute('r', '4'); dot.setAttribute('fill', data.accent);
    group.append(path, dot); binding.element.parentElement.append(group);
    const overlay = { key: item.key, group, path, dot, binding };
    overlays.set(item.ordinal, overlay); return overlay;
  }
  function draw() {
    const logical = Math.floor(normalize(position)); const active = new Set(); const keys = [];
    for (const item of plan.steps) {
      if (logical < item.start || logical >= item.start + item.duration) continue;
      active.add(item.ordinal); keys.push(item.key);
      if (item.visit) {
        const element = nodeElements.get(item.key);
        if (!element) throw new Error('Missing validated visit binding');
        const progress = Math.max(0, Math.min(1, (normalize(position) - item.start) / item.duration));
        element.classList.add('motion-visit'); element.dataset.motionProgress = String(progress); visits.set(item.ordinal, element);
        continue;
      }
      const overlay = overlays.get(item.ordinal) || makeOverlay(item);
      const progress = Math.max(0, Math.min(1, (normalize(position) - item.start) / item.duration));
      const point = overlay.binding.element.getPointAtLength(overlay.binding.length * (item.reversed ? 1 - progress : progress));
      overlay.dot.setAttribute('cx', String(point.x)); overlay.dot.setAttribute('cy', String(point.y));
      overlay.path.setAttribute('stroke-dashoffset', String((item.reversed ? 1 : -1) * overlay.binding.length * progress));
      overlay.group.dataset.progress = String(progress); overlay.group.dataset.reversed = String(Boolean(item.reversed));
    }
    for (const [ordinal, overlay] of overlays) if (!active.has(ordinal)) { overlay.group.remove(); overlays.delete(ordinal); }
    for (const [ordinal, element] of visits) if (!active.has(ordinal)) { element.classList.remove('motion-visit'); delete element.dataset.motionProgress; visits.delete(ordinal); }
    // Still startup keeps the complete static diagram without an overlay.
    if (!playing && position === 0 && !root.dataset.inspected) clearOverlays();
    root.dataset.position = String(logical); root.dataset.active = JSON.stringify(keys); root.dataset.finished = String(plan.mode === 'finite' && logical >= plan.duration);
    seek.max = String(plan.duration); seek.value = String(logical);
    const time = milliseconds => `${Math.floor(milliseconds / 60000)}:${String(Math.floor(milliseconds / 1000) % 60).padStart(2, '0')}.${String(milliseconds % 1000).padStart(3, '0')}`;
    positionLabel.textContent = `${time(logical)} / ${time(plan.duration)}`;
  }
  function advance(now) {
    if (previous !== null) position = normalize(position + Math.max(0, now - previous) * speed);
    previous = now;
    if (plan.mode === 'finite' && position >= plan.duration) { playing = false; stopFrame(); state('Finished'); }
  }
  function tick(now) {
    frame = null;
    if (!playing || document.hidden || reduced.matches) { previous = null; return; }
    advance(now); draw();
    if (playing) frame = requestAnimationFrame(tick);
  }
  function schedule() { stopFrame(); if (playing && !document.hidden && !reduced.matches) frame = requestAnimationFrame(tick); }
  function inspect(time) {
    playing = false; stopFrame(); position = Math.max(0, Math.min(time, plan.duration)); root.dataset.inspected = 'true'; draw(); state();
  }
  function nextStep() {
    const logical = Math.floor(normalize(position));
    let next = plan.duration;
    for (const item of plan.steps) if (item.start > logical && item.start < next) next = item.start;
    if (plan.mode === 'illustrative' && next >= plan.duration) inspect(0); else inspect(next);
  }
  play.addEventListener('click', () => {
    if (reduced.matches) { nextStep(); return; }
    if (!playing && plan.mode === 'finite' && position >= plan.duration) position = 0;
    const requested = !playing;
    if (playing && previous !== null) advance(performance.now());
    playing = requested; root.dataset.inspected = 'true'; state(); draw(); schedule();
  });
  restart.addEventListener('click', () => inspect(0));
  step.addEventListener('click', nextStep);
  speedControl.addEventListener('change', () => {
    if (playing && previous !== null) advance(performance.now());
    const selected = Number(speedControl.value); if ([.25, .5, 1, 1.5, 2, 4].includes(selected)) speed = selected;
    root.dataset.speed = String(speed); previous = null; draw(); schedule();
  });
  seek.addEventListener('input', () => { position = Math.max(0, Math.min(Number(seek.value), plan.duration)); previous = null; root.dataset.inspected = 'true'; draw(); state(); });
  document.addEventListener('visibilitychange', () => { schedule(); });
  reduced.addEventListener('change', () => { if (reduced.matches) playing = false; state(); schedule(); });
  control('download').addEventListener('click', () => {
    const url = URL.createObjectURL(new Blob([data.canonical], { type: 'image/svg+xml;charset=utf-8' }));
    const link = document.createElement('a'); link.href = url; link.download = `${data.view_id.replace(/[^a-z0-9._-]/gi, '_') || 'diagram'}.svg`;
    root.append(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 0);
  });

  const rasterForm = control('raster-form');
  if (rasterForm && typeof window.DiagramsRaster?.export === 'function') {
    rasterForm.hidden = false;
    const formatControl = control('raster-format'), widthControl = control('raster-width');
    const backgroundControl = control('raster-background'), transparentControl = control('raster-transparent');
    const qualityControl = control('raster-quality'), gifOptions = control('gif-options');
    const exportButton = control('raster-export'), cancelButton = control('raster-cancel'), exportStatus = control('raster-status');
    const fonts = JSON.parse(data.raster_fonts || 'null'), animation = JSON.parse(data.raster_animation || 'null');
    let exportJob = null;
    function exportDimensions() {
      const box = svg.viewBox.baseVal;
      const width = Number(widthControl.value) || box.width;
      control('raster-size').textContent = `${Math.ceil(width)} × ${Math.ceil(box.height * width / box.width)} pixels`;
    }
    function exportFormat() {
      const format = formatControl.value;
      exportButton.textContent = `Download ${format === 'gif' ? 'animated GIF' : format.toUpperCase()}`;
      transparentControl.disabled = format !== 'png'; qualityControl.disabled = format !== 'jpeg';
      gifOptions.disabled = format !== 'gif'; gifOptions.hidden = format !== 'gif';
      exportDimensions();
    }
    widthControl.addEventListener('input', exportDimensions);
    formatControl.addEventListener('change', exportFormat); exportFormat();
    cancelButton.addEventListener('click', () => exportJob?.abort());
    rasterForm.addEventListener('submit', async event => {
      event.preventDefault();
      if (exportJob || !rasterForm.reportValidity()) return;
      const job = new AbortController(); exportJob = job;
      const format = formatControl.value;
      const dimensionsText = control('raster-size').textContent;
      const options = { theme: root.dataset.viewerResolvedTheme || 'light',
        background: format === 'png' && transparentControl.checked ? null : backgroundControl.value,
        quality: Number(qualityControl.value), ...(widthControl.value ? { width: Number(widthControl.value) } : {}) };
      if (format === 'gif') {
        options.frameRate = Number(control('gif-rate').value);
        options.loop = control('gif-loop').value === 'repeat' ? Number(control('gif-repeats').value) : control('gif-loop').value;
        const start = control('gif-start').value, end = control('gif-end').value;
        if (start || end) options.interval = { start: start ? Number(start) : 0, end: end ? Number(end) : plan.duration };
      }
      const selectedPlan = animation ? { source_id: animation.source_id, mode: plan.mode, duration_ms: String(plan.duration),
        steps: plan.steps.map(item => ({ ordinal: item.ordinal, key: item.key, start_ms: String(item.start), duration_ms: String(item.duration),
          groups: [...item.groups], reversed: Boolean(item.reversed), visit: Boolean(item.visit) })) } : null;
      exportButton.disabled = true; cancelButton.hidden = false; rasterForm.setAttribute('aria-busy', 'true');
      exportStatus.textContent = `Preparing ${format.toUpperCase()}, ${dimensionsText}…`;
      try {
        if (data.raster_error || !fonts) throw new Error(data.raster_error || 'Raster font data is unavailable. SVG download remains available.');
        if (format === 'gif' && (data.raster_gif_error || !animation)) throw new Error(data.raster_gif_error || 'GIF playback data is unavailable. Still images and SVG remain available.');
        const result = await window.DiagramsRaster.export({ svg: data.canonical, format, options, fonts, animation, plan: selectedPlan, signal: job.signal,
          onProgress: value => { if (exportJob === job && !job.signal.aborted) exportStatus.textContent = typeof value === 'number' ? `Exporting ${format.toUpperCase()}: ${Math.round(value * 100)}%` : `Exporting ${format.toUpperCase()}, ${dimensionsText}…`; } });
        if (job.signal.aborted) throw new DOMException('Export cancelled', 'AbortError');
        const expectedType = format === 'png' ? 'image/png' : format === 'jpeg' ? 'image/jpeg' : 'image/gif';
        if (result.mediaType !== expectedType || !result.bytes.length) throw new Error('The converter returned no complete image.');
        const url = URL.createObjectURL(new Blob([result.bytes], { type: result.mediaType }));
        const link = document.createElement('a'); link.href = url;
        link.download = `${data.view_id.replace(/[^a-z0-9._-]/gi, '_') || 'diagram'}.${format === 'jpeg' ? 'jpg' : format}`;
        root.append(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
        exportStatus.textContent = `Downloaded ${format.toUpperCase()}, ${result.width} × ${result.height} pixels.`;
      } catch (error) { exportStatus.textContent = job.signal.aborted ? 'Export cancelled.' : `Export failed: ${error.message || error}`; }
      finally { exportJob = null; exportButton.disabled = false; cancelButton.hidden = true; rasterForm.removeAttribute('aria-busy'); }
    });
  }

  const outside = new Set(data.outside || []);
  const nodeIndex = new Map(data.graph.nodes.map((node, index) => [node.id, index]));
  const outgoing = new Map(), incoming = new Map();
  function add(table, node, kind, arc) { let kinds = table.get(node); if (!kinds) table.set(node, kinds = new Map()); let arcs = kinds.get(kind); if (!arcs) kinds.set(kind, arcs = []); arcs.push(arc); }
  data.graph.edges.forEach((edge, index) => { const a = nodeIndex.get(edge.source), b = nodeIndex.get(edge.target); add(outgoing, a, edge.kind, [b, index]); add(incoming, b, edge.kind, [a, index]); });
  function* arcs(node, kinds, selectedDirection) {
    const streams = [];
    for (const kind of kinds) {
      if (selectedDirection !== 'reverse') { const items = outgoing.get(node)?.get(kind); if (items) streams.push({ items, next: 0 }); }
      if (selectedDirection !== 'forward') { const items = incoming.get(node)?.get(kind); if (items) streams.push({ items, next: 0 }); }
    }
    let last = -1;
    for (;;) {
      let chosen = null;
      for (const stream of streams) if (stream.next < stream.items.length && (!chosen || stream.items[stream.next][1] < chosen.items[chosen.next][1])) chosen = stream;
      if (!chosen) return;
      const arc = chosen.items[chosen.next++]; if (arc[1] === last) continue; last = arc[1]; yield arc;
    }
  }
  function search(startId, targetId, selectedDirection, reach) {
    const limits = data.query_limits;
    const start = nodeIndex.get(startId), target = targetId === null ? null : nodeIndex.get(targetId);
    if (start === undefined || (!reach && target === undefined)) return { failure: outside.has(startId) || outside.has(targetId) ? 'Outside current view' : 'Invalid endpoint' };
    const kinds = data.kind === 'state' ? ['state'] : ['sequence', 'order', 'swimlane', 'flowchart', 'railroad', 'containment']; if (data.kind === 'architecture') kinds.push('architecture'); if (messageKinds.checked) kinds.push('message'); if (undirectedKinds.checked) kinds.push('undirected');
    const queue = [start], seen = new Set(queue), previous = new Map(); let at = 0, count = 0, work = kinds.length;
    if (!reach && start === target) return { nodes: [start], edges: [] };
    while (at < queue.length) {
      if (++work > limits.work) return { failure: 'Search limit exceeded: work' };
      const current = queue[at++];
      for (const [next, edge] of arcs(current, kinds, selectedDirection)) {
        if (++work > limits.work || ++count > limits.edges) return { failure: 'Search limit exceeded' };
        if (seen.has(next)) continue;
        if (queue.length >= limits.nodes || (reach && queue.length >= limits.results)) return { failure: 'Search limit exceeded: nodes/results' };
        seen.add(next); previous.set(next, [current, edge]); queue.push(next);
        if (!reach && next === target) {
          const nodes = [target], edges = []; let cursor = target;
          while (cursor !== start) { if (nodes.length >= limits.results) return { failure: 'Search limit exceeded: results' }; const [parent, selected] = previous.get(cursor); nodes.push(parent); edges.push(selected); cursor = parent; }
          return { nodes: nodes.reverse(), edges: edges.reverse() };
        }
      }
    }
    return reach ? { nodes: queue, edges: [] } : { failure: 'Unreachable under the selected connection kinds' };
  }
  for (const node of data.graph.nodes) {
    if (node.kind !== 'state' && node.kind !== 'flowchart' && node.kind !== 'bpmn' && node.kind !== 'message' && node.kind !== 'swimlane' && node.kind !== 'architecture' && node.kind !== 'point' && node.kind !== 'data') continue;
    for (const select of [from, to]) { const option = document.createElement('option'); option.value = node.id; option.textContent = node.label || node.id; if (node.description) option.title = node.description; select.append(option); }
  }
  if ((data.kind === 'swimlane' || data.kind === 'architecture' || data.kind === 'flowchart' || data.kind === 'state')) { const first = data.graph.nodes.find(node => node.primary); if (first) from.value = first.id; }
  if (to.options.length > 1) to.selectedIndex = to.options.length - 1;
  messageKinds.closest('label').hidden = data.kind !== 'bpmn';
  undirectedKinds.closest('label').hidden = (data.kind !== 'swimlane' && data.kind !== 'architecture' && data.kind !== 'flowchart' && data.kind !== 'state');
  connectionControl.closest('label').hidden = (data.kind !== 'swimlane' && data.kind !== 'architecture' && data.kind !== 'flowchart' && data.kind !== 'state'); showConnection.hidden = (data.kind !== 'swimlane' && data.kind !== 'architecture' && data.kind !== 'flowchart' && data.kind !== 'state');
  for (const binding of data.paths) {
    if (binding.kind !== 'swimlane' && binding.kind !== 'architecture' && binding.kind !== 'flowchart' && binding.kind !== 'state') continue;
    const option=document.createElement('option'); option.value=binding.key;
    option.textContent=binding.connection+(binding.label ? ': '+binding.label : ''); connectionControl.append(option);
  }
  showConnection.disabled=connectionControl.options.length===0;
  control('route').disabled = from.options.length === 0; control('reach').disabled = from.options.length === 0;
  function replace(next, message) { playing = false; stopFrame(); clearOverlays(); plan = next; position = 0; root.dataset.inspected = 'true'; draw(); state(message); }
  showConnection.addEventListener('click', () => {
    const binding=data.paths.find(binding => binding.key===connectionControl.value);
    if (!binding) return;
    replace({mode:'finite',duration:1000,steps:[{ordinal:0,key:binding.key,start:0,duration:1000,groups:[],reversed:Boolean(binding.reversed)}]},'Selected connection: '+binding.connection);
    clearHighlights(); const element=connectionElements.get(binding.connection);
    if(element) { element.classList.add('motion-selected'); highlights.add(element); }
    root.dataset.connection=binding.connection; root.dataset.route=JSON.stringify([binding.key]);
  });
  control('route').addEventListener('click', () => {
    delete root.dataset.connection;
    const result = search(from.value, to.value, (data.kind === 'swimlane' || data.kind === 'architecture' || data.kind === 'flowchart' || data.kind === 'state') ? direction.value : 'forward', false);
    if (result.failure) { replace({ mode: 'finite', duration: 0, steps: [] }, result.failure); clearHighlights(); root.dataset.route = '[]'; return; }
    if (structural) {
      // Railroad routes follow drawn connectors and term visits. Hierarchy
      // routes visit rows and boxes and follow connectors only where drawn.
      const items = [];
      if (data.kind === 'data-tree' && data.graph.nodes[result.nodes[0]].occurrence) items.push({ key: data.graph.nodes[result.nodes[0]].occurrence, visit: true });
      result.edges.forEach((index, ordinal) => {
        const key = data.graph.edges[index].occurrence;
        if (key) items.push({ key, visit: visitKeys.has(key) });
        const next = data.graph.nodes[result.nodes[ordinal + 1]];
        if (data.kind === 'data-tree' && next && next.occurrence) items.push({ key: next.occurrence, visit: true });
      });
      if (items.length > data.step_limit) { replace({ mode: 'finite', duration: 0, steps: [] }, 'Scenario step limit exceeded'); clearHighlights(); root.dataset.route = '[]'; return; }
      const steps = items.map((item, ordinal) => ({ ordinal, key: item.key, start: ordinal * 1000, duration: 1000, groups: [], reversed: false, visit: item.visit }));
      replace({ mode: 'finite', duration: steps.length * 1000, steps }, data.kind === 'data-tree' ? `Hierarchy route: ${steps.length} steps. Containment only; equal values create no relation.` : `Structural route: ${steps.length} steps. No input is matched or parsed.`);
      highlight(result.nodes.map(index => data.graph.nodes[index].id)); root.dataset.route = JSON.stringify(items.map(item => item.key));
      return;
    }
    if ((data.kind === 'flowchart' || data.kind === 'state') && result.edges.length === 0) {
      const node = data.graph.nodes[result.nodes[0]];
      const steps = node.occurrence ? [{ordinal:0,key:node.occurrence,start:0,duration:1000,groups:[],reversed:false,visit:true}] : [];
      replace({mode:'finite',duration:steps.length*1000,steps},'Structural node visit. No action is executed.');
      highlight([node.id]); root.dataset.route=JSON.stringify(steps.map(item=>item.key)); return;
    }
    const keys = data.kind !== 'sequence' ? result.edges.map(index => data.graph.edges[index].occurrence).filter(Boolean) : result.nodes.map(index => data.graph.nodes[index].occurrence).filter(Boolean);
    if (keys.length > data.step_limit) { replace({ mode: 'finite', duration: 0, steps: [] }, 'Scenario step limit exceeded'); clearHighlights(); root.dataset.route = '[]'; return; }
    const steps = keys.map((key, ordinal) => {
      const edge = data.graph.edges[result.edges[ordinal]];
      const reversed = (data.kind === 'swimlane' || data.kind === 'architecture' || data.kind === 'flowchart' || data.kind === 'state') && (Boolean(edge.reversed) !== (edge.source !== data.graph.nodes[result.nodes[ordinal]].id));
      return { ordinal, key, start: ordinal * 1000, duration: 1000, groups: [], reversed };
    });
    replace({ mode: 'finite', duration: steps.length * 1000, steps }, `Structural route: ${keys.length} connections. Conditions and event triggers are not evaluated.`);
    highlight(result.nodes.map(index => data.graph.nodes[index].id)); root.dataset.route = JSON.stringify(keys);
  });
  control('reach').addEventListener('click', () => {
    const result = search(from.value, null, direction.value, true);
    playing = false; stopFrame(); clearOverlays();
    if (result.failure) { clearHighlights(); state(result.failure); root.dataset.reachable = '[]'; return; }
    const ids = result.nodes.map(index => data.graph.nodes[index].id); highlight(ids); root.dataset.reachable = JSON.stringify(ids);
    const visible = new Set(ids.map(id => nodeElements.get(id)).filter(Boolean));
    state(`Structural reachability: ${visible.size} diagram elements. Conditions and event triggers are not evaluated.`);
  });
  control('clear').addEventListener('click', () => { clearHighlights(); delete root.dataset.route; delete root.dataset.connection; delete root.dataset.reachable; replace(authored, 'Paused'); delete root.dataset.inspected; draw(); });
  root.dataset.speed = '1'; draw(); state();
})();
