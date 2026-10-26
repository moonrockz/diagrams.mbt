///|
/// Authored architecture connections define the graph. Groups and alignments add no edges.
pub fn Catalog::architecture(
  view : @architecture.Architecture,
  limits~ : Limits = Limits::new(),
) -> CatalogResult {
  let build = builder(Architecture(view), view.id, limits)
  if build.budget.failed {
    return build.finish()
  }
  let findings = @architecture.validate(
    view,
    nodes_limit=limits.nodes,
    edges_limit=limits.edges,
    depth_limit=limits.depth,
    work_limit=limits.work,
  )
  if !findings.is_empty() {
    build.budget.diagnostics.append(findings)
    build.budget.failed = true
    return build.finish()
  }
  for group in view.groups {
    build.node({
      id: group.id,
      label: group.label,
      kind: ArchitectureGroup,
      occurrence: None,
      source_node: None,
      swimlane_node: None,
    })
  }
  for node in view.services {
    build.node({
      id: node.id,
      label: node.label,
      kind: ArchitectureService,
      occurrence: None,
      source_node: None,
      swimlane_node: None,
    })
  }
  for node in view.junctions {
    build.node({
      id: node.id,
      label: node.id,
      kind: ArchitectureJunction,
      occurrence: None,
      source_node: None,
      swimlane_node: None,
    })
  }
  for i, connection in view.connections {
    if !build.budget.charge(
        connection.id.length() +
        connection.source.id.length() +
        connection.target.id.length() +
        1,
      ) {
      return build.finish()
    }
    let key = "architecture:\{view.id.length()}:\{view.id}:\{connection.id.length()}:\{connection.id}"
    build.flows[connection.id] = build.occurrences.length()
    build.occurrence({
      key,
      index: i,
      kind: Architecture(connection),
      path: [],
      source: None,
      flow: None,
      message: None,
      swimlane_connection: None,
      railroad_connector: None,
      railroad_term: None,
      data_member: None,
      data_node: None,
    })
    let kind = if !connection.source_head && !connection.target_head {
      EdgeKind::Undirected
    } else {
      ArchitectureFlow
    }
    if connection.target_head || !connection.source_head {
      build.edge({
        kind,
        source: connection.source.id,
        target: connection.target.id,
        occurrence: Some(key),
        reversed: false,
      })
    }
    if connection.source_head || !connection.target_head {
      build.edge({
        kind,
        source: connection.target.id,
        target: connection.source.id,
        occurrence: Some(key),
        reversed: true,
      })
    }
  }
  build.finish()
}
