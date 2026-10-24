///|
/// The supported document families of the first implementation slice.
pub(all) enum Kind {
  Definitions
  Process
  StartEvent
  Task
  EndEvent
  SequenceFlow
  Incoming
  Outgoing
  Diagram
  Plane
  Shape
  Edge
  Bounds
  Waypoint
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with @debug.Debug::{to_repr}

///|
pub fn Kind::local_name(self : Kind) -> String {
  match self {
    Definitions => "definitions"; Process => "process"; StartEvent => "startEvent"
    Task => "task"; EndEvent => "endEvent"; SequenceFlow => "sequenceFlow"
    Incoming => "incoming"; Outgoing => "outgoing"; Diagram => "BPMNDiagram"
    Plane => "BPMNPlane"; Shape => "BPMNShape"; Edge => "BPMNEdge"
    Bounds => "Bounds"; Waypoint => "waypoint"
  }
}

///|
pub fn Kind::namespace_uri(self : Kind) -> String {
  match self {
    Diagram | Plane | Shape | Edge => "http://www.omg.org/spec/BPMN/20100524/DI"
    Bounds => "http://www.omg.org/spec/DD/20100524/DC"
    Waypoint => "http://www.omg.org/spec/DD/20100524/DI"
    _ => "http://www.omg.org/spec/BPMN/20100524/MODEL"
  }
}

///|
fn Kind::qualified_name(self : Kind) -> String {
  let prefix = match self {
    Diagram | Plane | Shape | Edge => "bpmndi"
    Bounds => "dc"; Waypoint => "di"; _ => "bpmn"
  }
  "\{prefix}:\{self.local_name()}"
}

///|
/// An immutable element. Attributes and children retain document order.
/// Coordinates retain their exact source value; no numeric defaults are added.
pub struct Element {
  kind : Kind
  attributes : ReadOnlyArray[(String, String)]
  children : ReadOnlyArray[Element]
  content : String
} derive(Eq, Debug)

///|
pub extend Element with Eq::{equal, not_equal}

///|
pub extend Element with @debug.Debug::{to_repr}

///|
pub fn Element::new(kind : Kind, attributes? : ArrayView[(String, String)] = [], children? : ArrayView[Element] = [], content? : String = "") -> Element {
  { kind, attributes: ReadOnlyArray::from_array(attributes), children: ReadOnlyArray::from_array(children), content }
}

///|
pub fn Element::attribute(self : Element, name : String) -> String? {
  for (key, value) in self.attributes { if key == name { return Some(value) } }
  None
}

///|
/// An immutable owned document, independent of source spelling and renderers.
pub struct Document { root : Element } derive(Eq, Debug)

///|
pub extend Document with Eq::{equal, not_equal}

///|
pub extend Document with @debug.Debug::{to_repr}

///|
pub fn Document::new(root : Element) -> Document { { root, } }

///|
/// Preorder containment walking. References are attributes, never traversed edges.
pub fn Document::walk(self : Document, visit : (Element) -> Unit) -> Unit {
  let stack = [self.root]
  while !stack.is_empty() {
    let node = stack.pop().unwrap()
    visit(node)
    for i = node.children.length() - 1; i >= 0; i = i - 1 { stack.push(node.children[i]) }
  }
}

///|
pub(all) enum Severity { Error; Warning } derive(Eq, Debug)

///|
pub extend Severity with Eq::{equal, not_equal}

///|
pub extend Severity with @debug.Debug::{to_repr}

///|
/// Half-open UTF-16 offsets. Source positions are separate from document values.
pub struct Span { start : Int; end : Int } derive(Eq, Debug)

///|
pub extend Span with Eq::{equal, not_equal}

///|
pub extend Span with @debug.Debug::{to_repr}

///|
pub struct Diagnostic { code : String; severity : Severity; message : String; span : Span? } derive(Eq, Debug)

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
fn finding(code : String, message : String, start? : Int, end? : Int) -> Diagnostic {
  { code, severity: Error, message, span: match (start, end) { (Some(start), Some(end)) => Some({ start, end }); _ => None } }
}

///|
/// One owned source segment, including trivia or malformed text.
pub struct Token { text : String; span : Span } derive(Eq, Debug)

///|
pub extend Token with Eq::{equal, not_equal}

///|
pub extend Token with @debug.Debug::{to_repr}

///|
pub struct Cst { tokens : ReadOnlyArray[Token] } derive(Eq, Debug)

///|
pub extend Cst with Eq::{equal, not_equal}

///|
pub extend Cst with @debug.Debug::{to_repr}

///|
pub fn Cst::text(self : Cst) -> String { self.tokens.map(t => t.text).iter().to_array().join("") }

///|
pub struct ReadResult { tree : Cst; document : Document?; diagnostics : ReadOnlyArray[Diagnostic] } derive(Eq, Debug)

///|
pub extend ReadResult with Eq::{equal, not_equal}

///|
pub extend ReadResult with @debug.Debug::{to_repr}
