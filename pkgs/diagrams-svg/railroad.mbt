///|
priv struct RailPaint {
  paint : Paint
  diagnostics : Array[@diagrams.Diagnostic]
  limit : Int32
  mut used : Int32
  mut failed : Bool
}

///|
fn RailPaint::reserve(self : RailPaint, units : Int32) -> Bool {
  if units < 0 || units > self.limit - self.used {
    if !self.failed {
      self.diagnostics.push(
        @diagrams.Diagnostic::error(
          "railroad/render-limit", "Railroad SVG output limit exceeded",
        ),
      )
    }
    self.failed = true
    return false
  }
  self.used += units
  true
}

///|
fn RailPaint::escaped(
  self : RailPaint,
  value : String,
  attribute : Bool,
) -> Bool {
  let mut i = 0
  while i < value.length() {
    let u = value.code_unit_at(i).to_int()
    i += 1
    if u >= 0xd800 && u <= 0xdbff {
      if i >= value.length() ||
        value.code_unit_at(i).to_int() < 0xdc00 ||
        value.code_unit_at(i).to_int() > 0xdfff {
        self.diagnostics.push(
          @diagrams.Diagnostic::error(
            "railroad/invalid-xml-character", "Railroad text contains an unpaired surrogate",
          ),
        )
        self.failed = true
        return false
      }
      i += 1
      if !self.reserve(2) {
        return false
      }
      continue
    }
    if (u < 32 && u != 9 && u != 10 && u != 13) ||
      (u >= 0xdc00 && u <= 0xdfff) ||
      u == 0xfffe ||
      u == 0xffff {
      self.diagnostics.push(
        @diagrams.Diagnostic::error(
          "railroad/invalid-xml-character", "Railroad text contains a forbidden XML character",
        ),
      )
      self.failed = true
      return false
    }
    let units = if u == 38 {
      5
    } else if u == 60 || u == 62 {
      4
    } else if u == 13 || (attribute && (u == 9 || u == 10)) {
      5
    } else if attribute && u == 34 {
      6
    } else {
      1
    }
    if !self.reserve(units) {
      return false
    }
  }
  true
}

///|
fn RailPaint::element(
  self : RailPaint,
  name : String,
  attrs~ : ArrayView[(String, String)] = [],
  children~ : ArrayView[@writer.Node] = [],
) -> @writer.Node {
  if !self.reserve(name.length() * 2 + 8) {
    return @writer.element("g")
  }
  for pair in attrs {
    if !self.reserve(pair.0.length() + 4) || !self.escaped(pair.1, true) {
      return @writer.element("g")
    }
  }
  @writer.element(name, attrs~, children~)
}

///|
fn RailPaint::text(self : RailPaint, value : String) -> @writer.Node {
  if !self.escaped(value, false) {
    return @writer.text("")
  }
  @writer.text(value)
}

///|
fn rail_number(value : Double) -> String {
  @railroad_layout.svg_number(value)
}

///|
fn RailPaint::label(
  self : RailPaint,
  label : @railroad_layout.Label,
  fill : String,
  class : String,
  anchor~ : String = "middle",
) -> @writer.Node {
  let x = if anchor == "start" { label.box.x } else { label.x }
  let children = []
  for i, line in label.lines {
    children.push(
      self.element(
        "tspan",
        attrs=[
          ("x", rail_number(x)),
          (
            "y",
            rail_number(
              label.box.y +
              label.size +
              i.to_double() * (label.size + 4.0) -
              2.0,
            ),
          ),
        ],
        children=[self.text(line)],
      ),
    )
  }
  self.element(
    "text",
    attrs=[
      ("class", class),
      ("x", rail_number(x)),
      ("y", rail_number(label.box.y + label.size - 2.0)),
      ("text-anchor", anchor),
      ("font-family", font_stack),
      ("font-size", rail_number(label.size)),
      ("font-weight", label.weight.to_string()),
      ("fill", fill),
    ],
    children~,
  )
}

///|
fn shape_name(shape : @railroad_layout.Shape) -> String {
  match shape {
    Pill => "terminal"
    Square => "reference"
    Class => "class"
    Special => "special"
    Anchor => "anchor"
    Lookaround => "lookaround"
    Dot => "empty"
  }
}

///|
fn term_family(shape : @railroad_layout.Shape) -> String {
  match shape {
    Pill => "frontend"
    Square => "database"
    Class => "cloud"
    Special => "messagebus"
    Anchor | Lookaround | Dot => "external"
  }
}

///|
fn term_role(kind : @railroad_trace.TermKind) -> String {
  match kind {
    Consumed => "consumed"
    Reference(_) => "reference"
    Anchor => "anchor"
    Assertion => "assertion"
    Empty => "empty"
  }
}

///|
fn RailPaint::rect(
  self : RailPaint,
  class : String,
  r : @railroad_layout.Rect,
  radius : Double,
  fill : String,
  stroke : String,
  dash? : String,
  width~ : String = "1.5",
) -> @writer.Node {
  let attrs = [
    ("class", class),
    ("x", rail_number(r.x)),
    ("y", rail_number(r.y)),
    ("width", rail_number(r.width)),
    ("height", rail_number(r.height)),
    ("rx", rail_number(radius)),
    ("fill", fill),
    ("stroke", stroke),
    ("stroke-width", width),
  ]
  if dash is Some(d) {
    attrs.push(("stroke-dasharray", d))
  }
  self.element("rect", attrs~)
}

///|
fn RailPaint::term(
  self : RailPaint,
  box : @railroad_layout.TermBox,
) -> @writer.Node {
  let family = term_family(box.shape)
  let fill = self.paint.color(family + "-fill")
  let stroke = self.paint.color(family + "-stroke")
  let ink = self.paint.color("text")
  let t = box.term
  let attrs = [
    ("class", "rr-term rr-" + shape_name(box.shape)),
    ("data-term", t.id),
    ("data-role", term_role(t.kind)),
    ("data-rule", t.rule),
  ]
  if t.constraint {
    attrs.push(("data-constraint", "true"))
  }
  let children = []
  let mut dash : String? = None
  match t.kind {
    Reference(Resolved(rule)) => attrs.push(("data-target", rule))
    Reference(Unresolved) => {
      attrs.push(("data-resolution", "unresolved"))
      dash = Some("4 3")
      children.push(
        self.element("title", children=[self.text("Undefined rule " + t.label)]),
      )
    }
    Reference(Ambiguous(_)) => {
      attrs.push(("data-resolution", "ambiguous"))
      dash = Some("4 3")
      children.push(
        self.element("title", children=[
          self.text("Rule " + t.label + " has more than one definition"),
        ]),
      )
    }
    _ => ()
  }
  let r = box.rect
  match box.shape {
    Dot =>
      children.push(
        self.element("circle", attrs=[
          ("class", "rr-dot"),
          ("cx", rail_number(r.x + r.width / 2.0)),
          ("cy", rail_number(r.y + r.height / 2.0)),
          ("r", "5"),
          ("fill", stroke),
        ]),
      )
    Pill =>
      children.push(self.rect("rr-box", r, r.height / 2.0, fill, stroke, dash?))
    Square => children.push(self.rect("rr-box", r, 2.0, fill, stroke, dash?))
    Class => children.push(self.rect("rr-box", r, 6.0, fill, stroke))
    Special =>
      children.push(self.rect("rr-box", r, 6.0, fill, stroke, dash="2 3"))
    Anchor =>
      children.push(self.rect("rr-box", r, 6.0, fill, stroke, dash="4 3"))
    Lookaround =>
      children.push(self.rect("rr-box", r, 8.0, fill, stroke, dash="6 4"))
  }
  if box.shape != Dot {
    children.push(
      self.label(
        box.label,
        if box.shape == Lookaround {
          self.paint.color("muted")
        } else {
          ink
        },
        "rr-label",
      ),
    )
  }
  for note in box.notes {
    children.push(self.label(note, self.paint.color("muted"), "rr-note-text"))
  }
  self.element("g", attrs~, children~)
}

///|
fn RailPaint::wire(
  self : RailPaint,
  wire : @railroad_layout.Wire,
) -> @writer.Node {
  let c = wire.connector
  let stroke = if c.constraint {
    self.paint.color("muted")
  } else {
    self.paint.color("arrow")
  }
  let attrs = [
    ("class", "rr-connector rr-" + c.role.name()),
    ("data-connector", c.id),
    ("data-role", c.role.name()),
    ("data-owner", c.owner),
    ("d", wire.path()),
    ("fill", "none"),
    ("stroke", stroke),
    ("stroke-width", "1.5"),
  ]
  if c.constraint {
    attrs.push(("data-constraint", "true"))
    attrs.push(("stroke-dasharray", "4 3"))
  }
  if c.role == Return {
    attrs.push(("marker-end", "url(#rr-return)"))
  }
  let path = self.element("path", attrs~)
  match wire.label {
    Some(label) =>
      self.element("g", attrs=[("class", "rr-wire")], children=[
        path,
        self.label(label, self.paint.color("muted"), "rr-bounds"),
      ])
    None => path
  }
}

///|
/// Supplied evidence for one target, by channel.
priv struct Evidence {
  matched : Array[String]
  not_matched : Array[String]
  taken : Array[String]
  failure : Array[(String, @railroad_trace.FailurePoint)]
}

///|
priv struct Overlay {
  trace : @railroad_trace.Trace
  selected : Array[@railroad_trace.Attempt]
  terms : Map[String, Evidence]
  connectors : Map[String, Evidence]
  /// Failures at entry or exit boundaries, by point identity.
  boundaries : Map[String, Evidence]
  order : Array[String]
}

///|
fn evidence() -> Evidence {
  { matched: [], not_matched: [], taken: [], failure: [], }
}

///|
fn add_unique(list : Array[String], value : String) -> Unit {
  if !list.contains(value) {
    list.push(value)
  }
}

///|
/// Validate a highlight request and collect evidence by target. The
/// trace must belong to this model and view; no target is guessed.
fn resolve_overlay(
  highlight : TraceHighlight,
  model : @railroad_layout.Model,
) -> Result[Overlay, ReadOnlyArray[@diagrams.Diagnostic]] {
  let trace = highlight.trace
  let subject : @railroad_trace.Subject = match model {
    Regex(m) => Regex(m)
    Ebnf(g) =>
      match trace.subject.start_rule {
        Some(rule) => Ebnf(g, rule)
        None =>
          return Err([
            @diagrams.Diagnostic::error(
              "trace/subject-mismatch", "The trace does not describe a grammar",
            ),
          ])
      }
  }
  let checked = @railroad_trace.validate_trace(
    trace,
    subject,
    view_id=subject.model_id(),
    limits=highlight.limits,
  )
  guard checked.validated is Some(validated) else {
    return Err(checked.diagnostics)
  }
  let topology = validated.topology
  let selected = match highlight.attempts {
    None => trace.attempts.iter().collect()
    Some(ids) => {
      let out = []
      for id in ids {
        match trace.attempts.iter().find_first(a => a.id == id) {
          Some(a) => out.push(a)
          None =>
            return Err([
              @diagrams.Diagnostic::error(
                "trace/invalid-attempt",
                "The highlight selects missing attempt '\{id}'",
              ),
            ])
        }
      }
      out
    }
  }
  let terms : Map[String, Evidence] = Map([])
  let connectors : Map[String, Evidence] = Map([])
  let boundaries : Map[String, Evidence] = Map([])
  let order = []
  fn slot(map : Map[String, Evidence], id : String) -> Evidence {
    match map.get(id) {
      Some(e) => e
      None => {
        let e = evidence()
        map[id] = e
        order.push(id)
        e
      }
    }
  }
  for attempt in selected {
    for step in attempt.steps {
      let e = match step {
        Visit(id, _) => slot(terms, id)
        Traverse(id, _) => slot(connectors, id)
      }
      match attempt.status {
        Matched => add_unique(e.matched, attempt.id)
        NotMatched => add_unique(e.not_matched, attempt.id)
      }
      add_unique(e.taken, attempt.id)
    }
    if attempt.failure is Some(failure) {
      let e = match failure.target {
        Terminal(id) | Assertion(id) => slot(terms, id)
        Entry(id) => slot(boundaries, topology.entry(id).unwrap_or(id))
        Exit(id) => slot(boundaries, topology.exit(id).unwrap_or(id))
      }
      e.failure.push((attempt.id, failure))
    }
  }
  Ok({ trace, selected, terms, connectors, boundaries, order, })
}

///|
fn RailPaint::channel_color(
  self : RailPaint,
  style : ChannelStyle,
  token : String,
) -> String {
  match style.color {
    Some(c) => c.to_css()
    None => self.paint.color(token)
  }
}

///|
fn status_text(channel : String, attempts : ArrayView[String]) -> String {
  "\{channel} in attempt\{if attempts.length() == 1 { "" } else { "s" }} \{attempts.join(", ")}. Supplied by an external trace provider."
}

///|
/// Draw supplied evidence in four independent layers: matched, not matched,
/// taken path or prefix, then failure points on top. Each layer has a
/// different stroke width, so shared targets keep every classification.
fn RailPaint::overlay(
  self : RailPaint,
  highlight : TraceHighlight,
  overlay : Overlay,
  geometry : @railroad_layout.Geometry,
) -> @writer.Node {
  let wires : Map[String, @railroad_layout.Wire] = Map([])
  for w in geometry.wires {
    wires[w.connector.id] = w
  }
  let boxes : Map[String, @railroad_layout.TermBox] = Map([])
  for b in geometry.terms {
    boxes[b.term.id] = b
  }
  let layers = []
  let channels : Array[
    (String, String, ChannelStyle, Double, (Evidence) -> Array[String]),
  ] = [
    ("matched", "backend-ink", highlight.matched, 4.0, e => e.matched),
    (
      "not-matched",
      "messagebus-ink",
      highlight.not_matched,
      2.0,
      e => e.not_matched,
    ),
    ("taken", "database-ink", highlight.taken, 0.0, e => e.taken),
  ]
  for channel in channels {
    let (name, token, style, extra, pick) = channel
    if !style.visible {
      continue
    }
    let color = self.channel_color(style, token)
    let items = []
    for id in overlay.order {
      if overlay.connectors.get(id) is Some(e) &&
        !pick(e).is_empty() &&
        wires.get(id) is Some(wire) {
        let attrs = [
          ("class", "rr-trace-path rr-trace-" + name),
          ("data-channel", name),
          ("data-target", id),
          ("data-attempts", pick(e).join(" ")),
          ("d", wire.path()),
          ("fill", "none"),
          ("stroke", color),
          ("stroke-width", rail_number(style.width + extra)),
          ("stroke-linecap", "round"),
          ("stroke-opacity", "0.85"),
          ("pointer-events", "none"),
        ]
        if style.dashed {
          attrs.push(("stroke-dasharray", "6 4"))
        }
        items.push(
          self.element("path", attrs~, children=[
            self.element("title", children=[
              self.text(
                status_text(
                  match name {
                    "matched" => "Matched"
                    "not-matched" => "Not matched"
                    _ => "Taken"
                  },
                  pick(e),
                ),
              ),
            ]),
          ]),
        )
      }
      if overlay.terms.get(id) is Some(e) &&
        !pick(e).is_empty() &&
        boxes.get(id) is Some(box) {
        let grow = 2.0 + extra
        let r = box.rect
        let attrs = [
          ("class", "rr-trace-term rr-trace-" + name),
          ("data-channel", name),
          ("data-target", id),
          ("data-attempts", pick(e).join(" ")),
          ("x", rail_number(r.x - grow)),
          ("y", rail_number(r.y - grow)),
          ("width", rail_number(r.width + 2.0 * grow)),
          ("height", rail_number(r.height + 2.0 * grow)),
          ("rx", rail_number(r.height / 2.0 + grow)),
          ("fill", "none"),
          ("stroke", color),
          ("stroke-width", rail_number(style.width)),
          ("stroke-opacity", "0.9"),
          ("pointer-events", "none"),
        ]
        if style.dashed {
          attrs.push(("stroke-dasharray", "6 4"))
        }
        items.push(
          self.element("rect", attrs~, children=[
            self.element("title", children=[
              self.text(
                status_text(
                  match name {
                    "matched" => "Matched"
                    "not-matched" => "Not matched"
                    _ => "Taken"
                  },
                  pick(e),
                ),
              ),
            ]),
          ]),
        )
      }
    }
    if !items.is_empty() {
      layers.push(
        self.element(
          "g",
          attrs=[("class", "rr-trace-layer"), ("data-channel", name)],
          children=items,
        ),
      )
    }
  }
  if highlight.failure.visible {
    let color = self.channel_color(highlight.failure, "security-ink")
    let items = []
    fn failure_title(e : Evidence) -> String {
      let parts = []
      for pair in e.failure {
        let (attempt, f) = pair
        let target = match f.target {
          Terminal(_) => "terminal"
          Assertion(_) => "assertion"
          Entry(_) => "entry boundary"
          Exit(_) => "exit boundary"
        }
        let position = f.position
          .map(p => " at input position \{p}")
          .unwrap_or("")
        let message = f.message.map(m => ": " + m).unwrap_or("")
        parts.push(
          "Failure in attempt \{attempt} at the \{target}\{position}\{message}",
        )
      }
      parts.join(". ") + ". Supplied by an external trace provider."
    }
    for id in overlay.order {
      match (overlay.terms.get(id), boxes.get(id)) {
        (Some(e), Some(box)) if !e.failure.is_empty() => {
          let r = box.rect
          let cx = r.x + r.width
          let cy = r.y
          items.push(
            self.element(
              "g",
              attrs=[
                ("class", "rr-trace-failure"),
                ("data-channel", "failure"),
                ("data-target", id),
                ("data-attempts", e.failure.map(p => p.0).join(" ")),
                ("pointer-events", "none"),
              ],
              children=[
                self.element("title", children=[self.text(failure_title(e))]),
                self.element("rect", attrs=[
                  ("x", rail_number(r.x - 2.0)),
                  ("y", rail_number(r.y - 2.0)),
                  ("width", rail_number(r.width + 4.0)),
                  ("height", rail_number(r.height + 4.0)),
                  ("rx", rail_number(r.height / 2.0 + 2.0)),
                  ("fill", "none"),
                  ("stroke", color),
                  ("stroke-width", rail_number(highlight.failure.width)),
                ]),
                self.element("circle", attrs=[
                  ("cx", rail_number(cx)),
                  ("cy", rail_number(cy)),
                  ("r", "7"),
                  ("fill", self.paint.color("bg")),
                  ("stroke", color),
                  ("stroke-width", "2"),
                ]),
                self.element("path", attrs=[
                  (
                    "d",
                    "M\{rail_number(cx - 3.0)} \{rail_number(cy - 3.0)} L\{rail_number(cx + 3.0)} \{rail_number(cy + 3.0)} M\{rail_number(cx + 3.0)} \{rail_number(cy - 3.0)} L\{rail_number(cx - 3.0)} \{rail_number(cy + 3.0)}",
                  ),
                  ("stroke", color),
                  ("stroke-width", "2"),
                ]),
              ],
            ),
          )
        }
        _ => ()
      }
      match (overlay.boundaries.get(id), geometry.point(id)) {
        (Some(e), Some(p)) if !e.failure.is_empty() =>
          items.push(
            self.element(
              "g",
              attrs=[
                ("class", "rr-trace-failure rr-trace-boundary"),
                ("data-channel", "failure"),
                ("data-target", id),
                ("data-attempts", e.failure.map(pair => pair.0).join(" ")),
                ("pointer-events", "none"),
              ],
              children=[
                self.element("title", children=[self.text(failure_title(e))]),
                self.element("circle", attrs=[
                  ("cx", rail_number(p.x)),
                  ("cy", rail_number(p.y)),
                  ("r", "8"),
                  ("fill", self.paint.color("bg")),
                  ("stroke", color),
                  ("stroke-width", "2.5"),
                ]),
                self.element("path", attrs=[
                  (
                    "d",
                    "M\{rail_number(p.x - 4.0)} \{rail_number(p.y - 4.0)} L\{rail_number(p.x + 4.0)} \{rail_number(p.y + 4.0)} M\{rail_number(p.x + 4.0)} \{rail_number(p.y - 4.0)} L\{rail_number(p.x - 4.0)} \{rail_number(p.y + 4.0)}",
                  ),
                  ("stroke", color),
                  ("stroke-width", "2"),
                ]),
              ],
            ),
          )
        _ => ()
      }
    }
    if !items.is_empty() {
      layers.push(
        self.element(
          "g",
          attrs=[("class", "rr-trace-layer"), ("data-channel", "failure")],
          children=items,
        ),
      )
    }
  }
  let matched = overlay.selected.iter().filter(a => a.status == Matched).count()
  self.element(
    "g",
    attrs=[
      ("class", "rr-trace"),
      ("data-provider", overlay.trace.provider),
      ("data-attempts", overlay.selected.map(a => a.id).join(" ")),
      ("data-matched", matched.to_string()),
      ("data-not-matched", (overlay.selected.length() - matched).to_string()),
    ],
    children=layers,
  )
}

///|
priv struct RailroadPaint {
  rendered : @render.Rendered
  geometry : @railroad_layout.Geometry?
}

///|
fn railroad_model(diagram : @render.Diagram) -> @railroad_layout.Model? {
  match diagram {
    Regex(m) => Some(Regex(m))
    Ebnf(g) => Some(Ebnf(g))
    _ => None
  }
}

///|
fn paint_railroad(
  diagram : @render.Diagram,
  renderer : SvgRenderer,
) -> RailroadPaint {
  fn failed(diagnostics : ArrayView[@diagrams.Diagnostic]) -> RailroadPaint {
    {
      rendered: @render.Rendered::failed("image/svg+xml", diagnostics),
      geometry: None,
    }
  }
  guard railroad_model(diagram) is Some(model) else {
    return failed([
      @diagrams.Diagnostic::error(
        "railroad/unsupported-diagram", "Not a regex or EBNF diagram",
      ),
    ])
  }
  let limits = renderer.railroad_limits
  let result = @railroad_layout.layout(model, limits~)
  let diagnostics = result.diagnostics.iter().collect()
  guard result.geometry is Some(geometry) else { return failed(diagnostics) }
  let overlay = match renderer.trace {
    None => None
    Some(h) =>
      match resolve_overlay(h, model) {
        Ok(o) => Some((h, o))
        Err(errors) => return failed(errors)
      }
  }
  let theme = renderer.theme
  let mode = renderer.mode
  let c = RailPaint::{
    paint: Paint::{ theme, mode, },
    diagnostics,
    limit: limits.output_units,
    used: 0,
    failed: false,
  }
  let defs = []
  if mode == Adaptive {
    defs.push(c.element("style", children=[c.text(style_sheet(theme))]))
  }
  let arrow = c.paint.color("arrow")
  defs.push(
    c.element(
      "marker",
      attrs=[
        ("id", "rr-return"),
        ("viewBox", "-10 -6 16 12"),
        ("refX", "0"),
        ("refY", "0"),
        ("markerWidth", "12"),
        ("markerHeight", "10"),
        ("markerUnits", "userSpaceOnUse"),
        ("orient", "auto-start-reverse"),
      ],
      children=[
        c.element("path", attrs=[
          ("d", "M-8 -4 L0 0 L-8 4 Z"),
          ("fill", arrow),
          ("stroke", "none"),
        ]),
      ],
    ),
  )
  let kind = if model is Regex(_) { "regex" } else { "ebnf" }
  let parts = []
  if geometry.title is Some(label) {
    parts.push(
      c.element("g", attrs=[("class", "rr-title")], children=[
        c.label(label, c.paint.color("text"), "rr-title-text"),
      ]),
    )
  }
  let notes = []
  for note in geometry.notes {
    notes.push(
      c.element("g", attrs=[("class", "rr-note"), ("data-note", note.id)], children=[
        c.rect(
          "rr-note-box",
          note.rect,
          4.0,
          c.paint.color("external-fill"),
          c.paint.color("external-stroke"),
        ),
        c.label(note.label, c.paint.color("text"), "rr-note-text"),
      ]),
    )
  }
  let tracks = []
  for track in geometry.tracks {
    let children = [
      c.label(
        track.label,
        c.paint.color("text"),
        "rr-rule-name",
        anchor="start",
      ),
    ]
    for note in track.notes {
      children.push(
        c.label(note, c.paint.color("muted"), "rr-note-text", anchor="start"),
      )
    }
    children.push(
      c.element("circle", attrs=[
        ("class", "rr-start"),
        ("cx", rail_number(track.start.x - 5.0)),
        ("cy", rail_number(track.start.y)),
        ("r", "5"),
        ("fill", arrow),
      ]),
    )
    children.push(
      c.element("circle", attrs=[
        ("class", "rr-end"),
        ("cx", rail_number(track.end.x + 6.0)),
        ("cy", rail_number(track.end.y)),
        ("r", "6"),
        ("fill", "none"),
        ("stroke", arrow),
        ("stroke-width", "1.5"),
      ]),
    )
    children.push(
      c.element("circle", attrs=[
        ("cx", rail_number(track.end.x + 6.0)),
        ("cy", rail_number(track.end.y)),
        ("r", "3"),
        ("fill", arrow),
      ]),
    )
    tracks.push(
      c.element(
        "g",
        attrs=[("class", "rr-track"), ("data-rule", track.track.id)],
        children~,
      ),
    )
  }
  let frames = []
  for frame in geometry.frames {
    let role = if frame.role == Except { "except" } else { "group" }
    frames.push(
      c.element(
        "g",
        attrs=[("class", "rr-frame rr-" + role), ("data-owner", frame.owner)],
        children=[
          c.rect(
            "rr-frame-box",
            frame.rect,
            8.0,
            "none",
            c.paint.color(
              if frame.role == Except {
                "security-stroke"
              } else {
                "muted"
              },
            ),
            dash="5 4",
            width="1.2",
          ),
          c.label(
            frame.label,
            c.paint.color(
              if frame.role == Except {
                "security-ink"
              } else {
                "muted"
              },
            ),
            "rr-frame-label",
          ),
        ],
      ),
    )
  }
  let wires = []
  for wire in geometry.wires {
    if c.failed {
      break
    }
    wires.push(c.wire(wire))
  }
  let terms = []
  for term in geometry.terms {
    if c.failed {
      break
    }
    terms.push(c.term(term))
  }
  let title = match model {
    Regex(m) =>
      m.accessibility_title
      .map(t => Some(t))
      .unwrap_or(m.title)
      .unwrap_or("Regular expression")
    Ebnf(g) =>
      g.accessibility_title
      .map(t => Some(t))
      .unwrap_or(g.title)
      .unwrap_or("EBNF grammar")
  }
  let mut description = match model {
    Regex(m) =>
      m.accessibility_description.unwrap_or(
        "Railroad diagram of the regular expression \{m.pattern.unwrap_or("")} with \{geometry.terms.length()} terms. It shows structure; it does not match input.",
      )
    Ebnf(g) =>
      g.accessibility_description.unwrap_or(
        "Railroad diagram of a grammar with \{geometry.tracks.length()} rules and \{geometry.terms.length()} terms. References are not expanded. It shows structure; it does not parse input.",
      )
  }
  let content = [
    c.element("g", attrs=[("class", "rr-notes")], children=notes),
    c.element("g", attrs=[("class", "rr-frames")], children=frames),
    c.element("g", attrs=[("class", "rr-connectors")], children=wires),
    c.element("g", attrs=[("class", "rr-terms")], children=terms),
    c.element("g", attrs=[("class", "rr-tracks")], children=tracks),
  ]
  if overlay is Some((h, o)) {
    let matched = o.selected.iter().filter(a => a.status == Matched).count()
    description = description +
      " Supplied trace from provider \{o.trace.provider} for input \"\{o.trace.input}\": \{o.selected.length()} attempts, \{matched} matched and \{o.selected.length() - matched} not matched. The library shows this external evidence and does not compute it."
    content.push(c.overlay(h, o, geometry))
  }
  let root = c.element(
    "svg",
    attrs=[
      ("xmlns", "http://www.w3.org/2000/svg"),
      (
        "viewBox",
        "0 0 \{rail_number(geometry.width)} \{rail_number(geometry.height)}",
      ),
      ("width", rail_number(geometry.width)),
      ("height", rail_number(geometry.height)),
      ("role", "img"),
      ("data-diagram", kind),
    ],
    children=[
      c.element("title", children=[c.text(title)]),
      c.element("desc", children=[c.text(description)]),
      c.element("defs", children=defs),
      c.element("rect", attrs=[
        ("class", "bg"),
        ("x", "0"),
        ("y", "0"),
        ("width", rail_number(geometry.width)),
        ("height", rail_number(geometry.height)),
        ("fill", c.paint.color("bg")),
      ]),
      ..parts,
      ..content,
    ],
  )
  if c.failed {
    return failed(c.diagnostics)
  }
  let original = @writer.to_string(root)
  if original.length() > limits.output_units / 2 {
    return failed([
      @diagrams.Diagnostic::error(
        "railroad/render-limit", "Railroad SVG output limit exceeded",
      ),
    ])
  }
  let prefix = match renderer.id_prefix {
    Some(raw) => {
      let out = StringBuilder()
      out.write_string("rr-u-")
      for ch in raw {
        out.write_string(ch.to_int().to_string(radix=16) + "-")
      }
      out.to_string()
    }
    None => {
      let mut hash : UInt64 = 14695981039346656037
      for i in 0..<original.length() {
        hash = (hash ^ original.code_unit_at(i).to_int().to_uint64()) *
          1099511628211
      }
      "rr-\{hash.to_string(radix=16)}-"
    }
  }
  let output = @writer.to_string(scope_svg(root, prefix, theme))
  if output.length() > limits.output_units {
    return failed([
      @diagrams.Diagnostic::error(
        "railroad/render-limit", "Scoped railroad SVG exceeds its output limit",
      ),
    ])
  }
  let palettes = match mode {
    Adaptive => [("dark", theme.dark), ("light", theme.light)]
    Fixed(Dark) => [("dark", theme.dark)]
    Fixed(Light) => [("light", theme.light)]
  }
  let custom = []
  if renderer.trace is Some(h) {
    for style in [h.matched, h.not_matched, h.taken, h.failure] {
      if style.visible && style.color is Some(color) {
        custom.push(color)
      }
    }
  }
  for pair in palettes {
    let (name, palette) = pair
    for
      finding in @railroad_layout.check(
        geometry,
        palette,
        work_limit=limits.work,
        highlight_colors=custom,
      ) {
      if finding.rule == Limit {
        return failed([
          @diagrams.Diagnostic::error("railroad/layout-limit", finding.message),
        ])
      }
      c.diagnostics.push(
        @diagrams.Diagnostic::warning(
          "railroad/legibility",
          name + ": " + finding.message,
        ),
      )
    }
  }
  {
    rendered: @render.Rendered::ok(
      output,
      "image/svg+xml",
      diagnostics=c.diagnostics,
    ),
    geometry: Some(geometry),
  }
}

///|
/// Scene parts of a railroad: the canonical render, one drawn path per
/// connector occurrence and one node binding per term visit.
fn railroad_scene(
  renderer : SvgRenderer,
  diagram : @render.Diagram,
  catalog : @animation.Catalog,
  output_units : Int32,
) -> Result[
  (@render.Rendered, Array[(@animation.Occurrence, String)], Array[NodeBinding]),
  ReadOnlyArray[@diagrams.Diagnostic],
] {
  let painted = paint_railroad(diagram, renderer)
  guard painted.geometry is Some(geometry) && painted.rendered.output is Some(_) else {
    return Err(painted.rendered.diagnostics)
  }
  let wires : Map[String, @railroad_layout.Wire] = Map([])
  for w in geometry.wires {
    wires[w.connector.id] = w
  }
  let paths = []
  let nodes = []
  for occurrence in catalog.occurrences {
    match (occurrence.railroad_connector, occurrence.railroad_term) {
      (Some(connector), _) => {
        guard wires.get(connector.id) is Some(wire) else {
          return Err([
            @diagrams.Diagnostic::error(
              "animation/binding-mismatch", "A railroad connector has no drawn path",
            ),
          ])
        }
        let d = wire.path()
        if d.length() > output_units {
          return Err([
            @diagrams.Diagnostic::error(
              "animation/scene-limit", "Railroad scene path exceeds its output limit",
            ),
          ])
        }
        paths.push((occurrence, d))
      }
      (None, Some(term)) =>
        nodes.push({ endpoint: occurrence.key, kind: RailroadTerm(term.id), })
      _ =>
        return Err([
          @diagrams.Diagnostic::error(
            "animation/binding-mismatch", "A railroad occurrence has no target",
          ),
        ])
    }
  }
  Ok((painted.rendered, paths, nodes))
}

///|
/// Render a regex railroad with the same options as `SvgRenderer`. A
/// supplied trace adds static highlights; no provider is invoked.
pub fn render_regex(
  model : @regex.Regex,
  theme~ : @theme.Theme = @theme.Theme::classic(),
  mode~ : Mode = Adaptive,
  id_prefix? : String,
  limits~ : @railroad_layout.Limits = @railroad_layout.Limits::new(),
  trace? : TraceHighlight,
) -> @render.Rendered {
  let renderer = SvgRenderer::new(
    theme~,
    mode~,
    id_prefix?,
    railroad_limits=limits,
    trace?,
  )
  paint_railroad(Regex(model), renderer).rendered
}

///|
/// Render a grammar railroad with the same options as `SvgRenderer`.
pub fn render_ebnf(
  grammar : @ebnf.Grammar,
  theme~ : @theme.Theme = @theme.Theme::classic(),
  mode~ : Mode = Adaptive,
  id_prefix? : String,
  limits~ : @railroad_layout.Limits = @railroad_layout.Limits::new(),
  trace? : TraceHighlight,
) -> @render.Rendered {
  let renderer = SvgRenderer::new(
    theme~,
    mode~,
    id_prefix?,
    railroad_limits=limits,
    trace?,
  )
  paint_railroad(Ebnf(grammar), renderer).rendered
}

///|
/// The result of the explicit provider-and-render driver.
pub struct TracedRender {
  run : @railroad_trace.TraceRun
  rendered : @render.Rendered
}

///|
/// Invoke `provider` once for `input` and render its validated trace with
/// the given channels. This is the only renderer entry point that calls a
/// provider. Unsupported, exhausted and error outcomes give diagnostics and
/// no SVG; a completed non-match renders its evidence.
pub fn[P : @railroad_trace.RailroadTraceProvider] SvgRenderer::render_traced(
  self : SvgRenderer,
  diagram : @render.Diagram,
  provider : P,
  input : String,
  start_rule? : String,
  limits~ : @railroad_trace.TraceLimits = @railroad_trace.TraceLimits::new(),
  attempts? : ArrayView[String],
  matched~ : ChannelStyle = ChannelStyle::new(),
  not_matched~ : ChannelStyle = ChannelStyle::new(dashed=true),
  taken~ : ChannelStyle = ChannelStyle::hidden(),
  failure~ : ChannelStyle = ChannelStyle::new(),
) -> TracedRender {
  fn refused(diagnostics : ArrayView[@diagrams.Diagnostic]) -> TracedRender {
    {
      run: @railroad_trace.TraceRun::refused(diagnostics),
      rendered: @render.Rendered::failed("image/svg+xml", diagnostics),
    }
  }
  let request = match diagram {
    Regex(m) => @railroad_trace.TraceRequest::regex(m, input, limits~)
    Ebnf(g) =>
      match start_rule {
        Some(rule) =>
          @railroad_trace.TraceRequest::ebnf(g, rule, input, limits~)
        None =>
          return refused([
            @diagrams.Diagnostic::error(
              "trace/invalid-request", "A grammar trace needs a start rule identity",
            ),
          ])
      }
    _ =>
      return refused([
        @diagrams.Diagnostic::error(
          "trace/subject-mismatch", "Traces apply only to regex and EBNF diagrams",
        ),
      ])
  }
  let run = @railroad_trace.run(provider, request)
  guard run.validated is Some(validated) else {
    return {
      run,
      rendered: @render.Rendered::failed("image/svg+xml", run.diagnostics),
    }
  }
  let highlight = TraceHighlight::new(
    validated.trace,
    attempts?,
    matched~,
    not_matched~,
    taken~,
    failure~,
    limits~,
  )
  let rendered = paint_railroad(diagram, { ..self, trace: Some(highlight), }).rendered
  { run, rendered, }
}

///|
/// A traced render that did not reach a provider, with the reasons.
pub fn TracedRender::refused(
  diagnostics : ArrayView[@diagrams.Diagnostic],
) -> TracedRender {
  {
    run: @railroad_trace.TraceRun::refused(diagnostics),
    rendered: @render.Rendered::failed("image/svg+xml", diagnostics),
  }
}
