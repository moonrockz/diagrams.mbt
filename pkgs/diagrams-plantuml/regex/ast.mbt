///|
/// One typed regex expression. Composite nodes are flat: a concatenation
/// never holds another concatenation directly, and an alternation never
/// holds another alternation directly.
pub(all) enum Expr {
  /// One code point. `true` marks an escaped character such as `\.`.
  Char(String, Bool, @diagrams.Span?)
  Class(@model.ClassKind, @diagrams.Span?)
  Backreference(String, @diagrams.Span?)
  /// A bracketed set. `true` marks a negated set.
  Set(Bool, ReadOnlyArray[@model.SetItem], @diagrams.Span?)
  Anchor(@model.AnchorKind, @diagrams.Span?)
  Concat(ReadOnlyArray[Expr])
  Alt(ReadOnlyArray[Expr])
  Group(@model.GroupKind, Expr, @diagrams.Span?)
  /// A lookaround. `true` marks a positive assertion.
  Look(@model.Look, Bool, Expr, @diagrams.Span?)
  Quantified(Expr, @model.Bounds, @diagrams.Span?)
} derive(Eq, Debug)

///|
pub extend Expr with Eq::{not_equal, equal}

///|
pub extend Expr with @debug.Debug::{to_repr}

///|
/// The expression without source locations, for logical comparison.
pub fn Expr::without_spans(self : Expr) -> Expr {
  match self {
    Char(c, escaped, _) => Char(c, escaped, None)
    Class(kind, _) => Class(kind, None)
    Backreference(n, _) => Backreference(n, None)
    Set(negated, items, _) => Set(negated, items, None)
    Anchor(kind, _) => Anchor(kind, None)
    Concat(items) => Concat(ReadOnlyArray::from_iter(items.iter().map(e => e.without_spans())))
    Alt(items) => Alt(ReadOnlyArray::from_iter(items.iter().map(e => e.without_spans())))
    Group(kind, inner, _) => Group(kind, inner.without_spans(), None)
    Look(look, positive, inner, _) =>
      Look(look, positive, inner.without_spans(), None)
    Quantified(inner, bounds, _) => Quantified(inner.without_spans(), bounds, None)
  }
}

///|
/// One parsed regex block.
pub struct Document {
  name : String?
  statements : ReadOnlyArray[@envelope.Statement]
  pattern : Expr
  /// The source spelling of the pattern line, for display.
  text : String
  span : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Document with Eq::{not_equal, equal}

///|
pub extend Document with @debug.Debug::{to_repr}

///|
pub fn Document::new(
  pattern : Expr,
  name? : String,
  statements? : ArrayView[@envelope.Statement] = [],
  text? : String = "",
) -> Document {
  {
    name,
    statements: ReadOnlyArray::from_array(statements),
    pattern,
    text,
    span: None,
  }
}

///|
/// The document without source locations and source spelling.
pub fn Document::without_spans(self : Document) -> Document {
  { ..self, pattern: self.pattern.without_spans(), text: "", span: None }
}

///|
/// True when two documents have equal logical content. Source locations,
/// source spelling and trivia are not compared.
pub fn Document::logical_equal(self : Document, other : Document) -> Bool {
  self.without_spans() == other.without_spans()
}
