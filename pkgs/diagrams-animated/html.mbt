///|
/// Standalone HTML renderer for the first BPMN flow. Starts still; a caller may
/// choose a different connection with an explicit pure plan.
pub struct AnimatedRenderer { plan : @animation.MotionPlan? }

///|
pub fn AnimatedRenderer::new(plan? : @animation.MotionPlan) -> AnimatedRenderer { { plan, } }

///|
pub impl @render.Renderer for AnimatedRenderer with render(self, diagram) {
  guard diagram is Bpmn(view) else { return @render.Rendered::unsupported("text/html", diagram) }
  guard !view.flows.is_empty() else { return @render.Rendered::failed("text/html", [@diagrams.Diagnostic::error("animation/no-flow", "A flow is required for playback")]) }
  let plan = self.plan.unwrap_or_else(() => @animation.MotionPlan::new(view.id, view.flows[0].id).unwrap())
  guard plan.view_id == view.id && view.flows.iter().filter(f => f.id == plan.flow_id).count() == 1 else {
    return @render.Rendered::failed("text/html", [@diagrams.Diagnostic::error("animation/plan-mismatch", "Plan does not name this view and one of its flows")])
  }
  let rendered = @svg.SvgRenderer::new().render(diagram)
  guard rendered.output is Some(svg) else { return @render.Rendered::failed("text/html", rendered.diagnostics) }
  let flow = view.flows.iter().find_first(f => f.id == plan.flow_id).unwrap()
  // Only validated integer geometry and duration enter JavaScript context.
  // Source labels remain escaped SVG text, outside the script element.
  let path = @svg.bpmn_path(flow)
  let runtime = runtime_source()
  let html = "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"><title>BPMN flow illustration</title><style>body{margin:2rem;font:16px system-ui;background:#f4f5f7;color:#0f172a}main{max-width:70rem;margin:auto}svg{width:100%;height:auto}button{font:inherit;padding:.5rem 1rem}button:focus-visible{outline:3px solid #2563eb}.motion-overlay{pointer-events:none}@media print{button,.motion-overlay{display:none}}</style></head><body><main aria-label=\"BPMN flow viewer\"><p>Illustrative flow. Conditions, events and gateway synchronization are not evaluated.</p><button type=\"button\" aria-pressed=\"false\">Play</button><p role=\"status\" aria-live=\"polite\">Paused</p>\n\{svg}<script>\n(() => {\nconst duration = \{plan.duration_ms};\nconst pathData = '\{path}';\n\{runtime}\n})();\n</script></main></body></html>\n"
  @render.Rendered::ok(html, "text/html", diagnostics=rendered.diagnostics)
}

///|
pub extend AnimatedRenderer with @render.Renderer::{render}

///|
/// Embedded verbatim; asset generation and the full viewer arrive in group 12.
fn runtime_source() -> String {
  let source =
  #|const root = document.currentScript.closest('main');
  #|const svg = root.querySelector('svg');
  #|const button = root.querySelector('button');
  #|const status = root.querySelector('[role="status"]');
  #|const ns = 'http://www.w3.org/2000/svg';
  #|const overlay = document.createElementNS(ns, 'g');
  #|overlay.setAttribute('class', 'motion-overlay');
  #|overlay.setAttribute('aria-hidden', 'true');
  #|const path = document.createElementNS(ns, 'path');
  #|path.setAttribute('d', pathData);
  #|path.setAttribute('fill', 'none');
  #|path.setAttribute('stroke', '#2563eb');
  #|path.setAttribute('stroke-width', '4');
  #|path.setAttribute('stroke-dasharray', '12 8');
  #|const dot = document.createElementNS(ns, 'circle');
  #|dot.setAttribute('r', '4');
  #|dot.setAttribute('fill', '#2563eb');
  #|overlay.append(path, dot);
  #|overlay.style.display = 'none';
  #|svg.append(overlay);
  #|const length = path.getTotalLength();
  #|const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  #|let playing = false, elapsed = 0, previous = null, frame = null;
  #|function draw() {
  #|  const progress = (elapsed % duration) / duration;
  #|  const point = path.getPointAtLength(length * progress);
  #|  dot.setAttribute('cx', String(point.x));
  #|  dot.setAttribute('cy', String(point.y));
  #|  path.setAttribute('stroke-dashoffset', String(-length * progress));
  #|}
  #|function stopFrame() {
  #|  if (frame !== null) cancelAnimationFrame(frame);
  #|  frame = null; previous = null;
  #|}
  #|function tick(now) {
  #|  frame = null;
  #|  if (!playing || document.hidden || reduced.matches) return;
  #|  if (previous !== null) elapsed = (elapsed + now - previous) % duration;
  #|  previous = now; draw(); frame = requestAnimationFrame(tick);
  #|}
  #|function update() {
  #|  stopFrame();
  #|  button.textContent = playing ? 'Pause' : 'Play';
  #|  button.setAttribute('aria-pressed', String(playing));
  #|  status.textContent = playing ? 'Playing illustrative flow' : 'Paused';
  #|  overlay.style.display = playing || elapsed > 0 ? '' : 'none';
  #|  draw();
  #|  if (playing && !document.hidden && !reduced.matches) frame = requestAnimationFrame(tick);
  #|}
  #|button.addEventListener('click', () => {
  #|  if (reduced.matches) { elapsed = (elapsed + duration / 4) % duration; playing = false; }
  #|  else playing = !playing;
  #|  update();
  #|});
  #|document.addEventListener('visibilitychange', update);
  #|reduced.addEventListener('change', () => { if (reduced.matches) playing = false; update(); });
  #|update();
  source
}
