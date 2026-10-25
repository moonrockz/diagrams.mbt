///|
pub(all) enum ValidationStage { Syntax; Structure; References } derive(Eq, Debug)

///|
pub extend ValidationStage with Eq::{equal, not_equal}

///|
pub extend ValidationStage with @debug.Debug::{to_repr}

///|
/// The node ordinal is local to the result's index. It is not a revision handle.
pub struct ValidationFinding {
  stage : ValidationStage
  diagnostic : Diagnostic
  resource_id : String?
  node : Int?
  element_id : String?
  field : ExpandedName?
} derive(Eq, Debug)

///|
pub extend ValidationFinding with Eq::{equal, not_equal}

///|
pub extend ValidationFinding with @debug.Debug::{to_repr}

///|
pub struct IndexedElement {
  ordinal : Int
  element : Element
  parent : Int?
  child_index : Int
  children : ReadOnlyArray[Int]
  depth : Int
  scope : Int?
  payload : Bool
} derive(Eq, Debug)

///|
pub extend IndexedElement with Eq::{equal, not_equal}

///|
pub extend IndexedElement with @debug.Debug::{to_repr}

///|
pub(all) enum IdLookup { Found(IndexedElement); Ambiguous(ReadOnlyArray[IndexedElement]); Missing; Incomplete } derive(Eq, Debug)

///|
pub extend IdLookup with Eq::{equal, not_equal}

///|
pub extend IdLookup with @debug.Debug::{to_repr}

///|
/// Immutable source-order index. Duplicate occurrences are never overwritten.
pub struct DocumentIndex {
  document : Document
  nodes : ReadOnlyArray[IndexedElement]
  complete : Bool
  priv records : Int
  priv ids : @namespaces.HashMap[String,ReadOnlyArray[Int]]
} derive(Debug)

///|
pub extend DocumentIndex with @debug.Debug::{to_repr}

///|
pub fn DocumentIndex::lookup(self : DocumentIndex, id : String) -> IdLookup {
  if !self.complete { return Incomplete }
  match self.ids.get(id) {
    None => Missing
    Some(indices) => if indices.length() == 1 { Found(self.nodes[indices[0]]) }
      else { Ambiguous(ReadOnlyArray::from_array(indices.map(i => self.nodes[i]))) }
  }
}

///|
pub struct StructureResult { index : DocumentIndex; findings : ReadOnlyArray[ValidationFinding]; complete : Bool } derive(Debug)

///|
pub extend StructureResult with @debug.Debug::{to_repr}

///|
priv struct ValidationLog {
  limits : Limits
  findings : Array[ValidationFinding]
  mut resource_id : String?
  mut stopped : Bool
}

///|
fn ValidationLog::add(self : ValidationLog, stage : ValidationStage, code : String, message : String, node : IndexedElement?, field : ExpandedName?, attribute? : Attribute) -> Unit {
  if self.stopped { return }
  let element=node.map(n => n.element)
  let span=match attribute { Some(a) => a.span; None => element.map(e => e.span).unwrap_or(None) }
  let location=match attribute { Some(a) => a.location(); None => element.map(e => e.location()).unwrap_or(None) }
  let item=ValidationFinding::{stage,diagnostic:{code,severity:Error,message,span,location},resource_id:self.resource_id,node:node.map(n => n.ordinal),element_id:element.map(e => e.attribute("id")).unwrap_or(None),field}
  if self.findings.length() < self.limits.diagnostics { self.findings.push(item) }
  else {
    self.findings[self.limits.diagnostics-1]={..item,diagnostic:{..item.diagnostic,code:"bpmn/validation-diagnostic-limit",message:"Validation diagnostic limit exceeded"}}
    self.stopped=true
  }
}

///|
fn valid_limits(limits : Limits) -> Bool {
  limits.nodes > 0 && limits.depth > 0 && limits.token_units > 0 && limits.diagnostics > 0 && limits.source_units > 0 && limits.output_units > 0
}

///|
fn flow_container(element : Element) -> Bool {
  [TypeId::Process,SubProcess,Choreography,SubChoreography].iter().any(t => typed_element_is(element,t))
}

///|
fn schema_id(element : Element) -> String? {
  if opaque_kind(element.kind) { return None }
  match element.scalar(ExpandedName::new("","id")) { Some(Identifier(id)) if ncname(id) => Some(id); _ => None }
}

///|
pub let validation_diagnostic_codes : ReadOnlyArray[String] = [
  "bpmn/validation-invalid-limits", "bpmn/validation-node-limit", "bpmn/validation-depth-limit",
  "bpmn/validation-token-limit", "bpmn/validation-diagnostic-limit", "bpmn/duplicate-id",
  "bpmn/required-field", "bpmn/field-cardinality", "bpmn/invalid-containment", "bpmn/child-order",
  "bpmn/choice-conflict", "bpmn/abstract-element", "bpmn/invalid-field", "bpmn/invalid-type",
  "bpmn/unresolved-reference", "bpmn/ambiguous-reference", "bpmn/invalid-reference",
  "bpmn/wrong-reference-kind", "bpmn/sequence-flow-scope", "bpmn/boundary-attachment",
  "bpmn/reference-endpoint", "bpmn/unresolved-import", "bpmn/ambiguous-import", "bpmn/import-namespace",
  "bpmn/import-type", "bpmn/resource-limit",
]
