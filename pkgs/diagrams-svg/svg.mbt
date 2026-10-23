///|
/// The font stack of archify. The SVG has no font data.
let font_stack = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace"

///|
/// The CSS custom properties of `p`, one on each line with `indent`.
fn variables(p : @theme.Palette, indent : String) -> String {
  let buf = StringBuilder()
  let put = (name : String, c : @theme.Color) => buf.write_string(
    "\{indent}--\{name}: \{c.to_css()};\n",
  )
  put("bg", p.bg)
  put("text", p.text)
  put("muted", p.muted)
  put("mask", p.mask)
  put("arrow", p.arrow)
  for f in @theme.all_families {
    let c = p.family(f)
    put("\{f.name()}-fill", c.fill)
    put("\{f.name()}-stroke", c.stroke)
    put("\{f.name()}-ink", c.ink)
  }
  buf.to_string()
}

///|
/// The style sheet of the adaptive mode. Dark is the default. The viewer's
/// light preference selects light, and a `data-theme` attribute on the root
/// overrides both.
fn style_sheet(t : @theme.Theme) -> String {
  let buf = StringBuilder()
  buf.write_string("\nsvg {\n\{variables(t.dark, "  ")}}\n")
  buf.write_string(
    "@media (prefers-color-scheme: light) {\n  svg {\n\{variables(t.light, "    ")}  }\n}\n",
  )
  buf.write_string("svg[data-theme=\"dark\"] {\n\{variables(t.dark, "  ")}}\n")
  buf.write_string("svg[data-theme=\"light\"] {\n\{variables(t.light, "  ")}}\n")
  buf.write_string("text { font-family: \{font_stack}; }\n")
  buf.write_string(".bg { fill: var(--bg); }\n")
  buf.write_string(".mask { fill: var(--mask); }\n")
  buf.write_string(
    ".lifeline { stroke: var(--arrow); stroke-width: 0.8; stroke-dasharray: 3 7; fill: none; }\n",
  )
  for f in @theme.all_families {
    let n = f.name()
    buf.write_string(
      ".f-\{n} { --fill: var(--\{n}-fill); --stroke: var(--\{n}-stroke); --ink: var(--\{n}-ink); }\n",
    )
  }
  buf.write_string(".box { fill: var(--fill); stroke: var(--stroke); stroke-width: 1.5; }\n")
  buf.write_string(".p-label { fill: var(--text); font-size: 12px; font-weight: 600; }\n")
  buf.write_string(".m-line { stroke: var(--stroke); stroke-width: 1.4; fill: none; }\n")
  buf.write_string(".m-head { fill: var(--stroke); }\n")
  buf.write_string(".m-label { fill: var(--ink); font-size: 11px; }\n")
  buf.to_string()
}

///|
fn num(n : Int) -> String {
  n.to_string()
}

///|
fn rect(
  class : String,
  r : @layout.Rect,
  radius : Int,
) -> @writer.Node {
  @writer.element("rect", attrs=[
    ("class", class),
    ("x", num(r.x)),
    ("y", num(r.y)),
    ("width", num(r.width)),
    ("height", num(r.height)),
    ("rx", num(radius)),
  ])
}

///|
fn label(class : String, l : @layout.Label) -> @writer.Node {
  @writer.element(
    "text",
    attrs=[
      ("class", class),
      ("x", num(l.x)),
      ("y", num(l.baseline)),
      ("text-anchor", "middle"),
    ],
    children=[@writer.text(l.content)],
  )
}

///|
fn description(s : @sequence.Sequence) -> String {
  let ids = s.participants.map(p => p.id).iter().to_array()
  let n = ids.length()
  let m = s.events.length()
  let parts = if n == 1 { "1 participant" } else { "\{n} participants" }
  let list = if n > 0 { " (\{ids.join(", ")})" } else { "" }
  let msgs = if m == 1 { "1 message" } else { "\{m} messages" }
  "Sequence diagram with \{parts}\{list} and \{msgs}."
}

///|
/// The adaptive SVG of `sequence`, and the legibility findings of its layout
/// in the dark and light palettes of `theme`.
fn paint(
  sequence : @sequence.Sequence,
  theme : @theme.Theme,
) -> (String, Array[@diagrams.Diagnostic]) {
  let g = @layout.layout(sequence)
  let used = []
  for m in g.messages {
    if !used.contains(m.family) {
      used.push(m.family)
    }
  }
  let markers = @theme.all_families
    .iter()
    .filter(f => used.contains(f))
    .map(f => @writer.element(
      "marker",
      attrs=[
        ("id", "head-\{f.name()}"),
        ("viewBox", "0 0 10 7"),
        ("refX", "9"),
        ("refY", "3.5"),
        ("markerWidth", "10"),
        ("markerHeight", "7"),
        ("markerUnits", "userSpaceOnUse"),
        ("orient", "auto"),
      ],
      children=[
        @writer.element("path", attrs=[
          ("class", "m-head f-\{f.name()}"),
          ("d", "M0,0 L10,3.5 L0,7 z"),
        ]),
      ],
    ))
    .to_array()
  let defs = [@writer.element("style", children=[@writer.text(style_sheet(theme))])]
  for m in markers {
    defs.push(m)
  }
  let lifelines = g.participants
    .map(p => @writer.element("path", attrs=[
      ("class", "lifeline"),
      ("d", "M\{p.lifeline_x} \{g.lifeline_top} V\{g.lifeline_bottom}"),
    ]))
    .iter()
    .to_array()
  let messages = g.messages
    .map(m => @writer.element(
      "g",
      attrs=[
        ("class", "message f-\{m.family.name()}"),
        ("data-index", num(m.index)),
        ("data-from", m.sender),
        ("data-to", m.receiver),
      ],
      children=[
        @writer.element("path", attrs=[
          ("class", "m-line"),
          ("d", "M\{m.x1} \{m.y} H\{m.x2}"),
          ("marker-end", "url(#head-\{m.family.name()})"),
        ]),
        rect("mask", m.chip, 3),
        label("m-label", m.label),
      ],
    ))
    .iter()
    .to_array()
  let participants = g.participants
    .map(p => @writer.element(
      "g",
      attrs=[("class", "participant f-\{p.family.name()}"), ("data-id", p.id)],
      children=[rect("mask", p.box, 6), rect("box", p.box, 6), label("p-label", p.label)],
    ))
    .iter()
    .to_array()
  let root = @writer.element(
    "svg",
    attrs=[
      ("xmlns", "http://www.w3.org/2000/svg"),
      ("viewBox", "0 0 \{g.width} \{g.height}"),
      ("width", num(g.width)),
      ("height", num(g.height)),
      ("role", "img"),
      ("data-diagram", "sequence"),
    ],
    children=[
      @writer.element("title", children=[
        @writer.text(sequence.title.unwrap_or("Sequence diagram")),
      ]),
      @writer.element("desc", children=[@writer.text(description(sequence))]),
      @writer.element("defs", children=defs),
      @writer.element("rect", attrs=[
        ("class", "bg"),
        ("x", "0"),
        ("y", "0"),
        ("width", num(g.width)),
        ("height", num(g.height)),
      ]),
      @writer.element("g", attrs=[("class", "lifelines")], children=lifelines),
      @writer.element("g", attrs=[("class", "messages")], children=messages),
      @writer.element("g", attrs=[("class", "participants")], children=participants),
    ],
  )
  let diagnostics = []
  for variant in [("dark", theme.dark), ("light", theme.light)] {
    for f in @layout.check(g, variant.1) {
      diagnostics.push(
        @diagrams.Diagnostic::warning("svg/legibility", "\{variant.0}: \{f.message}"),
      )
    }
  }
  (@writer.to_string(root), diagnostics)
}

///|
/// The adaptive SVG of `sequence`.
pub fn render_sequence(
  sequence : @sequence.Sequence,
  theme? : @theme.Theme = @theme.Theme::classic(),
) -> String {
  paint(sequence, theme).0
}

///|
/// A renderer that writes one standalone SVG document. The SVG uses the dark
/// theme by default and the light theme when the viewer prefers light.
pub struct SvgRenderer {
  theme : @theme.Theme
}

///|
/// An SVG renderer with `theme`, which is archify's classic preset by default.
pub fn SvgRenderer::new(theme? : @theme.Theme = @theme.Theme::classic()) -> SvgRenderer {
  { theme, }
}

///|
/// Render `diagram` as SVG. Legibility findings are warnings in the result.
pub impl @render.Renderer for SvgRenderer with render(self, diagram) {
  match diagram {
    Sequence(s) => {
      let (svg, diagnostics) = paint(s, self.theme)
      @render.Rendered::ok(svg, "image/svg+xml", diagnostics~)
    }
  }
}

///|
pub extend SvgRenderer with @render.Renderer::{render}
