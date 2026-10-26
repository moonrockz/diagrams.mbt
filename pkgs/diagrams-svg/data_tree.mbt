///|
/// A budgeted SVG builder for data views. It escapes text, refuses
/// characters that XML forbids and stops at the output limit.
priv struct DataPaint {
  paint : Paint
  diagnostics : Array[@diagrams.Diagnostic]
  limit : Int32
  mut used : Int32
  mut failed : Bool
}

///|
fn DataPaint::reserve(self : DataPaint, units : Int32) -> Bool {
  if units < 0 || units > self.limit - self.used {
    if !self.failed {
      self.diagnostics.push(
        @diagrams.Diagnostic::error(
          "data-tree/render-limit", "Data-tree SVG output limit exceeded",
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
fn DataPaint::invalid(self : DataPaint, message : String) -> Bool {
  if !self.failed {
    self.diagnostics.push(
      @diagrams.Diagnostic::error("data-tree/invalid-xml-character", message),
    )
  }
  self.failed = true
  false
}

///|
fn DataPaint::escaped(
  self : DataPaint,
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
        return self.invalid("Data-tree text contains an unpaired surrogate")
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
      return self.invalid(
        "Data-tree text contains a character that XML forbids",
      )
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
fn DataPaint::element(
  self : DataPaint,
  name : String,
  attrs~ : ArrayView[(String, String)] = [],
  children~ : ArrayView[@writer.Node] = [],
) -> @writer.Node {
  if !self.reserve(name.length() * 2 + 8) {
    return @writer.element("g")
  }
  for pair in attrs {
    let (key, value) = pair
    if !self.reserve(key.length() + 4) || !self.escaped(value, true) {
      return @writer.element("g")
    }
  }
  @writer.element(name, attrs~, children~)
}

///|
fn DataPaint::text(self : DataPaint, value : String) -> @writer.Node {
  if !self.escaped(value, false) {
    return @writer.text("")
  }
  @writer.text(value)
}

///|
fn data_number(value : Double) -> String {
  @data_tree_layout.svg_number(value)
}

///|
fn DataPaint::rect(
  self : DataPaint,
  class : String,
  r : @data_tree_layout.Rect,
  fill : String,
  stroke : String,
  width : String,
  radius? : String,
) -> @writer.Node {
  let attrs = [
    ("class", class),
    ("x", data_number(r.x)),
    ("y", data_number(r.y)),
    ("width", data_number(r.width)),
    ("height", data_number(r.height)),
  ]
  if radius is Some(rx) {
    attrs.push(("rx", rx))
  }
  attrs.push(("fill", fill))
  attrs.push(("stroke", stroke))
  attrs.push(("stroke-width", width))
  self.element("rect", attrs~)
}

///|
/// One label with a line for each wrapped line. Spaces are kept.
fn DataPaint::label(
  self : DataPaint,
  class : String,
  label : @data_tree_layout.Label,
) -> @writer.Node {
  let step = if label.size >= 16.0 { 21.0 } else { 17.0 }
  let x = data_number(label.box.x)
  let lines = []
  for i, line in label.lines {
    lines.push(
      self.element(
        "tspan",
        attrs=[
          ("x", x),
          (
            "y",
            data_number(label.box.y + label.size + i.to_double() * step - 2.0),
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
      ("xml:space", "preserve"),
      ("font-family", font_stack),
      ("font-size", data_number(label.size)),
      ("font-weight", label.weight.to_string()),
      ("fill", self.paint.color(label.ink.token())),
    ],
    children=lines,
  )
}

///|
fn DataPaint::row(
  self : DataPaint,
  row : @data_tree_layout.Row,
) -> @writer.Node {
  let attrs = [
    ("class", "data-row"),
    ("data-member", row.entry),
    ("data-node", row.node),
    ("data-type", row.kind.name()),
  ]
  if row.highlighted {
    attrs.push(("data-highlight", "true"))
  }
  let children = [
    self.rect(
      "data-row-bounds",
      row.box,
      self.paint.color(if row.highlighted { "cloud-fill" } else { "mask" }),
      self.paint.color(
        if row.highlighted {
          "cloud-stroke"
        } else {
          "external-stroke"
        },
      ),
      if row.highlighted {
        "1.5"
      } else {
        "0.75"
      },
    ),
  ]
  if row.key is Some(key) {
    children.push(self.label("data-key", key))
  }
  if row.value is Some(value) {
    children.push(self.label("data-value", value))
  }
  self.element("g", attrs~, children~)
}

///|
fn DataPaint::box(
  self : DataPaint,
  box : @data_tree_layout.Box,
) -> @writer.Node {
  let attrs = [
    ("class", "data-box"),
    ("data-node", box.node),
    ("data-type", box.kind.name()),
  ]
  let container = box.kind is (Object | Array)
  if container && box.rows.is_empty() {
    attrs.push(("data-empty", "true"))
  }
  if box.highlighted {
    attrs.push(("data-highlight", "true"))
  }
  let children = [
    self.rect(
      "data-box-frame",
      box.box,
      self.paint.color("mask"),
      self.paint.color(
        if box.highlighted {
          "cloud-stroke"
        } else {
          "external-stroke"
        },
      ),
      if box.highlighted {
        "2.5"
      } else {
        "1.5"
      },
      radius="4",
    ),
  ]
  if box.label is Some(label) {
    children.push(self.label("data-value", label))
  }
  for row in box.rows {
    if self.failed {
      break
    }
    children.push(self.row(row))
  }
  if box.divider is Some(x) {
    children.push(
      self.element("path", attrs=[
        ("class", "data-divider"),
        (
          "d",
          "M\{data_number(x)} \{data_number(box.box.y)} V\{data_number(box.box.bottom())}",
        ),
        ("fill", "none"),
        ("stroke", self.paint.color("external-stroke")),
        ("stroke-width", "0.75"),
      ]),
    )
  }
  self.element("g", attrs~, children~)
}

///|
/// The painted connector path of a geometry connector.
fn data_connector_path(connector : @data_tree_layout.Connector) -> String {
  connector.path()
}

///|
fn data_theme(theme : @theme.Theme) -> @theme.Theme {
  {
    dark: @data_tree_layout.palette(theme.dark),
    light: @data_tree_layout.palette(theme.light),
  }
}

///|
fn paint_data_tree(
  view : @data_tree.DataTree,
  theme : @theme.Theme,
  mode : Mode,
  id_prefix : String?,
  limits : @data_tree_layout.Limits,
  precomputed? : @data_tree_layout.Result,
) -> @render.Rendered {
  let result = match precomputed {
    Some(result) => result
    None => @data_tree_layout.layout(view, limits~)
  }
  let diagnostics = result.diagnostics.iter().to_array()
  guard result.geometry is Some(geometry) else {
    return @render.Rendered::failed("image/svg+xml", diagnostics)
  }
  let theme = data_theme(theme)
  let c : DataPaint = {
    paint: { theme, mode, },
    diagnostics,
    limit: limits.output_units,
    used: 0,
    failed: false,
  }
  let defs = []
  if mode == Adaptive {
    defs.push(c.element("style", children=[c.text(style_sheet(theme))]))
  }
  defs.push(
    c.element(
      "marker",
      attrs=[
        ("id", "dt-arrow"),
        ("viewBox", "-10 -6 12 12"),
        ("refX", "0"),
        ("refY", "0"),
        ("markerWidth", "12"),
        ("markerHeight", "12"),
        ("markerUnits", "userSpaceOnUse"),
        ("orient", "auto"),
      ],
      children=[
        c.element("path", attrs=[
          ("d", "M-9 -4 L0 0 L-9 4 Z"),
          ("fill", c.paint.color("arrow")),
        ]),
      ],
    ),
  )
  let connectors = []
  for connector in geometry.connectors {
    if c.failed {
      break
    }
    connectors.push(
      c.element("path", attrs=[
        ("class", "data-connector"),
        ("data-member", connector.entry),
        ("data-source", connector.source),
        ("data-target", connector.target),
        ("d", data_connector_path(connector)),
        ("fill", "none"),
        ("stroke", c.paint.color("arrow")),
        ("stroke-width", "1.5"),
        ("marker-end", "url(#dt-arrow)"),
      ]),
    )
  }
  let boxes = []
  for box in geometry.boxes {
    if c.failed {
      break
    }
    boxes.push(c.box(box))
  }
  let containers = geometry.boxes
    .iter()
    .filter(b => b.kind is (Object | Array))
    .count()
  let title = view.accessibility_title
    .map(value => Some(value))
    .unwrap_or(view.title)
    .unwrap_or(view.id)
  let description = view.accessibility_description.unwrap_or(
    "Structured data diagram with \{view.nodes.length()} values in \{containers} containers. Rows show members in source order and arrays show positions; connectors join nested containers.",
  )
  let body = [
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
  ]
  if geometry.title is Some(label) {
    body.push(c.label("data-title", label))
  }
  body.push(
    c.element("g", attrs=[("class", "data-connectors")], children=connectors),
  )
  body.push(c.element("g", attrs=[("class", "data-boxes")], children=boxes))
  let root = c.element(
    "svg",
    attrs=[
      ("xmlns", "http://www.w3.org/2000/svg"),
      ("viewBox", "0 0 \{geometry.width} \{geometry.height}"),
      ("width", geometry.width.to_string()),
      ("height", geometry.height.to_string()),
      ("role", "img"),
      ("data-diagram", "data-tree"),
    ],
    children=body,
  )
  if c.failed {
    return @render.Rendered::failed("image/svg+xml", diagnostics)
  }
  fn prefix_failure() -> @render.Rendered {
    @render.Rendered::failed("image/svg+xml", [
      @diagrams.Diagnostic::error(
        "data-tree/render-limit", "Scoped SVG identifiers exceed the output limit",
      ),
    ])
  }
  let original = @writer.to_string(root)
  if original.length() > limits.output_units - 128 {
    return prefix_failure()
  }
  // The scoped style sheet repeats the prefix four times; the marker and its
  // two references use it too.
  let occurrences = (if mode == Adaptive { 4 } else { 0 }) +
    2 +
    connectors.length()
  let prefix_limit = (limits.output_units - original.length() - 128) /
    occurrences
  let prefix = match id_prefix {
    Some(raw) => {
      let out = StringBuilder()
      out.write_string("dt-u-")
      for ch in raw {
        out.write_string(ch.to_int().to_string(radix=16) + "-")
        if out.to_string().length() > prefix_limit {
          return prefix_failure()
        }
      }
      out.to_string()
    }
    None => {
      // FNV-1a over UTF-16 units keeps IDs deterministic on every backend.
      let mut hash : UInt64 = 14695981039346656037
      for i in 0..<original.length() {
        hash = (hash ^ original.code_unit_at(i).to_int().to_uint64()) *
          1099511628211
      }
      "dt-\{hash.to_string(radix=16)}-"
    }
  }
  if prefix.length() > prefix_limit {
    return prefix_failure()
  }
  let output = @writer.to_string(scope_svg(root, prefix, theme))
  if output.length() > limits.output_units {
    return @render.Rendered::failed("image/svg+xml", [
      @diagrams.Diagnostic::error(
        "data-tree/render-limit", "Scoped SVG exceeds its output limit",
      ),
    ])
  }
  let palettes = match mode {
    Adaptive => [("dark", theme.dark), ("light", theme.light)]
    Fixed(Dark) => [("dark", theme.dark)]
    Fixed(Light) => [("light", theme.light)]
  }
  for pair in palettes {
    let (name, palette) = pair
    for
      finding in @data_tree_layout.check(
        geometry,
        palette,
        work_limit=limits.work,
      ) {
      if finding.rule == Limit {
        diagnostics.push(
          @diagrams.Diagnostic::error("data-tree/layout-limit", finding.message),
        )
        return @render.Rendered::failed("image/svg+xml", diagnostics)
      }
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "data-tree/legibility",
          name + ": " + finding.message,
        ),
      )
    }
  }
  @render.Rendered::ok(output, "image/svg+xml", diagnostics~)
}

///|
/// Render one standalone data-tree SVG with the same caller-supplied options
/// as `SvgRenderer`. Keys and values are escaped text; a stereotype of a
/// highlight is never style. Highlights use the theme colours.
pub fn render_data_tree(
  view : @data_tree.DataTree,
  theme~ : @theme.Theme = @theme.Theme::classic(),
  mode~ : Mode = Adaptive,
  id_prefix? : String,
  limits~ : @data_tree_layout.Limits = @data_tree_layout.Limits::new(),
) -> @render.Rendered {
  paint_data_tree(view, theme, mode, id_prefix, limits)
}

///|
/// Scene geometry for a data tree: the canonical render, the connector paths
/// and the box/row bindings, all from one measured layout.
fn data_tree_scene(
  renderer : SvgRenderer,
  view : @data_tree.DataTree,
  catalog : @animation.Catalog,
  output_units : Int32,
) -> Result[
  (@render.Rendered, Array[(@animation.Occurrence, String)], Array[NodeBinding]),
  ReadOnlyArray[@diagrams.Diagnostic],
] {
  let limits = renderer.data_tree_limits
  let result = @data_tree_layout.layout(view, limits~)
  let rendered = paint_data_tree(
    view,
    renderer.theme,
    renderer.mode,
    renderer.id_prefix,
    limits,
    precomputed=result,
  )
  guard result.geometry is Some(geometry) && rendered.output is Some(_) else {
    return Err(rendered.diagnostics)
  }
  fn mismatch(
    message : String,
  ) -> Result[
    (
      @render.Rendered,
      Array[(@animation.Occurrence, String)],
      Array[NodeBinding],
    ),
    ReadOnlyArray[@diagrams.Diagnostic],
  ] {
    Err([@diagrams.Diagnostic::error("animation/binding-mismatch", message)])
  }
  let connectors : Map[String, @data_tree_layout.Connector] = Map([])
  for connector in geometry.connectors {
    connectors[connector.entry] = connector
  }
  let boxes : Map[String, Bool] = Map([])
  let rows : Map[String, Bool] = Map([])
  for box in geometry.boxes {
    boxes[box.node] = true
    for row in box.rows {
      rows[row.entry] = true
    }
  }
  let paths = []
  let nodes = []
  let mut units = 0
  for occurrence in catalog.occurrences {
    match occurrence.kind {
      DataConnector => {
        guard occurrence.data_member is Some(entry) &&
          connectors.get(entry.id) is Some(connector) else {
          return mismatch("A data connector occurrence has no drawn path")
        }
        let path = data_connector_path(connector)
        if path.length() > output_units - units {
          return Err([
            @diagrams.Diagnostic::error(
              "animation/scene-limit", "Data-tree scene paths exceed their output limit",
            ),
          ])
        }
        units += path.length()
        paths.push((occurrence, path))
      }
      Visit(DataBox) => {
        guard occurrence.data_node is Some(node) && boxes.contains(node.id) else {
          return mismatch("A data box occurrence has no drawn box")
        }
        nodes.push({ endpoint: occurrence.key, kind: DataBox(node.id), })
      }
      Visit(DataRow) => {
        guard occurrence.data_member is Some(entry) && rows.contains(entry.id) else {
          return mismatch("A data row occurrence has no drawn row")
        }
        nodes.push({ endpoint: occurrence.key, kind: DataRow(entry.id), })
      }
      _ =>
        return mismatch(
          "A data-tree catalog has a target that is not a box, row or connector",
        )
    }
  }
  if paths.length() != geometry.connectors.length() {
    return mismatch("The drawn connectors and the catalog connectors differ")
  }
  Ok((rendered, paths, nodes))
}
