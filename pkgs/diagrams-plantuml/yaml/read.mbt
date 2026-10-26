///|
/// The stable diagnostic codes of the YAML reader, writer and converter.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "yaml/text-without-key", "yaml/unsupported-folded", "yaml/unsupported-item-block",
  "yaml/mixed-collection", "yaml/indentation", "yaml/unsupported-nested-list", "yaml/missing-value",
  "yaml/no-data", "yaml/duplicate-key", "yaml/depth-limit", "yaml/node-limit", "yaml/work-limit",
  "yaml/output-limit", "yaml/invalid-limits", "yaml/diagnostic-limit", "yaml/unrepresentable-value",
  "yaml/unrepresentable-document", "yaml/invalid-highlight", "yaml/unresolved-highlight",
  "yaml/ambiguous-highlight", "yaml/unapplied-highlight-style",
]

///|
/// The result of reading a YAML body.
pub struct ReadResult {
  /// The body nodes in source order, with shared statement nodes.
  nodes : Array[@cst.Node]
  document : Document?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
fn is_blank(text : String) -> Bool {
  java_trim(text).is_empty()
}

///|
/// A block content line: leading space, trimmed text, trailing space.
fn content_node(line : @envelope.Line) -> @cst.Node {
  let (a, b) = trim_range(line.text, 0, line.text.length())
  let marks = if b > a { [(a, b, @cst.TokenKind::Text)] } else { [] }
  let origin = Array::makei(line.text.length() + 1, i => i)
  @cst.Node::new(Data, marks_to_tokens(line, line.text.length(), origin, marks))
}

///|
fn blank_node(line : @envelope.Line) -> @cst.Node {
  let origin = Array::makei(line.text.length() + 1, i => i)
  @cst.Node::new(Blank, marks_to_tokens(line, line.text.length(), origin, []))
}

///|
/// Read the YAML body of a scanned block with the pinned native line rules.
/// Reading keeps every line form, including forms that conversion refuses,
/// such as folded text. A `key: |` line takes the following lines that are
/// text, comments or deeper than the key; blank lines are not content, as
/// upstream removes them before the YAML parser runs. Tabs count as four
/// spaces. Comments are ` #` outside quotes, or `#` at the start.
pub fn read(
  scan : @envelope.Scan,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> ReadResult {
  let diagnostics = scan.diagnostics.iter().to_array()
  fn report(diagnostic : @diagrams.Diagnostic) {
    if diagnostics.length() < limits.diagnostics {
      diagnostics.push(diagnostic)
    } else if diagnostics.length() == limits.diagnostics {
      diagnostics.push(
        @diagrams.Diagnostic::error(
          "yaml/diagnostic-limit", "Diagnostic limit reached",
        ),
      )
    }
  }
  let made : Map[Int32, @cst.Node] = Map([])
  let lines : Array[Line] = []
  let bodies = scan.lines.iter().filter(line => line.role is Body).to_array()
  let mut work = 0
  let mut stopped = false
  let mut i = 0
  while i < bodies.length() {
    let line = bodies[i]
    work += line.text.length() + 1
    if work > limits.work {
      report(
        @diagrams.Diagnostic::error(
          "yaml/work-limit", "YAML reading exceeds its work limit",
        ),
      )
      stopped = true
      break
    }
    if is_blank(line.text) {
      made[line.offset] = blank_node(line)
      i += 1
      continue
    }
    let (e, origin, class) = classify_line(line.text)
    let tokens = line_tokens(line, e, origin, class)
    guard class.content() is Some(content) else {
      made[line.offset] = @cst.Node::new(Comment, tokens)
      i += 1
      continue
    }
    made[line.offset] = @cst.Node::new(Data, tokens)
    if lines.length() >= limits.nodes {
      report(
        @diagrams.Diagnostic::error(
          "yaml/node-limit",
          "YAML data exceeds the node limit",
          span=scan.span(line.offset, line.offset + line.text.length()),
        ),
      )
      stopped = true
      break
    }
    let mut end = line.offset + line.text.length()
    let mut content = content
    i += 1
    if class.ty == Block {
      let native = class.native_indent()
      let block = []
      while i < bodies.length() {
        let next = bodies[i]
        if is_blank(next.text) {
          made[next.offset] = blank_node(next)
          i += 1
          continue
        }
        let (_, _, inner) = classify_line(next.text)
        if inner.ty != TextOnly &&
          inner.ty != Empty &&
          inner.native_indent() <= native {
          break
        }
        work += next.text.length() + 1
        block.push(java_trim(next.text))
        made[next.offset] = content_node(next)
        end = next.offset + next.text.length()
        i += 1
      }
      if content is Pair(item, key, _) {
        content = Pair(item, key, Block(ReadOnlyArray::from_array(block)))
      }
    }
    lines.push({
      indent: class.count,
      content,
      span: Some(scan.span(line.offset, end)),
    })
  }
  if stopped {
    for line in bodies {
      if !made.contains(line.offset) {
        let origin = Array::makei(line.text.length() + 1, i => i)
        made[line.offset] = @cst.Node::new(
          Data,
          marks_to_tokens(line, line.text.length(), origin, [
            (0, line.text.length(), Text),
          ]),
        )
      }
    }
  }
  let nodes = scan.line_nodes(line => made.get(line.offset))
  let (selectors, highlight_issues) = @data.read_selectors(scan, "yaml")
  for diagnostic in highlight_issues {
    report(diagnostic)
  }
  if !limits.valid() {
    report(
      @diagrams.Diagnostic::error(
        "yaml/invalid-limits", "YAML limits must be positive",
      ),
    )
  }
  let failed = stopped || diagnostics.iter().any(d => d.severity == Error)
  {
    nodes,
    document: if failed {
      None
    } else {
      Some({
        name: scan.name,
        statements: scan.statements,
        highlights: ReadOnlyArray::from_array(selectors),
        lines: ReadOnlyArray::from_array(lines),
      })
    },
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}
