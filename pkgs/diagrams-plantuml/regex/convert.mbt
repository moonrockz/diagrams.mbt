///|
pub struct Conversion {
  regex : @model.Regex?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Convert a regex document to the format-independent model. Adjacent
/// characters of a concatenation become one literal term, as PlantUML draws
/// them. Node identities are ordered ownership paths, never labels.
pub fn to_regex(
  document : Document,
  id? : String = "regex",
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> Conversion {
  let nodes : Array[@model.Node] = []
  let mut failure : String? = None
  fn add(id : String, kind : @model.Kind, span : @diagrams.Span?) -> String {
    if nodes.length() >= limits.nodes {
      failure = Some("Regex node limit exceeded")
    } else {
      nodes.push(@model.Node::new(id, kind, source?=span))
    }
    id
  }
  fn convert(expr : Expr, id : String, depth : Int) -> String {
    if depth > limits.depth {
      failure = Some("Regex depth limit exceeded")
      return id
    }
    if failure is Some(_) {
      return id
    }
    match expr {
      Char(c, _, span) => add(id, Literal(c), span)
      Class(kind, span) => add(id, Class(kind), span)
      Backreference(n, span) => add(id, Backreference(n), span)
      Set(negated, items, span) => add(id, Set(negated, items), span)
      Anchor(kind, span) => add(id, Anchor(kind), span)
      Concat(items) => {
        // Group the items into merged literal runs and other expressions.
        let runs : Array[(Int, Array[Expr])] = []
        for i, item in items {
          match (item, runs.last()) {
            (Char(_, _, _), Some((_, run))) if run.last() is Some(Char(_, _, _)) =>
              run.push(item)
            _ => runs.push((i, [item]))
          }
        }
        fn literal(run : Array[Expr], id : String) -> String {
          let text = StringBuilder()
          let mut first : @diagrams.Span? = None
          let mut last : @diagrams.Span? = None
          for e in run {
            if e is Char(c, _, span) {
              text.write_string(c)
              if first is None {
                first = span
              }
              last = span
            }
          }
          let span = match (first, last) {
            (Some(a), Some(b)) => Some(@diagrams.Span::{ start: a.start, end: b.end })
            _ => None
          }
          add(id, Literal(text.to_string()), span)
        }
        if runs.length() == 1 {
          let (_, run) = runs[0]
          return literal(run, id)
        }
        let children = []
        for pair in runs {
          let (index, run) = pair
          let child = id + "." + index.to_string()
          if run.length() > 1 || run[0] is Char(_, _, _) {
            children.push(literal(run, child))
          } else {
            children.push(convert(run[0], child, depth + 1))
          }
        }
        add(id, Sequence(ReadOnlyArray::from_array(children)), None)
      }
      Alt(items) => {
        let children = []
        for i, item in items {
          children.push(convert(item, id + "." + i.to_string(), depth + 1))
        }
        add(id, Choice(ReadOnlyArray::from_array(children)), None)
      }
      Group(kind, inner, span) => {
        let child = convert(inner, id + ".0", depth + 1)
        add(id, Group(kind, child), span)
      }
      Look(look, positive, inner, span) => {
        let child = convert(inner, id + ".0", depth + 1)
        add(id, Assertion(look, positive, child), span)
      }
      Quantified(inner, bounds, span) => {
        let child = convert(inner, id + ".0", depth + 1)
        add(id, Repeat(bounds, child), span)
      }
    }
  }
  let root = convert(document.pattern, "p", 0)
  if failure is Some(message) {
    return {
      regex: None,
      diagnostics: [@diagrams.Diagnostic::error("regex/limit", message)],
    }
  }
  let mut title = None
  for statement in document.statements {
    if statement is Title(text) {
      title = Some(text)
    }
  }
  let model = @model.Regex::new(
    id,
    root,
    nodes,
    title?,
    pattern?=if document.text.is_empty() { None } else { Some(document.text) },
  )
  let findings = @model.validate(
    model,
    limits=@model.Limits::new(
      nodes=limits.nodes,
      depth=limits.depth + 1,
      work=limits.work,
    ),
  )
  if !findings.is_empty() {
    return { regex: None, diagnostics: findings }
  }
  { regex: Some(model), diagnostics: [] }
}
