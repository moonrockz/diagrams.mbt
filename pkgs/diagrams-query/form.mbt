///|
/// An unresolved name of the query form. `prefix` is a query namespace
/// prefix; `None` means no namespace.
pub struct QName {
  prefix : String?
  local_name : String
} derive(Eq, Debug)

///|
pub extend QName with Eq::{equal, not_equal}

///|
pub extend QName with @debug.Debug::{to_repr}

///|
pub fn QName::new(local_name : String, prefix? : String) -> QName {
  { prefix, local_name }
}

///|
/// What a node pattern selects: an exact kind, a category or any node.
pub(all) enum Selector {
  Kind(QName)
  Category(String)
  Wildcard
} derive(Eq, Debug)

///|
pub extend Selector with Eq::{equal, not_equal}

///|
pub extend Selector with @debug.Debug::{to_repr}

///|
/// A structural pattern. `Node` has a selector, ordered parts and capture
/// names. `Alternation` tries its branches in order; its captures bind the
/// node that the selected branch matched.
pub(all) enum Pattern {
  Node(Selector, ReadOnlyArray[Part], ReadOnlyArray[String])
  Alternation(ReadOnlyArray[Pattern], ReadOnlyArray[String])
} derive(Eq, Debug)

///|
pub extend Pattern with Eq::{equal, not_equal}

///|
pub extend Pattern with @debug.Debug::{to_repr}

///|
/// A part of a node pattern. `Child` matches a direct child, `Field` a
/// direct child in a named field, and `Absent` requires that the field has no
/// child.
pub(all) enum Part {
  Child(Pattern)
  Field(QName, Pattern)
  Absent(QName)
} derive(Eq, Debug)

///|
pub extend Part with Eq::{equal, not_equal}

///|
pub extend Part with @debug.Debug::{to_repr}

///|
/// A native predicate. `name` is the predicate name without `#`, for example
/// `attr-eq?`. `operands` are the strings after the capture.
pub struct Predicate {
  name : String
  capture : String
  operands : ReadOnlyArray[String]
} derive(Eq, Debug)

///|
pub extend Predicate with Eq::{equal, not_equal}

///|
pub extend Predicate with @debug.Debug::{to_repr}

///|
/// One source pattern with its conjunctive predicates.
pub struct Rule {
  pattern : Pattern
  predicates : ReadOnlyArray[Predicate]
} derive(Eq, Debug)

///|
pub extend Rule with Eq::{equal, not_equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
/// The typed form of a query. `parse` gives the same form for query text,
/// with source spans for diagnostics; forms built in code have no spans.
pub struct QueryForm {
  rules : ReadOnlyArray[Rule]
  priv spans : ReadOnlyArray[QuerySpan]
}

///|
/// Forms are equal when their rules are equal; source spans do not count.
pub impl Eq for QueryForm with equal(a, b) {
  a.rules == b.rules
}

///|
pub extend QueryForm with Eq::{equal, not_equal}

///|
pub impl @debug.Debug for QueryForm with to_repr(self) {
  @debug.Repr::Repr(self.rules.iter().to_array())
}

///|
pub extend QueryForm with @debug.Debug::{to_repr}

///|
pub fn QueryForm::new(rules : ArrayView[Rule]) -> QueryForm {
  { rules: ReadOnlyArray::from_array(rules.to_owned()), spans: [] }
}

///|
pub fn Rule::new(
  pattern : Pattern,
  predicates? : ArrayView[Predicate] = [],
) -> Rule {
  { pattern, predicates: ReadOnlyArray::from_array(predicates.to_owned()) }
}

///|
/// A node pattern.
pub fn Pattern::node(
  selector : Selector,
  parts? : ArrayView[Part] = [],
  captures? : ArrayView[String] = [],
) -> Pattern {
  Node(
    selector,
    ReadOnlyArray::from_array(parts.to_owned()),
    ReadOnlyArray::from_array(captures.to_owned()),
  )
}

///|
pub fn Pattern::alternation(
  branches : ArrayView[Pattern],
  captures? : ArrayView[String] = [],
) -> Pattern {
  Alternation(
    ReadOnlyArray::from_array(branches.to_owned()),
    ReadOnlyArray::from_array(captures.to_owned()),
  )
}

///|
pub fn Predicate::new(
  name : String,
  capture : String,
  operands? : ArrayView[String] = [],
) -> Predicate {
  { name, capture, operands: ReadOnlyArray::from_array(operands.to_owned()) }
}

///|
pub fn Predicate::has_attr(capture : String, attribute : String) -> Predicate {
  Predicate::new("has-attr?", capture, operands=[attribute])
}

///|
pub fn Predicate::missing_attr(
  capture : String,
  attribute : String,
) -> Predicate {
  Predicate::new("missing-attr?", capture, operands=[attribute])
}

///|
pub fn Predicate::attr_eq(
  capture : String,
  attribute : String,
  value : String,
) -> Predicate {
  Predicate::new("attr-eq?", capture, operands=[attribute, value])
}

///|
pub fn Predicate::attr_not_eq(
  capture : String,
  attribute : String,
  value : String,
) -> Predicate {
  Predicate::new("attr-not-eq?", capture, operands=[attribute, value])
}

///|
pub fn Predicate::attr_in(
  capture : String,
  attribute : String,
  values : ArrayView[String],
) -> Predicate {
  let operands = [attribute]
  operands.append(values.to_owned())
  Predicate::new("attr-in?", capture, operands~)
}

///|
pub fn Predicate::text_eq(capture : String, value : String) -> Predicate {
  Predicate::new("text-eq?", capture, operands=[value])
}
