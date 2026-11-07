///|
/// A predefined character class. The spelling is kept for display.
#derive(Eq, Debug)
pub(all) enum ClassKind {
  /// `.`
  Any
  /// A letter escape such as `\d`, `\W` or `\s`.
  Shorthand(Char)
  /// A Unicode property such as `\p{Lu}`.
  Property(String)
  /// A code point escape such as `\x{41}`, `A` or `\0101`.
  CodePoint(String)
  /// A POSIX bracket class such as `[[:alpha:]]`, stored as `alpha`.
  Posix(String)
}

///|
pub extend ClassKind with Eq::{equal, not_equal}

///|
pub extend ClassKind with @debug.Debug::{to_repr}

///|
/// One item of a bracketed character set.
#derive(Eq, Debug)
pub(all) enum SetItem {
  /// One literal character, or one escaped character.
  Char(String)
  /// An inclusive range such as `a-z`.
  Range(String, String)
  /// A letter escape inside the set, such as `\d`.
  Escape(String)
}

///|
pub extend SetItem with Eq::{equal, not_equal}

///|
pub extend SetItem with @debug.Debug::{to_repr}

///|
/// A zero-width position test that consumes no input.
#derive(Eq, Debug)
pub(all) enum AnchorKind {
  /// `^`
  LineStart
  /// `$`
  LineEnd
  /// `\A`
  InputStart
  /// `\Z`
  InputEndBeforeNewline
  /// `\z`
  InputEnd
  /// `\G`
  PreviousMatchEnd
  /// `\b`
  WordBoundary
  /// `\B`
  NonWordBoundary
}

///|
pub extend AnchorKind with Eq::{equal, not_equal}

///|
pub extend AnchorKind with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum GroupKind {
  Capturing
  NonCapturing
  Named(String)
}

///|
pub extend GroupKind with Eq::{equal, not_equal}

///|
pub extend GroupKind with @debug.Debug::{to_repr}

///|
/// The direction of a lookaround assertion.
#derive(Eq, Debug)
pub(all) enum Look {
  Ahead
  Behind
}

///|
pub extend Look with Eq::{equal, not_equal}

///|
pub extend Look with @debug.Debug::{to_repr}

///|
/// Symbolic repetition bounds. A repeat is never expanded into copies.
#derive(Eq, Debug)
pub struct Bounds {
  min : Int32
  max : Int32?
  reluctant : Bool
  spelling : String
}

///|
pub extend Bounds with Eq::{equal, not_equal}

///|
pub extend Bounds with @debug.Debug::{to_repr}

///|
/// Make bounds. The spelling defaults to the canonical regex quantifier.
pub fn Bounds::new(
  min : Int32,
  max? : Int32,
  reluctant~ : Bool = false,
  spelling? : String,
) -> Bounds {
  let spelling = match spelling {
    Some(text) => text
    None => {
      let base = match (min, max) {
        (0, None) => "*"
        (1, None) => "+"
        (0, Some(1)) => "?"
        (n, None) => "{\{n},}"
        (n, Some(m)) => if n == m { "{\{n}}" } else { "{\{n},\{m}}" }
      }
      if reluctant {
        base + "?"
      } else {
        base
      }
    }
  }
  { min, max, reluctant, spelling, }
}

///|
/// The meaning of one expression node. Composite kinds name their children by
/// node identity, so a model is a flat, bounded arena.
#derive(Eq, Debug)
pub(all) enum Kind {
  /// Consumed literal text of one or more code points.
  Literal(String)
  Class(ClassKind)
  /// A bracketed set. `true` marks a negated set such as `[^abc]`.
  Set(Bool, ReadOnlyArray[SetItem])
  Anchor(AnchorKind)
  /// A numbered backreference such as `\1`. It consumes the text of a group.
  Backreference(String)
  Sequence(ReadOnlyArray[String])
  Choice(ReadOnlyArray[String])
  Group(GroupKind, String)
  Repeat(Bounds, String)
  /// A lookaround constraint. `true` marks a positive assertion.
  Assertion(Look, Bool, String)
}

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub struct Node {
  id : String
  kind : Kind
  source : @diagrams.Span?
}

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub fn Node::new(id : String, kind : Kind, source? : @diagrams.Span) -> Node {
  { id, kind, source, }
}

///|
/// The children of `node` in drawing order.
pub fn Node::children(self : Node) -> ReadOnlyArray[String] {
  match self.kind {
    Sequence(items) | Choice(items) => items
    Group(_, child) | Repeat(_, child) | Assertion(_, _, child) => [child]
    _ => []
  }
}

///|
/// Literal text, classes, sets and anchors are leaves of the railroad.
pub fn Node::is_leaf(self : Node) -> Bool {
  match self.kind {
    Literal(_) | Class(_) | Set(_, _) | Anchor(_) | Backreference(_) => true
    _ => false
  }
}

///|
/// The visible label of a leaf, or the name of a composite construct.
pub fn Node::label(self : Node) -> String {
  match self.kind {
    Literal(text) => text
    Class(Any) => "."
    Class(Shorthand(c)) => "\\" + c.to_string()
    Class(Property(name)) => "\\p{" + name + "}"
    Class(CodePoint(spelling)) => spelling
    Class(Posix(name)) => ":" + name + ":"
    Set(negated, items) => {
      let out = StringBuilder()
      if negated {
        out.write_string("not ")
      }
      for i, item in items {
        if i > 0 {
          out.write_string(" ")
        }
        match item {
          Char(c) => out.write_string(c)
          Range(a, b) => out.write_string(a + "-" + b)
          Escape(e) => out.write_string(e)
        }
      }
      out.to_string()
    }
    Anchor(kind) =>
      match kind {
        LineStart => "^"
        LineEnd => "$"
        InputStart => "\\A"
        InputEndBeforeNewline => "\\Z"
        InputEnd => "\\z"
        PreviousMatchEnd => "\\G"
        WordBoundary => "\\b"
        NonWordBoundary => "\\B"
      }
    Backreference(number) => "\\" + number
    Sequence(_) => "sequence"
    Choice(_) => "choice"
    Group(Capturing, _) => "group"
    Group(NonCapturing, _) => "?:"
    Group(Named(name), _) => name
    Repeat(bounds, _) => bounds.spelling
    Assertion(look, positive, _) =>
      match (look, positive) {
        (Ahead, true) => "?="
        (Ahead, false) => "?!"
        (Behind, true) => "?<="
        (Behind, false) => "?<!"
      }
  }
}

///|
/// One immutable regular-expression diagram. It describes the structure of a
/// pattern; it does not match input.
#derive(Eq, Debug)
pub struct Regex {
  id : String
  root : String
  nodes : ReadOnlyArray[Node]
  title : String?
  accessibility_title : String?
  accessibility_description : String?
  pattern : String?
}

///|
pub extend Regex with Eq::{equal, not_equal}

///|
pub extend Regex with @debug.Debug::{to_repr}

///|
/// Make a regex model. `pattern` is the optional source spelling for display.
pub fn Regex::new(
  id : String,
  root : String,
  nodes : ArrayView[Node],
  title? : String,
  accessibility_title? : String,
  accessibility_description? : String,
  pattern? : String,
) -> Regex {
  {
    id,
    root,
    nodes: ReadOnlyArray::from_array(nodes),
    title,
    accessibility_title,
    accessibility_description,
    pattern,
  }
}

///|
/// Find a node by identity. The search is linear; use `Index` for repeated lookups.
pub fn Regex::node(self : Regex, id : String) -> Node? {
  for node in self.nodes {
    if node.id == id {
      return Some(node)
    }
  }
  None
}
