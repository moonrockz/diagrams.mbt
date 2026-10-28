///|
priv struct Input {
  nodes : Map[String, Int32]
  visible : Array[Bool]
  containers : Array[Int32?]
}

///|
fn input(view : @model.Bpmn, budget : Budget) -> Input? {
  let result = view.scope(
    limits=@model.ScopeLimits::new(
      nodes=budget.limits.nodes,
      work=budget.limits.work - budget.work,
    ),
  )
  guard result.scope is Some(scope) else {
    budget.diagnostics.append(result.diagnostics)
    budget.failed = true
    return None
  }
  if !budget.charge(scope.work) {
    return None
  }
  let nodes = Map([])
  for i, node in view.nodes {
    nodes[node.id] = i
  }
  Some({
    nodes,
    visible: scope.visible.iter().to_array(),
    containers: scope.containers.iter().to_array(),
  })
}

///|
pub fn activity(kind : @model.NodeKind) -> Bool {
  match kind {
    Task
    | UserTask
    | ServiceTask
    | SendTask
    | ReceiveTask
    | ManualTask
    | BusinessRuleTask
    | ScriptTask
    | SubProcess
    | AdHocSubProcess
    | Transaction
    | CallActivity => true
    _ => false
  }
}

///|
fn event(kind : @model.NodeKind) -> Bool {
  match kind {
    StartEvent
    | EndEvent
    | IntermediateCatchEvent
    | IntermediateThrowEvent
    | BoundaryEvent => true
    _ => false
  }
}

///|
fn gateway(kind : @model.NodeKind) -> Bool {
  match kind {
    ExclusiveGateway
    | InclusiveGateway
    | ParallelGateway
    | ComplexGateway
    | EventBasedGateway => true
    _ => false
  }
}

///|
fn visible_endpoint(
  id : String,
  view : @model.Bpmn,
  input : Input,
  budget : Budget,
) -> Int32? {
  guard input.nodes.get(id) is Some(start) else { return None }
  let mut i = start
  while !input.visible[i] {
    if !budget.charge(1) {
      return None
    }
    if view.nodes[i].ownership.pool is Some(pool) &&
      view.nodes[input.nodes[pool]].black_box {
      i = input.nodes[pool]
    } else if input.containers[i] is Some(parent) {
      i = parent
    } else if view.nodes[i].ownership.lanes
      .last()
      .bind(id => input.nodes.get(id))
      is Some(parent) {
      i = parent
    } else if view.nodes[i].ownership.attached_to.bind(id => input.nodes.get(id))
      is Some(parent) {
      i = parent
    } else {
      return None
    }
  }
  Some(i)
}
