///|
pub struct ScopeLimits { nodes : Int; work : Int } derive(Eq,Debug)

///|
pub fn ScopeLimits::new(nodes? : Int = 10000, work? : Int = 1000000) -> ScopeLimits { {nodes,work} }

///|
pub struct Scope {
  view : Bpmn
  visible : ReadOnlyArray[Bool]
  containers : ReadOnlyArray[Int?]
  work : Int
  priv nodes : Map[String,Int]
}

///|
pub fn Scope::node_index(self : Scope, id : String) -> Int? { self.nodes.get(id) }

///|
pub struct ScopeResult { scope : Scope?; diagnostics : ReadOnlyArray[@diagrams.Diagnostic] }

///|
priv struct ScopeBudget { limits : ScopeLimits; diagnostics : Array[@diagrams.Diagnostic]; mut work : Int; mut failed : Bool }

///|
fn ScopeBudget::error(self : ScopeBudget, code : String, message : String) -> Unit {
  if !self.failed { self.diagnostics.push(@diagrams.Diagnostic::error(code,message)) }
  self.failed=true
}

///|
fn ScopeBudget::charge(self : ScopeBudget, amount : Int) -> Bool {
  if amount < 0 || amount > self.limits.work-self.work { self.error("bpmn/layout-limit","BPMN scope work limit exceeded"); return false }
  self.work+=amount; true
}

///|
fn scope_activity(kind : NodeKind) -> Bool {
  match kind { Task | UserTask | ServiceTask | SendTask | ReceiveTask | ManualTask | BusinessRuleTask | ScriptTask | SubProcess | AdHocSubProcess | Transaction | CallActivity => true; _ => false }
}

///|
/// Pure selected visibility shared by geometry, motion and structural queries.
/// Group membership is visual grouping and never hides a member.
pub fn Bpmn::scope(self : Bpmn, limits? : ScopeLimits = ScopeLimits::new()) -> ScopeResult {
  let budget=ScopeBudget::{limits,diagnostics:[],work:0,failed:false}
  if limits.nodes <= 0 || limits.work <= 0 { budget.error("bpmn/layout-limit","Scope limits must be positive") }
  let scope : Scope?=if budget.failed { None } else { build_scope(self,budget) }
  {scope,diagnostics:ReadOnlyArray::from_array(budget.diagnostics)}
}

///|
fn build_scope(view : Bpmn, budget : ScopeBudget) -> Scope? {
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
      guard nodes.get(owner) is Some(j) && [NodeKind::SubProcess,AdHocSubProcess,Transaction,CallActivity].contains(view.nodes[j].kind) else { budget.error("bpmn/invalid-reference","Invalid subprocess owner of \{node.id}"); return None }
      containers[i]=Some(j)
    }
    if node.ownership.attached_to is Some(owner) {
      guard nodes.get(owner) is Some(j) && scope_activity(view.nodes[j].kind) && node.kind == BoundaryEvent else { budget.error("bpmn/invalid-reference","Invalid boundary attachment of \{node.id}"); return None }
    } else if node.kind == BoundaryEvent { budget.error("bpmn/invalid-reference","Boundary event has no attached activity: \{node.id}"); return None }
  }
  let owners : Array[Array[Int]]=Array::makei(view.nodes.length(),_ => [])
  for i,node in view.nodes {
    for id in node.ownership.lanes.iter().concat(node.ownership.pool.iter()).concat(node.ownership.subprocess.iter()) { let parent=nodes[id]; if !owners[i].contains(parent) { owners[i].push(parent) } }
  }
  // Attachments inherit visibility from their activity, including when that
  // activity is inside a collapsed scope. Attaching to a visible collapsed
  // subprocess does not hide its outside boundary event.
  for i,node in view.nodes {
    if node.ownership.attached_to is Some(id) { let parent=nodes[id]; if !owners[i].contains(parent) { owners[i].push(parent) } }
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
  Some({view,nodes,visible:ReadOnlyArray::from_array(visible),containers:ReadOnlyArray::from_array(containers),work:budget.work})
}


///|
pub extend ScopeLimits with Eq::{equal,not_equal}

///|
pub extend ScopeLimits with @debug.Debug::{to_repr}
