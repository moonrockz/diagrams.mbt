///|
fn DocumentGraph::endpoint(self : DocumentGraph, endpoint : GraphEndpoint, limits : GraphLimits) -> Result[Int,GraphFailure] {
  let candidates=match endpoint {
    Node(handle) => {
      for i in 0..<self.trees.length() {
        let tree=self.trees[i]
        if tree.revision.resource_id != handle.revision.resource_id { continue }
        match tree.lookup(handle) { Found(_) => return Ok(self.offsets[i]+handle.ordinal); DocumentMismatch => return Err(DocumentMismatch); InvalidHandle => return Err(InvalidEndpoint) }
      }
      return Err(DocumentMismatch)
    }
    Id(id) => { if id.length() > limits.work { return Err(Limit(Work)) }; self.local_ids.get(id).unwrap_or([]) }
    Qualified(name) => { if name.namespace_uri.length() > limits.work || name.local_name.length() > limits.work-name.namespace_uri.length() { return Err(Limit(Work)) }; if name.namespace_uri == "" { self.local_ids.get(name.local_name).unwrap_or([]) } else { self.qualified_ids.get((name.namespace_uri,name.local_name)).unwrap_or([]) } }
    Symbol(symbol) => { if symbol.resource_id.length() > limits.work || symbol.name.namespace_uri.length() > limits.work-symbol.resource_id.length() || symbol.name.local_name.length() > limits.work-symbol.resource_id.length()-symbol.name.namespace_uri.length() { return Err(Limit(Work)) }; self.symbols.get((symbol.resource_id,symbol.name.namespace_uri,symbol.name.local_name)).unwrap_or([]) }
  }
  if candidates.length() > limits.results { return Err(Limit(Results)) }
  if candidates.length() == 1 { Ok(candidates[0]) }
  else if candidates.is_empty() { Err(InvalidEndpoint) }
  else { Err(Ambiguous(candidates.map(i => self.nodes[i]))) }
}

///|
pub fn DocumentGraph::lookup(self : DocumentGraph, endpoint : GraphEndpoint, limits? : GraphLimits = GraphLimits::new()) -> Result[GraphNode,GraphFailure] {
  if !limits.valid() { return Err(InvalidLimits) }
  match self.endpoint(endpoint,limits) { Ok(i) => Ok(self.nodes[i]); Err(failure) => Err(failure) }
}

///|
fn selected_kinds(kinds : ArrayView[GraphEdgeKind]) -> Array[GraphEdgeKind] {
  let selected : Array[GraphEdgeKind] = []
  for kind in kinds { if !selected.contains(kind) { selected.push(kind) } }
  selected
}

///|
fn bounded_failure(failure : GraphFailure, limits : GraphLimits) -> GraphFailure {
  match failure { Ambiguous(nodes) if nodes.length() > limits.results => Limit(Results); _ => failure }
}

///|
priv struct ArcStream { arcs : ReadOnlyArray[GraphArc]; mut next : Int }

///|
fn DocumentGraph::streams(self : DocumentGraph, node : Int, kinds : ArrayView[GraphEdgeKind], direction : GraphDirection) -> Array[ArcStream] {
  let streams : Array[ArcStream] = []
  let seen : Map[Int,Bool] = Map([])
  for kind in kinds {
    let tag=kind.tag(); if seen.contains(tag) { continue }; seen[tag]=true
    if direction != Reverse && self.outgoing.get((node,tag)) is Some(arcs) { streams.push({arcs,next:0}) }
    if direction != Forward && self.incoming.get((node,tag)) is Some(arcs) { streams.push({arcs,next:0}) }
  }
  streams
}

///|
fn next_arc(streams : Array[ArcStream]) -> GraphArc? {
  let mut chosen : Int? = None
  for i in 0..<streams.length() {
    let stream=streams[i]
    if stream.next >= stream.arcs.length() { continue }
    let candidate=stream.arcs[stream.next]
    let earlier=chosen.map(j => { let old=streams[j].arcs[streams[j].next]; candidate.order < old.order || (candidate.order == old.order && candidate.serial < old.serial) }).unwrap_or(true)
    if earlier { chosen=Some(i) }
  }
  chosen.map(i => { let stream=streams[i]; let arc=stream.arcs[stream.next]; stream.next+=1; arc })
}

///|
/// Breadth-first discovery, including the start once. References, coordinates
/// and XML order never create implicit control-flow edges.
pub fn DocumentGraph::reachable(self : DocumentGraph, start : GraphEndpoint, kinds? : ArrayView[GraphEdgeKind] = [SequenceFlow], direction? : GraphDirection = Forward, limits? : GraphLimits = GraphLimits::new()) -> ReachabilityResult {
  if !limits.valid() { return Failed(InvalidLimits) }
  if kinds.length() > limits.work { return Failed(Limit(Work)) }
  let initial_work=kinds.length(); let kinds=selected_kinds(kinds)
  let start=match self.endpoint(start,limits) { Ok(n) => n; Err(failure) => return Failed(failure) }
  let visited : Map[Int,Bool] = Map([(start,true)])
  let queue=[start]; let mut at=0; let mut edges=0; let mut work=initial_work
  while at < queue.length() {
    if work >= limits.work { return Failed(Limit(Work)) }; work+=1
    let current=queue[at]; at+=1
    let streams=self.streams(current,kinds,direction)
    while next_arc(streams) is Some(arc) {
      if edges >= limits.edges { return Failed(Limit(Edges)) }; edges+=1
      if work >= limits.work { return Failed(Limit(Work)) }; work+=1
      if arc.failure is Some(failure) { return Failed(bounded_failure(failure,limits)) }
      guard arc.neighbor is Some(next) else { continue }
      if visited.contains(next) { continue }
      if queue.length() >= limits.nodes { return Failed(Limit(Nodes)) }
      if queue.length() >= limits.results { return Failed(Limit(Results)) }
      visited[next]=true; queue.push(next)
    }
  }
  Complete(ReadOnlyArray::from_array(queue.map(i => self.nodes[i])))
}

///|
fn DocumentGraph::route_value(self : DocumentGraph, start : Int, target : Int, predecessors : Map[Int,(Int,Int)], limits : GraphLimits) -> RouteResult {
  let reversed_nodes=[target]; let reversed_edges : Array[Int] = []; let mut current=target
  while current != start {
    if reversed_nodes.length() >= limits.results { return Failed(Limit(Results)) }
    let (previous,edge)=predecessors[current]; reversed_edges.push(edge); reversed_nodes.push(previous); current=previous
  }
  Found({nodes:ReadOnlyArray::from_array(Array::makei(reversed_nodes.length(),i => self.nodes[reversed_nodes[reversed_nodes.length()-1-i]])),edges:ReadOnlyArray::from_array(Array::makei(reversed_edges.length(),i => self.edges[reversed_edges[reversed_edges.length()-1-i]]))})
}

///|
/// One shortest route. The first differing authored connection in document
/// order breaks ties. Reverse traversal keeps authored edge endpoints intact.
pub fn DocumentGraph::route(self : DocumentGraph, start : GraphEndpoint, target : GraphEndpoint, kinds? : ArrayView[GraphEdgeKind] = [SequenceFlow], direction? : GraphDirection = Forward, limits? : GraphLimits = GraphLimits::new()) -> RouteResult {
  if !limits.valid() { return Failed(InvalidLimits) }
  if kinds.length() > limits.work { return Failed(Limit(Work)) }
  let initial_work=kinds.length(); let kinds=selected_kinds(kinds)
  let start=match self.endpoint(start,limits) { Ok(n) => n; Err(failure) => return Failed(failure) }
  let target=match self.endpoint(target,limits) { Ok(n) => n; Err(failure) => return Failed(failure) }
  let predecessors : Map[Int,(Int,Int)] = Map([])
  if start == target { return self.route_value(start,target,predecessors,limits) }
  let visited : Map[Int,Bool] = Map([(start,true)])
  let queue=[start]; let mut at=0; let mut edges=0; let mut work=initial_work
  while at < queue.length() {
    if work >= limits.work { return Failed(Limit(Work)) }; work+=1
    let current=queue[at]; at+=1
    let streams=self.streams(current,kinds,direction)
    while next_arc(streams) is Some(arc) {
      if edges >= limits.edges { return Failed(Limit(Edges)) }; edges+=1
      if work >= limits.work { return Failed(Limit(Work)) }; work+=1
      if arc.failure is Some(failure) { return Failed(bounded_failure(failure,limits)) }
      guard arc.neighbor is Some(next) && arc.edge is Some(edge) else { continue }
      if visited.contains(next) { continue }
      if queue.length() >= limits.nodes { return Failed(Limit(Nodes)) }
      visited[next]=true; predecessors[next]=(current,edge); queue.push(next)
      if next == target { return self.route_value(start,target,predecessors,limits) }
    }
  }
  Unreachable
}
