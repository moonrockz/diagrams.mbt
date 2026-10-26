///|
fn architecture_prefix(
  model : @architecture.Architecture,
  id_prefix : String?,
  theme : @theme.Theme,
  mode : Mode,
) -> String {
  let raw = match id_prefix {
    Some(value) => value
    None => {
      let source = @debug.to_string((model, theme, mode))
      let mut hash : UInt64 = 14695981039346656037
      for i in 0..<source.length() {
        hash = (hash ^ source.code_unit_at(i).to_int().to_uint64()) *
          1099511628211
      }
      hash.to_string(radix=16)
    }
  }
  let out = StringBuilder()
  out.write_string("arch-u-")
  for c in raw {
    out.write_string(c.to_int().to_string(radix=16) + "-")
  }
  out.to_string()
}

///|
fn architecture_label(
  p : Paint,
  text : String,
  x : Int32,
  y : Int32,
  class : String,
) -> @writer.Node {
  let children = text
    .split("\n")
    .to_array()
    .mapi((i, line) => {
      @writer.element(
        "tspan",
        attrs=[("x", x.to_string()), ("y", (y + i * 18).to_string())],
        children=[@writer.text(line.to_owned())],
      )
    })
  @writer.element(
    "text",
    attrs=[
      ("class", class),
      ("x", x.to_string()),
      ("y", y.to_string()),
      ("text-anchor", "middle"),
      ("font-family", font_stack),
      ("font-size", "13"),
      ("fill", p.color("text")),
    ],
    children~,
  )
}

///|
fn architecture_rect(
  box : @architecture_layout.Rect,
  fill : String,
  stroke : String,
  class : String,
) -> @writer.Node {
  @writer.element("rect", attrs=[
    ("class", class),
    ("x", box.x.to_string()),
    ("y", box.y.to_string()),
    ("width", box.width.to_string()),
    ("height", box.height.to_string()),
    ("rx", "6"),
    ("fill", fill),
    ("stroke", stroke),
    ("stroke-width", "1.5"),
  ])
}

///|
fn architecture_path(
  points : ReadOnlyArray[@architecture_layout.Point],
) -> String {
  let out = StringBuilder()
  for i, p in points {
    out.write_string(
      (if i == 0 { "M" } else { " L" }) +
      p.x.to_string() +
      " " +
      p.y.to_string(),
    )
  }
  out.to_string()
}

///|
fn paint_architecture(
  model : @architecture.Architecture,
  theme : @theme.Theme,
  mode : Mode,
  id_prefix : String?,
  limits : @architecture_layout.Limits,
  geometry? : @architecture_layout.Geometry,
) -> @render.Rendered {
  let result = match geometry {
    Some(g) =>
      @architecture_layout.LayoutResult::{ geometry: Some(g), diagnostics: [], }
    None => @architecture_layout.layout(model, limits~)
  }
  guard result.geometry is Some(g) else {
    return @render.Rendered::failed(
      "image/svg+xml",
      result.diagnostics.iter().to_array()[:],
    )
  }
  let diagnostics = result.diagnostics.iter().to_array()
  let p = Paint::{ theme, mode, }
  let prefix = architecture_prefix(model, id_prefix, theme, mode)
  let defs = []
  let used : Map[String, Bool] = Map([])
  if mode == Adaptive {
    defs.push(
      @writer.element("style", children=[
        @writer.text(style_sheet(theme, selector="svg#" + prefix + "diagram")),
      ]),
    )
  }
  for
    icon in model.groups
    .iter()
    .map(s => s.icon)
    .concat(model.services.iter().map(s => s.icon)) {
    if icon is Some(icon) {
      if !@symbols.known(icon) {
        diagnostics.push(
          @diagrams.Diagnostic::warning(
            "architecture/unknown-icon",
            "Unresolved icon " + icon.pack + ":" + icon.key,
          ),
        )
      }
      let id = @symbols.asset_id(icon, prefix)
      if !used.contains(id) && @symbols.known(icon) {
        used[id] = true
        defs.push(@symbols.definition_node(icon, prefix))
      }
    }
  }
  let groups = []
  let nodes = []
  let paths = []
  // Groups are painted outside-in; their shapes were resolved inside-out.
  for i = g.shapes.length() - 1; i >= 0; i = i - 1 {
    let shape = g.shapes[i]
    if shape.kind != Group {
      continue
    }
    let children = [
      architecture_rect(
        shape.box,
        p.color("external-fill"),
        p.color("external-stroke"),
        "architecture-group",
      ),
      architecture_label(
        p,
        shape.label,
        shape.box.x + shape.box.width / 2,
        shape.box.y + 23,
        "group-label",
      ),
    ]
    for group in model.groups {
      if group.id == shape.id {
        if group.icon is Some(icon) {
          children.push(
            @symbols.paint_node(
              icon,
              prefix,
              (shape.box.x + 8).to_double(),
              (shape.box.y + 8).to_double(),
              24.0,
            ),
          )
          if !@symbols.known(icon) {
            children.push(
              architecture_label(
                p,
                icon.key,
                shape.box.x + shape.box.width / 2,
                shape.box.y + 30 + shape.label.split("\n").count() * 18,
                "unknown-icon-label",
              ),
            )
          }
        }
      }
    }
    groups.push(
      @writer.element(
        "g",
        attrs=[("class", "architecture-group"), ("data-id", shape.id)],
        children~,
      ),
    )
  }
  for shape in g.shapes {
    if shape.kind == Group {
      continue
    }
    let attrs = [
      (
        "class",
        if shape.kind == Junction {
          "architecture-junction"
        } else {
          "architecture-service"
        },
      ),
      ("data-id", shape.id),
    ]
    let children = []
    if shape.kind == Junction {
      children.push(
        @writer.element("circle", attrs=[
          ("cx", (shape.box.x + shape.box.width / 2).to_string()),
          ("cy", (shape.box.y + shape.box.height / 2).to_string()),
          ("r", "8"),
          ("fill", p.color("arrow")),
        ]),
      )
    } else {
      children.push(
        architecture_rect(
          shape.box,
          p.color("backend-fill"),
          p.color("backend-stroke"),
          "service-box",
        ),
      )
      for service in model.services {
        if service.id != shape.id {
          continue
        }
        if service.icon is Some(icon) {
          children.push(
            @symbols.paint_node(
              icon,
              prefix,
              (shape.box.x + shape.box.width / 2 - 20).to_double(),
              (shape.box.y + 12).to_double(),
              40.0,
            ),
          )
          if !@symbols.known(icon) {
            children.push(
              architecture_label(
                p,
                icon.key,
                shape.box.x + shape.box.width / 2,
                shape.box.y + 65,
                "unknown-icon-label",
              ),
            )
          }
        } else if service.icon_text is Some(text) {
          children.push(
            architecture_label(
              p,
              text,
              shape.box.x + shape.box.width / 2,
              shape.box.y + 38,
              "literal-icon",
            ),
          )
        }
      }
      children.push(
        architecture_label(
          p,
          shape.label,
          shape.box.x + shape.box.width / 2,
          shape.box.y +
          shape.box.height -
          22 -
          (shape.label.split("\n").count() - 1) * 18,
          "service-label",
        ),
      )
    }
    nodes.push(@writer.element("g", attrs~, children~))
  }
  for i, route in g.connections {
    let edge = route.connection
    let attrs = [
      ("class", "architecture-path"),
      ("d", architecture_path(route.points)),
      ("fill", "none"),
      ("stroke", p.color("arrow")),
      ("stroke-width", "1.5"),
    ]
    for (end, head) in [("start", edge.source_head), ("end", edge.target_head)] {
      if head {
        let id = prefix + "head-" + i.to_string() + "-" + end
        defs.push(marker(id, Arrow, p.color("arrow"), false))
        attrs.push(("marker-" + end, "url(#" + id + ")"))
      }
    }
    let children = [@writer.element("path", attrs~)]
    if route.label_box is Some(box) {
      children.push(
        architecture_rect(box, p.color("mask"), "none", "edge-label-mask"),
      )
      children.push(
        architecture_label(
          p,
          edge.label.unwrap_or(""),
          box.x + box.width / 2,
          box.y + 14,
          "edge-label",
        ),
      )
    }
    paths.push(
      @writer.element(
        "g",
        attrs=[
          ("class", "architecture-connection"),
          ("data-id", edge.id),
          ("data-from", edge.source.id),
          ("data-to", edge.target.id),
        ],
        children~,
      ),
    )
  }
  let children = [
    @writer.element("title", children=[
      @writer.text(
        model.accessibility_title.unwrap_or(
          model.title.unwrap_or("Architecture diagram"),
        ),
      ),
    ]),
    @writer.element("desc", children=[
      @writer.text(
        model.accessibility_description.unwrap_or(
          "Architecture diagram of authored services, junctions and connections.",
        ),
      ),
    ]),
    @writer.element("defs", children=defs),
    @writer.element("rect", attrs=[
      ("class", "bg"),
      ("x", "0"),
      ("y", "0"),
      ("width", g.width.to_string()),
      ("height", g.height.to_string()),
      ("fill", p.color("bg")),
    ]),
    @writer.element(
      "g",
      attrs=[("class", "architecture-groups")],
      children=groups,
    ),
    @writer.element(
      "g",
      attrs=[("class", "architecture-connections")],
      children=paths,
    ),
    @writer.element(
      "g",
      attrs=[("class", "architecture-nodes")],
      children=nodes,
    ),
  ]
  if model.title is Some(title) {
    children.push(
      architecture_label(p, title, g.width / 2, 24, "diagram-title"),
    )
  }
  let svg = @writer.to_string(
    @writer.element(
      "svg",
      attrs=[
        ("xmlns", "http://www.w3.org/2000/svg"),
        ("id", prefix + "diagram"),
        ("viewBox", "0 0 " + g.width.to_string() + " " + g.height.to_string()),
        ("width", g.width.to_string()),
        ("height", g.height.to_string()),
        ("role", "img"),
        ("data-diagram", "architecture"),
      ],
      children~,
    ),
  )
  if svg.length() > limits.output_units {
    return @render.Rendered::failed("image/svg+xml", [
      @diagrams.Diagnostic::error(
        "architecture/output-limit", "SVG output budget exhausted",
      ),
    ])
  }
  for
    palette in (match mode {
      Fixed(Dark) => [theme.dark]
      Fixed(Light) => [theme.light]
      Adaptive => [theme.dark, theme.light]
    }) {
    for finding in @architecture_layout.check(g, palette~) {
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "architecture/legibility",
          finding.code + ": " + finding.message + " " + finding.element,
        ),
      )
    }
  }
  @render.Rendered::ok(svg, "image/svg+xml", diagnostics=diagnostics[:])
}

///|
pub fn render_architecture(
  model : @architecture.Architecture,
  theme~ : @theme.Theme = @theme.Theme::classic(),
  mode~ : Mode = Adaptive,
  id_prefix? : String,
  limits~ : @architecture_layout.Limits = @architecture_layout.Limits::new(),
) -> @render.Rendered {
  paint_architecture(model, theme, mode, id_prefix, limits)
}
