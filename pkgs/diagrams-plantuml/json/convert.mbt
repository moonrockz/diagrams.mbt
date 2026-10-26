///|
/// The result of converting a document to a data tree.
pub struct Conversion {
  tree : @data_tree.DataTree?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Convert a JSON document to a structured-data model. Identities come from
/// ordered ownership paths: the root value is `v`, member 2 of the value of
/// root member 0 is `m/0/2` and its value is `v/0/2`. Names and scalar text
/// never define identity, so repeated members stay separate.
///
/// The model keeps a scalar root and empty root containers as they are.
/// PlantUML 1.2026.9 draws a scalar root as a one-element array and an empty
/// root container as an array with one empty string; this library does not
/// copy that projection. The title is the last `title` statement.
pub fn to_data_tree(
  document : Document,
  id? : String,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> Conversion {
  let diagnostics : Array[@diagrams.Diagnostic] = []
  fn failed(code : String, message : String) -> Conversion {
    diagnostics.push(@diagrams.Diagnostic::error(code, message))
    { tree: None, diagnostics: ReadOnlyArray::from_array(diagnostics), }
  }
  if !limits.valid() {
    return failed("json/invalid-limits", "JSON limits must be positive")
  }
  let view = id.unwrap_or(document.name.unwrap_or("json"))
  let nodes : Array[@data_tree.Node] = []
  let mut work = 0
  // Pre-order with an explicit stack: (value, path).
  let stack : Array[(Value, Array[Int32])] = [(document.value, [])]
  while stack.pop() is Some((value, path)) {
    work += 1
    if work > limits.work {
      return failed("json/work-limit", "JSON conversion exceeds its work limit")
    }
    if nodes.length() >= limits.nodes {
      return failed("json/node-limit", "JSON data exceeds the node limit")
    }
    if path.length() > limits.depth {
      return failed(
        "json/depth-limit",
        "JSON nesting exceeds the depth limit of \{limits.depth}",
      )
    }
    let node_id = @data.value_id(path)
    let child_path = (i : Int32) => {
      let next = path.copy()
      next.push(i)
      next
    }
    let node = match value.kind {
      Object(members) => {
        let entries = []
        for i, entry in members {
          let p = child_path(i)
          entries.push(
            @data_tree.Member::named(
              @data.member_id(p),
              entry.name.text,
              @data.value_id(p),
              source?=entry.span,
            ),
          )
        }
        for i in 0..<members.length() {
          let k = members.length() - 1 - i
          stack.push((members[k].value, child_path(k)))
        }
        @data_tree.Node::object(node_id, entries, source?=value.span)
      }
      Array(items) => {
        let entries = []
        for i, item in items {
          let p = child_path(i)
          entries.push(
            @data_tree.Member::index(
              @data.member_id(p),
              i,
              @data.value_id(p),
              source?=item.span,
            ),
          )
        }
        for i in 0..<items.length() {
          let k = items.length() - 1 - i
          stack.push((items[k], child_path(k)))
        }
        @data_tree.Node::array(node_id, entries, source?=value.span)
      }
      String(s) =>
        @data_tree.Node::new(node_id, Text(s.text), source?=value.span)
      Number(lexeme) =>
        @data_tree.Node::new(node_id, Number(lexeme), source?=value.span)
      Boolean(b) =>
        @data_tree.Node::new(node_id, Boolean(b), source?=value.span)
      Null => @data_tree.Node::new(node_id, Null, source?=value.span)
    }
    nodes.push(node)
  }
  let title = document.statements
    .iter()
    .fold(init=None, (last, statement) => {
      match statement {
        Title(text) => Some(text)
        _ => last
      }
    })
  let base = @data_tree.DataTree::new(view, @data.value_id([]), nodes, title?)
  let resolution = @data.resolve(
    base,
    document.highlights,
    "json",
    work_limit=limits.work,
  )
  diagnostics.append(resolution.diagnostics)
  if !resolution.complete {
    return { tree: None, diagnostics: ReadOnlyArray::from_array(diagnostics), }
  }
  let tree = @data_tree.DataTree::new(
    view,
    @data.value_id([]),
    nodes,
    highlights=resolution.highlights,
    title?,
  )
  let invalid = @data_tree.validate(
    tree,
    limits=@data_tree.Limits::new(
      nodes=limits.nodes,
      depth=limits.depth,
      work=limits.work,
    ),
  )
  if !invalid.is_empty() {
    diagnostics.append(invalid)
    return { tree: None, diagnostics: ReadOnlyArray::from_array(diagnostics), }
  }
  { tree: Some(tree), diagnostics: ReadOnlyArray::from_array(diagnostics), }
}
