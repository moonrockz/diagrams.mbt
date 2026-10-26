///|
fn Graph::endpoint(
  self : Graph,
  id : String,
  limits : Limits,
) -> Result[Int32, QueryFailure] {
  if id.length() > limits.work {
    return Err(Limit(Work))
  }
  match self.indices.get(id) {
    Some(index) => Ok(index)
    None =>
      if self.outside.contains(id) {
        Err(OutsideView(id))
      } else {
        Err(InvalidEndpoint(id))
      }
  }
}

///|
pub fn Graph::lookup(
  self : Graph,
  id : String,
  limits~ : Limits = Limits::new(),
) -> Result[GraphNode, QueryFailure] {
  if !limits.valid() {
    return Err(InvalidLimits)
  }
  self.endpoint(id, limits).map(i => self.nodes[i])
}

///|
fn EdgeKind::tag(self : EdgeKind) -> Int32 {
  match self {
    SequenceFlow => 0
    MessageFlow => 1
    Order => 2
    SwimlaneFlow => 3
    Undirected => 4
    Railroad => 5
    Containment => 6
  }
}

///|
fn query_kinds(kinds : ArrayView[EdgeKind]) -> Array[EdgeKind] {
  let selected = Array::make(7, false)
  let unique = []
  for kind in kinds {
    let tag = kind.tag()
    if !selected[tag] {
      selected[tag] = true
      unique.push(kind)
    }
  }
  unique
}

///|
priv struct ArcStream {
  arcs : Array[(Int32, Int32)]
  mut next : Int32
}

///|
fn Graph::streams(
  self : Graph,
  node : Int32,
  kinds : ArrayView[EdgeKind],
  direction : Direction,
) -> Array[ArcStream] {
  let streams = []
  for kind in kinds {
    let tag = kind.tag()
    if direction != Reverse && self.outgoing.get((node, tag)) is Some(arcs) {
      streams.push({ arcs, next: 0, })
    }
    if direction != Forward && self.incoming.get((node, tag)) is Some(arcs) {
      streams.push({ arcs, next: 0, })
    }
  }
  streams
}

///|
fn next_arc(streams : ArrayView[ArcStream]) -> (Int32, Int32)? {
  let mut chosen : Int32? = None
  for i, stream in streams {
    if stream.next >= stream.arcs.length() {
      continue
    }
    let candidate = stream.arcs[stream.next]
    if chosen
      .map(j => candidate.1 < streams[j].arcs[streams[j].next].1)
      .unwrap_or(true) {
      chosen = Some(i)
    }
  }
  chosen.map(i => {
    let stream = streams[i]
    let arc = stream.arcs[stream.next]
    stream.next += 1
    arc
  })
}

///|
/// Breadth-first discovery includes the selected start once. Associations never
/// become control-flow edges; MessageFlow is explicit opt-in.
pub fn Graph::reachable(
  self : Graph,
  start : String,
  kinds~ : ArrayView[EdgeKind] = [SequenceFlow, Order, SwimlaneFlow, Railroad, Containment],
  direction~ : Direction = Forward,
  limits~ : Limits = Limits::new(),
) -> ReachabilityResult {
  if !limits.valid() {
    return Failed(InvalidLimits)
  }
  if kinds.length() > limits.work {
    return Failed(Limit(Work))
  }
  let initial_work = kinds.length()
  let kinds = query_kinds(kinds)
  let start = match self.endpoint(start, limits) {
    Ok(index) => index
    Err(failure) => return Failed(failure)
  }
  let queue = [start]
  let seen = Map([(start, true)])
  let mut cursor = 0
  let mut edges = 0
  let mut work = initial_work
  while cursor < queue.length() {
    if work >= limits.work {
      return Failed(Limit(Work))
    }
    work += 1
    let current = queue[cursor]
    cursor += 1
    let streams = self.streams(current, kinds, direction)
    let mut previous : Int32? = None
    while next_arc(streams) is Some((next, edge)) {
      if previous == Some(edge) {
        continue
      }
      previous = Some(edge)
      if work >= limits.work {
        return Failed(Limit(Work))
      }
      work += 1
      if edges >= limits.edges {
        return Failed(Limit(Edges))
      }
      edges += 1
      if seen.contains(next) {
        continue
      }
      if queue.length() >= limits.nodes {
        return Failed(Limit(Nodes))
      }
      if queue.length() >= limits.results {
        return Failed(Limit(Results))
      }
      seen[next] = true
      queue.push(next)
    }
  }
  Complete(ReadOnlyArray::from_array(queue.map(i => self.nodes[i])))
}

///|
fn Graph::route_value(
  self : Graph,
  start : Int32,
  target : Int32,
  previous : Map[Int32, (Int32, Int32)],
  direction : Direction,
  limits : Limits,
) -> RouteResult {
  let nodes = [target]
  let edges = []
  let mut current = target
  while current != start {
    if nodes.length() >= limits.results {
      return Failed(Limit(Results))
    }
    let (parent, edge) = previous[current]
    nodes.push(parent)
    edges.push(edge)
    current = parent
  }
  let ordered_nodes = Array::makei(nodes.length(), i => {
    self.nodes[nodes[nodes.length() - 1 - i]]
  })
  let ordered_edges = Array::makei(edges.length(), i => {
    self.edges[edges[edges.length() - 1 - i]]
  })
  let reversed = Array::makei(ordered_edges.length(), i => {
    ordered_edges[i].reversed !=
    (ordered_edges[i].source != ordered_nodes[i].id)
  })
  Found({
    view_id: self.view_id,
    source: self.source,
    direction,
    reversed: ReadOnlyArray::from_array(reversed),
    nodes: ReadOnlyArray::from_array(
      Array::makei(nodes.length(), i => {
        self.nodes[nodes[nodes.length() - 1 - i]]
      }),
    ),
    edges: ReadOnlyArray::from_array(
      Array::makei(edges.length(), i => {
        self.edges[edges[edges.length() - 1 - i]]
      }),
    ),
  })
}

///|
/// One shortest structural route; authored edge order breaks equal-length ties.
/// Reverse queries keep the original connection direction and identities.
pub fn Graph::route(
  self : Graph,
  start : String,
  target : String,
  kinds~ : ArrayView[EdgeKind] = [SequenceFlow, Order, SwimlaneFlow, Railroad, Containment],
  direction~ : Direction = Forward,
  limits~ : Limits = Limits::new(),
) -> RouteResult {
  if !limits.valid() {
    return Failed(InvalidLimits)
  }
  if kinds.length() > limits.work {
    return Failed(Limit(Work))
  }
  let initial_work = kinds.length()
  let kinds = query_kinds(kinds)
  let start = match self.endpoint(start, limits) {
    Ok(index) => index
    Err(failure) => return Failed(failure)
  }
  let target = match self.endpoint(target, limits) {
    Ok(index) => index
    Err(failure) => return Failed(failure)
  }
  let previous = Map([])
  if start == target {
    return self.route_value(start, target, previous, direction, limits)
  }
  let queue = [start]
  let seen = Map([(start, true)])
  let mut cursor = 0
  let mut edges = 0
  let mut work = initial_work
  while cursor < queue.length() {
    if work >= limits.work {
      return Failed(Limit(Work))
    }
    work += 1
    let current = queue[cursor]
    cursor += 1
    let streams = self.streams(current, kinds, direction)
    let mut prior : Int32? = None
    while next_arc(streams) is Some((next, edge)) {
      if prior == Some(edge) {
        continue
      }
      prior = Some(edge)
      if work >= limits.work {
        return Failed(Limit(Work))
      }
      work += 1
      if edges >= limits.edges {
        return Failed(Limit(Edges))
      }
      edges += 1
      if seen.contains(next) {
        continue
      }
      if queue.length() >= limits.nodes {
        return Failed(Limit(Nodes))
      }
      seen[next] = true
      previous[next] = (current, edge)
      queue.push(next)
      if next == target {
        return self.route_value(start, target, previous, direction, limits)
      }
    }
  }
  Unreachable
}

///|
pub fn PlaybackPlan::route(
  catalog : Catalog,
  route : Route,
  duration_ms~ : Int64 = 1000L,
  limits~ : Limits = Limits::new(),
) -> PlanResult {
  if route.view_id != catalog.view_id || route.source != catalog.source {
    return {
      plan: None,
      diagnostics: [
        @diagrams.Diagnostic::error(
          "animation/plan-mismatch", "Route and catalog name different source diagrams",
        ),
      ],
    }
  }
  let actions = []
  match catalog.source {
    Bpmn(_) =>
      for edge in route.edges {
        if edge.occurrence is Some(key) {
          actions.push(Motion::Step(key, duration_ms))
        }
      }
    Swimlane(_) =>
      for i, edge in route.edges {
        if edge.occurrence is Some(key) {
          actions.push(
            Motion::OrientedStep(key, duration_ms, route.reversed[i]),
          )
        }
      }
    Sequence(_) =>
      for node in route.nodes {
        if node.occurrence is Some(key) {
          actions.push(Motion::Step(key, duration_ms))
        }
      }
    Regex(_) | Ebnf(_) =>
      for i, edge in route.edges {
        if edge.occurrence is Some(key) {
          actions.push(catalog.motion(key, duration_ms, route.reversed[i]))
        }
      }
    DataTree(_) => {
      // A hierarchy route visits each value's row or box and follows a drawn
      // connector only where one exists. Containment has no other relation.
      if route.nodes.get(0).bind(n => n.occurrence) is Some(key) {
        actions.push(Motion::Visit(key, duration_ms))
      }
      for i, edge in route.edges {
        if edge.occurrence is Some(key) {
          actions.push(catalog.motion(key, duration_ms, route.reversed[i]))
        }
        if route.nodes.get(i + 1).bind(n => n.occurrence) is Some(key) {
          actions.push(Motion::Visit(key, duration_ms))
        }
      }
    }
  }
  PlaybackPlan::scenario(catalog, Motion::serial(actions), limits~)
}
