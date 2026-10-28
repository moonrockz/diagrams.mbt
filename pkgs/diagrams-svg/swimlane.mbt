///|
priv struct SwimlanePaint {
  paint : Paint
  kind : String
  state_roles : Map[String, @state.State]
  state_regions : Map[String, @state.Region]
  state_separators : Map[String, (@state.Separator, String)]
  state_bounds : Map[String, @swimlane_layout.Shape]
  parent_overrides : Map[String, String?]
  diagnostics : Array[@diagrams.Diagnostic]
  limit : Int32
  mut used : Int32
  mut failed : Bool
}

///|
fn SwimlanePaint::reserve(self : SwimlanePaint, units : Int32) -> Bool {
  if units < 0 || units > self.limit - self.used {
    if !self.failed {
      self.diagnostics.push(
        @diagrams.Diagnostic::error(
          "swimlane/render-limit", "Swimlane SVG output limit exceeded",
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
fn SwimlanePaint::escaped(
  self : SwimlanePaint,
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
            "swimlane/invalid-xml-character", "Swimlane text contains an unpaired surrogate",
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
          "swimlane/invalid-xml-character", "Swimlane text contains a forbidden XML character",
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
fn SwimlanePaint::element(
  self : SwimlanePaint,
  name : String,
  attrs~ : ArrayView[(String, String)] = [],
  children~ : ArrayView[@writer.Node] = [],
) -> @writer.Node {
  if !self.reserve(name.length() * 2 + 8) {
    return @writer.element("g")
  }
  for (key, value) in attrs {
    if !self.reserve(key.length() + 4) || !self.escaped(value, true) {
      return @writer.element("g")
    }
  }
  @writer.element(name, attrs~, children~)
}

///|
fn SwimlanePaint::text(self : SwimlanePaint, value : String) -> @writer.Node {
  if !self.escaped(value, false) {
    return @writer.text("")
  }
  @writer.text(value)
}

///|
fn swimlane_number(value : Double) -> String {
  @swimlane_layout.svg_number(value)
}

///|
pub fn swimlane_path(edge : @swimlane_layout.Connection) -> String {
  let b = StringBuilder()
  for i, p in edge.line {
    b.write_string(
      "\{if i == 0 { "M" } else { " L" }}\{swimlane_number(p.x)} \{swimlane_number(p.y)}",
    )
  }
  b.to_string()
}

///|
fn swimlane_outline(shape : @swimlane_layout.Shape) -> String {
  if shape.shape == "datastore" {
    let r = shape.outline_box
    let n = swimlane_number
    return "M\{n(r.x)} \{n(r.y)} H\{n(r.x+r.width)} M\{n(r.x)} \{n(r.y+r.height)} H\{n(r.x+r.width)}"
  }

  fn boundary(kind : String) -> String {
    let b = StringBuilder()
    for i, p in @swimlane_layout.outline(kind, shape.outline_box) {
      b.write_string(
        "\{if i == 0 { "M" } else { " L" }}\{swimlane_number(p.x)} \{swimlane_number(p.y)}",
      )
    }
    b.write_string(" Z")
    b.to_string()
  }
  if shape.shape == "braces" {
    boundary("brace") + " " + boundary("brace-r")
  } else {
    boundary(shape.shape)
  }
}

///|
fn SwimlanePaint::line(
  self : SwimlanePaint,
  d : String,
  color : String,
  width~ : String = "1.5",
) -> @writer.Node {
  self.element("path", attrs=[
    ("d", d),
    ("fill", "none"),
    ("stroke", color),
    ("stroke-width", width),
  ])
}

///|
fn SwimlanePaint::label(
  self : SwimlanePaint,
  label : @swimlane_layout.Label,
  inverted~ : Bool = false,
) -> @writer.Node {
  let color = if inverted {
    self.paint.color("bg")
  } else {
    label.family
    .map(f => self.paint.color(f.name() + "-ink"))
    .unwrap_or(self.paint.color("text"))
  }
  let children = []
  for i, line in label.text.split("\n") {
    children.push(
      self.element(
        "tspan",
        attrs=[
          ("x", swimlane_number(label.box.x + label.box.width / 2.0)),
          (
            "y",
            swimlane_number(
              label.box.y + label.size + i.to_double() * (label.size + 4.0),
            ),
          ),
        ],
        children=[self.text(line.to_owned())],
      ),
    )
  }
  self.element(
    "text",
    attrs=[
      ("class", self.kind + "-label"),
      ("data-label-owner", label.owner),
      ("x", swimlane_number(label.box.x + label.box.width / 2.0)),
      ("y", swimlane_number(label.box.y + label.size)),
      ("text-anchor", "middle"),
      ("font-family", font_stack),
      ("font-size", swimlane_number(label.size)),
      ("font-weight", label.weight.to_string()),
      ("fill", color),
    ],
    children~,
  )
}

///|
fn SwimlanePaint::decorations(
  self : SwimlanePaint,
  shape : @swimlane_layout.Shape,
  stroke : String,
) -> Array[@writer.Node] {
  let r = shape.outline_box
  let x = r.x
  let y = r.y
  let w = r.width
  let h = r.height
  let n = swimlane_number
  let result = []
  fn line(d : String) {
    result.push(self.line(d, stroke))
  }
  match shape.shape {
    "subroutine" => {
      line("M\{n(x+10.0)} \{n(y)} V\{n(y+h)}")
      line("M\{n(x+w-10.0)} \{n(y)} V\{n(y+h)}")
    }
    "lin-rect" | "lin-doc" => line("M\{n(x+12.0)} \{n(y+8.0)} V\{n(y+h-8.0)}")
    "div-rect" | "composite" => line("M\{n(x)} \{n(y+14.0)} H\{n(x+w)}")
    "win-pane" => {
      line("M\{n(x+14.0)} \{n(y)} V\{n(y+h)}")
      line("M\{n(x)} \{n(y+14.0)} H\{n(x+w)}")
    }
    "doublecircle" | "fr-circ" | "cross-circ" => {
      result.push(
        self.element("ellipse", attrs=[
          ("cx", n(x + w / 2.0)),
          ("cy", n(y + h / 2.0)),
          ("rx", n(w / 2.0 - 6.0)),
          ("ry", n(h / 2.0 - 6.0)),
          (
            "fill",
            if shape.shape == "fr-circ" {
              self.paint.color("messagebus-ink")
            } else {
              "none"
            },
          ),
          ("stroke", stroke),
          ("stroke-width", "1.5"),
        ]),
      )
      if shape.shape == "cross-circ" {
        line(
          "M\{n(x+w*0.15)} \{n(y+h*0.15)} L\{n(x+w*0.85)} \{n(y+h*0.85)} M\{n(x+w*0.85)} \{n(y+h*0.15)} L\{n(x+w*0.15)} \{n(y+h*0.85)}",
        )
      }
    }
    "cylinder" | "lin-cyl" => {
      result.push(
        self.element("ellipse", attrs=[
          ("cx", n(x + w / 2.0)),
          ("cy", n(y + h * 0.15)),
          ("rx", n(w / 2.0)),
          ("ry", n(h * 0.15)),
          ("fill", "none"),
          ("stroke", stroke),
          ("stroke-width", "1.5"),
        ]),
      )
      if shape.shape == "lin-cyl" {
        for offset in [0.24, 0.3] {
          line(
            "M\{n(x)} \{n(y+h*offset)} Q\{n(x+w/2.0)} \{n(y+h*(offset+0.25))} \{n(x+w)} \{n(y+h*offset)}",
          )
        }
      }
    }
    "h-cyl" =>
      result.push(
        self.element("ellipse", attrs=[
          ("cx", n(x + w * 0.12)),
          ("cy", n(y + h / 2.0)),
          ("rx", n(w * 0.12)),
          ("ry", n(h / 2.0)),
          ("fill", "none"),
          ("stroke", stroke),
          ("stroke-width", "1.5"),
        ]),
      )
    "tag-doc" | "tag-rect" | "note" =>
      line("M\{n(x+w-18.0)} \{n(y)} V\{n(y+18.0)} H\{n(x+w)}")
    "st-rect" | "docs" => {
      line("M\{n(x+6.0)} \{n(y+6.0)} H\{n(x+w-6.0)} V\{n(y+h-6.0)}")
      line("M\{n(x+12.0)} \{n(y+12.0)} H\{n(x+w-12.0)}")
    }
    "fork" => ()
    "browser" | "console" => {
      line("M\{n(x)} \{n(y+18.0)} H\{n(x+w)}")
      if shape.shape == "console" {
        line(
          "M\{n(x+8.0)} \{n(y+7.0)} L\{n(x+13.0)} \{n(y+10.0)} L\{n(x+8.0)} \{n(y+13.0)}",
        )
      } else {
        for px in [8.0, 15.0, 22.0] {
          result.push(
            self.element("circle", attrs=[
              ("cx", n(x + px)),
              ("cy", n(y + 9.0)),
              ("r", "2"),
              ("fill", stroke),
            ]),
          )
        }
      }
    }
    "bucket" =>
      line(
        "M\{n(x+w*0.15)} \{n(y+8.0)} Q\{n(x+w/2.0)} \{n(y-8.0)} \{n(x+w*0.85)} \{n(y+8.0)}",
      )
    "person" =>
      result.push(
        self.element("circle", attrs=[
          ("cx", n(x + w / 2.0)),
          ("cy", n(y + h * 0.17)),
          ("r", n(h * 0.15)),
          ("fill", self.paint.color("backend-fill")),
          ("stroke", stroke),
        ]),
      )
    "bang" => {
      line("M\{n(x+w/2.0)} \{n(y+8.0)} V\{n(y+22.0)}")
      result.push(
        self.element("circle", attrs=[
          ("cx", n(x + w / 2.0)),
          ("cy", n(y + 27.0)),
          ("r", "2"),
          ("fill", stroke),
        ]),
      )
    }
    _ => ()
  }
  result
}

///|
fn SwimlanePaint::shape(
  self : SwimlanePaint,
  shape : @swimlane_layout.Shape,
  node : @swimlane.Node?,
) -> @writer.Node {
  let family = @swimlane_layout.family(shape.shape)
  let stroke = if shape.kind == Node {
    self.paint.color(family.name() + "-stroke")
  } else {
    self.paint.color("muted")
  }
  let filled = ["f-circ", "sm-circ", "anchor", "fork"].contains(shape.shape)
  let fill = if filled {
    self.paint.color(family.name() + "-ink")
  } else if shape.kind == Node {
    self.paint.color(family.name() + "-fill")
  } else {
    self.paint.color("bg")
  }
  let empty = ["text"].contains(shape.shape)
  let attrs = [
    (
      "class",
      "\{self.kind}-\{match shape.kind { Lane => "lane"; Group => "group"; Node => "node" }}",
    ),
    ("data-" + self.kind + "-id", shape.id),
    ("data-shape", shape.shape),
    ("data-expanded", if shape.expanded { "true" } else { "false" }),
  ]
  if shape.lane is Some(lane) {
    attrs.push(("data-lane", lane))
  }
  if self.parent_overrides.get(shape.id).unwrap_or(shape.parent) is Some(parent) {
    attrs.push(("data-parent", parent))
  }
  if node.bind(n => n.properties) is Some(properties) {
    if properties.link is Some(link) {
      attrs.push(("data-link", link))
    }
    for i, (key, value) in properties.metadata {
      attrs.push(
        (
          "data-property-" +
          i.to_string() +
          "-" +
          key.to_array().map(ch => ch.to_int().to_string(radix=16)).join("-"),
          value,
        ),
      )
    }
  }
  let outline_attrs = [
    ("class", self.kind + "-outline"),
    ("d", swimlane_outline(shape)),
    ("fill", if empty { "none" } else { fill }),
    ("stroke", if empty { "none" } else { stroke }),
    ("stroke-width", if shape.kind == Lane { "2" } else { "1.5" }),
  ]
  if shape.kind == Group && self.kind != "state" {
    outline_attrs.push(("stroke-dasharray", "6 4"))
  }
  if self.kind == "state" {
    if self.state_roles.get(shape.id) is Some(state) {
      attrs.push(("data-role", @debug.to_string(state.role)))
      if state.role == Composite {
        outline_attrs[1] = ("d", state_rounded_outline(shape.outline_box))
      }
    } else if self.state_regions.contains(shape.id) {
      let b = shape.box
      let d = match self.state_separators.get(shape.id) {
        Some((orientation, previous)) => {
          let old = self.state_bounds[previous].box
          let parent = self.state_bounds[self.state_regions[shape.id].owner.unwrap()].box
          if orientation == Vertical {
            let x = (old.x + old.width + b.x) / 2.0
            "M" +
            swimlane_number(x) +
            " " +
            swimlane_number((old.y.min(b.y) - 24.0).max(parent.y + 48.0)) +
            " L" +
            swimlane_number(x) +
            " " +
            swimlane_number(parent.y + parent.height)
          } else {
            let y = (old.y + old.height + b.y) / 2.0
            "M" +
            swimlane_number((old.x.min(b.x) - 24.0).max(parent.x)) +
            " " +
            swimlane_number(y) +
            " L" +
            swimlane_number(parent.x + parent.width) +
            " " +
            swimlane_number(y)
          }
        }
        None => ""
      }
      outline_attrs[1] = ("d", d)
      outline_attrs[2] = ("fill", "none")
      outline_attrs.push(("stroke-dasharray", "6 4"))
    }
  }
  let box = shape.box
  let children = [
    self.element("rect", attrs=[
      ("class", self.kind + "-bounds"),
      ("x", swimlane_number(box.x)),
      ("y", swimlane_number(box.y)),
      ("width", swimlane_number(box.width)),
      ("height", swimlane_number(box.height)),
      ("fill", "none"),
      ("stroke", "none"),
      ("pointer-events", "none"),
      ("aria-hidden", "true"),
    ]),
    self.element("path", attrs=outline_attrs),
  ]
  children.append(self.decorations(shape, stroke))
  if self.kind == "state" &&
    self.state_roles.get(shape.id) is Some(state) &&
    !state.descriptions.is_empty() {
    let b = shape.outline_box
    let y = if shape.kind == Group {
      b.y + 35.0
    } else {
      shape.label.map(l => l.box.y + 20.0).unwrap_or(b.y + 30.0)
    }
    children.push(
      self.element("path", attrs=[
        ("class", "state-compartment"),
        (
          "d",
          "M" +
          swimlane_number(b.x) +
          " " +
          swimlane_number(y) +
          " L" +
          swimlane_number(b.x + b.width) +
          " " +
          swimlane_number(y),
        ),
        ("stroke", stroke),
        ("fill", "none"),
      ]),
    )
  }
  if shape.label is Some(label) {
    children.push(
      self.label(
        label,
        inverted=filled && shape.outline_box.contains(label.box),
      ),
    )
  }
  self.element("g", attrs~, children~)
}

///|
fn swimlane_marker_name(marker : @swimlane.Marker) -> String? {
  match marker {
    None => None
    Arrow => Some("sl-arrow")
    Circle => Some("sl-circle")
    Cross => Some("sl-cross")
  }
}

///|
fn SwimlanePaint::connection(
  self : SwimlanePaint,
  edge : @swimlane_layout.Connection,
) -> @writer.Node {
  let flow = edge.connection
  let attrs = [
    ("class", self.kind + "-connector"),
    ("d", swimlane_path(edge)),
    ("fill", "none"),
    ("stroke", self.paint.color("arrow")),
    ("stroke-width", if flow.style == Thick { "3" } else { "1.5" }),
  ]
  if flow.style == Dotted {
    attrs.push(("stroke-dasharray", "4 4"))
  }
  if swimlane_marker_name(flow.source_marker) is Some(id) {
    attrs.push(("marker-start", "url(#" + id + ")"))
  }
  if swimlane_marker_name(flow.target_marker) is Some(id) {
    attrs.push(("marker-end", "url(#" + id + ")"))
  }
  let children = [self.element("path", attrs~)]
  if edge.label is Some(label) {
    let r = label.box
    children.push(
      self.element("rect", attrs=[
        ("x", swimlane_number(r.x - 4.0)),
        ("y", swimlane_number(r.y - 2.0)),
        ("width", swimlane_number(r.width + 8.0)),
        ("height", swimlane_number(r.height + 4.0)),
        ("rx", "3"),
        ("fill", self.paint.color("bg")),
      ]),
    )
    children.push(self.label(label))
  }
  self.element(
    "g",
    attrs=[
      ("class", self.kind + "-connection"),
      ("data-" + self.kind + "-id", flow.id),
      ("data-source", flow.source),
      ("data-target", flow.target),
      ("data-display-source", edge.source),
      ("data-display-target", edge.target),
    ],
    children~,
  )
}

///|
fn paint_swimlane(
  view : @swimlane.Swimlane,
  theme : @theme.Theme,
  mode : Mode,
  id_prefix : String?,
  limits : @swimlane_layout.Limits,
  precomputed? : @swimlane_layout.Result,
  kind~ : String = "swimlane",
  state_view? : @state.StateDiagram,
  intentional_containment~ : ArrayView[(String, String)] = [],
  boundary_attachments~ : ArrayView[(String, String)] = [],
  hidden_containers~ : ArrayView[String] = [],
  parent_overrides~ : ArrayView[(String, String?)] = [],
  connectors~ : ConnectorOptions = ConnectorOptions::new(),
) -> @render.Rendered {
  if !connector_options_valid(connectors) {
    return @render.Rendered::failed("image/svg+xml", [
      @diagrams.Diagnostic::error(
        "connector/invalid-option", "Invalid connector options",
      ),
    ])
  }
  let limits = limits.with_minimum_approach(connectors.minimum_approach)
  let result = precomputed.unwrap_or_else(() => {
    @swimlane_layout.layout(view, limits~)
  })
  let diagnostics = result.diagnostics.iter().to_array()
  guard result.geometry is Some(geometry) else {
    return @render.Rendered::failed("image/svg+xml", diagnostics)
  }
  let theme = @theme.Theme::{
    dark: @swimlane_layout.palette(theme.dark),
    light: @swimlane_layout.palette(theme.light),
  }
  let state_separators = Map([])
  if state_view is Some(view) {
    let seen = Map([])
    for r in view.regions {
      if r.owner is Some(owner) {
        if seen.get(owner) is Some(previous) {
          state_separators[r.id] = (r.separator, previous)
        }
        seen[owner] = r.id
      }
    }
  }
  let c = SwimlanePaint::{
    kind,
    state_separators,
    state_bounds: Map(geometry.shapes.map(s => (s.id, s))),
    state_roles: Map(
      state_view
      .map(v => v.states.map(s => (s.id, s)).iter().to_array())
      .unwrap_or([]),
    ),
    state_regions: Map(
      state_view
      .map(v => v.regions.map(r => (r.id, r)).iter().to_array())
      .unwrap_or([]),
    ),
    parent_overrides: Map(parent_overrides),
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
  let color = c.paint.color("arrow")
  for
    (id, shape) in [
      ("sl-arrow", "M-9 -4 L0 0 L-9 4 Z"),
      ("sl-circle", "M-4 0 A4 4 0 1 0 4 0 A4 4 0 1 0 -4 0 Z"),
      ("sl-cross", "M-4 -4 L4 4 M-4 4 L4 -4"),
    ] {
    defs.push(
      c.element(
        "marker",
        attrs=[
          ("id", id),
          ("viewBox", "-10 -6 16 12"),
          ("refX", "0"),
          ("refY", "0"),
          ("markerWidth", "16"),
          ("markerHeight", "12"),
          ("markerUnits", "userSpaceOnUse"),
          ("orient", "auto-start-reverse"),
        ],
        children=[
          c.element("path", attrs=[
            ("d", shape),
            ("fill", if id == "sl-cross" { "none" } else { color }),
            ("stroke", color),
            ("stroke-width", "1.5"),
          ]),
        ],
      ),
    )
  }
  let node_map = Map([])
  for node in view.nodes {
    node_map[node.id] = node
  }
  let backgrounds = []
  let nodes = []
  if state_view is Some(view) {
    for r in view.regions {
      if r.owner == None {
        backgrounds.push(
          c.element(
            "g",
            attrs=[("class", "state-group"), ("data-state-id", r.id)],
            children=[
              c.element("rect", attrs=[
                ("class", "state-bounds"),
                ("x", "0"),
                ("y", "0"),
                ("width", geometry.width.to_string()),
                ("height", geometry.height.to_string()),
                ("fill", "none"),
                ("stroke", "none"),
              ]),
            ],
          ),
        )
      }
    }
  }
  let connections = []
  for shape in geometry.shapes {
    if c.failed {
      break
    }
    if shape.kind == Node {
      nodes.push(c.shape(shape, node_map.get(shape.id)))
    }
  }
  // Larger ancestors paint first, independently of authored declaration order.
  let ordered = geometry.shapes.iter().filter(s => s.kind != Node).to_array()
  ordered.sort_by((a, b) => {
    let area = (b.box.width * b.box.height).compare(a.box.width * a.box.height)
    if area == 0 {
      a.index.compare(b.index)
    } else {
      area
    }
  })
  let hidden = Map(hidden_containers.map(id => (id, true)))
  for shape in ordered {
    if hidden.contains(shape.id) {
      continue
    }
    if c.failed {
      break
    }
    backgrounds.push(c.shape(shape, None))
  }
  for edge in geometry.connections {
    if c.failed {
      break
    }
    if edge.connection.style != Invisible {
      connections.push(c.connection(edge))
    }
  }
  let title = view.accessibility_title
    .map(value => Some(value))
    .unwrap_or(view.title)
    .unwrap_or(view.id)
  let description = view.accessibility_description.unwrap_or(
    if kind == "flowchart" {
      "Flowchart with \{view.nodes.length()} nodes and \{view.connections.length()} structural connections. Playback illustrates structure and does not execute a workflow."
    } else {
      "Swimlane diagram with \{view.lanes.length()} responsibility lanes and \{view.connections.length()} structural connections. Playback illustrates structure and does not execute a process."
    },
  )
  let root = c.element(
    "svg",
    attrs=[
      ("xmlns", "http://www.w3.org/2000/svg"),
      ("viewBox", "0 0 \{geometry.width} \{geometry.height}"),
      ("width", geometry.width.to_string()),
      ("height", geometry.height.to_string()),
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
        ("width", geometry.width.to_string()),
        ("height", geometry.height.to_string()),
        ("fill", c.paint.color("bg")),
      ]),
      c.element(
        "g",
        attrs=[("class", kind + "-backgrounds")],
        children=backgrounds,
      ),
      c.element(
        "g",
        attrs=[("class", kind + "-connections")],
        children=connections,
      ),
      c.element("g", attrs=[("class", kind + "-nodes")], children=nodes),
    ],
  )
  if c.failed {
    return @render.Rendered::failed("image/svg+xml", diagnostics)
  }
  fn prefix_failure() -> @render.Rendered {
    @render.Rendered::failed("image/svg+xml", [
      @diagrams.Diagnostic::error(
        "swimlane/render-limit", "Scoped SVG identifiers exceed the output limit",
      ),
    ])
  }
  let obstacles : Array[ConnectorObstacle] = []
  let labels : Array[(String, ConnectorObstacle)] = []
  for shape in geometry.shapes {
    if shape.kind == Node {
      let r = shape.outline_box
      obstacles.push({
        owner: shape.id,
        x: r.x,
        y: r.y,
        width: r.width,
        height: r.height,
      })
    }
    if shape.label is Some(label) {
      let r = label.box
      labels.push(
        (
          "",
          { owner: shape.id, x: r.x, y: r.y, width: r.width, height: r.height, },
        ),
      )
    }
  }
  for edge in geometry.connections {
    if edge.label is Some(label) {
      let r = label.box
      labels.push(
        (
          "",
          {
            owner: edge.connection.id,
            x: r.x,
            y: r.y,
            width: r.width,
            height: r.height,
          },
        ),
      )
    }
  }
  guard finalize_connectors(
      root,
      connectors,
      diagnostics,
      obstacles=obstacles[:],
      labels=labels[:],
    )
    is Some(root) else {
    return @render.Rendered::failed("image/svg+xml", diagnostics)
  }
  let original = @writer.to_string(root)
  if original.length() > limits.output_units - 128 {
    return prefix_failure()
  }
  let stack = [root]
  let mut occurrences = 1
  while stack.pop() is Some(node) {
    match node {
      Text(_) => ()
      Element(name, attrs, children) => {
        if name == "style" {
          occurrences += 4
        }
        for (key, _) in attrs {
          if key == "id" || key == "marker-start" || key == "marker-end" {
            occurrences += 1
          }
        }
        stack.append(children)
      }
    }
  }
  let prefix_limit = (limits.output_units - original.length() - 128) /
    occurrences
  let prefix = match id_prefix {
    Some(raw) => {
      if raw.length() > prefix_limit / 2 {
        return prefix_failure()
      }
      let out = StringBuilder()
      let mut units = 5
      out.write_string("sl-u-")
      for ch in raw {
        let part = ch.to_int().to_string(radix=16) + "-"
        if part.length() > prefix_limit - units {
          return prefix_failure()
        }
        units += part.length()
        out.write_string(part)
      }
      out.to_string()
    }
    None => {
      let mut hash : UInt64 = 14695981039346656037
      for i in 0..<original.length() {
        hash = (hash ^ original.code_unit_at(i).to_int().to_uint64()) *
          1099511628211
      }
      "sl-\{hash.to_string(radix=16)}-"
    }
  }
  if prefix.length() > prefix_limit {
    return prefix_failure()
  }
  let output = @writer.to_string(scope_svg(root, prefix, theme))
  if output.length() > limits.output_units {
    return @render.Rendered::failed("image/svg+xml", [
      @diagrams.Diagnostic::error(
        "swimlane/render-limit", "Scoped SVG exceeds its output limit",
      ),
    ])
  }
  let palettes = match mode {
    Adaptive => [("dark", theme.dark), ("light", theme.light)]
    Fixed(Dark) => [("dark", theme.dark)]
    Fixed(Light) => [("light", theme.light)]
  }
  for (name, palette) in palettes {
    for
      finding in @swimlane_layout.check(
        geometry,
        palette,
        work_limit=limits.work,
        intentional_containment~,
        boundary_attachments~,
      ) {
      if finding.rule == Limit {
        diagnostics.push(
          @diagrams.Diagnostic::error("swimlane/layout-limit", finding.message),
        )
        return @render.Rendered::failed("image/svg+xml", diagnostics)
      }
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "swimlane/legibility",
          name + ": " + finding.message,
        ),
      )
    }
  }
  @render.Rendered::ok(output, "image/svg+xml", diagnostics~)
}

///|
/// Render a standalone swimlane with the same caller-supplied options as SvgRenderer.
pub fn render_swimlane(
  view : @swimlane.Swimlane,
  theme~ : @theme.Theme = @theme.Theme::classic(),
  mode~ : Mode = Adaptive,
  id_prefix? : String,
  limits~ : @swimlane_layout.Limits = @swimlane_layout.Limits::new(),
  connectors~ : ConnectorOptions = ConnectorOptions::new(),
) -> @render.Rendered {
  paint_swimlane(view, theme, mode, id_prefix, limits, connectors~)
}

///|
fn state_rounded_outline(box : @swimlane_layout.Rect) -> String {
  let points = @swimlane_layout.outline("rounded", box)
  let out = StringBuilder()
  for i, p in points {
    out.write_string(
      (if i == 0 { "M" } else { " L" }) +
      swimlane_number(p.x) +
      " " +
      swimlane_number(p.y),
    )
  }
  out.write_string(" Z")
  out.to_string()
}
