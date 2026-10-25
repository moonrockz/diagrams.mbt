///|
/// Checked conversion inventory. Each entry has a concrete conversion assertion
/// in the unpublished acceptance suite; no abstract kind becomes a generic task.
pub let graphical_types : ReadOnlyArray[@bpmn.TypeId] = [
StartEvent, EndEvent, IntermediateCatchEvent, IntermediateThrowEvent, BoundaryEvent, ImplicitThrowEvent, Task, UserTask, ServiceTask, SendTask, ReceiveTask, ManualTask, BusinessRuleTask, ScriptTask, SubProcess, AdHocSubProcess, Transaction, CallActivity, ExclusiveGateway, InclusiveGateway, ParallelGateway, ComplexGateway, EventBasedGateway, Participant, Lane, DataObject, DataObjectReference, DataStore, DataStoreReference, DataInput, DataOutput, Group, TextAnnotation, Message, SequenceFlow, MessageFlow, Association, DataInputAssociation, DataOutputAssociation]

///|
fn node_kind(e : @bpmn.Element) -> @model.NodeKind? {
  match actual(e) {
    Some(StartEvent) => Some(StartEvent)
    Some(EndEvent) => Some(EndEvent)
    Some(IntermediateCatchEvent) => Some(IntermediateCatchEvent)
    Some(IntermediateThrowEvent) => Some(IntermediateThrowEvent)
    Some(BoundaryEvent) => Some(BoundaryEvent)
    Some(ImplicitThrowEvent) => Some(ImplicitThrowEvent)
    Some(Task) => Some(Task)
    Some(UserTask) => Some(UserTask)
    Some(ServiceTask) => Some(ServiceTask)
    Some(SendTask) => Some(SendTask)
    Some(ReceiveTask) => Some(ReceiveTask)
    Some(ManualTask) => Some(ManualTask)
    Some(BusinessRuleTask) => Some(BusinessRuleTask)
    Some(ScriptTask) => Some(ScriptTask)
    Some(SubProcess) => Some(SubProcess)
    Some(AdHocSubProcess) => Some(AdHocSubProcess)
    Some(Transaction) => Some(Transaction)
    Some(CallActivity) => Some(CallActivity)
    Some(ExclusiveGateway) => Some(ExclusiveGateway)
    Some(InclusiveGateway) => Some(InclusiveGateway)
    Some(ParallelGateway) => Some(ParallelGateway)
    Some(ComplexGateway) => Some(ComplexGateway)
    Some(EventBasedGateway) => Some(EventBasedGateway)
    Some(Participant) => Some(Participant)
    Some(Lane) => Some(Lane)
    Some(DataObject) => Some(DataObject)
    Some(DataObjectReference) => Some(DataObjectReference)
    Some(DataStore) => Some(DataStore)
    Some(DataStoreReference) => Some(DataStoreReference)
    Some(DataInput) => Some(DataInput)
    Some(DataOutput) => Some(DataOutput)
    Some(Group) => Some(Group)
    Some(TextAnnotation) => Some(TextAnnotation)
    Some(Message) => Some(Message)
    _ => None
  }
}

///|
fn connection_kind(e : @bpmn.Element) -> @model.ConnectionKind? {
  match actual(e) {
    Some(SequenceFlow) => Some(SequenceFlow)
    Some(MessageFlow) => Some(MessageFlow)
    Some(Association) => Some(Association)
    Some(DataInputAssociation) => Some(DataInputAssociation)
    Some(DataOutputAssociation) => Some(DataOutputAssociation)
    Some(DataAssociation) => Some(DataAssociation)
    _ => None
  }
}

///|
fn flag(e : @bpmn.Element, key : String) -> Bool? { match e.boolean(key) { Present(b) => Some(b); _ => None } }

///|
fn semantic_settings(e : @bpmn.Element) -> Array[(String,String)] {
  let out=[]; let stack=[("",e)]
  while stack.pop() is Some((path,current)) {
    if actual(current) == None { continue }
    for (name,value) in current.attributes { if name != "id" { out.push((path+"@"+name,value)) } }
    if !current.content.trim().is_empty() { out.push((path+"#text",current.content)) }
    for i=current.children.length()-1; i>=0; i=i-1 { let child=current.children[i]; stack.push((path+child.kind.local_name()+"/",child)) }
  }
  out
}

///|
fn Converter::markers(self : Converter, resource : Int, ordinal : Int) -> @model.Markers {
  let e=self.sources[resource].index.nodes[ordinal].element
  let events=[]
  let mut loop_kind=@model.LoopKind::None
  for child in e.children {
    if actual(child) == Some(StandardLoopCharacteristics) { loop_kind=Standard }
    if actual(child) == Some(MultiInstanceLoopCharacteristics) { loop_kind=if flag(child,"isSequential").unwrap_or(false) { Sequential } else { Parallel } }
  }
  let definitions=self.sources[resource].index.nodes[ordinal].children.iter().filter(i => is_type(self.sources[resource].index.nodes[i].element,EventDefinition)).map(i => (resource,i)).to_array()
  for key in self.resolve_field(resource,ordinal,"eventDefinitionRef") { definitions.push(key) }
  for key in definitions {
    let definition=self.sources[key.0].index.nodes[key.1].element
    let kind : @model.EventKind?=match actual(definition) {
      Some(MessageEventDefinition) => Some(Message); Some(TimerEventDefinition) => Some(Timer)
      Some(ConditionalEventDefinition) => Some(Conditional); Some(LinkEventDefinition) => Some(Link)
      Some(SignalEventDefinition) => Some(Signal); Some(ErrorEventDefinition) => Some(Error)
      Some(EscalationEventDefinition) => Some(Escalation); Some(CancelEventDefinition) => Some(Cancel)
      Some(CompensateEventDefinition) => Some(Compensation); Some(TerminateEventDefinition) => Some(Terminate)
      _ => None
    }
    if kind is Some(kind) { events.push(@model.EventMarker::new(kind,identity=self.identity(key.0,key.1),settings=semantic_settings(definition))) }
    else { self.add("bpmn/unsupported-element","No event symbol is defined for the selected event definition",e=definition) }
  }
  let mut collection=flag(e,"isCollection").unwrap_or(false)
  for key in self.resolve_field(resource,ordinal,"dataObjectRef") { collection=flag(self.sources[key.0].index.nodes[key.1].element,"isCollection").unwrap_or(false) }
  let called=self.resolve_field(resource,ordinal,"calledElement").get(0)
  let called_kind=called.bind(key => match actual(self.sources[key.0].index.nodes[key.1].element) {
    Some(GlobalTask) => Some(@model.NodeKind::Task); Some(GlobalUserTask) => Some(UserTask)
    Some(GlobalManualTask) => Some(ManualTask); Some(GlobalScriptTask) => Some(ScriptTask)
    Some(GlobalBusinessRuleTask) => Some(BusinessRuleTask); Some(Process) => Some(SubProcess)
    _ => None
  })
  let details=semantic_settings(@bpmn.Element::from_values(e.kind,values=e.values))
  for child in e.children {
    if actual(child) == Some(ParticipantMultiplicity) || actual(child) == Some(DataState) || is_type(child,LoopCharacteristics) {
      for (key,value) in semantic_settings(child) { details.push((child.kind.local_name()+"/"+key,value)) }
    }
  }
  @model.Markers::new(loop_kind~,called_kind?,called_element?=called.map(key => self.identity(key.0,key.1)),compensation=flag(e,"isForCompensation").unwrap_or(false),event_subprocess=flag(e,"triggeredByEvent").unwrap_or(false),interrupting=flag(e,"cancelActivity").unwrap_or_else(() => flag(e,"isInterrupting").unwrap_or(true)),parallel_multiple=flag(e,"parallelMultiple").unwrap_or(false),collection~,instantiate=flag(e,"instantiate").unwrap_or(false),events~,details~)
}
