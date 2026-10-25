///|
priv struct Builder {
  view_id : String; source : @render.Diagram; budget : Budget
  occurrences : Array[Occurrence]; frames : Array[FrameInfo]; controls : Array[Control]
  nodes : Array[GraphNode]; edges : Array[GraphEdge]; outside : Map[String,Bool]
  indices : Map[String,Int]; keys : Map[String,Int]; flows : Map[String,Int]
}

///|
fn builder(source : @render.Diagram, view_id : String, limits : Limits) -> Builder {
  let budget=Budget::{limits,diagnostics:[],work:0,failed:false}
  if !limits.valid() { budget.error("animation/plan-limit","Animation limits must be positive and steps at most 100000") }
  ignore(budget.charge(view_id.length()))
  if view_id.is_empty() { budget.error("animation/invalid-identity","A motion catalog needs a view identity") }
  {source,view_id,budget,occurrences:[],frames:[],controls:[],nodes:[],edges:[],outside:Map([]),indices:Map([]),keys:Map([]),flows:Map([])}
}

///|
fn Builder::node(self : Builder, node : GraphNode) -> Unit {
  if !self.budget.charge(node.id.length()+node.label.length()+1) { return }
  if self.nodes.length() >= self.budget.limits.nodes { self.budget.error("animation/plan-limit","Catalog node limit exceeded"); return }
  if self.indices.contains(node.id) { self.budget.error("animation/invalid-identity","Duplicate catalog endpoint identity"); return }
  self.indices[node.id]=self.nodes.length(); self.nodes.push(node)
}

///|
fn Builder::edge(self : Builder, edge : GraphEdge) -> Unit {
  if !self.budget.charge(1) { return }
  if self.edges.length() >= self.budget.limits.edges { self.budget.error("animation/plan-limit","Catalog connection limit exceeded"); return }
  self.edges.push(edge)
}

///|
fn Builder::occurrence(self : Builder, occurrence : Occurrence) -> Unit {
  if !self.budget.charge(occurrence.key.length()+occurrence.path.length()+1) { return }
  if self.occurrences.length() >= self.budget.limits.edges { self.budget.error("animation/plan-limit","Catalog occurrence limit exceeded"); return }
  if self.keys.contains(occurrence.key) { self.budget.error("animation/invalid-identity","Duplicate occurrence identity"); return }
  self.keys[occurrence.key]=self.occurrences.length(); self.occurrences.push(occurrence)
}

///|
fn Builder::finish(self : Builder) -> CatalogResult {
  fn failed() -> CatalogResult { {catalog:None,diagnostics:ReadOnlyArray::from_array(self.budget.diagnostics)} }
  if self.budget.failed { return failed() }
  let outgoing : Map[(Int,Int),Array[(Int,Int)]]=Map([]); let incoming : Map[(Int,Int),Array[(Int,Int)]]=Map([])
  for i,edge in self.edges {
    if !self.budget.charge(1) { return failed() }
    guard self.indices.get(edge.source) is Some(a) && self.indices.get(edge.target) is Some(b) else { self.budget.error("animation/invalid-identity","Catalog connection has an invalid endpoint"); return failed() }
    let tag=edge.kind.tag()
    match outgoing.get((a,tag)) { Some(arcs) => arcs.push((b,i)); None => outgoing[(a,tag)]=[(b,i)] }
    match incoming.get((b,tag)) { Some(arcs) => arcs.push((a,i)); None => incoming[(b,tag)]=[(a,i)] }
  }
  let graph=Graph::{view_id:self.view_id,source:self.source,nodes:ReadOnlyArray::from_array(self.nodes),edges:ReadOnlyArray::from_array(self.edges),indices:self.indices,outside:self.outside,outgoing,incoming}
  {catalog:Some({view_id:self.view_id,source:self.source,occurrences:ReadOnlyArray::from_array(self.occurrences),frames:ReadOnlyArray::from_array(self.frames),controls:ReadOnlyArray::from_array(self.controls),graph,keys:self.keys,flows:self.flows}),diagnostics:[]}
}

///|
fn source_key(identity : @bpmn.SourceIdentity) -> String {
  let resource=identity.resource_id.map(id => "s\{id.length()}:\{id}").unwrap_or("n")
  let id=identity.source_id.map(id => "s\{id.length()}:\{id}").unwrap_or("n")
  resource+":"+id+":"+path_key("",identity.path)
}

///|
fn anchor(scope : @bpmn.Scope, id : String, budget : Budget) -> Int? {
  guard scope.node_index(id) is Some(start) else { return None }
  let view=scope.view; let mut i=start
  while !scope.visible[i] {
    if !budget.charge(1) { return None }
    let node=view.nodes[i]
    if node.ownership.pool is Some(id) && scope.node_index(id) is Some(pool) && view.nodes[pool].black_box { i=pool }
    else if scope.containers[i] is Some(parent) { i=parent }
    else if node.ownership.lanes.last().bind(id => scope.node_index(id)) is Some(parent) { i=parent }
    else if node.ownership.attached_to.bind(id => scope.node_index(id)) is Some(parent) { i=parent }
    else { return None }
  }
  Some(i)
}

///|
fn under(scope : @bpmn.Scope, child : Int, container : Int, budget : Budget) -> Bool {
  let stack=[child]; let seen=Map([])
  while stack.pop() is Some(i) {
    if !budget.charge(1) { return false }
    if seen.contains(i) { continue }; seen[i]=true
    if i == container { return true }
    let node=scope.view.nodes[i]
    for id in node.ownership.pool.iter().concat(node.ownership.lanes.iter()).concat(node.ownership.subprocess.iter()) { if scope.node_index(id) is Some(parent) { stack.push(parent) } }
  }
  false
}

///|
// Match the actual semantic identity within its displayed instance. A pool or
// collapsed subprocess is an anchor, never an invented control-flow endpoint.
fn semantic_endpoint(scope : @bpmn.Scope, identities : Map[String,Array[Int]], identity : @bpmn.SourceIdentity, display : Int, budget : Budget) -> Int? {
  let candidates=identities.get(source_key(identity)).unwrap_or([])
  if !budget.charge(candidates.length()+1) { return None }
  if candidates.is_empty() { budget.error("animation/invalid-identity","Connection semantic endpoint is absent from the model"); return None }
  if candidates.contains(display) { return if scope.visible[display] { Some(display) } else { None } }
  let shown=scope.view.nodes[display]
  let pool=if shown.kind == Participant { Some(display) } else { shown.ownership.pool.bind(id => scope.node_index(id)) }
  let scoped=if shown.kind == SubProcess || shown.kind == AdHocSubProcess || shown.kind == Transaction || shown.kind == CallActivity {
    candidates.filter(i => under(scope,i,display,budget))
  } else { [] }
  let matches=if !scoped.is_empty() { scoped } else { candidates.filter(i => pool.map(pool => under(scope,i,pool,budget)).unwrap_or(true)) }
  if matches.length() != 1 { budget.error("animation/ambiguous-endpoint","Connection semantic endpoint has no unique instance in its displayed scope"); return None }
  if scope.visible[matches[0]] { Some(matches[0]) } else { None }
}

///|
pub fn Catalog::bpmn(view : @bpmn.Bpmn, limits? : Limits = Limits::new()) -> CatalogResult {
  let build=builder(Bpmn(view),view.id,limits); let budget=build.budget
  if budget.failed { return build.finish() }
  let scoped=view.scope(limits=@bpmn.ScopeLimits::new(nodes=limits.nodes,work=limits.work))
  guard scoped.scope is Some(scope) else { budget.diagnostics.append(scoped.diagnostics); budget.failed=true; return build.finish() }
  if !budget.charge(scope.work) { return build.finish() }
  let identities : Map[String,Array[Int]]=Map([])
  for i,node in view.nodes {
    let key=source_key(node.source)
    if !budget.charge(key.length()) { return build.finish() }
    match identities.get(key) { Some(values) => values.push(i); None => identities[key]=[i] }
    if scope.visible[i] { build.node({id:node.id,label:node.label,kind:Bpmn(node.kind),occurrence:None,source_node:Some(node)}) }
    else { build.outside[node.id]=true }
  }
  for i,flow in view.flows {
    if !budget.charge(1) { break }
    if !flow.has_source { continue }
    guard scope.node_index(flow.source) is Some(a) && scope.node_index(flow.target) is Some(b) else { budget.error("animation/invalid-identity","Connection display endpoint is missing"); break }
    let visible=if scope.visible[a] && scope.visible[b] { true }
      else if flow.kind == MessageFlow { anchor(scope,flow.source,budget) != None && anchor(scope,flow.target,budget) != None }
      else { false }
    if !visible { continue }
    let key=flow_key(view.id,flow.id); build.flows[flow.id]=build.occurrences.length()
    build.occurrence({key,index:i,kind:Bpmn(flow.kind),path:[],source:Some(flow.identity),flow:Some(flow),message:None})
    if flow.kind != SequenceFlow && flow.kind != MessageFlow { continue }
    let a=flow.semantic_source.bind(id => semantic_endpoint(scope,identities,id,a,budget))
    let b=semantic_endpoint(scope,identities,flow.semantic_target,b,budget)
    if a is Some(a) && b is Some(b) { build.edge({kind:if flow.kind == SequenceFlow { SequenceFlow } else { MessageFlow },source:view.nodes[a].id,target:view.nodes[b].id,occurrence:Some(key)}) }
  }
  build.finish()
}
