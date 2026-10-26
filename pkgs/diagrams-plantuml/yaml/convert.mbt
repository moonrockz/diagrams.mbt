///|
/// The result of converting a document to a data tree.
pub struct Conversion {
  tree : @data_tree.DataTree?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// One value under construction. A value starts undetermined; its first
/// use fixes it as a scalar, a list or a map, as in the pinned profile.
priv enum Shape {
  Open
  Leaf(String)
  List(Array[Int32])
  Map(Array[(String, Int32)])
}

///|
priv struct Slot {
  mut shape : Shape
  /// The line that made the value, for source spans.
  line : Int32
}

///|
/// A native refusal: the pinned profile gives no data for the block.
priv suberror Refusal {
  Refusal(String, String, Int32)
}

///|
priv struct Builder {
  slots : Array[Slot]
  indents : Array[Int32]
  stack : Array[Int32]
  warnings : Array[(String, String, Int32)]
  /// The line of the member occurrence that set each map entry value.
  entry_lines : Map[Int32, Int32]
}

///|
fn Builder::slot(self : Builder, shape : Shape, line : Int32) -> Int32 {
  self.slots.push({ shape, line, })
  self.slots.length() - 1
}

///|
fn Builder::last(self : Builder, line : Int32) -> Int32 raise Refusal {
  guard self.stack.last() is Some(top) else {
    raise Refusal(
      "yaml/indentation", "The indentation leaves the top level of the data", line,
    )
  }
  top
}

///|
fn Builder::adjust(
  self : Builder,
  indent : Int32,
  line : Int32,
) -> Unit raise Refusal {
  guard self.indents.last() is Some(top) else {
    self.indents.push(indent)
    return
  }
  if indent > top {
    self.indents.push(indent)
    return
  }
  while self.indents.last() is Some(top) && indent < top {
    ignore(self.indents.pop())
    guard self.stack.pop() is Some(_) else {
      raise Refusal(
        "yaml/indentation", "The indentation leaves the top level of the data", line,
      )
    }
    if self.slots[self.last(line)].shape is List(_) {
      ignore(self.stack.pop())
    }
  }
}

///|
/// True when the top of the stack is the last element of the list below it.
fn Builder::in_list(self : Builder) -> Bool {
  let n = self.stack.length()
  if n < 2 {
    return false
  }
  match self.slots[self.stack[n - 2]].shape {
    List(items) => items.last() == Some(self.stack[n - 1])
    _ => false
  }
}

///|
fn Builder::add(
  self : Builder,
  target : Int32,
  value : Int32,
  line : Int32,
) -> Unit raise Refusal {
  match self.slots[target].shape {
    Open => self.slots[target].shape = List([value])
    List(items) => items.push(value)
    _ =>
      raise Refusal(
        "yaml/mixed-collection", "A list item stands where the data has a map or a scalar",
        line,
      )
  }
}

///|
fn Builder::put(
  self : Builder,
  target : Int32,
  key : String,
  value : Int32,
  line : Int32,
) -> Unit raise Refusal {
  match self.slots[target].shape {
    Open => {
      self.slots[target].shape = Map([(key, value)])
      self.entry_lines[value] = line
    }
    Map(entries) => {
      for i, entry in entries {
        if entry.0 == key {
          // The pinned profile keeps the first position and the last value.
          entries[i] = (key, value)
          self.entry_lines[value] = line
          self.warnings.push(
            (
              "yaml/duplicate-key",
              "Key '\{key}' repeats; PlantUML 1.2026.9 keeps the last value at the first position",
              line,
            ),
          )
          return
        }
      }
      entries.push((key, value))
      self.entry_lines[value] = line
    }
    _ =>
      raise Refusal(
        "yaml/mixed-collection", "A key stands where the data has a list or a scalar",
        line,
      )
  }
}

///|
/// Start a list element: leave a finished element of the same list first.
fn Builder::element(self : Builder, line : Int32) -> Int32 raise Refusal {
  if self.in_list() {
    ignore(self.stack.pop())
  }
  self.last(line)
}

///|
fn text_after_key(
  lines : ReadOnlyArray[Line],
  start : Int32,
) -> (String, Int32) {
  let out = StringBuilder()
  let mut i = start
  while i < lines.length() && lines[i].content is Text(text) {
    // As upstream, a space separates parts only after non-empty text.
    if !out.is_empty() {
      out.write_char(' ')
    }
    out.write_string(text.text)
    i += 1
  }
  (out.to_string(), i)
}

///|
fn block_text(contents : ReadOnlyArray[String]) -> String {
  let out = StringBuilder()
  for line in contents {
    out.write_string(line)
    out.write_char('\n')
  }
  out.to_string()
}

///|
/// Build the native value of the lines. The result is the root slot.
fn Builder::run(
  self : Builder,
  lines : ReadOnlyArray[Line],
  work_limit : Int32,
) -> Int32 raise Refusal {
  let root = self.slot(Open, -1)
  self.stack.push(root)
  let mut i = 0
  while i < lines.length() {
    if i > work_limit {
      raise Refusal(
        "yaml/work-limit", "YAML conversion exceeds its work limit", i,
      )
    }
    let line = lines[i]
    match line.content {
      Text(_) =>
        raise Refusal(
          "yaml/text-without-key", "PlantUML 1.2026.9 refuses text without a key here",
          i,
        )
      Dash => {
        let target = self.element(i)
        let value = self.slot(Open, i)
        self.add(target, value, i)
        self.stack.push(value)
        i += 1
        continue
      }
      _ => ()
    }
    let indent = line.native_indent()
    self.adjust(indent, i)
    match line.content {
      Item(value) => {
        let target = self.element(i)
        self.add(target, self.slot(Leaf(value.text), i), i)
      }
      Pair(true, key, entry) => {
        let target = self.element(i)
        let element = self.slot(Open, i)
        self.add(target, element, i)
        self.stack.push(element)
        match entry {
          Empty => {
            let child = self.slot(Open, i)
            self.put(element, key.text, child, i)
            self.stack.push(child)
          }
          Value(value) =>
            self.put(element, key.text, self.slot(Leaf(value.text), i), i)
          Flow(items) => self.put(element, key.text, self.list(items, i), i)
          Block(_) | Folded =>
            raise Refusal(
              "yaml/unsupported-item-block", "PlantUML 1.2026.9 refuses '|' and '>' text after '- key:'",
              i,
            )
        }
      }
      Pair(false, key, entry) => {
        let target = self.last(i)
        match entry {
          Empty => {
            let next = if i + 1 < lines.length() {
              Some(lines[i + 1])
            } else {
              None
            }
            match next {
              None => self.put(target, key.text, self.slot(Leaf(""), i), i)
              Some(next) if next.native_indent() <= indent =>
                self.put(target, key.text, self.slot(Leaf(""), i), i)
              Some({ content: Text(_), .. }) => {
                let (text, after) = text_after_key(lines, i + 1)
                self.put(target, key.text, self.slot(Leaf(text), i), i)
                i = after
                continue
              }
              Some(_) => {
                let child = self.slot(Open, i)
                self.put(target, key.text, child, i)
                self.stack.push(child)
              }
            }
          }
          Value(value) =>
            self.put(target, key.text, self.slot(Leaf(value.text), i), i)
          Block(contents) =>
            self.put(
              target,
              key.text,
              self.slot(Leaf(block_text(contents)), i),
              i,
            )
          Flow(items) => self.put(target, key.text, self.list(items, i), i)
          Folded =>
            raise Refusal(
              "yaml/unsupported-folded", "PlantUML 1.2026.9 refuses folded '>' text",
              i,
            )
        }
      }
      _ => ()
    }
    i += 1
  }
  root
}

///|
fn Builder::list(
  self : Builder,
  items : ReadOnlyArray[String],
  line : Int32,
) -> Int32 {
  let values = []
  for item in items {
    values.push(self.slot(Leaf(item), line))
  }
  self.slot(List(values), line)
}

///|
/// Convert a YAML document to a structured-data model with the scalar policy
/// of PlantUML 1.2026.9: every scalar is text, so `enabled: true` gives the
/// text `true`. Anchors, aliases and tags stay literal text. A repeated key
/// keeps the last value at the first position, with a warning; the document
/// keeps every occurrence. Input that the pinned profile refuses gives an
/// error and no tree. Identities come from ordered ownership paths, as in
/// the JSON converter. The title is the last `title` statement.
pub fn to_data_tree(
  document : Document,
  id? : String,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> Conversion {
  let diagnostics : Array[@diagrams.Diagnostic] = []
  fn span_of(line : Int32) -> @diagrams.Span? {
    if line >= 0 && line < document.lines.length() {
      document.lines[line].span
    } else {
      None
    }
  }
  fn failed(code : String, message : String, line : Int32) -> Conversion {
    diagnostics.push(
      @diagrams.Diagnostic::error(code, message, span?=span_of(line)),
    )
    { tree: None, diagnostics: ReadOnlyArray::from_array(diagnostics), }
  }
  if !limits.valid() {
    return failed("yaml/invalid-limits", "YAML limits must be positive", -1)
  }
  let builder : Builder = {
    slots: [],
    indents: [],
    stack: [],
    warnings: [],
    entry_lines: Map([]),
  }
  let root = builder.run(document.lines, limits.work) catch {
    Refusal(code, message, line) => return failed(code, message, line)
  }
  for warning in builder.warnings {
    let (code, message, line) = warning
    diagnostics.push(
      @diagrams.Diagnostic::warning(code, message, span?=span_of(line)),
    )
  }
  if builder.slots[root].shape is Open {
    return failed("yaml/no-data", "The YAML block has no data", -1)
  }
  let view = id.unwrap_or(document.name.unwrap_or("yaml"))
  let nodes : Array[@data_tree.Node] = []
  let mut work = 0
  let stack : Array[(Int32, Array[Int32], Bool)] = [(root, [], false)]
  while stack.pop() is Some((slot, path, in_list)) {
    work += 1
    if work > limits.work {
      return failed(
        "yaml/work-limit", "YAML conversion exceeds its work limit", -1,
      )
    }
    if nodes.length() >= limits.nodes {
      return failed("yaml/node-limit", "YAML data exceeds the node limit", -1)
    }
    if path.length() > limits.depth {
      return failed(
        "yaml/depth-limit",
        "YAML nesting exceeds the depth limit of \{limits.depth}",
        -1,
      )
    }
    let line = builder.slots[slot].line
    let node_id = @data.value_id(path)
    let child_path = (i : Int32) => {
      let next = path.copy()
      next.push(i)
      next
    }
    let source = span_of(line)
    let node = match builder.slots[slot].shape {
      Leaf(text) => @data_tree.Node::new(node_id, Text(text), source?)
      Open =>
        return failed(
          "yaml/missing-value", "PlantUML 1.2026.9 refuses a key or item that has no value",
          line,
        )
      List(items) => {
        if in_list {
          return failed(
            "yaml/unsupported-nested-list", "PlantUML 1.2026.9 refuses a list directly inside a list",
            line,
          )
        }
        let entries = []
        for i, item in items {
          let p = child_path(i)
          entries.push(
            @data_tree.Member::index(
              @data.member_id(p),
              i,
              @data.value_id(p),
              source?=span_of(builder.slots[item].line),
            ),
          )
        }
        for i in 0..<items.length() {
          let k = items.length() - 1 - i
          stack.push((items[k], child_path(k), true))
        }
        @data_tree.Node::array(node_id, entries, source?)
      }
      Map(entries) => {
        let members = []
        for i, entry in entries {
          let p = child_path(i)
          members.push(
            @data_tree.Member::named(
              @data.member_id(p),
              entry.0,
              @data.value_id(p),
              source?=span_of(builder.entry_lines.get(entry.1).unwrap_or(line)),
            ),
          )
        }
        for i in 0..<entries.length() {
          let k = entries.length() - 1 - i
          stack.push((entries[k].1, child_path(k), false))
        }
        @data_tree.Node::object(node_id, members, source?)
      }
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
    "yaml",
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
