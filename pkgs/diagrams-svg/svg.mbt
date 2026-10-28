///|
/// The font stack of archify. The SVG has no font data.
let font_stack = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', 'Liberation Mono', monospace"

///|
/// The CSS custom properties of `p`, one on each line with `indent`.
fn variables(p : @theme.Palette, indent : String) -> String {
  let buf = StringBuilder()
  let put = (name : String, c : @theme.Color) => {
    buf.write_string("\{indent}--\{name}: \{c.to_css()};\n")
  }
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
fn style_sheet(t : @theme.Theme, selector~ : String = "svg") -> String {
  let buf = StringBuilder()
  buf.write_string("\n\{selector} {\n\{variables(t.dark, "  ")}}\n")
  buf.write_string(
    "@media (prefers-color-scheme: light) {\n  \{selector} {\n\{variables(t.light, "    ")}  }\n}\n",
  )
  buf.write_string(
    "\{selector}[data-theme=\"dark\"] {\n\{variables(t.dark, "  ")}}\n",
  )
  buf.write_string(
    "\{selector}[data-theme=\"light\"] {\n\{variables(t.light, "  ")}}\n",
  )
  buf.to_string()
}

///|
/// The palette selected by fixed output.
pub(all) enum Variant {
  Dark
  Light
} derive(Eq, Debug)

///|
/// Adaptive uses CSS variables; fixed writes literal presentation attributes.
pub(all) enum Mode {
  Adaptive
  Fixed(Variant)
} derive(Eq, Debug)

///|
priv struct Paint {
  theme : @theme.Theme
  mode : Mode
}

///|
fn Paint::color(self : Paint, token : String) -> String {
  match self.mode {
    Adaptive => "var(--\{token})"
    Fixed(v) => {
      let p = match v {
        Dark => self.theme.dark
        Light => self.theme.light
      }
      let c = match token {
        "bg" => p.bg
        "mask" => p.mask
        "text" => p.text
        "muted" => p.muted
        "arrow" => p.arrow
        _ => {
          let mut found = p.text
          for f in @theme.all_families {
            let c = p.family(f)
            if token == "\{f.name()}-fill" {
              found = c.fill
            }
            if token == "\{f.name()}-stroke" {
              found = c.stroke
            }
            if token == "\{f.name()}-ink" {
              found = c.ink
            }
          }
          found
        }
      }
      c.to_css()
    }
  }
}

///|
fn Paint::ink(self : Paint, ink : @layout.Ink) -> String {
  match ink {
    Primary => self.color("text")
    Muted => self.color("muted")
    Accent(f) => self.color("\{f.name()}-ink")
    Color(c) => c.to_css()
  }
}

///|
fn rect(
  class : String,
  r : @layout.Rect,
  radius : Int32,
  fill : String,
  stroke? : String,
) -> @writer.Node {
  let attrs = [
    ("class", class),
    ("x", r.x.to_string()),
    ("y", r.y.to_string()),
    ("width", r.width.to_string()),
    ("height", r.height.to_string()),
    ("rx", radius.to_string()),
    ("fill", fill),
  ]
  if stroke is Some(s) {
    attrs.push(("stroke", s))
    attrs.push(("stroke-width", "1.5"))
  }
  @writer.element("rect", attrs~)
}

///|
fn path(
  class : String,
  d : String,
  stroke : String,
  dash? : String,
  width~ : String = "1.4",
) -> @writer.Node {
  let attrs = [
    ("class", class),
    ("d", d),
    ("fill", "none"),
    ("stroke", stroke),
    ("stroke-width", width),
  ]
  if dash is Some(d) {
    attrs.push(("stroke-dasharray", d))
  }
  @writer.element("path", attrs~)
}

///|
fn segment(s : @layout.Segment) -> String {
  "M\{s.x1} \{s.y1} L\{s.x2} \{s.y2}"
}

///|
fn Paint::label(
  self : Paint,
  class : String,
  l : @layout.Label,
) -> @writer.Node {
  let children = l.content
    .split("\n")
    .to_array()
    .mapi((i, line) => {
      @writer.element(
        "tspan",
        attrs=[
          ("x", l.x.to_string()),
          ("y", (l.baseline + i * (l.size + 4)).to_string()),
        ],
        children=[@writer.text(line.to_owned())],
      )
    })
  @writer.element(
    "text",
    attrs=[
      ("class", class),
      ("x", l.x.to_string()),
      ("y", l.baseline.to_string()),
      ("text-anchor", "middle"),
      ("font-family", font_stack),
      ("font-size", l.size.to_string()),
      ("font-weight", l.weight.to_string()),
      ("fill", self.ink(l.ink)),
    ],
    children~,
  )
}

///|
fn metadata(
  attrs : Array[(String, String)],
  link : @sequence.Link?,
  description : String?,
) -> Unit {
  if link is Some(l) {
    let scheme = match l.scheme {
      Smithy => "smithy"
      OpenRpc => "openrpc"
    }
    attrs.push(("data-link", "\{scheme}:\{l.target}"))
  }
  if description is Some(d) {
    attrs.push(("data-description", d))
  }
}

///|
fn head_name(h : @sequence.Head) -> String {
  match h {
    NoHead => "none"
    Arrow => "arrow"
    OpenArrow => "open"
    Cross => "cross"
    Async => "async"
    HalfArrow(upper~, filled~) =>
      "half-\{if upper { "upper" } else { "lower" }}-\{if filled { "filled" } else { "open" }}"
    Central(h) => "central-\{head_name(h)}"
  }
}

///|
/// Markers point along the path; auto-start-reverse turns a sender head back.
fn marker(
  id : String,
  head : @sequence.Head,
  stroke : String,
  reversed : Bool,
) -> @writer.Node {
  let (d, filled) = match head {
    Arrow => ("M-9,-4 L0,0 L-9,4 z", true)
    OpenArrow => ("M-9,-4 L0,0 L-9,4", false)
    Cross => ("M-4,-4 L4,4 M-4,4 L4,-4", false)
    Async => ("M-9,-4 L0,0", false)
    HalfArrow(upper~, filled~) => {
      let upper = if reversed { !upper } else { upper }
      (
        (if upper { "M-9,-4 L0,0" } else { "M-9,4 L0,0" }) +
        (if filled { " L-9,0 z" } else { "" }),
        filled,
      )
    }
    Central(h) => return marker(id, h, stroke, reversed)
    NoHead => ("", false)
  }
  @writer.element(
    "marker",
    attrs=[
      ("id", id),
      ("viewBox", "-10 -5 15 10"),
      ("refX", "0"),
      ("refY", "0"),
      ("markerWidth", "15"),
      ("markerHeight", "10"),
      ("markerUnits", "userSpaceOnUse"),
      ("orient", "auto-start-reverse"),
    ],
    children=[
      @writer.element("path", attrs=[
        ("d", d),
        ("fill", if filled { stroke } else { "none" }),
        ("stroke", stroke),
        ("stroke-width", "1.4"),
      ]),
    ],
  )
}

///|
fn description(s : @sequence.Sequence, m : Int32) -> String {
  let ids = s.participants.map(p => p.id).iter().to_array()
  let n = ids.length()
  let parts = if n == 1 { "1 participant" } else { "\{n} participants" }
  let list = if n > 0 { " (\{ids.join(", ")})" } else { "" }
  let msgs = if m == 1 { "1 message" } else { "\{m} messages" }
  "Sequence diagram with \{parts}\{list} and \{msgs}."
}

///|
fn paint(
  sequence : @sequence.Sequence,
  theme : @theme.Theme,
  mode : Mode,
  id_prefix : String?,
  geometry? : @layout.Geometry,
) -> (String, Array[@diagrams.Diagnostic]) {
  let g = geometry.unwrap_or_else(() => @layout.layout(sequence))
  let p = Paint::{ theme, mode, }
  let diagnostics : Array[@diagrams.Diagnostic] = []
  let defs : Array[@writer.Node] = []
  if mode == Adaptive {
    defs.push(
      @writer.element("style", children=[@writer.text(style_sheet(theme))]),
    )
  }
  let icon_ids : Map[String, Bool] = Map([])
  for participant in sequence.participants {
    if participant.icon is Some(icon) {
      let id = @symbols.asset_id(icon, "")
      if @symbols.known(icon) && !icon_ids.contains(id) {
        defs.push(@symbols.definition_node(icon, ""))
        icon_ids[id] = true
      } else if !@symbols.known(icon) {
        diagnostics.push(
          @diagrams.Diagnostic::warning(
            "svg/unknown-icon",
            "Unknown icon \{icon.pack}:\{icon.key} on participant \{participant.id}",
          ),
        )
      }
    }
  }
  let bg = p.color("bg")
  let mask = p.color("mask")
  let arrow = p.color("arrow")
  let backgrounds : Array[@writer.Node] = []
  let foregrounds : Array[@writer.Node] = []
  // A theme-background mask makes every author tint independent of nesting.
  fn band(class : String, box : @layout.Rect, colour : String?) -> Unit {
    backgrounds.push(rect("band-mask", box, 6, bg))
    let fill = match colour {
      Some(raw) =>
        match @theme.parse_color(raw) {
          Some(c) => c.tint().to_css()
          None => {
            diagnostics.push(
              @diagrams.Diagnostic::warning(
                "svg/invalid-colour",
                "Cannot read colour '\{raw}'; using the theme colour.",
              ),
            )
            p.color("external-fill")
          }
        }
      None => p.color("external-fill")
    }
    backgrounds.push(rect(class, box, 6, fill, stroke=arrow))
  }
  for group in g.groups {
    band("box-group", group.box, group.group.colour)
    foregrounds.push(rect("mask", group.chip, 3, mask))
    foregrounds.push(p.label("group-label", group.label))
  }
  for frame in g.frames {
    band("frame", frame.box, frame.colour)
    if frame.chip is Some(c) {
      foregrounds.push(rect("mask", c, 3, mask))
    }
    if frame.header is Some(l) {
      foregrounds.push(p.label("frame-label", l))
    }
    for section in frame.sections {
      if section.divider is Some(s) {
        foregrounds.push(path("section-divider", segment(s), arrow, dash="4 4"))
      }
      if section.chip is Some(c) {
        foregrounds.push(rect("mask", c, 3, mask))
      }
      if section.label is Some(l) {
        foregrounds.push(p.label("section-label", l))
      }
    }
  }
  let lifelines : Array[@writer.Node] = []
  for participant in g.participants {
    lifelines.push(
      path(
        "lifeline",
        "M\{participant.lifeline_x} \{participant.lifeline_top} V\{participant.lifeline_bottom}",
        arrow,
        dash="3 7",
        width="0.8",
      ),
    )
    if participant.destroyed {
      let x = participant.lifeline_x
      let y = participant.lifeline_bottom
      foregrounds.push(
        path(
          "destruction",
          "M\{x - 6} \{y - 6} L\{x + 6} \{y + 6} M\{x - 6} \{y + 6} L\{x + 6} \{y - 6}",
          p.color("security-stroke"),
        ),
      )
    }
  }
  let bars : Array[@writer.Node] = []
  for a in g.activations {
    let mut family : @theme.Family = Backend
    for part in g.participants {
      if part.id == a.participant {
        family = part.family
      }
    }
    bars.push(rect("activation-mask", a.box, 0, mask))
    bars.push(
      rect(
        "activation",
        a.box,
        0,
        p.color("\{family.name()}-fill"),
        stroke=p.color("\{family.name()}-stroke"),
      ),
    )
  }
  let messages : Array[@writer.Node] = []
  for m in g.messages {
    let family = m.family
    let stroke = if m.message.line == Dotted && family != Security {
      arrow
    } else {
      p.color("\{family.name()}-stroke")
    }
    let attrs = [
      ("class", "message f-\{family.name()}"),
      ("data-index", m.index.to_string()),
      ("data-from", m.sender),
      ("data-to", m.receiver),
      ("data-sender-head", head_name(m.message.sender_head)),
      ("data-receiver-head", head_name(m.message.receiver_head)),
    ]
    metadata(
      attrs,
      m.message.link,
      m.message.properties.bind(props => props.description),
    )
    let d = StringBuilder()
    for i, s in m.path {
      if i == 0 {
        d.write_string("M\{s.x1} \{s.y1}")
      }
      d.write_string(" L\{s.x2} \{s.y2}")
    }
    let line_attrs = [
      ("class", "m-line"),
      ("d", d.to_string()),
      ("fill", "none"),
      ("stroke", stroke),
      ("stroke-width", "1.4"),
    ]
    if m.message.line == Dotted {
      line_attrs.push(("stroke-dasharray", "4 4"))
    }
    for
      (end, head) in [
        ("start", m.message.sender_head),
        ("end", m.message.receiver_head),
      ] {
      if head != NoHead && head != Central(NoHead) {
        let id = "head-\{m.index}-\{end}"
        let edge = if end == "start" {
          m.path[0]
        } else {
          m.path[m.path.length() - 1]
        }
        let reversed = if end == "start" {
          edge.x2 > edge.x1
        } else {
          edge.x2 < edge.x1
        }
        defs.push(marker(id, head, stroke, reversed))
        line_attrs.push(("marker-\{end}", "url(#\{id})"))
      }
    }
    let children = [
      @writer.element("path", attrs=line_attrs),
      rect("mask", m.chip, 3, mask),
      p.label("m-label", m.label),
    ]
    for
      (id, head, y) in [
        (m.sender, m.message.sender_head, m.y),
        (m.receiver, m.message.receiver_head, m.path[m.path.length() - 1].y2),
      ] {
      if head is Central(_) {
        for part in g.participants {
          if part.id == id {
            children.push(
              @writer.element("circle", attrs=[
                ("class", "central-connection"),
                ("cx", part.lifeline_x.to_string()),
                ("cy", y.to_string()),
                ("r", "5"),
                ("fill", mask),
                ("stroke", stroke),
                ("stroke-width", "1.4"),
              ]),
            )
          }
        }
      }
    }
    if m.sublabel is Some(l) {
      children.push(p.label("sublabel", l))
    }
    messages.push(@writer.element("g", attrs~, children~))
  }
  let notes : Array[@writer.Node] = []
  for n in g.notes {
    notes.push(rect("note-mask", n.box, 4, mask))
    notes.push(
      rect(
        "note",
        n.box,
        4,
        p.color("external-fill"),
        stroke=p.color("external-stroke"),
      ),
    )
    notes.push(p.label("note-label", n.label))
  }
  let participants : Array[@writer.Node] = []
  for part in g.participants {
    let attrs = [
      ("class", "participant f-\{part.family.name()}"),
      ("data-id", part.id),
    ]
    metadata(
      attrs,
      part.participant.link,
      part.participant.properties.bind(props => props.description),
    )
    let children = [
      rect("mask", part.box, 6, mask),
      rect(
        "box",
        part.box,
        6,
        p.color("\{part.family.name()}-fill"),
        stroke=p.color("\{part.family.name()}-stroke"),
      ),
      p.label("p-label", part.label),
    ]
    if part.participant.icon is Some(icon) {
      let icon_box = part.icon_box.unwrap()
      let x = icon_box.x
      let y = icon_box.y
      children.push(
        @writer.element("rect", attrs=[
          ("x", x.to_string()),
          ("y", y.to_string()),
          ("width", "32"),
          ("height", "32"),
          ("rx", "4"),
          ("fill", "#ffffff"),
        ]),
      )
      if @symbols.known(icon) {
        children.push(
          @symbols.paint_node(icon, "", x.to_double(), y.to_double(), 32.0),
        )
      } else {
        children.push(
          @writer.element(
            "g",
            attrs=[("role", "img"), ("aria-label", "Unknown icon " + icon.key)],
            children=[
              @writer.element("title", children=[
                @writer.text("Unknown icon " + icon.key),
              ]),
              @writer.element(
                "text",
                attrs=[
                  ("x", (x + 16).to_string()),
                  ("y", (y + 22).to_string()),
                  ("text-anchor", "middle"),
                  ("font-size", "24"),
                  ("fill", "#333333"),
                ],
                children=[@writer.text("?")],
              ),
            ],
          ),
        )
      }
    }
    if part.sublabel is Some(l) {
      children.push(p.label("sublabel", l))
    }
    participants.push(@writer.element("g", attrs~, children~))
  }
  if g.title_box is Some(b) {
    foregrounds.push(rect("mask", b, 3, mask))
  }
  if g.title is Some(l) {
    foregrounds.push(p.label("diagram-title", l))
  }
  let root = @writer.element(
    "svg",
    attrs=[
      ("xmlns", "http://www.w3.org/2000/svg"),
      ("viewBox", "0 0 \{g.width} \{g.height}"),
      ("width", g.width.to_string()),
      ("height", g.height.to_string()),
      ("role", "img"),
      ("data-diagram", "sequence"),
    ],
    children=[
      @writer.element("title", children=[
        @writer.text(
          sequence.accessibility_title.unwrap_or(
            sequence.title.unwrap_or("Sequence diagram"),
          ),
        ),
      ]),
      @writer.element("desc", children=[
        @writer.text(
          sequence.accessibility_description.unwrap_or(
            description(sequence, g.messages.length()),
          ),
        ),
      ]),
      @writer.element("defs", children=defs),
      rect("bg", { x: 0, y: 0, width: g.width, height: g.height, }, 0, bg),
      @writer.element("g", attrs=[("class", "bands")], children=backgrounds),
      @writer.element("g", attrs=[("class", "lifelines")], children=lifelines),
      @writer.element("g", attrs=[("class", "activations")], children=bars),
      @writer.element("g", attrs=[("class", "messages")], children=messages),
      @writer.element("g", attrs=[("class", "notes")], children=notes),
      @writer.element(
        "g",
        attrs=[("class", "participants")],
        children=participants,
      ),
      @writer.element(
        "g",
        attrs=[("class", "annotations")],
        children=foregrounds,
      ),
    ],
  )
  let palettes = match mode {
    Adaptive => [("dark", theme.dark), ("light", theme.light)]
    Fixed(Dark) => [("dark", theme.dark)]
    Fixed(Light) => [("light", theme.light)]
  }
  for (name, palette) in palettes {
    for f in @layout.check(g, palette) {
      diagnostics.push(
        @diagrams.Diagnostic::warning("svg/legibility", "\{name}: \{f.message}"),
      )
    }
  }
  let prefix = match id_prefix {
    Some(value) => {
      let encoded = StringBuilder()
      for c in value {
        encoded.write_string("\{c.to_int().to_string(radix=16)}-")
      }
      "seq-u-\{encoded.to_string()}"
    }
    None => {
      // FNV-1a over UTF-16 units keeps IDs deterministic on every backend.
      // Hash the complete unscoped output, including both palettes and mode.
      let source = @writer.to_string(root)
      let mut hash : UInt64 = 14695981039346656037
      for i in 0..<source.length() {
        hash = (hash ^ source.code_unit_at(i).to_int().to_uint64()) *
          1099511628211
      }
      "seq-\{hash.to_string(radix=16)}-"
    }
  }
  (@writer.to_string(scope_svg(root, prefix, theme)), diagnostics)
}

///|
/// Render one standalone SVG. Adaptive is the default; fixed selects a palette.
pub fn render_sequence(
  sequence : @sequence.Sequence,
  theme~ : @theme.Theme = @theme.Theme::classic(),
  mode~ : Mode = Adaptive,
  id_prefix? : String,
) -> String {
  paint(sequence, theme, mode, id_prefix).0
}

///|
/// A renderer that writes one standalone SVG document.
pub struct SvgRenderer {
  theme : @theme.Theme
  mode : Mode
  id_prefix : String?
  bpmn_policy : @bpmn.GeometryPolicy
  bpmn_limits : @bpmn_layout.Limits
  architecture_limits : @architecture_layout.Limits
  swimlane_limits : @swimlane_layout.Limits
  flowchart_limits : @flowchart_layout.Limits
  railroad_limits : @railroad_layout.Limits
  data_tree_limits : @data_tree_layout.Limits
  /// Supplied trace evidence for regex and EBNF static highlights. It is part
  /// of canonical output; no provider is invoked.
  trace : TraceHighlight?
}

///|
pub fn SvgRenderer::new(
  theme~ : @theme.Theme = @theme.Theme::classic(),
  mode~ : Mode = Adaptive,
  id_prefix? : String,
  bpmn_policy~ : @bpmn.GeometryPolicy = PreferDi,
  bpmn_limits~ : @bpmn_layout.Limits = @bpmn_layout.Limits::new(),
  architecture_limits~ : @architecture_layout.Limits = @architecture_layout.Limits::new(),
  swimlane_limits~ : @swimlane_layout.Limits = @swimlane_layout.Limits::new(),
  flowchart_limits~ : @flowchart_layout.Limits = @flowchart_layout.Limits::new(),
  railroad_limits~ : @railroad_layout.Limits = @railroad_layout.Limits::new(),
  data_tree_limits~ : @data_tree_layout.Limits = @data_tree_layout.Limits::new(),
  trace? : TraceHighlight,
) -> SvgRenderer {
  {
    theme,
    mode,
    id_prefix,
    bpmn_policy,
    bpmn_limits,
    architecture_limits,
    swimlane_limits,
    flowchart_limits,
    railroad_limits,
    data_tree_limits,
    trace,
  }
}

///|
pub impl @render.Renderer for SvgRenderer with fn render(self, diagram) {
  match diagram {
    Sequence(s) => {
      let (svg, diagnostics) = paint(s, self.theme, self.mode, self.id_prefix)
      @render.Rendered::ok(svg, "image/svg+xml", diagnostics~)
    }
    Bpmn(b) =>
      paint_bpmn(
        b,
        self.theme,
        self.mode,
        self.id_prefix,
        self.bpmn_policy,
        self.bpmn_limits,
      )
    Architecture(a) =>
      paint_architecture(
        a,
        self.theme,
        self.mode,
        self.id_prefix,
        self.architecture_limits,
      )
    Swimlane(s) =>
      paint_swimlane(
        s,
        self.theme,
        self.mode,
        self.id_prefix,
        self.swimlane_limits,
      )
    Flowchart(view) => paint_flowchart(view, self.theme, self.mode, self.id_prefix, self.flowchart_limits)
    Regex(_) | Ebnf(_) => paint_railroad(diagram, self).rendered
    DataTree(tree) =>
      if self.trace is Some(_) {
        trace_kind_mismatch()
      } else {
        paint_data_tree(
          tree,
          self.theme,
          self.mode,
          self.id_prefix,
          self.data_tree_limits,
        )
      }
  }
}

///|
fn trace_kind_mismatch() -> @render.Rendered {
  @render.Rendered::failed("image/svg+xml", [
    @diagrams.Diagnostic::error(
      "trace/subject-mismatch", "Trace highlights apply only to regex and EBNF diagrams",
    ),
  ])
}

///|
pub extend SvgRenderer with @render.Renderer::{render}

///|
pub extend Variant with Eq::{not_equal, equal}

///|
pub extend Variant with @debug.Debug::{to_repr}

///|
pub extend Mode with Eq::{not_equal, equal}

///|
pub extend Mode with @debug.Debug::{to_repr}

///|
/// Rewrite only generated identifiers and fragment references, never user text.
/// Scope the stylesheet too, so adjacent SVGs can have different custom themes.
fn scope_svg(
  node : @writer.Node,
  prefix : String,
  theme : @theme.Theme,
) -> @writer.Node {
  match node {
    Text(_) => node
    Element(name, attributes, children) => {
      let attrs = attributes
        .map(pair => {
          let (key, value) = pair
          let value = if key == "id" {
            prefix + value
          } else if [
              "fill", "stroke", "clip-path", "mask", "filter", "marker-start", "marker-mid",
              "marker-end",
            ].contains(key) &&
            value.has_prefix("url(#") &&
            value.has_suffix(")") {
            "url(#\{prefix}\{value.view(start_offset=5, end_offset=value.length() - 1)})"
          } else if (key == "href" || key == "xlink:href") &&
            value.has_prefix("#") {
            "#" + prefix + value[1:].to_owned()
          } else {
            value
          }
          (key, value)
        })
        .iter()
        .to_array()
      if name == "svg" {
        attrs.push(("id", prefix + "diagram"))
      }
      let children = if name == "style" {
        [@writer.text(style_sheet(theme, selector="svg#\{prefix}diagram"))]
      } else {
        children.map(c => scope_svg(c, prefix, theme)).iter().to_array()
      }
      @writer.element(name, attrs~, children~)
    }
  }
}
