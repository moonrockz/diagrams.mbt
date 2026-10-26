///|
/// The motion for one occurrence: a visit for a node target, or a connection
/// step with the given orientation.
pub fn Catalog::motion(
  self : Catalog,
  key : String,
  duration_ms : Int64,
  reversed : Bool,
) -> Motion {
  match self.occurrence(key) {
    Some(occurrence) if occurrence.is_visit() => Visit(key, duration_ms)
    _ => OrientedStep(key, duration_ms, reversed)
  }
}

///|
/// The occurrence key of a railroad term or connector identity.
pub fn railroad_key(view_id : String, id : String) -> String {
  "railroad:\{view_id.length()}:\{view_id}:\{id.length()}:\{id}"
}

///|
/// The occurrence key of a data member row, data box or data connector.
pub fn data_key(view_id : String, kind : String, id : String) -> String {
  "data:\{view_id.length()}:\{view_id}:\{kind}:\{id.length()}:\{id}"
}

///|
/// The rule identity that an EBNF reference term resolves to. A reference is
/// an inspectable target; no route edge joins the two rules.
pub fn Catalog::reference_target(self : Catalog, key : String) -> String? {
  match self.occurrence(key).bind(o => o.railroad_term) {
    Some({ kind: Reference(Resolved(rule)), .. }) => Some(rule)
    _ => None
  }
}

///|
fn point_label(topology : @railroad_trace.Topology) -> Map[String, String] {
  let labels : Map[String, String] = Map([])
  for track in topology.tracks {
    labels[track.start] = "start of " + track.name
    labels[track.end] = "end of " + track.name
  }
  for term in topology.terms {
    if !labels.contains(term.entry) {
      labels[term.entry] = "before " + term.label
    }
    if !labels.contains(term.exit) {
      labels[term.exit] = "after " + term.label
    }
  }
  for connector in topology.connectors {
    for point in [connector.from, connector.to] {
      if !labels.contains(point) {
        labels[point] = connector.role.name() + " junction of " + connector.owner
      }
    }
  }
  labels
}

///|
/// Build a catalog from a railroad topology. Terms are node visits and drawn
/// connectors are paths, both in drawing-walk order. Graph nodes are points;
/// graph edges are connectors and term traversals.
fn railroad_catalog(
  source : @render.Diagram,
  topology : @railroad_trace.Topology,
  limits : Limits,
) -> CatalogResult {
  let build = builder(source, topology.model_id, limits)
  let budget = build.budget
  if budget.failed {
    return build.finish()
  }
  if topology.terms.length() + topology.connectors.length() > limits.edges {
    budget.error(
      "animation/plan-limit", "Railroad catalog exceeds its occurrence limit",
    )
    return build.finish()
  }
  let labels = point_label(topology)
  let added : Map[String, Bool] = Map([])
  fn point(id : String) {
    if !added.contains(id) {
      added[id] = true
      build.node({
        id,
        label: labels.get(id).unwrap_or(id),
        kind: RailroadPoint,
        occurrence: None,
        source_node: None,
        swimlane_node: None,
      })
    }
  }
  for track in topology.tracks {
    point(track.start)
  }
  for i, step in topology.walk {
    if budget.failed {
      break
    }
    match step {
      Visit(id, _) => {
        guard topology.term(id) is Some(term) else { continue }
        let key = railroad_key(topology.model_id, id)
        point(term.entry)
        point(term.exit)
        build.flows[id] = build.occurrences.length()
        build.occurrence({
          key,
          index: i,
          kind: Visit(RailroadTerm(term.kind)),
          path: [],
          source: None,
          flow: None,
          message: None,
          swimlane_connection: None,
          railroad_connector: None,
          railroad_term: Some(term),
          data_member: None,
          data_node: None,
        })
        build.edge({
          kind: Railroad,
          source: term.entry,
          target: term.exit,
          occurrence: Some(key),
          reversed: false,
        })
      }
      Traverse(id, _) => {
        guard topology.connector(id) is Some(connector) else { continue }
        let key = railroad_key(topology.model_id, id)
        point(connector.from)
        point(connector.to)
        build.flows[id] = build.occurrences.length()
        build.occurrence({
          key,
          index: i,
          kind: Railroad(connector.role),
          path: [],
          source: None,
          flow: None,
          message: None,
          swimlane_connection: None,
          railroad_connector: Some(connector),
          railroad_term: None,
          data_member: None,
          data_node: None,
        })
        build.edge({
          kind: Railroad,
          source: connector.from,
          target: connector.to,
          occurrence: Some(key),
          reversed: false,
        })
      }
    }
  }
  build.finish()
}

///|
/// A catalog of a regex railroad: terms are visits, connectors are paths.
pub fn Catalog::regex(
  model : @regex.Regex,
  limits? : Limits = Limits::new(),
) -> CatalogResult {
  let built = @railroad_trace.Topology::regex(
    model,
    limits=@regex.Limits::new(
      nodes=limits.nodes,
      depth=limits.depth,
      work=limits.work,
    ),
  )
  guard built.topology is Some(topology) else {
    return { catalog: None, diagnostics: built.diagnostics }
  }
  railroad_catalog(Regex(model), topology, limits)
}

///|
/// A catalog of a grammar railroad. References are inspectable visit targets;
/// they never add an edge to another rule.
pub fn Catalog::ebnf(
  grammar : @ebnf.Grammar,
  limits? : Limits = Limits::new(),
) -> CatalogResult {
  let built = @railroad_trace.Topology::ebnf(
    grammar,
    limits=@ebnf.Limits::new(
      nodes=limits.nodes,
      depth=limits.depth,
      work=limits.work,
    ),
  )
  guard built.topology is Some(topology) else {
    return { catalog: None, diagnostics: built.diagnostics }
  }
  railroad_catalog(Ebnf(grammar), topology, limits)
}

///|
/// A catalog of a data tree. Every box and member row is a visit target.
/// A connector exists only from a row to a nested container box. The graph
/// has containment edges between values and no other relation.
pub fn Catalog::data_tree(
  tree : @data_tree.DataTree,
  limits? : Limits = Limits::new(),
) -> CatalogResult {
  let build = builder(DataTree(tree), tree.id, limits)
  let budget = build.budget
  if budget.failed {
    return build.finish()
  }
  let indexed = @data_tree.Index::build(
    tree,
    limits=@data_tree.Limits::new(
      nodes=limits.nodes,
      depth=limits.depth,
      work=limits.work,
    ),
  )
  guard indexed.index is Some(index) else {
    budget.diagnostics.append(indexed.diagnostics)
    budget.failed = true
    return build.finish()
  }
  fn value_label(id : String) -> String {
    match index.owner(id) {
      None => "root"
      Some(entry) =>
        match entry.key {
          Name(name) => name
          Index(i) => "[\{i}]"
        }
    }
  }
  for id in index.order {
    if budget.failed {
      break
    }
    let node = index.node(id).unwrap()
    let owner = index.owner(id)
    // A container, and the root, has its own box. A nested scalar is shown
    // in its owner's row.
    let visit = if node.is_container() || owner == None {
      let key = data_key(tree.id, "box", id)
      build.occurrence({
        key,
        index: build.occurrences.length(),
        kind: Visit(DataBox),
        path: [],
        source: None,
        flow: None,
        message: None,
        swimlane_connection: None,
        railroad_connector: None,
        railroad_term: None,
        data_member: None,
        data_node: Some(node),
      })
      key
    } else {
      data_key(tree.id, "row", owner.unwrap().id)
    }
    build.node({
      id,
      label: value_label(id),
      kind: DataValue,
      occurrence: Some(visit),
      source_node: None,
      swimlane_node: None,
    })
    for entry in node.members() {
      let row = data_key(tree.id, "row", entry.id)
      build.flows[entry.id] = build.occurrences.length()
      build.occurrence({
        key: row,
        index: build.occurrences.length(),
        kind: Visit(DataRow),
        path: [],
        source: None,
        flow: None,
        message: None,
        swimlane_connection: None,
        railroad_connector: None,
        railroad_term: None,
        data_member: Some(entry),
        data_node: index.node(entry.value),
      })
      let child = index.node(entry.value).unwrap()
      let connector = if child.is_container() {
        let key = data_key(tree.id, "link", entry.id)
        build.occurrence({
          key,
          index: build.occurrences.length(),
          kind: DataConnector,
          path: [],
          source: None,
          flow: None,
          message: None,
          swimlane_connection: None,
          railroad_connector: None,
          railroad_term: None,
          data_member: Some(entry),
          data_node: Some(child),
        })
        Some(key)
      } else {
        None
      }
      build.edge({
        kind: Containment,
        source: id,
        target: entry.value,
        occurrence: connector,
        reversed: false,
      })
    }
  }
  build.finish()
}
