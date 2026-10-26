///|
/// The quote character of a terminal string.
pub(all) enum Quote {
  Double
  Single
} derive(Eq, Debug)

///|
pub extend Quote with Eq::{equal, not_equal}

///|
pub extend Quote with @debug.Debug::{to_repr}

///|
/// The meaning of one grammar expression node. Composite kinds name their
/// children by node identity, so a grammar is a flat, bounded arena.
pub(all) enum Kind {
  /// A quoted terminal string.
  Terminal(String, Quote)
  /// A named nonterminal. The optional identity names its target rule
  /// explicitly; without it, validation resolves the name.
  Reference(String, String?)
  /// A special sequence such as `? digits ?`.
  Special(String)
  /// An empty term.
  Empty
  Sequence(ReadOnlyArray[String])
  Choice(ReadOnlyArray[String])
  /// `[ x ]`
  Optional(String)
  /// `{ x }`
  ZeroOrMore(String)
  /// `{ x }-`
  OneOrMore(String)
  /// `n * x`, with the decimal count spelling.
  Count(String, String)
  /// `x - y`: the left term, constrained so that it does not match the excluded term.
  Exclusion(String, String)
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with @debug.Debug::{to_repr}

///|
pub struct Node {
  id : String
  kind : Kind
  notes_above : ReadOnlyArray[String]
  notes_below : ReadOnlyArray[String]
  source : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub fn Node::new(
  id : String,
  kind : Kind,
  notes_above? : ArrayView[String] = [],
  notes_below? : ArrayView[String] = [],
  source? : @diagrams.Span,
) -> Node {
  {
    id,
    kind,
    notes_above: ReadOnlyArray::from_array(notes_above),
    notes_below: ReadOnlyArray::from_array(notes_below),
    source,
  }
}

///|
/// The children of `node` in drawing order. An exclusion lists its left term
/// first and its excluded term second.
pub fn Node::children(self : Node) -> ReadOnlyArray[String] {
  match self.kind {
    Sequence(items) | Choice(items) => items
    Optional(child) | ZeroOrMore(child) | OneOrMore(child) | Count(_, child) =>
      [child]
    Exclusion(left, excluded) => [left, excluded]
    _ => []
  }
}

///|
/// Terminals, references, special sequences and empty terms are leaves.
pub fn Node::is_leaf(self : Node) -> Bool {
  match self.kind {
    Terminal(_, _) | Reference(_, _) | Special(_) | Empty => true
    _ => false
  }
}

///|
pub fn Node::label(self : Node) -> String {
  match self.kind {
    Terminal(text, _) => text
    Reference(name, _) => name
    Special(text) => text
    Empty => "empty"
    Sequence(_) => "sequence"
    Choice(_) => "choice"
    Optional(_) => "optional"
    ZeroOrMore(_) => "zero or more"
    OneOrMore(_) => "one or more"
    Count(count, _) => count + "\u{d7}"
    Exclusion(_, _) => "except"
  }
}

///|
/// One named rule. A rule without a body is an empty definition.
pub struct Rule {
  id : String
  name : String
  body : String?
  note_above : String?
  note_below : String?
  source : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Rule with Eq::{equal, not_equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
pub fn Rule::new(
  id : String,
  name : String,
  body? : String,
  note_above? : String,
  note_below? : String,
  source? : @diagrams.Span,
) -> Rule {
  { id, name, body, note_above, note_below, source }
}

///|
/// One ordered grammar statement: a rule or a free-standing note.
pub(all) enum Item {
  Rule(Rule)
  Note(String, String)
} derive(Eq, Debug)

///|
pub extend Item with Eq::{equal, not_equal}

///|
pub extend Item with @debug.Debug::{to_repr}

///|
/// One immutable grammar diagram. It describes a grammar; it does not parse input.
pub struct Grammar {
  id : String
  items : ReadOnlyArray[Item]
  nodes : ReadOnlyArray[Node]
  title : String?
  accessibility_title : String?
  accessibility_description : String?
} derive(Eq, Debug)

///|
pub extend Grammar with Eq::{equal, not_equal}

///|
pub extend Grammar with @debug.Debug::{to_repr}

///|
pub fn Grammar::new(
  id : String,
  items : ArrayView[Item],
  nodes : ArrayView[Node],
  title? : String,
  accessibility_title? : String,
  accessibility_description? : String,
) -> Grammar {
  {
    id,
    items: ReadOnlyArray::from_array(items),
    nodes: ReadOnlyArray::from_array(nodes),
    title,
    accessibility_title,
    accessibility_description,
  }
}

///|
/// The rules of the grammar in source order.
pub fn Grammar::rules(self : Grammar) -> Array[Rule] {
  let out = []
  for item in self.items {
    if item is Rule(rule) {
      out.push(rule)
    }
  }
  out
}
