///|
pub(all) struct NodeDecl { id : String; label : String?; label_kind : String; shape : String?; metadata : ReadOnlyArray[(String,Json)]; classes : ReadOnlyArray[String]; spelling : String } derive(Debug)
///|
pub(all) struct Link { spelling : String; label : String; label_kind : String; id : String?; source_marker : String; target_marker : String; style : String; length : Int } derive(Debug)
///|
pub(all) struct Chain { endpoints : ReadOnlyArray[ReadOnlyArray[NodeDecl]]; links : ReadOnlyArray[Link] } derive(Eq, Debug)
///|
pub(all) enum StatementKind { Nodes(ReadOnlyArray[NodeDecl]); Edges(Chain); Subgraph(id~ : String, label~ : String); End; Direction(String); Title(String); AccTitle(String); AccDescription(String); Metadata(keyword~ : String, text~ : String); Comment(String) } derive(Eq, Debug)
///|
pub(all) struct Statement { kind : StatementKind; spelling : String; span : @diagrams.Span } derive(Debug)
///|
pub impl Eq for Statement with equal(a,b) { a.kind == b.kind }
///|
pub struct Diagram { direction : String?; front_matter : String?; directives : ReadOnlyArray[String]; statements : ReadOnlyArray[Statement] } derive(Eq, Debug)
///|
pub fn Diagram::new(statements : ArrayView[Statement], direction? : String, front_matter? : String, directives? : ArrayView[String] = []) -> Diagram { {direction,front_matter,directives:ReadOnlyArray::from_array(directives),statements:ReadOnlyArray::from_array(statements)} }

///|
pub extend NodeDecl with Eq::{equal,not_equal}
///|
pub extend NodeDecl with @debug.Debug::{to_repr}

///|
pub extend Link with Eq::{equal,not_equal}
///|
pub extend Link with @debug.Debug::{to_repr}

///|
pub extend Chain with Eq::{equal,not_equal}
///|
pub extend Chain with @debug.Debug::{to_repr}

///|
pub extend StatementKind with Eq::{equal,not_equal}
///|
pub extend StatementKind with @debug.Debug::{to_repr}

///|
pub extend Statement with Eq::{equal,not_equal}
///|
pub extend Statement with @debug.Debug::{to_repr}

///|
pub extend Diagram with Eq::{equal,not_equal}
///|
pub extend Diagram with @debug.Debug::{to_repr}

///|
fn node_metadata(node : NodeDecl) -> Array[(String,Json)] {
 let values=node.metadata.iter().filter(data => data.0 != "label" && data.0 != "shape" && data.0 != "labelType").to_array()
 values.sort_by((a,b) => a.0.lexical_compare(b.0)); values
}
///|
pub impl Eq for NodeDecl with equal(a,b) { a.id == b.id && a.label == b.label && a.label_kind == b.label_kind && a.shape == b.shape && metadata_equal(node_metadata(a),node_metadata(b)) && a.classes == b.classes }
///|
pub impl Eq for Link with equal(a,b) { a.label == b.label && a.label_kind == b.label_kind && a.id == b.id && a.source_marker == b.source_marker && a.target_marker == b.target_marker && a.style == b.style && a.length == b.length }

///|
fn metadata_equal(left : Array[(String,Json)], right : Array[(String,Json)]) -> Bool {
 if left.length() != right.length() { return false }
 let stack=[]
 for index,pair in left { if pair.0 != right[index].0 { return false }; stack.push((pair.1,right[index].1)) }
 while stack.pop() is Some((a,b)) {
  match (a,b) {
   (Number(x,..),Number(y,..)) => if !(x == y || (x.is_nan() && y.is_nan())) { return false }
   (Array(x),Array(y)) => { if x.length() != y.length() { return false }; for i,value in x { stack.push((value,y[i])) } }
   (Object(x),Object(y)) => { if x.length() != y.length() { return false }; for key,value in x { guard y.get(key) is Some(other) else { return false }; stack.push((value,other)) } }
   _ => if a != b { return false }
  }
 }
 true
}
