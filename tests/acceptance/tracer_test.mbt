///|
/// The thin path of add-mermaid-sequence: Mermaid text to a model to SVG.
let source = "sequenceDiagram\n  participant Client\n  actor U as User\n  U->>Client: open the forecast\n  Client->>API: GET /forecast\n"

///|
test "the Mermaid source reproduces, prints canonically and converts" {
  let r = @mermaid.read(source)
  assert_eq(r.tree.text(), source)
  assert_eq(r.diagnostics.length(), 0)
  let ast = r.ast.unwrap()
  assert_eq(@mermaid.print(ast), source)
  let s = @mermaid.to_sequence(ast).sequence
  assert_eq(s.participants.map(p => p.id).iter().to_array(), ["Client", "U", "API"])
}

///|
test "the Mermaid source renders as the same SVG on every target" {
  let r = @mermaid.render_svg(source)
  assert_eq(r.diagnostics.length(), 0)
  inspect(r.output.unwrap(), content=(
    #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 468 240" width="468" height="240" role="img" data-diagram="sequence">
    #|  <title>Sequence diagram</title>
    #|  <desc>Sequence diagram with 3 participants (Client, U, API) and 2 messages.</desc>
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
    #|  <rect class="bg" x="0" y="0" width="468" height="240"/>
    #|  <g class="lifelines">
    #|    <path class="lifeline" d="M80 72 V208"/>
    #|    <path class="lifeline" d="M244 72 V208"/>
    #|    <path class="lifeline" d="M388 72 V208"/>
    #|  </g>
    #|  <g class="messages">
    #|    <g class="message f-frontend" data-index="0" data-from="U" data-to="Client">
    #|      <path class="m-line" d="M237 127 H87" marker-end="url(#head-frontend)"/>
    #|      <rect class="mask" x="96" y="100" width="132" height="23" rx="3"/>
    #|      <text class="m-label" x="162" y="115" text-anchor="middle">open the forecast</text>
    #|    </g>
    #|    <g class="message f-frontend" data-index="1" data-from="Client" data-to="API">
    #|      <path class="m-line" d="M87 175 H381" marker-end="url(#head-frontend)"/>
    #|      <rect class="mask" x="182" y="148" width="105" height="23" rx="3"/>
    #|      <text class="m-label" x="234" y="163" text-anchor="middle">GET /forecast</text>
    #|    </g>
    #|  </g>
    #|  <g class="participants">
    #|    <g class="participant f-frontend" data-id="Client">
    #|      <rect class="mask" x="32" y="24" width="96" height="48" rx="6"/>
    #|      <rect class="box" x="32" y="24" width="96" height="48" rx="6"/>
    #|      <text class="p-label" x="80" y="52" text-anchor="middle">Client</text>
    #|    </g>
    #|    <g class="participant f-frontend" data-id="U">
    #|      <rect class="mask" x="196" y="24" width="96" height="48" rx="6"/>
    #|      <rect class="box" x="196" y="24" width="96" height="48" rx="6"/>
    #|      <text class="p-label" x="244" y="52" text-anchor="middle">User</text>
    #|    </g>
    #|    <g class="participant f-backend" data-id="API">
    #|      <rect class="mask" x="340" y="24" width="96" height="48" rx="6"/>
    #|      <rect class="box" x="340" y="24" width="96" height="48" rx="6"/>
    #|      <text class="p-label" x="388" y="52" text-anchor="middle">API</text>
    #|    </g>
    #|  </g>
    #|</svg>
    #|


  ))
}
