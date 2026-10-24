///|
fn simple() -> @sequence.Sequence {
  @sequence.Sequence::new(
    [@sequence.Participant::new("Client"), @sequence.Participant::new("API")],
    [Message(@sequence.Message::new("Client", "API", "GET /forecast"))],
  )
}

///|
fn svg_of(s : @sequence.Sequence) -> String {
  @render.Renderer::render(@svg.SvgRenderer::new(), Sequence(s)).output.unwrap()
}

///|
test "the SVG renderer renders a sequence" {
  let r = @render.Renderer::render(@svg.SvgRenderer::new(), Sequence(simple()))
  assert_eq(r.media_type, "image/svg+xml")
  assert_eq(r.diagnostics.length(), 0)
  let svg = r.output.unwrap()
  assert_true(svg.has_prefix("<svg xmlns=\"http://www.w3.org/2000/svg\""))
  assert_true(svg.has_suffix("</svg>\n"))
}

///|
test "the SVG has no scripts and no external references" {
  let svg = svg_of(simple())
  assert_eq(svg.find("<script"), None)
  assert_eq(svg.find("@import"), None)
  assert_eq(svg.find("href"), None)
  for part in svg.split("url(").drop(1) {
    assert_true(part.has_prefix("#"), msg="url( must point to a local # id")
  }
}

///|
test "the SVG has a title and a description" {
  let svg = svg_of(simple())
  assert_true(svg.contains("<title>Sequence diagram</title>"))
  assert_true(
    svg.contains(
      "<desc>Sequence diagram with 2 participants (Client, API) and 1 message.</desc>",
    ),
  )
  let titled = @sequence.Sequence::new([], [], title="Login flow")
  assert_true(svg_of(titled).contains("<title>Login flow</title>"))
}

///|
test "the adaptive SVG is dark by default and light when the viewer prefers light" {
  let svg = svg_of(simple())
  assert_true(svg.contains("svg {\n  --bg: #020617;"))
  assert_true(svg.contains("@media (prefers-color-scheme: light) {\n  svg {\n    --bg: #f4f5f7;"))
  assert_true(svg.contains("svg[data-theme=\"dark\"] {\n  --bg: #020617;"))
  assert_true(svg.contains("svg[data-theme=\"light\"] {\n  --bg: #f4f5f7;"))
}

///|
test "participant and message groups have data attributes" {
  let svg = svg_of(simple())
  assert_true(svg.contains("data-id=\"Client\""))
  assert_true(svg.contains("data-from=\"Client\" data-to=\"API\""))
}

///|
test "the SVG of a simple sequence" {
  inspect(svg_of(simple()), content=(
    #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 304 192" width="304" height="192" role="img" data-diagram="sequence">
    #|  <title>Sequence diagram</title>
    #|  <desc>Sequence diagram with 2 participants (Client, API) and 1 message.</desc>
    #|  <defs>
    #|    <style>
    #|svg {
    #|  --bg: #020617;
    #|  --text: #ffffff;
    #|  --muted: #94a3b8;
    #|  --mask: #0f172a;
    #|  --arrow: #94a3b8;
    #|  --frontend-fill: rgba(8, 51, 68, 0.4);
    #|  --frontend-stroke: #22d3ee;
    #|  --frontend-ink: #22d3ee;
    #|  --backend-fill: rgba(6, 78, 59, 0.4);
    #|  --backend-stroke: #34d399;
    #|  --backend-ink: #34d399;
    #|  --database-fill: rgba(76, 29, 149, 0.4);
    #|  --database-stroke: #a78bfa;
    #|  --database-ink: #a78bfa;
    #|  --cloud-fill: rgba(120, 53, 15, 0.3);
    #|  --cloud-stroke: #fbbf24;
    #|  --cloud-ink: #fbbf24;
    #|  --security-fill: rgba(136, 19, 55, 0.4);
    #|  --security-stroke: #fb7185;
    #|  --security-ink: #fb7185;
    #|  --messagebus-fill: rgba(251, 146, 60, 0.3);
    #|  --messagebus-stroke: #fb923c;
    #|  --messagebus-ink: #fb923c;
    #|  --external-fill: rgba(30, 41, 59, 0.5);
    #|  --external-stroke: #94a3b8;
    #|  --external-ink: #94a3b8;
    #|}
    #|@media (prefers-color-scheme: light) {
    #|  svg {
    #|    --bg: #f4f5f7;
    #|    --text: #111827;
    #|    --muted: #5b6474;
    #|    --mask: #ffffff;
    #|    --arrow: #64748b;
    #|    --frontend-fill: rgba(34, 211, 238, 0.15);
    #|    --frontend-stroke: #0891b2;
    #|    --frontend-ink: #077995;
    #|    --backend-fill: rgba(52, 211, 153, 0.18);
    #|    --backend-stroke: #059669;
    #|    --backend-ink: #047d58;
    #|    --database-fill: rgba(167, 139, 250, 0.2);
    #|    --database-stroke: #7c3aed;
    #|    --database-ink: #7c3aed;
    #|    --cloud-fill: rgba(251, 191, 36, 0.18);
    #|    --cloud-stroke: #d97706;
    #|    --cloud-ink: #a75c05;
    #|    --security-fill: rgba(251, 113, 133, 0.15);
    #|    --security-stroke: #e11d48;
    #|    --security-ink: #d81c45;
    #|    --messagebus-fill: rgba(251, 146, 60, 0.15);
    #|    --messagebus-stroke: #ea580c;
    #|    --messagebus-ink: #c3490a;
    #|    --external-fill: rgba(148, 163, 184, 0.18);
    #|    --external-stroke: #64748b;
    #|    --external-ink: #606f85;
    #|  }
    #|}
    #|svg[data-theme="dark"] {
    #|  --bg: #020617;
    #|  --text: #ffffff;
    #|  --muted: #94a3b8;
    #|  --mask: #0f172a;
    #|  --arrow: #94a3b8;
    #|  --frontend-fill: rgba(8, 51, 68, 0.4);
    #|  --frontend-stroke: #22d3ee;
    #|  --frontend-ink: #22d3ee;
    #|  --backend-fill: rgba(6, 78, 59, 0.4);
    #|  --backend-stroke: #34d399;
    #|  --backend-ink: #34d399;
    #|  --database-fill: rgba(76, 29, 149, 0.4);
    #|  --database-stroke: #a78bfa;
    #|  --database-ink: #a78bfa;
    #|  --cloud-fill: rgba(120, 53, 15, 0.3);
    #|  --cloud-stroke: #fbbf24;
    #|  --cloud-ink: #fbbf24;
    #|  --security-fill: rgba(136, 19, 55, 0.4);
    #|  --security-stroke: #fb7185;
    #|  --security-ink: #fb7185;
    #|  --messagebus-fill: rgba(251, 146, 60, 0.3);
    #|  --messagebus-stroke: #fb923c;
    #|  --messagebus-ink: #fb923c;
    #|  --external-fill: rgba(30, 41, 59, 0.5);
    #|  --external-stroke: #94a3b8;
    #|  --external-ink: #94a3b8;
    #|}
    #|svg[data-theme="light"] {
    #|  --bg: #f4f5f7;
    #|  --text: #111827;
    #|  --muted: #5b6474;
    #|  --mask: #ffffff;
    #|  --arrow: #64748b;
    #|  --frontend-fill: rgba(34, 211, 238, 0.15);
    #|  --frontend-stroke: #0891b2;
    #|  --frontend-ink: #077995;
    #|  --backend-fill: rgba(52, 211, 153, 0.18);
    #|  --backend-stroke: #059669;
    #|  --backend-ink: #047d58;
    #|  --database-fill: rgba(167, 139, 250, 0.2);
    #|  --database-stroke: #7c3aed;
    #|  --database-ink: #7c3aed;
    #|  --cloud-fill: rgba(251, 191, 36, 0.18);
    #|  --cloud-stroke: #d97706;
    #|  --cloud-ink: #a75c05;
    #|  --security-fill: rgba(251, 113, 133, 0.15);
    #|  --security-stroke: #e11d48;
    #|  --security-ink: #d81c45;
    #|  --messagebus-fill: rgba(251, 146, 60, 0.15);
    #|  --messagebus-stroke: #ea580c;
    #|  --messagebus-ink: #c3490a;
    #|  --external-fill: rgba(148, 163, 184, 0.18);
    #|  --external-stroke: #64748b;
    #|  --external-ink: #606f85;
    #|}
    #|text { font-family: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace; }
    #|.bg { fill: var(--bg); }
    #|.mask { fill: var(--mask); }
    #|.lifeline { stroke: var(--arrow); stroke-width: 0.8; stroke-dasharray: 3 7; fill: none; }
    #|.f-frontend { --fill: var(--frontend-fill); --stroke: var(--frontend-stroke); --ink: var(--frontend-ink); }
    #|.f-backend { --fill: var(--backend-fill); --stroke: var(--backend-stroke); --ink: var(--backend-ink); }
    #|.f-database { --fill: var(--database-fill); --stroke: var(--database-stroke); --ink: var(--database-ink); }
    #|.f-cloud { --fill: var(--cloud-fill); --stroke: var(--cloud-stroke); --ink: var(--cloud-ink); }
    #|.f-security { --fill: var(--security-fill); --stroke: var(--security-stroke); --ink: var(--security-ink); }
    #|.f-messagebus { --fill: var(--messagebus-fill); --stroke: var(--messagebus-stroke); --ink: var(--messagebus-ink); }
    #|.f-external { --fill: var(--external-fill); --stroke: var(--external-stroke); --ink: var(--external-ink); }
    #|.box { fill: var(--fill); stroke: var(--stroke); stroke-width: 1.5; }
    #|.p-label { fill: var(--text); font-size: 12px; font-weight: 600; }
    #|.m-line { stroke: var(--stroke); stroke-width: 1.4; fill: none; }
    #|.m-head { fill: var(--stroke); }
    #|.m-label { fill: var(--ink); font-size: 11px; }
    #|</style>
    #|    <marker id="head-frontend" viewBox="0 0 10 7" refX="9" refY="3.5" markerWidth="10" markerHeight="7" markerUnits="userSpaceOnUse" orient="auto">
    #|      <path class="m-head f-frontend" d="M0,0 L10,3.5 L0,7 z"/>
    #|    </marker>
    #|  </defs>
    #|  <rect class="bg" x="0" y="0" width="304" height="192"/>
    #|  <g class="lifelines">
    #|    <path class="lifeline" d="M80 72 V160"/>
    #|    <path class="lifeline" d="M224 72 V160"/>
    #|  </g>
    #|  <g class="messages">
    #|    <g class="message f-frontend" data-index="0" data-from="Client" data-to="API">
    #|      <path class="m-line" d="M87 124 H217" marker-end="url(#head-frontend)"/>
    #|      <rect class="mask" x="100" y="100" width="105" height="20" rx="3"/>
    #|      <text class="m-label" x="152" y="114" text-anchor="middle">GET /forecast</text>
    #|    </g>
    #|  </g>
    #|  <g class="participants">
    #|    <g class="participant f-frontend" data-id="Client">
    #|      <rect class="mask" x="32" y="24" width="96" height="48" rx="6"/>
    #|      <rect class="box" x="32" y="24" width="96" height="48" rx="6"/>
    #|      <text class="p-label" x="80" y="52" text-anchor="middle">Client</text>
    #|    </g>
    #|    <g class="participant f-backend" data-id="API">
    #|      <rect class="mask" x="176" y="24" width="96" height="48" rx="6"/>
    #|      <rect class="box" x="176" y="24" width="96" height="48" rx="6"/>
    #|      <text class="p-label" x="224" y="52" text-anchor="middle">API</text>
    #|    </g>
    #|  </g>
    #|</svg>
    #|
  ))
}

///|
test "the description counts messages rather than other events" {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [Activate("A"), Frame(@sequence.Frame::new(Loop, @sequence.Section::new([
      Message(@sequence.Message::new("A", "B", "hello")),
    ]))), Deactivate("A")],
  )
  assert_true(svg_of(s).contains("and 1 message.</desc>"))
}
