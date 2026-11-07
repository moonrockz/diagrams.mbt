///|
/// A position in source text. Offsets and columns count UTF-16 code units;
/// lines and columns start at 1.
#derive(Eq, Debug)
pub(all) struct QueryPosition {
  offset : Int32
  line : Int32
  column : Int32
}

///|
pub extend QueryPosition with Eq::{equal, not_equal}

///|
pub extend QueryPosition with @debug.Debug::{to_repr}

///|
/// A half-open source range with an optional source identifier.
#derive(Eq, Debug)
pub(all) struct QueryLocation {
  source_id : String?
  start : QueryPosition
  end : QueryPosition
}

///|
pub extend QueryLocation with Eq::{equal, not_equal}

///|
pub extend QueryLocation with @debug.Debug::{to_repr}

///|
/// A present attribute value. `tag` is one of the schema scalar tags and
/// `text` is the decoded value that predicates compare.
#derive(Eq, Debug)
pub(all) struct ScalarValue {
  tag : String
  text : String
}

///|
pub extend ScalarValue with Eq::{equal, not_equal}

///|
pub extend ScalarValue with @debug.Debug::{to_repr}

///|
/// One step of a document-relative path: the containing field, the index in
/// that field and the position among all children of the parent.
#derive(Eq, Debug)
pub(all) struct QueryPathStep {
  field : Name
  index : Int32
  position : Int32
}

///|
pub extend QueryPathStep with Eq::{equal, not_equal}

///|
pub extend QueryPathStep with @debug.Debug::{to_repr}

///|
/// A read-only tree that the query evaluator can search.
///
/// Nodes are integers from 0 to `node_count() - 1`. The evaluator follows only
/// `children`, which is the containment declared by the adapter. It never
/// follows references. An adapter must give the same answers for the same
/// node for as long as a cursor uses it. All names and categories must be
/// admitted by `schema()`.
pub(open) trait QueryTree {
  fn schema(Self) -> Schema
  /// The default search root.
  fn root(Self) -> Int32
  fn node_count(Self) -> Int32
  /// The exact kind of an element node, or `None` for other nodes.
  fn kind(Self, Int32) -> Name?
  fn category(Self, Int32) -> String
  /// The ordered containment children.
  fn children(Self, Int32) -> ArrayView[Int32]
  /// The field that contains the node in its parent, or `None` for a root.
  fn field(Self, Int32) -> Name?
  /// The value of an attribute, or `None` when the attribute is absent.
  fn attribute(Self, Int32, Name) -> ScalarValue?
  /// The adapter-declared scalar text, or `None` when the node has none.
  fn text(Self, Int32) -> String?
  /// The value of an adapter-declared projection field.
  fn extra(Self, Int32, String) -> ScalarValue?
  fn location(Self, Int32) -> QueryLocation?
  /// The document-relative path from the tree root.
  fn path(Self, Int32) -> ReadOnlyArray[QueryPathStep]
  fn depth(Self, Int32) -> Int32
}
