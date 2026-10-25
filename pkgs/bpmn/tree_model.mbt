///|
pub(all) enum NodeValue { Document; Element(Element); Text(String); Comment(String); ProcessingInstruction(target~ : String,data~ : String) } derive(Eq, Debug)

///|
pub extend NodeValue with Eq::{equal, not_equal}

///|
pub extend NodeValue with @debug.Debug::{to_repr}

///|
pub(all) enum NodeCategory {
  Document; Definitions; Process; Activity; Event; Gateway; SequenceFlow
  Collaboration; Participant; Lane; Choreography; ChoreographyActivity
  Conversation; ConversationLink; DiagramInterchange; Extension; Other
  Text; Comment; ProcessingInstruction
} derive(Eq, Debug)

///|
pub extend NodeCategory with Eq::{equal, not_equal}

///|
pub extend NodeCategory with @debug.Debug::{to_repr}

///|
pub(all) enum PathField { Named(ExpandedName); Text; Comment; ProcessingInstruction; Root; Prolog; Epilog } derive(Eq, Debug)

///|
pub extend PathField with Eq::{equal, not_equal}

///|
pub extend PathField with @debug.Debug::{to_repr}

///|
fn PathField::key(self : PathField) -> (String,String) {
  match self { Named(n) => ("n:"+n.namespace_uri,n.local_name); Text => ("text",""); Comment => ("comment",""); ProcessingInstruction => ("pi",""); Root => ("root",""); Prolog => ("prolog",""); Epilog => ("epilog","") }
}

///|
/// Index within a named field, plus the absolute ordered-content index.
pub struct PathStep { field : PathField; index : Int; content_index : Int } derive(Eq, Debug)

///|
pub extend PathStep with Eq::{equal, not_equal}

///|
pub extend PathStep with @debug.Debug::{to_repr}

///|
priv struct TreeRecord { value : NodeValue; parent : Int?; children : ReadOnlyArray[Int]; step : PathStep?; depth : Int; span : Span?; origin : SourceOrigin?; element_ordinal : Int? }

///|
pub struct DocumentTree {
  document : Document
  priv revision : DocumentRevision
  priv records : ReadOnlyArray[TreeRecord]
  priv element_nodes : ReadOnlyArray[Int]
}

///|
pub impl @debug.Debug for DocumentTree with to_repr(self) { @debug.Repr::Repr(("DocumentTree",self.revision.resource_id,self.records.length())) }

///|
pub extend DocumentTree with @debug.Debug::{to_repr}

///|
pub struct NodeHandle { priv revision : DocumentRevision; ordinal : Int }

///|
pub impl Eq for NodeHandle with equal(a,b) { a.ordinal == b.ordinal && same_revision(a.revision,b.revision) }

///|
pub extend NodeHandle with Eq::{equal, not_equal}

///|
pub impl @debug.Debug for NodeHandle with to_repr(self) { @debug.Repr::Repr(("NodeHandle",self.revision.resource_id,self.ordinal)) }

///|
pub extend NodeHandle with @debug.Debug::{to_repr}

///|
pub struct NodeRef { priv tree : DocumentTree; priv ordinal : Int }

///|
pub impl Eq for NodeRef with equal(a,b) { a.ordinal == b.ordinal && same_revision(a.tree.revision,b.tree.revision) }

///|
pub extend NodeRef with Eq::{equal, not_equal}

///|
pub impl @debug.Debug for NodeRef with to_repr(self) { @debug.Repr::Repr(("NodeRef",self.handle(),self.category())) }

///|
pub extend NodeRef with @debug.Debug::{to_repr}

///|
pub(all) enum NodeLookup { Found(NodeRef); DocumentMismatch; InvalidHandle } derive(Eq, Debug)

///|
pub extend NodeLookup with Eq::{equal, not_equal}

///|
pub extend NodeLookup with @debug.Debug::{to_repr}

///|
pub struct TreeBuildResult { tree : DocumentTree?; diagnostics : ReadOnlyArray[Diagnostic] } derive(Debug)

///|
pub extend TreeBuildResult with @debug.Debug::{to_repr}

///|
pub fn DocumentTree::root(self : DocumentTree) -> NodeRef { {tree:self,ordinal:0} }

///|
pub fn DocumentTree::length(self : DocumentTree) -> Int { self.records.length() }

///|
pub fn DocumentTree::resource_id(self : DocumentTree) -> String? { self.revision.resource_id }

///|
pub fn NodeHandle::resource_id(self : NodeHandle) -> String? { self.revision.resource_id }

///|
pub fn NodeRef::resource_id(self : NodeRef) -> String? { self.tree.resource_id() }

///|
pub fn DocumentTree::lookup(self : DocumentTree, handle : NodeHandle) -> NodeLookup {
  if !same_revision(self.revision,handle.revision) { return DocumentMismatch }
  if handle.ordinal < 0 || handle.ordinal >= self.records.length() { return InvalidHandle }
  Found({tree:self,ordinal:handle.ordinal})
}

///|
pub fn NodeRef::handle(self : NodeRef) -> NodeHandle { {revision:self.tree.revision,ordinal:self.ordinal} }

///|
pub fn NodeRef::value(self : NodeRef) -> NodeValue { self.tree.records[self.ordinal].value }

///|
pub fn NodeRef::element(self : NodeRef) -> Element? { match self.value() { Element(e) => Some(e); _ => None } }

///|
pub fn NodeRef::kind(self : NodeRef) -> Kind? { self.element().map(e => e.kind) }

///|
pub fn NodeRef::id(self : NodeRef) -> String? { self.element().map(e => schema_id(e)).unwrap_or(None) }

///|
pub fn NodeRef::parent(self : NodeRef) -> NodeRef? { self.tree.records[self.ordinal].parent.map(ordinal => NodeRef::{tree:self.tree,ordinal}) }

///|
pub fn NodeRef::children(self : NodeRef) -> ReadOnlyArray[NodeRef] { self.tree.records[self.ordinal].children.map(ordinal => NodeRef::{tree:self.tree,ordinal}) }

///|
pub fn NodeRef::depth(self : NodeRef) -> Int { self.tree.records[self.ordinal].depth }

///|
pub fn NodeRef::step(self : NodeRef) -> PathStep? { self.tree.records[self.ordinal].step }

///|
pub fn NodeRef::span(self : NodeRef) -> Span? { self.tree.records[self.ordinal].span }

///|
pub fn NodeRef::location(self : NodeRef) -> Location? {
  let record=self.tree.records[self.ordinal]
  match (record.origin,record.span) { (Some(origin),Some(span)) => origin.map.location(span); _ => None }
}

///|
pub fn NodeRef::attributes(self : NodeRef) -> ReadOnlyArray[Attribute] { self.element().map(e => e.values).unwrap_or([]) }

///|
pub fn NodeRef::scalar(self : NodeRef, name : ExpandedName) -> Scalar? { self.element().map(e => e.scalar(name)).unwrap_or(None) }

///|
pub fn NodeRef::category(self : NodeRef) -> NodeCategory {
  match self.value() {
    Document => Document; Text(_) => Text; Comment(_) => Comment; ProcessingInstruction(..) => ProcessingInstruction
    Element(e) => {
      if opaque_kind(e.kind) { return Extension }
      for (t,category) in [(TypeId::Definitions,NodeCategory::Definitions),(Choreography,Choreography),(ChoreographyActivity,ChoreographyActivity),(ConversationNode,Conversation),(ConversationLink,ConversationLink),(Process,Process),(Activity,Activity),(Event,Event),(Gateway,Gateway),(SequenceFlow,SequenceFlow),(Collaboration,Collaboration),(Participant,Participant),(Lane,Lane)] { if typed_element_is(e,t) { return category } }
      if e.kind.namespace_uri() != model_namespace { DiagramInterchange } else { Other }
    }
  }
}

///|
/// The view is constant size; steps are materialized only when requested.
pub struct NodePath { priv node : NodeRef }

///|
pub impl Eq for NodePath with equal(a,b) { a.node == b.node }

///|
pub extend NodePath with Eq::{equal, not_equal}

///|
pub impl @debug.Debug for NodePath with to_repr(self) { @debug.Repr::Repr(self.steps()) }

///|
pub extend NodePath with @debug.Debug::{to_repr}

///|
pub fn NodeRef::path(self : NodeRef) -> NodePath { {node:self} }

///|
pub fn NodePath::depth(self : NodePath) -> Int { self.node.depth() }

///|
pub fn NodePath::steps(self : NodePath) -> ReadOnlyArray[PathStep] {
  let reversed : Array[PathStep] = []
  let mut node=self.node
  while node.step() is Some(step) { reversed.push(step); node=node.parent().unwrap() }
  ReadOnlyArray::from_array(Array::makei(reversed.length(),i => reversed[reversed.length()-i-1]))
}

///|
pub fn NodePath::resolve(self : NodePath, tree : DocumentTree) -> NodeLookup { tree.lookup(self.node.handle()) }

///|
pub struct NodeField { field : PathField; attributes : ReadOnlyArray[Attribute]; children : ReadOnlyArray[NodeRef] } derive(Eq, Debug)

///|
pub extend NodeField with Eq::{equal, not_equal}

///|
pub extend NodeField with @debug.Debug::{to_repr}

///|
pub fn NodeRef::fields(self : NodeRef) -> ReadOnlyArray[NodeField] {
  let keys : Map[(String,String),Int] = Map([])
  let fields : Array[(PathField,Array[Attribute],Array[NodeRef])] = []
  fn slot(field : PathField) -> Int {
    match keys.get(field.key()) { Some(i) => i; None => { let i=fields.length(); keys[field.key()]=i; fields.push((field,[],[])); i } }
  }
  for attr in self.attributes() { if attr.name is Some(name) { fields[slot(Named(name))].1.push(attr) } }
  for child in self.children() { let field=child.step().unwrap().field; fields[slot(field)].2.push(child) }
  ReadOnlyArray::from_array(fields.map(f => NodeField::{field:f.0,attributes:ReadOnlyArray::from_array(f.1),children:ReadOnlyArray::from_array(f.2)}))
}

///|
pub fn NodeRef::field(self : NodeRef, field : PathField) -> NodeField? { self.fields().iter().find_first(f => f.field == field) }

///|
pub let traversal_diagnostic_codes : ReadOnlyArray[String] = ["bpmn/traversal-invalid-limits","bpmn/traversal-node-limit","bpmn/traversal-depth-limit","bpmn/traversal-token-limit"]
