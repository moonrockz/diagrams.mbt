///|
/// One typed EBNF expression. Concatenations and alternations are flat.
/// Grouping parentheses are syntax only; the tree records the structure.
pub(all) enum Expr {
  Terminal(String, @model.Quote, Notes, @diagrams.Span?)
  /// A nonterminal reference by name.
  Name(String, Notes, @diagrams.Span?)
  Special(String, Notes, @diagrams.Span?)
  Concat(ReadOnlyArray[Expr])
  Alt(ReadOnlyArray[Expr])
  Optional(Expr, @diagrams.Span?)
  ZeroOrMore(Expr, @diagrams.Span?)
  OneOrMore(Expr, @diagrams.Span?)
  /// `n * x`, with the decimal count spelling.
  Count(String, Expr, @diagrams.Span?)
  /// `- x`: an exclusion of `x` from the previous item of its concatenation.
  Not(Expr, @diagrams.Span?)
} derive(Eq, Debug)

///|
/// The note above and the note below a leaf term.
pub struct Notes {
  above : String?
  below : String?
} derive(Eq, Debug)

///|
pub let no_note : Notes = { above: None, below: None }

///|
pub extend Expr with Eq::{not_equal, equal}

///|
pub extend Expr with @debug.Debug::{to_repr}

///|
pub extend Notes with Eq::{not_equal, equal}

///|
pub extend Notes with @debug.Debug::{to_repr}

///|
pub fn Expr::without_spans(self : Expr) -> Expr {
  fn all(items : ReadOnlyArray[Expr]) -> ReadOnlyArray[Expr] {
    ReadOnlyArray::from_iter(items.iter().map(e => e.without_spans()))
  }
  match self {
    Terminal(t, q, n, _) => Terminal(t, q, n, None)
    Name(t, n, _) => Name(t, n, None)
    Special(t, n, _) => Special(t, n, None)
    Concat(items) => Concat(all(items))
    Alt(items) => Alt(all(items))
    Optional(e, _) => Optional(e.without_spans(), None)
    ZeroOrMore(e, _) => ZeroOrMore(e.without_spans(), None)
    OneOrMore(e, _) => OneOrMore(e.without_spans(), None)
    Count(c, e, _) => Count(c, e.without_spans(), None)
    Not(e, _) => Not(e.without_spans(), None)
  }
}

///|
pub struct Rule {
  name : String
  body : Expr?
  above : String?
  below : String?
  span : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Rule with Eq::{not_equal, equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
pub(all) enum Item {
  Rule(Rule)
  /// A free-standing note, one entry per line.
  Note(ReadOnlyArray[String], @diagrams.Span?)
} derive(Eq, Debug)

///|
pub extend Item with Eq::{not_equal, equal}

///|
pub extend Item with @debug.Debug::{to_repr}

///|
pub struct Document {
  name : String?
  statements : ReadOnlyArray[@envelope.Statement]
  items : ReadOnlyArray[Item]
} derive(Eq, Debug)

///|
pub extend Document with Eq::{not_equal, equal}

///|
pub extend Document with @debug.Debug::{to_repr}

///|
pub fn Document::new(
  items : ArrayView[Item],
  name? : String,
  statements? : ArrayView[@envelope.Statement] = [],
) -> Document {
  {
    name,
    statements: ReadOnlyArray::from_array(statements),
    items: ReadOnlyArray::from_array(items),
  }
}

///|
pub fn Document::without_spans(self : Document) -> Document {
  {
    ..self,
    items: ReadOnlyArray::from_iter(
      self.items
      .iter()
      .map(item => match item {
        Rule(rule) =>
          Rule({ ..rule, body: rule.body.map(e => e.without_spans()), span: None })
        Note(lines, _) => Note(lines, None)
      }),
    ),
  }
}

///|
pub fn Document::logical_equal(self : Document, other : Document) -> Bool {
  self.without_spans() == other.without_spans()
}
