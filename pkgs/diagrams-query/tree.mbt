///|
/// A position in source text. Offsets and columns count UTF-16 code units;
/// lines and columns start at 1.
pub(all) struct QueryPosition {
  offset : Int
  line : Int
  column : Int
} derive(Eq, Debug)

///|
pub extend QueryPosition with Eq::{equal, not_equal}

///|
pub extend QueryPosition with @debug.Debug::{to_repr}

///|
/// A half-open source range with an optional source identifier.
pub(all) struct QueryLocation {
  source_id : String?
  start : QueryPosition
  end : QueryPosition
} derive(Eq, Debug)

///|
pub extend QueryLocation with Eq::{equal, not_equal}

///|
pub extend QueryLocation with @debug.Debug::{to_repr}

///|
/// A present attribute value. `tag` is one of the schema scalar tags and
/// `text` is the decoded value that predicates compare.
pub(all) struct ScalarValue {
  tag : String
  text : String
} derive(Eq, Debug)

///|
pub extend ScalarValue with Eq::{equal, not_equal}

///|
pub extend ScalarValue with @debug.Debug::{to_repr}

///|
/// One step of a document-relative path: the containing field, the index in
/// that field and the position among all children of the parent.
pub(all) struct QueryPathStep {
  field : Name
  index : Int
  position : Int
} derive(Eq, Debug)

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
  schema(Self) -> Schema
  /// The default search root.
  root(Self) -> Int
  node_count(Self) -> Int
  /// The exact kind of an element node, or `None` for other nodes.
  kind(Self, Int) -> Name?
  category(Self, Int) -> String
  /// The ordered containment children.
  children(Self, Int) -> ArrayView[Int]
  /// The field that contains the node in its parent, or `None` for a root.
  field(Self, Int) -> Name?
  /// The value of an attribute, or `None` when the attribute is absent.
  attribute(Self, Int, Name) -> ScalarValue?
  /// The adapter-declared scalar text, or `None` when the node has none.
  text(Self, Int) -> String?
  /// The value of an adapter-declared projection field.
  extra(Self, Int, String) -> ScalarValue?
  location(Self, Int) -> QueryLocation?
  /// The document-relative path from the tree root.
  path(Self, Int) -> ReadOnlyArray[QueryPathStep]
  depth(Self, Int) -> Int
}
