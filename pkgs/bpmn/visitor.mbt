///|
/// Family methods have typed values and default to Continue. Other schema
/// families remain inspectable through visit_other and NodeRef.element().
pub(open) trait Visitor {
  fn enter(Self, NodeRef) -> Control = _
  fn visit_definitions(Self, Definitions, NodeRef) -> Control = _
  fn visit_process(Self, Process, NodeRef) -> Control = _
  fn visit_activity(Self, Activity, NodeRef) -> Control = _
  fn visit_event(Self, Event, NodeRef) -> Control = _
  fn visit_gateway(Self, Gateway, NodeRef) -> Control = _
  fn visit_sequence_flow(Self, SequenceFlow, NodeRef) -> Control = _
  fn visit_collaboration(Self, Collaboration, NodeRef) -> Control = _
  fn visit_participant(Self, Participant, NodeRef) -> Control = _
  fn visit_lane(Self, Lane, NodeRef) -> Control = _
  fn visit_choreography(Self, Choreography, NodeRef) -> Control = _
  fn visit_choreography_activity(Self, ChoreographyActivity, NodeRef) -> Control = _
  fn visit_conversation(Self, ConversationNode, NodeRef) -> Control = _
  fn visit_conversation_link(Self, ConversationLink, NodeRef) -> Control = _
  fn visit_extension(Self, XmlElement, NodeRef) -> Control = _
  fn visit_document(Self, NodeRef) -> Control = _
  fn visit_diagram_interchange(Self, NodeRef) -> Control = _
  fn visit_text(Self, NodeRef) -> Control = _
  fn visit_comment(Self, NodeRef) -> Control = _
  fn visit_processing_instruction(Self, NodeRef) -> Control = _
  fn visit_other(Self, NodeRef) -> Control = _
  fn leave(Self, NodeRef) -> Unit = _
}

///|
impl Visitor with visit_definitions(_self,_value,_node) { Continue }

///|
impl Visitor with visit_process(_self,_value,_node) { Continue }

///|
impl Visitor with visit_activity(_self,_value,_node) { Continue }

///|
impl Visitor with visit_event(_self,_value,_node) { Continue }

///|
impl Visitor with visit_gateway(_self,_value,_node) { Continue }

///|
impl Visitor with visit_sequence_flow(_self,_value,_node) { Continue }

///|
impl Visitor with visit_collaboration(_self,_value,_node) { Continue }

///|
impl Visitor with visit_participant(_self,_value,_node) { Continue }

///|
impl Visitor with visit_lane(_self,_value,_node) { Continue }

///|
impl Visitor with visit_choreography(_self,_value,_node) { Continue }

///|
impl Visitor with visit_choreography_activity(_self,_value,_node) { Continue }

///|
impl Visitor with visit_conversation(_self,_value,_node) { Continue }

///|
impl Visitor with visit_conversation_link(_self,_value,_node) { Continue }

///|
impl Visitor with visit_extension(_self,_value,_node) { Continue }

///|
impl Visitor with visit_document(_self,_node) { Continue }

///|
impl Visitor with visit_diagram_interchange(_self,_node) { Continue }

///|
impl Visitor with visit_text(_self,_node) { Continue }

///|
impl Visitor with visit_comment(_self,_node) { Continue }

///|
impl Visitor with visit_processing_instruction(_self,_node) { Continue }

///|
impl Visitor with visit_other(_self,_node) { Continue }

///|
impl Visitor with leave(_self,_node) { () }

///|
fn[V : Visitor] dispatch_visitor(visitor : V, node : NodeRef) -> Control {
  match node.category() {
    Definitions => visitor.visit_definitions(Definitions::from_element(node.element().unwrap()).unwrap(),node)
    Process => visitor.visit_process(Process::from_element(node.element().unwrap()).unwrap(),node)
    Activity => visitor.visit_activity(Activity::from_element(node.element().unwrap()).unwrap(),node)
    Event => visitor.visit_event(Event::from_element(node.element().unwrap()).unwrap(),node)
    Gateway => visitor.visit_gateway(Gateway::from_element(node.element().unwrap()).unwrap(),node)
    SequenceFlow => visitor.visit_sequence_flow(SequenceFlow::from_element(node.element().unwrap()).unwrap(),node)
    Collaboration => visitor.visit_collaboration(Collaboration::from_element(node.element().unwrap()).unwrap(),node)
    Participant => visitor.visit_participant(Participant::from_element(node.element().unwrap()).unwrap(),node)
    Lane => visitor.visit_lane(Lane::from_element(node.element().unwrap()).unwrap(),node)
    Choreography => visitor.visit_choreography(Choreography::from_element(node.element().unwrap()).unwrap(),node)
    ChoreographyActivity => visitor.visit_choreography_activity(ChoreographyActivity::from_element(node.element().unwrap()).unwrap(),node)
    Conversation => visitor.visit_conversation(ConversationNode::from_element(node.element().unwrap()).unwrap(),node)
    ConversationLink => visitor.visit_conversation_link(ConversationLink::from_element(node.element().unwrap()).unwrap(),node)
    Extension => visitor.visit_extension(XmlElement::from_element(node.element().unwrap()).unwrap(),node)
    Document => visitor.visit_document(node)
    DiagramInterchange => visitor.visit_diagram_interchange(node)
    Text => visitor.visit_text(node)
    Comment => visitor.visit_comment(node)
    ProcessingInstruction => visitor.visit_processing_instruction(node)
    Other => visitor.visit_other(node)
  }
}

///|
pub fn[V : Visitor] accept(root : NodeRef, visitor : V) -> Unit { walk(root,node => match visitor.enter(node) { Continue => dispatch_visitor(visitor,node); other => other },leave=node => visitor.leave(node)) }

///|
impl Visitor with enter(_self,_node) { Continue }
