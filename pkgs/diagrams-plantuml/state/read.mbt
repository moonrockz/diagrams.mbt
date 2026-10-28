///|
pub struct ReadResult {
  nodes : ReadOnlyArray[@cst.Node]
  document : Document?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "state/syntax", "state/unclosed-composite", "state/unexpected-close", "state/limit",
  "state/refused-scope", "state/invalid-ast", "state/unapplied-presentation", "state/external-asset",
]

///|
fn trim(text : String) -> String { @envelope.trim(text) }
///|
fn part(text : String, a : Int32, b : Int32) -> String { @cst.slice(text, a, b) }
///|
fn after(text : String, prefix : String) -> String {
  trim(part(text, prefix.length(), text.length()))
}

///|
fn outside(text : String, needle : Int32) -> Int32? {
  let mut quote = false
  let mut escaped = false
  for i = 0; i < text.length(); i = i + 1 {
    let c = text.code_unit_at(i).to_int()
    if c == 34 && !escaped { quote = !quote }
    if !quote && c == needle { return Some(i) }
    escaped = c == 92 && !escaped
  }
  None
}

///|
fn unquote(text : String) -> String {
  if text.length() >= 2 && text.has_prefix("\"") && text.has_suffix("\"") {
    part(text, 1, text.length() - 1)
    .replace_all(old="\\n", new="\n")
    .replace_all(old="\\\"", new="\"")
    .replace_all(old="\\\\", new="\\")
  } else { text }
}

///|
fn quote_end(text : String) -> Int32? {
  let mut escaped = false
  for i = 1; i < text.length(); i = i + 1 {
    let c = text.code_unit_at(i).to_int()
    if c == 34 && !escaped { return Some(i) }
    escaped = c == 92 && !escaped
  }
  None
}

///|
fn identifier(text : String) -> Bool {
  if ["[*]", "[H]", "[H*]"].contains(text) { return true }
  let mut name = text
  if name.has_suffix("[H*]") { name = part(name, 0, name.length() - 4) }
  else if name.has_suffix("[H]") { name = part(name, 0, name.length() - 3) }
  if name.has_prefix("==") && name.has_suffix("==") {
    name = name.trim_start(chars="=").trim_end(chars="=").to_owned()
  }
  if name.is_empty() { return false }
  for c in name {
    if c.is_whitespace() || c.is_control() { return false }
    if c.is_ascii() && !(c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '_' || c == '.') { return false }
  }
  true
}

///|
fn declaration(text : String) -> Kind? {
  let mut t = after(text, "state")
  let composite = t.has_suffix("{")
  if composite { t = trim(part(t, 0, t.length() - 1)) }
  let mut decoration = ""
  if outside(t, 60) is Some(at) {
    decoration = trim(part(t, at, t.length()))
    t = trim(part(t, 0, at))
  } else if outside(t, 35) is Some(at) {
    decoration = trim(part(t, at, t.length()))
    t = trim(part(t, 0, at))
  }
  let mut code = ""
  let mut label = ""
  if t.has_prefix("\"") {
    guard quote_end(t) is Some(end) else { return None }
    label = unquote(part(t, 0, end + 1))
    let tail = trim(part(t, end + 1, t.length()))
    if tail.has_prefix("as ") { code = after(tail, "as") }
    else if tail.is_empty() { code = label }
    else { return None }
  } else if t.contains(" as ") {
    let at = t.find(" as ").unwrap()
    code = trim(part(t, 0, at))
    label = unquote(trim(part(t, at + 4, t.length())))
  } else {
    code = t
    label = t.split(".").to_array().last().unwrap_or(t[:]).to_owned()
  }
  if !identifier(code) { None }
  else { Some(Declaration(code, label, decoration, composite)) }
}

///|
fn transition(text : String) -> Kind? {
  let mut t = text
  let mut label = ""
  if outside(t, 58) is Some(colon) {
    label = trim(part(t, colon + 1, t.length()))
    t = trim(part(t, 0, colon))
  }
  let mut a = -1
  let mut b = -1
  let mut quote = false
  let mut bracket = 0
  for i = 0; i < t.length(); i = i + 1 {
    let c = t.code_unit_at(i).to_int()
    if c == 34 { quote = !quote }
    if quote { continue }
    if c == 91 { bracket += 1 }
    if c == 93 { bracket -= 1 }
    if bracket > 0 { continue }
    if a < 0 && (c == 45 || c == 60 || (c == 46 && i + 1 < t.length() && t.code_unit_at(i + 1).to_int() == 46)) {
      a = i
    }
    if a >= 0 && (c == 62 || c == 45 || c == 46) { b = i + 1 }
    if a >= 0 && b > a && (c == 32 || c == 9) { break }
  }
  guard a > 0 && b > a else { return None }
  if b < t.length() && t.code_unit_at(b).to_int() == 111 { b += 1 }
  if a > 0 && t.code_unit_at(a - 1).to_int() == 120 { a -= 1 }
  let from = trim(part(t, 0, a))
  let arrow = trim(part(t, a, b))
  let target = trim(part(t, b, t.length()))
  if identifier(from) && identifier(target) &&
    (arrow.contains(">") || arrow.contains("<") || arrow == "--" || arrow == "..") {
    Some(Transition(from, arrow, target, label))
  } else { None }
}

///|
/// Read a scanned native state block. Recovery preserves subsequent statements.
pub fn read(
  scan : @envelope.Scan,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> ReadResult {
  let diagnostics = scan.diagnostics.iter().collect()
  let items : Array[Statement] = []
  let nodes = scan.line_nodes(line => Some(@cst.Node::new(Data, line.tokens(Text))))
  let mut depth = 0
  let mut regions = 1
  let mut transitions = 0
  let mut declarations = 0
  let mut work = 0
  let mut i = 0
  fn error(code : String, text : String, span : @diagrams.Span?) {
    if diagnostics.length() < limits.diagnostics.max(1) {
      diagnostics.push(@diagrams.Diagnostic::error(code, text, span?))
    }
  }
  fn emit(kind : Kind, span : @diagrams.Span) {
    items.push(Statement::new(kind, span~))
  }
  while i < scan.lines.length() {
    let line = scan.lines[i]
    i += 1
    if line.role != Body { continue }
    let mut text = trim(line.text)
    let span = scan.span(line.offset, line.offset + line.text.length())
    work += text.length() + 1
    if work > limits.work || items.length() >= limits.nodes || !limits.valid() {
      error("state/limit", "State reading work or statement limit exceeded", Some(span))
      break
    }
    if text.is_empty() { continue }
    if outside(text, 39) is Some(at) { text = trim(part(text, 0, at)) }
    if text.is_empty() { continue }
    if text.contains("<img") || text.contains("[[") || text.contains("<$") {
      error("state/external-asset", "External assets and links are refused", Some(span))
    }
    if text.has_prefix("note ") || text == "note" || text.has_prefix("floating note") {
      let mut header = text
      let mut content = ""
      let mut target : String? = None
      let mut code : String? = None
      if outside(text, 58) is Some(at) {
        header = trim(part(text, 0, at))
        content = trim(part(text, at + 1, text.length()))
      } else if text.has_prefix("note \"") {
        let tail = after(text, "note")
        if quote_end(tail) is Some(end) {
          content = unquote(part(tail, 0, end + 1))
          let rest = trim(part(tail, end + 1, tail.length()))
          if rest.has_prefix("as ") { code = Some(after(rest, "as")) }
        } else { error("state/syntax", "Unclosed note text", Some(span)) }
      } else {
        let lines = []
        let mut closed = false
        while i < scan.lines.length() {
          let t = scan.lines[i]
          i += 1
          work += t.text.length() + 1
          if work > limits.work { error("state/limit", "Note work limit exceeded", Some(span)); break }
          if trim(t.text) == "end note" || trim(t.text) == "endnote" {
            closed = true
            break
          }
          lines.push(t.text)
        }
        content = lines.join("\n")
        if !closed { error("state/syntax", "Unclosed note", Some(span)) }
      }
      let placement = if header.has_prefix("note left") { "left" }
      else if header.has_prefix("note top") { "top" }
      else if header.has_prefix("note bottom") { "bottom" }
      else { "right" }
      if header.has_prefix("note on link") { target = Some("@link") }
      if header.find(" of ") is Some(at) { target = Some(trim(part(header, at + 4, header.length()))) }
      if content.contains("<img") || content.contains("[[") || content.contains("<$") {
        error("state/external-asset", "External assets in notes are refused", Some(span))
      }
      emit(Note(placement, target, content, code), span)
      continue
    }
    if text == "}" {
      if depth <= 0 { error("state/unexpected-close", "Unexpected composite close", Some(span)) }
      else { depth -= 1 }
      emit(Close, span)
    } else if text == "--" || text == "||" {
      if depth == 0 { error("state/syntax", "Concurrent separator requires a composite", Some(span)) }
      regions += 1
      if regions > limits.regions { error("state/limit", "Region count limit exceeded", Some(span)); break }
      emit(Separator(text == "||"), span)
    } else if text == "left to right direction" {
      emit(Direction(LR), span)
    } else if text == "top to bottom direction" {
      emit(Direction(TB), span)
    } else if text.to_lower().has_prefix("state ") {
      let mut declaration_text = text
      let mut description : String? = None
      if outside(text, 58) is Some(at) {
        // Color specifications contain colons until a separating space-colon.
        if !text.contains("#") || (at > 0 && text.code_unit_at(at - 1).to_int() == 32) {
          declaration_text = trim(part(text, 0, at))
          description = Some(trim(part(text, at + 1, text.length())))
        } else if text.find(" : ") is Some(at) {
          declaration_text = trim(part(text, 0, at))
          description = Some(trim(part(text, at + 3, text.length())))
        }
      }
      match declaration("state " + part(declaration_text, 6, declaration_text.length())) {
        Some(kind) => {
          declarations += 1
          if kind is Declaration(_, _, decoration, composite) {
            if composite { depth += 1; regions += 1 }
            if !decoration.is_empty() && diagnostics.length() < limits.diagnostics {
              diagnostics.push(@diagrams.Diagnostic::warning("state/unapplied-presentation", "Stereotypes and colors remain inert", span~))
            }
          }
          if depth > limits.depth || declarations > limits.nodes || regions > limits.regions {
            error("state/limit", "State count or nesting limit exceeded", Some(span))
            break
          }
          let declaration_body = after(declaration_text, "state")
          let explicit_label = declaration_body.has_prefix("\"") || declaration_body.contains(" as ")
          items.push(Statement::new(kind, span~, explicit_label~))
          if description is Some(description) && kind is Declaration(code, _, _, _) {
            emit(Description(code, description), span)
          }
        }
        None => error("state/syntax", "Invalid state declaration", Some(span))
      }
    } else if text.has_prefix("mainframe ") {
      emit(Presentation(text), span)
      if diagnostics.length() < limits.diagnostics {
        diagnostics.push(@diagrams.Diagnostic::warning("state/unapplied-presentation", "Mainframe presentation is retained but unapplied", span~))
      }
    } else if transition(text) is Some(kind) {
      transitions += 1
      if transitions > limits.edges { error("state/limit", "Transition limit exceeded", Some(span)); break }
      emit(kind, span)
    } else if outside(text, 58) is Some(at) {
      let code = trim(part(text, 0, at))
      if identifier(code) { emit(Description(code, trim(part(text, at + 1, text.length()))), span) }
      else { error("state/syntax", "Invalid description target", Some(span)) }
    } else {
      error("state/syntax", "Unknown state statement: " + text, Some(span))
    }
  }
  if depth > 0 { error("state/unclosed-composite", "Unclosed composite state", None) }
  if diagnostics.length() >= limits.diagnostics {
    diagnostics.push(@diagrams.Diagnostic::error("state/limit", "Diagnostic limit reached"))
  }
  { nodes: ReadOnlyArray::from_array(nodes), document: Some(Document::new(items[:], name?=scan.name, complete=!diagnostics.iter().any(d => d.severity == Error), statements=scan.statements[:])), diagnostics: ReadOnlyArray::from_array(diagnostics) }
}
