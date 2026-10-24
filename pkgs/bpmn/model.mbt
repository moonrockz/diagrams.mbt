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
