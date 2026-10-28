///|
/// A structural state catalog. Ownership, history and descriptions add no arcs.
pub fn Catalog::state(
  view : @state.StateDiagram,
  limits~ : Limits = Limits::new(),
) -> CatalogResult {
  let build = builder(State(view), view.id, limits)
  let budget = build.budget
  if budget.failed {
    return build.finish()
  }
  let findings = @state.validate(
    view,
    nodes_limit=limits.nodes,
    regions_limit=limits.nodes,
    edges_limit=limits.edges,
    depth_limit=limits.depth,
    work_limit=limits.work,
  )
  if !findings.is_empty() {
    budget.diagnostics.append(findings)
    budget.failed = true
    return build.finish()
  }
  let states : Map[String, @state.State] = Map(view.states.map(s => (s.id, s)))
  let regions : Map[String, @state.Region] = Map(
    view.regions.map(r => (r.id, r)),
  )
  fn visible(region : String) -> Bool {
    let mut current = Some(region)
    let mut depth = 0
    while current is Some(id) {
      if !budget.charge(1) {
        return false
      }
      if depth >= limits.depth {
        budget.error(
          "animation/plan-limit", "State containment depth limit exceeded",
        )
        return false
      }
      depth += 1
      match regions.get(id).bind(r => r.owner).bind(id => states.get(id)) {
        Some(owner) => {
          if !owner.expanded {
            return false
          }
          current = Some(owner.region)
        }
        None => current = None
      }
    }
    true
  }
  fn visit(id : String, kind : VisitKind, index : Int32) -> String {
    let key = "state-visit:\{view.id.length()}:\{view.id}:\{id.length()}:\{id}"
    build.occurrence({
      key,
      index,
      kind: Visit(kind),
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
    key
  }
  for state in view.states {
    if visible(state.region) {
      let key = visit(
        state.id,
        StateNode(state.role),
        build.occurrences.length(),
      )
      build.node({
        id: state.id,
        label: state.label,
        kind: StateNode(state),
        occurrence: Some(key),
        source_node: None,
        swimlane_node: None,
      })
    } else {
      build.outside[state.id] = true
    }
  }
  for region in view.regions {
    if visible(region.id) {
      build.node({
        id: region.id,
        label: region.id,
        kind: StateRegion(region),
        occurrence: None,
        source_node: None,
        swimlane_node: None,
      })
    } else {
      build.outside[region.id] = true
    }
  }
  for note in view.notes {
    if visible(note.region) {
      let key = visit(note.id, StateNote, build.occurrences.length())
      build.node({
        id: note.id,
        label: note.text,
        kind: StateNote(note),
        occurrence: Some(key),
        source_node: None,
        swimlane_node: None,
      })
    } else {
      build.outside[note.id] = true
    }
  }
  fn anchor(id : String) -> String? {
    let mut current = id
    let mut depth = 0
    while !build.indices.contains(current) {
      if !budget.charge(1) {
        return None
      }
      if depth >= limits.depth {
        budget.error(
          "animation/plan-limit", "State display-anchor depth limit exceeded",
        )
        return None
      }
      depth += 1
      guard states
        .get(current)
        .bind(s => regions.get(s.region))
        .bind(r => r.owner)
        is Some(owner) else {
        return None
      }
      current = owner
    }
    Some(current)
  }
  for index, edge in view.transitions {
    if !budget.charge(
        edge.id.length() + edge.source.length() + edge.target.length() + 1,
      ) {
      return build.finish()
    }
    if edge.style == Invisible {
      continue
    }
    let a = anchor(edge.source)
    let b = anchor(edge.target)
    if a == None || b == None {
      continue
    }
    if a == b &&
      (
        !build.indices.contains(edge.source) ||
        !build.indices.contains(edge.target)
      ) {
      continue
    }
    let key = "state:\{view.id.length()}:\{view.id}:\{edge.id.length()}:\{edge.id}"
    build.flows[edge.id] = build.occurrences.length()
    build.occurrence({
      key,
      index,
      kind: State(edge),
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
    if !build.indices.contains(edge.source) ||
      !build.indices.contains(edge.target) {
      continue
    }
    let kind = if edge.direction == Undirected {
      EdgeKind::Undirected
    } else {
      StateTransition
    }
    if edge.direction != Backward {
      build.edge({
        kind,
        source: edge.source,
        target: edge.target,
        occurrence: Some(key),
        reversed: false,
      })
    }
    if edge.direction == Backward ||
      edge.direction == Both ||
      edge.direction == Undirected {
      build.edge({
        kind,
        source: edge.target,
        target: edge.source,
        occurrence: Some(key),
        reversed: true,
      })
    }
  }
  build.finish()
}
