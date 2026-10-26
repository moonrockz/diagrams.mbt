///|
pub struct Conversion {
  grammar : @model.Grammar?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Convert an EBNF document to the format-independent grammar model. Names
/// stay symbolic references; recursive rules are never expanded. An
/// exclusion constrains the term before it and is never an alternative.
pub fn to_grammar(
  document : Document,
  id? : String = "ebnf",
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> Conversion {
  let nodes : Array[@model.Node] = []
  let items : Array[@model.Item] = []
  let mut failure : String? = None
  fn add(
    id : String,
    kind : @model.Kind,
    notes : Notes,
    span : @diagrams.Span?,
  ) -> String {
    if nodes.length() >= limits.nodes {
      failure = Some("EBNF node limit exceeded")
    } else {
      nodes.push(
        @model.Node::new(
          id,
          kind,
          notes_above=notes.above.map(t => [t]).unwrap_or([]),
          notes_below=notes.below.map(t => [t]).unwrap_or([]),
          source?=span,
        ),
      )
    }
    id
  }
  fn convert(e : Expr, id : String, depth : Int) -> String {
    if depth > limits.depth {
      failure = Some("EBNF depth limit exceeded")
    }
    if failure is Some(_) {
      return id
    }
    match e {
      Terminal(text, quote, notes, span) => add(id, Terminal(text, quote), notes, span)
      Name(name, notes, span) => add(id, Reference(name, None), notes, span)
      Special(text, notes, span) => add(id, Special(text), notes, span)
      Concat(list) => {
        let units : Array[String] = []
        for k, item in list {
          let child = id + "." + k.to_string()
          match item {
            Not(excluded, span) =>
              match units.pop() {
                Some(left) => {
                  let x = convert(excluded, child + ".0", depth + 2)
                  units.push(add(child, Exclusion(left, x), no_note, span))
                }
                None => {
                  failure = Some("An exclusion has no term on its left")
                  return id
                }
              }
            _ => units.push(convert(item, child, depth + 1))
          }
        }
        if units.length() == 1 {
          // The concatenation is only `left - excluded`; keep the identity of
          // the exclusion node.
          return units[0]
        }
        add(id, Sequence(ReadOnlyArray::from_array(units)), no_note, None)
      }
      Alt(list) => {
        let children = []
        for k, item in list {
          if item is Not(_, _) {
            failure = Some("An exclusion has no term on its left")
            return id
          }
          children.push(convert(item, id + "." + k.to_string(), depth + 1))
        }
        add(id, Choice(ReadOnlyArray::from_array(children)), no_note, None)
      }
      Optional(inner, span) =>
        add(id, Optional(convert(inner, id + ".0", depth + 1)), no_note, span)
      ZeroOrMore(inner, span) =>
        add(id, ZeroOrMore(convert(inner, id + ".0", depth + 1)), no_note, span)
      OneOrMore(inner, span) =>
        add(id, OneOrMore(convert(inner, id + ".0", depth + 1)), no_note, span)
      Count(count, inner, span) =>
        add(id, Count(count, convert(inner, id + ".0", depth + 1)), no_note, span)
      Not(_, _) => {
        failure = Some("An exclusion has no term on its left")
        id
      }
    }
  }
  for k, item in document.items {
    let item_id = "item-" + k.to_string()
    match item {
      Note(lines, _) => items.push(Note(item_id, lines.iter().collect().join("\n")))
      Rule(rule) => {
        let body = rule.body.map(e => convert(e, item_id + "/e", 0))
        items.push(
          Rule(
            @model.Rule::new(
              item_id,
              rule.name,
              body?,
              note_above?=rule.above,
              note_below?=rule.below,
              source?=rule.span,
            ),
          ),
        )
      }
    }
  }
  if failure is Some(message) {
    return {
      grammar: None,
      diagnostics: [@diagrams.Diagnostic::error("ebnf/limit", message)],
    }
  }
  let mut title = None
  for statement in document.statements {
    if statement is Title(text) {
      title = Some(text)
    }
  }
  let grammar = @model.Grammar::new(id, items, nodes, title?)
  let findings = @model.validate(
    grammar,
    limits=@model.Limits::new(
      nodes=limits.nodes,
      depth=limits.depth + 2,
      work=limits.work,
    ),
  )
  if findings.iter().any(d => d.severity == Error) {
    return { grammar: None, diagnostics: findings }
  }
  { grammar: Some(grammar), diagnostics: findings }
}
