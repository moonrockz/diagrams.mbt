///|
fn paint_flowchart(
  view : @flowchart.Flowchart,
  theme : @theme.Theme,
  mode : Mode,
  id_prefix : String?,
  limits : @flowchart_layout.Limits,
  geometry? : @flowchart_layout.Geometry,
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
  let geometry = match geometry {
    Some(geometry) => geometry
    None => {
      let result = @flowchart_layout.layout(view, limits~)
      guard result.geometry is Some(geometry) else {
        return @render.Rendered::failed("image/svg+xml", result.diagnostics[:])
      }
      geometry
    }
  }
  let drawing = geometry.drawing()
  let parents : Array[(String, String?)] = []
  for node in view.nodes {
    parents.push(
      (node.id, node.groups.last().map(id => Some(id)).unwrap_or(node.lane)),
    )
  }
  for note in view.notes {
    parents.push(
      (note.id, note.groups.last().map(id => Some(id)).unwrap_or(note.lane)),
    )
  }
  for group in view.groups {
    parents.push(
      (group.id, group.parent.map(id => Some(id)).unwrap_or(group.lane)),
    )
  }
  let rendered = paint_swimlane(
    drawing.view,
    theme,
    mode,
    id_prefix,
    @swimlane_layout.Limits::new(
      nodes=limits.nodes,
      edges=limits.edges,
      depth=limits.depth,
      work=limits.work,
      output_units=limits.output_units,
    ),
    connectors~,
    precomputed=geometry.drawing_result(),
    kind="flowchart",
    intentional_containment=geometry.intentional_containment()[:],
    hidden_containers=geometry.hidden_containers()[:],
    parent_overrides=parents[:],
  )
  let diagnostics = @flowchart_layout.diagnostics(
    geometry
    .prior_diagnostics()
    .iter()
    .concat(rendered.diagnostics.iter())
    .to_array()[:],
  )
  match rendered.output {
    Some(output) =>
      @render.Rendered::ok(output, "image/svg+xml", diagnostics=diagnostics[:])
    None => @render.Rendered::failed("image/svg+xml", diagnostics[:])
  }
}

///|
/// Render a standalone flowchart using the shared themes and vector primitives.
pub fn render_flowchart(
  view : @flowchart.Flowchart,
  theme~ : @theme.Theme = @theme.Theme::classic(),
  mode~ : Mode = Adaptive,
  id_prefix? : String,
  limits~ : @flowchart_layout.Limits = @flowchart_layout.Limits::new(),
  connectors~ : ConnectorOptions = ConnectorOptions::new(),
) -> @render.Rendered {
  paint_flowchart(view, theme, mode, id_prefix, limits, connectors~)
}

///|
pub fn flowchart_path(edge : @flowchart_layout.Connection) -> String {
  let out = StringBuilder()
  for i, p in edge.line {
    out.write_string(
      "\{if i == 0 { "M" } else { " L" }}\{@swimlane_layout.svg_number(p.x)} \{@swimlane_layout.svg_number(p.y)}",
    )
  }
  out.to_string()
}
