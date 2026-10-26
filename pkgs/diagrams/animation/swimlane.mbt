///|
/// Swimlane paths are structural connections. Containment never adds an arc.
pub fn Catalog::swimlane(
  view : @swimlane.Swimlane,
  limits~ : Limits = Limits::new(),
) -> CatalogResult {
  let build = builder(Swimlane(view), view.id, limits)
  let budget = build.budget
  if budget.failed {
    return build.finish()
  }
  if view.nodes.length() + view.groups.length() + view.lanes.length() >
    limits.nodes ||
    view.connections.length() > limits.edges {
    budget.error(
      "animation/plan-limit", "Swimlane catalog exceeds its element limits",
    )
    return build.finish()
  }
  let findings = @swimlane.validate(
    view,
    nodes_limit=limits.nodes,
    edges_limit=limits.edges,
    depth_limit=limits.depth,
    work_limit=limits.work,
  )
  if !findings.is_empty() {
    budget.diagnostics.append(findings)
    budget.failed = true
    return build.finish()
  }
  let groups : Map[String, @swimlane.Group] = Map([])
  let lanes : Map[String, @swimlane.Lane] = Map([])
  for group in view.groups {
    groups[group.id] = group
  }
  for lane in view.lanes {
    lanes[lane.id] = lane
  }
  fn visible(lane : String?, parent : String?) -> Bool {
    if lane.bind(id => lanes.get(id)) is Some(lane) && !lane.expanded {
      return false
    }
    let mut cursor = parent
    let mut depth = 0
    while cursor is Some(id) {
      if !budget.charge(1) {
        return false
      }
      if depth >= limits.depth {
        budget.error(
          "animation/plan-limit", "Swimlane containment depth limit exceeded",
        )
        return false
      }
      depth += 1
      guard groups.get(id) is Some(group) else {
        budget.error("animation/invalid-identity", "Missing swimlane group")
        return false
      }
      if !group.expanded {
        return false
      }
      cursor = group.parent
    }
    true
  }
  for lane in view.lanes {
    build.node({
      id: lane.id,
      label: lane.label,
      kind: SwimlaneLane,
      occurrence: None,
      source_node: None,
      swimlane_node: None,
    })
  }
  for group in view.groups {
    if visible(group.lane, group.parent) {
      build.node({
        id: group.id,
        label: group.label,
        kind: SwimlaneGroup,
        occurrence: None,
        source_node: None,
        swimlane_node: None,
      })
    } else {
      build.outside[group.id] = true
    }
  }
  for node in view.nodes {
    if visible(node.lane, node.groups.last()) {
      build.node({
        id: node.id,
        label: node.label,
        kind: SwimlaneNode,
        occurrence: None,
        source_node: None,
        swimlane_node: Some(node),
      })
    } else {
      build.outside[node.id] = true
    }
  }
  if budget.failed {
    return build.finish()
  }
  let parents : Map[String, String] = Map([])
  for group in view.groups {
    if (match group.parent {
        Some(_) => group.parent
        None => group.lane
      })
      is Some(parent) {
      parents[group.id] = parent
    }
  }
  for node in view.nodes {
    if (match node.groups.last() {
        Some(id) => Some(id)
        None => node.lane
      })
      is Some(parent) {
      parents[node.id] = parent
    }
  }
  fn display_anchor(id : String) -> String? {
    let mut current = id
    let mut depth = 0
    while !build.indices.contains(current) {
      if !budget.charge(1) {
        return None
      }
      if depth >= limits.depth {
        budget.error(
          "animation/plan-limit", "Swimlane display-anchor depth limit exceeded",
        )
        return None
      }
      depth += 1
      guard parents.get(current) is Some(parent) else { return None }
      current = parent
    }
    Some(current)
  }
  for i, connection in view.connections {
    if !budget.charge(
        connection.id.length() +
        connection.source.length() +
        connection.target.length() +
        1,
      ) {
      return build.finish()
    }
    if connection.style == Invisible {
      continue
    }
    if (
        !build.indices.contains(connection.source) &&
        !build.outside.contains(connection.source)
      ) ||
      (
        !build.indices.contains(connection.target) &&
        !build.outside.contains(connection.target)
      ) {
      budget.error(
        "animation/invalid-identity", "Swimlane connection endpoint is missing",
      )
      return build.finish()
    }
    let a = display_anchor(connection.source)
    let b = display_anchor(connection.target)
    if a == None || b == None {
      continue
    }
    if a == b &&
      (
        !build.indices.contains(connection.source) ||
        !build.indices.contains(connection.target)
      ) {
      continue
    }
    let key = "swimlane:\{view.id.length()}:\{view.id}:\{connection.id.length()}:\{connection.id}"
    if build.flows.contains(connection.id) {
      budget.error(
        "animation/invalid-identity", "Duplicate swimlane connection identity",
      )
      return build.finish()
    }
    build.flows[connection.id] = build.occurrences.length()
    build.occurrence({
      key,
      index: i,
      kind: Swimlane(connection.direction),
      path: [],
      source: None,
      flow: None,
      message: None,
      swimlane_connection: Some(connection),
      railroad_connector: None,
      railroad_term: None,
      data_member: None,
      data_node: None,
    })
    // A visible collapsed ancestor is only a display anchor. Its hidden child
    // remains outside the route graph while the connection can still be played.
    if !build.indices.contains(connection.source) ||
      !build.indices.contains(connection.target) {
      continue
    }
    let kind = if connection.direction == Undirected {
      EdgeKind::Undirected
    } else {
      SwimlaneFlow
    }
    if connection.direction != Backward {
      build.edge({
        kind,
        source: connection.source,
        target: connection.target,
        occurrence: Some(key),
        reversed: false,
      })
    }
    if connection.direction == Backward ||
      connection.direction == Both ||
      connection.direction == Undirected {
      build.edge({
        kind,
        source: connection.target,
        target: connection.source,
        occurrence: Some(key),
        reversed: true,
      })
    }
  }
  build.finish()
}
