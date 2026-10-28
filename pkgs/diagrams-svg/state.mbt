///|
fn paint_state(
  view : @state.StateDiagram,
  theme : @theme.Theme,
  mode : Mode,
  id_prefix : String?,
  limits : @state_layout.Limits,
  geometry? : @state_layout.Geometry,
  connectors~ : ConnectorOptions = ConnectorOptions::new(),
) -> @render.Rendered {
  if !connector_options_valid(connectors) {
    return @render.Rendered::failed("image/svg+xml", [
      @diagrams.Diagnostic::error(
        "connector/invalid-option", "Invalid connector options",
      ),
    ])
  }
  let connectors = if connectors.style == None {
    { ..connectors, style: Some(Rounded), }
  } else {
    connectors
  }
  let limits = limits.with_minimum_approach(connectors.minimum_approach)
  let geometry = match geometry {
    Some(geometry) => geometry
    None => {
      let result = @state_layout.layout(view, limits~)
      guard result.geometry is Some(geometry) else {
        return @render.Rendered::failed("image/svg+xml", result.diagnostics[:])
      }
      geometry
    }
  }
  let graph = geometry.drawing()
  let drawing = geometry.drawing_result().geometry.unwrap()
  let parents : Array[(String, String?)] = []
  for node in view.states {
    parents.push((node.id, Some(node.region)))
  }
  for note in view.notes {
    parents.push((note.id, Some(note.region)))
  }
  for region in view.regions {
    parents.push((region.id, region.owner))
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
    kind="state",
    state_view=view,
    boundary_attachments=geometry.boundaries[:],
    intentional_containment=graph.intentional_containment()[:],
    hidden_containers=graph.hidden_containers()[:],
    parent_overrides=parents[:],
  )
  let diagnostics = @state_layout.diagnostics(
    graph
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
/// Render a standalone state using the shared themes and vector primitives.
pub fn render_state(
  view : @state.StateDiagram,
  theme~ : @theme.Theme = @theme.Theme::classic(),
  mode~ : Mode = Adaptive,
  id_prefix? : String,
  limits~ : @state_layout.Limits = @state_layout.Limits::new(),
  connectors~ : ConnectorOptions = ConnectorOptions::new(),
) -> @render.Rendered {
  paint_state(view, theme, mode, id_prefix, limits, connectors~)
}

///|
pub fn state_path(edge : @state_layout.Connection) -> String {
  let out = StringBuilder()
  for i, p in edge.line {
    out.write_string(
      "\{if i == 0 { "M" } else { " L" }}\{@swimlane_layout.svg_number(p.x)} \{@swimlane_layout.svg_number(p.y)}",
    )
  }
  out.to_string()
}
