///|
priv struct Input { nodes : Map[String,Int]; visible : Array[Bool]; containers : Array[Int?] }

///|
fn input(view : @model.Bpmn, budget : Budget) -> Input? {
  if !budget.charge(view.nodes.length()) || !budget.charge(view.flows.length()) { return None }
  let nodes : Map[String,Int]=Map([])
  let ids : Map[String,Bool]=Map([])
  for i,node in view.nodes {
    if !budget.charge(node.id.length()+node.label.length()+node.source.path.length()) { return None }
    if ids.contains(node.id) || node.id.is_empty() { budget.error("bpmn/invalid-reference","Duplicate or empty render identity: \{node.id}"); return None }
    nodes[node.id]=i; ids[node.id]=true
  }
  for flow in view.flows {
    if !budget.charge(flow.id.length()+flow.label.length()) { return None }
    if ids.contains(flow.id) || flow.id.is_empty() { budget.error("bpmn/invalid-reference","Duplicate or empty connection identity: \{flow.id}"); return None }
    ids[flow.id]=true
    if (flow.has_source && !nodes.contains(flow.source)) || !nodes.contains(flow.target) { budget.error("bpmn/invalid-reference","Connection endpoint is absent: \{flow.id}"); return None }
  }
  let containers : Array[Int?]=Array::make(view.nodes.length(),None)
  for i,node in view.nodes {
    for owner in node.ownership.lanes {
      if !budget.charge(1) { return None }
      guard nodes.get(owner) is Some(j) && view.nodes[j].kind == Lane else { budget.error("bpmn/invalid-reference","Invalid lane owner of \{node.id}"); return None }
    }
    if node.ownership.pool is Some(owner) {
      guard nodes.get(owner) is Some(j) && view.nodes[j].kind == Participant else { budget.error("bpmn/invalid-reference","Invalid pool owner of \{node.id}"); return None }
    }
    if node.ownership.subprocess is Some(owner) {
      guard nodes.get(owner) is Some(j) && [@model.NodeKind::SubProcess,AdHocSubProcess,Transaction,CallActivity].contains(view.nodes[j].kind) else { budget.error("bpmn/invalid-reference","Invalid subprocess owner of \{node.id}"); return None }
      containers[i]=Some(j)
    }
    if node.ownership.attached_to is Some(owner) {
      guard nodes.get(owner) is Some(j) && activity(view.nodes[j].kind) && node.kind == BoundaryEvent else { budget.error("bpmn/invalid-reference","Invalid boundary attachment of \{node.id}"); return None }
    } else if node.kind == BoundaryEvent { budget.error("bpmn/invalid-reference","Boundary event has no attached activity: \{node.id}"); return None }
  }
  let owners : Array[Array[Int]]=Array::makei(view.nodes.length(),_ => [])
  for i,node in view.nodes {
    for id in node.ownership.lanes.iter().concat(node.ownership.pool.iter()).concat(node.ownership.subprocess.iter()) { let parent=nodes[id]; if !owners[i].contains(parent) { owners[i].push(parent) } }
  }
  let states=Array::make(view.nodes.length(),0)
  let visible=Array::make(view.nodes.length(),true)
  for start in 0..<view.nodes.length() {
    if states[start] == 2 { continue }
    let stack : Array[(Int,Bool)]=[(start,false)]
    while stack.pop() is Some((i,leave)) {
      if !budget.charge(1) { return None }
      if leave {
        visible[i]=owners[i].iter().all(p => visible[p] && (if view.nodes[p].kind == Participant { !view.nodes[p].black_box } else if containers[i] == Some(p) { view.nodes[p].expanded.unwrap_or(false) } else { true }))
        states[i]=2
      } else {
        if states[i] == 2 { continue }
        if states[i] == 1 { budget.error("bpmn/invalid-reference","Containment ownership cycle at \{view.nodes[i].id}"); return None }
        states[i]=1; stack.push((i,true))
        for parent in owners[i] { stack.push((parent,false)) }
      }
    }
  }
  if visible.iter().filter(v => v).count() > budget.limits.nodes { budget.error("bpmn/layout-limit","Visible node limit exceeded"); return None }
  Some({nodes,visible,containers})
}

///|
pub fn activity(kind : @model.NodeKind) -> Bool {
  match kind { Task | UserTask | ServiceTask | SendTask | ReceiveTask | ManualTask | BusinessRuleTask | ScriptTask | SubProcess | AdHocSubProcess | Transaction | CallActivity => true; _ => false }
}

///|
fn event(kind : @model.NodeKind) -> Bool { match kind { StartEvent | EndEvent | IntermediateCatchEvent | IntermediateThrowEvent | BoundaryEvent => true; _ => false } }

///|
fn gateway(kind : @model.NodeKind) -> Bool { match kind { ExclusiveGateway | InclusiveGateway | ParallelGateway | ComplexGateway | EventBasedGateway => true; _ => false } }

///|
fn visible_endpoint(id : String, view : @model.Bpmn, input : Input, budget : Budget) -> Int? {
  guard input.nodes.get(id) is Some(start) else { return None }
  let mut i=start
  while !input.visible[i] {
    if !budget.charge(1) { return None }
    if view.nodes[i].ownership.pool is Some(pool) && view.nodes[input.nodes[pool]].black_box { i=input.nodes[pool] }
    else if input.containers[i] is Some(parent) { i=parent }
    else if view.nodes[i].ownership.lanes.last().bind(id => input.nodes.get(id)) is Some(parent) { i=parent }
    else { return None }
  }
  Some(i)
}
