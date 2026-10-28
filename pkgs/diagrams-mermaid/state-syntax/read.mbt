///|
pub struct Limits {
  source : Int32
  output : Int32
  states : Int32
  regions : Int32
  transitions : Int32
  depth : Int32
  diagnostics : Int32
  work : Int32
} derive(Eq, Debug)

///|
pub fn Limits::new(
  source~ : Int32 = 16777216,
  output~ : Int32 = 16777216,
  states~ : Int32 = 10000,
  regions~ : Int32 = 10000,
  transitions~ : Int32 = 50000,
  depth~ : Int32 = 256,
  diagnostics~ : Int32 = 256,
  work~ : Int32 = 1000000,
) -> Limits {
  { source, output, states, regions, transitions, depth, diagnostics, work, }
}

///|
pub struct ReadResult {
  tree : @cst.Node
  ast : @ast.Diagram?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub fn trim(s : String) -> String {
  let mut a = 0
  let mut b = s.length()
  while a < b && [9, 10, 13, 32].contains(s.code_unit_at(a).to_int()) {
    a += 1
  }
  while b > a && [9, 10, 13, 32].contains(s.code_unit_at(b - 1).to_int()) {
    b -= 1
  }
  s[a:b].to_owned()
}

///|
/// Mermaid state identifiers are opaque tokens, not executable names.
pub fn valid_id(s : String) -> Bool {
  s != "" &&
  s != "[*]" &&
  !s.iter().any(c => [9, 10, 13, 32, 34, 58, 123, 125, 45].contains(c.to_int())) &&
  !s.contains("%%")
}

///|
fn endpoint(s : String) -> (String, ReadOnlyArray[String])? {
  let parts = s.split(":::").map(p => trim(p.to_owned())).to_array()
  if parts.length() > 2 || (parts[0] != "[*]" && !valid_id(parts[0])) {
    return None
  }
  if parts.length() == 2 && !valid_id(parts[1]) {
    return None
  }
  Some(
    (
      parts[0],
      if parts.length() == 2 {
        ReadOnlyArray::from_array([parts[1]])
      } else {
        []
      },
    ),
  )
}

///|
fn outside(s : String, needle : String) -> Int32? {
  let mut i = 0
  let mut quoted = false
  while i < s.length() {
    if s.code_unit_at(i).to_int() == 34 {
      quoted = !quoted
    }
    if !quoted && s[i:].has_prefix(needle) {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn description_colon(s : String) -> Int32? {
  let mut i = 0
  while i < s.length() {
    if s[i:].has_prefix(":::") {
      i += 3
      continue
    }
    if s.code_unit_at(i).to_int() == 58 {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn declaration(s : String, composite : Bool) -> @ast.StatementKind? {
  let mut text = trim(s)
  let mut label : String? = None
  if text.has_prefix("\"") {
    guard text[1:].find("\"") is Some(close) else { return None }
    label = Some(text[1:close + 1].to_owned())
    let rest = trim(text[close + 2:].to_owned())
    guard rest.to_lower().has_prefix("as ") ||
      rest.to_lower().has_prefix("as\t") else {
      return None
    }
    text = trim(rest[2:].to_owned())
  }
  let mut description : String? = None
  if label != None && description_colon(text) is Some(colon) {
    description = Some(text[colon + 1:].to_owned())
    text = trim(text[:colon].to_owned())
  }
  let mut role : String? = None
  for r in ["choice", "fork", "join"] {
    for suffix in ["<<" + r + ">>", "[[" + r + "]]"] {
      if text.to_lower().has_suffix(suffix) {
        role = Some(r)
        text = trim(text[:text.length() - suffix.length()].to_owned())
      }
    }
  }
  guard endpoint(text) is Some((id, classes)) else { return None }
  if id == "[*]" || (composite && role != None) {
    return None
  }
  if !composite && label == None && role == None {
    return Some(Presentation("state " + s))
  }
  if composite {
    Some(@ast.StatementKind::Composite(id~, label~))
  } else {
    Some(@ast.StatementKind::State(id~, label~, role~, description~, classes~))
  }
}

///|
fn metadata_prefix(text : String, word : String) -> Bool {
  let lower = text.to_lower()
  if !lower.has_prefix(word) {
    return false
  }
  let suffix = trim(text[word.length():].to_owned())
  suffix.has_prefix(":") || suffix.has_prefix("{")
}

///|
fn statement(s : String) -> @ast.StatementKind? {
  let text = trim(s)
  let lower = text.to_lower()
  if text == "}" {
    return Some(EndComposite)
  }
  if text == "--" {
    return Some(Concurrent)
  }
  if lower.has_prefix("direction ") || lower.has_prefix("direction\t") {
    let d = trim(text[9:].to_owned()).to_upper()
    return if ["TB", "BT", "LR", "RL"].contains(d) {
      Some(Direction(d))
    } else {
      None
    }
  }
  if lower.has_prefix("state ") || lower.has_prefix("state\t") {
    let composite = text.has_suffix("{")
    let end = if composite { text.length() - 1 } else { text.length() }
    return declaration(text[6:end].to_owned(), composite)
  }
  if metadata_prefix(text, "acctitle") || metadata_prefix(text, "accdescr") {
    guard text.find(":") is Some(colon) else { return None }
    return if metadata_prefix(text, "acctitle") {
      Some(AccTitle(trim(text[colon + 1:].to_owned())))
    } else {
      Some(AccDescription(trim(text[colon + 1:].to_owned())))
    }
  }
  if [
      "classDef ", "classDef\t", "class ", "class\t", "style ", "style\t", "click ",
      "click\t", "scale ", "hide empty description",
    ]
    .iter()
    .any(p => lower.has_prefix(p.to_lower())) {
    return Some(Presentation(text))
  }
  if lower.has_prefix("note ") || lower.has_prefix("note\t") {
    let rest = trim(text[4:].to_owned())
    if rest.has_prefix("\"") {
      guard rest[1:].find("\"") is Some(close) else { return None }
      let suffix = trim(rest[close + 2:].to_owned())
      guard suffix.to_lower().has_prefix("as ") else { return None }
      let id = trim(suffix[3:].to_owned())
      return if valid_id(id) {
        Some(FloatingNote(id~, text=rest[1:close + 1].to_owned()))
      } else {
        None
      }
    }
    let placement = if rest.to_lower().has_prefix("left of ") {
      "left"
    } else if rest.to_lower().has_prefix("right of ") {
      "right"
    } else {
      return None
    }
    let suffix = trim(rest[if placement == "left" { 8 } else { 9 }:].to_owned())
    guard suffix.find(":") is Some(colon) else { return None }
    let target = trim(suffix[:colon].to_owned())
    return if valid_id(target) {
      Some(Note(target~, placement~, text=trim(suffix[colon + 1:].to_owned())))
    } else {
      None
    }
  }
  if outside(text, "-->") is Some(arrow) {
    let left = trim(text[:arrow].to_owned())
    let right = trim(text[arrow + 3:].to_owned())
    let colon = description_colon(right)
    let target = trim(right[:colon.unwrap_or(right.length())].to_owned())
    let label = colon.map(i => trim(right[i + 1:].to_owned()))
    match (endpoint(left), endpoint(target)) {
      (Some((a, ac)), Some((b, bc))) =>
        return Some(
          Transition(
            source=a,
            target=b,
            label~,
            source_classes=ac,
            target_classes=bc,
          ),
        )
      _ => return None
    }
  }
  if description_colon(text) is Some(colon) {
    let id = trim(text[:colon].to_owned())
    return if valid_id(id) {
      Some(Description(id~, text=trim(text[colon + 1:].to_owned())))
    } else {
      None
    }
  }
  endpoint(text).map(pair => {
    @ast.StatementKind::State(
      id=pair.0,
      label=None,
      role=None,
      description=None,
      classes=pair.1,
    )
  })
}

///|
pub fn read(source : String, limits~ : Limits = Limits::new()) -> ReadResult {
  let tokens : Array[@cst.Token] = []
  let statements : Array[@ast.Statement] = []
  let diagnostics : Array[@diagrams.Diagnostic] = []
  let directives = []
  let mut front_matter : String? = None
  let mut header : String? = None
  let mut offset = 0
  let mut depth = 0
  let mut regions = 1
  let mut states = 0
  let mut transitions = 0
  let mut fatal = false
  let mut work = 0
  let line_starts : Array[Int32] = [0]
  fn position(offset : Int32) -> @diagrams.Position {
    let mut low = 0
    let mut high = line_starts.length()
    while low + 1 < high {
      work += 1
      let middle = (low + high) / 2
      if line_starts[middle] <= offset {
        low = middle
      } else {
        high = middle
      }
    }
    { offset, line: low + 1, column: offset - line_starts[low] + 1, }
  }
  fn span(start : Int32, end : Int32) -> @diagrams.Span {
    { start: position(start), end: position(end), }
  }
  fn error(code : String, message : String, start : Int32, end : Int32) {
    let d = @diagrams.Diagnostic::error(
      "state/" + code,
      message,
      span=span(start, end),
    )
    if diagnostics.length() < limits.diagnostics.max(1) {
      diagnostics.push(d)
    } else {
      diagnostics[diagnostics.length() - 1] = @diagrams.Diagnostic::error(
        "state/diagnostic-limit", "Diagnostic budget exhausted",
      )
      fatal = true
    }
  }
  if limits.source < 0 || source.length() > limits.source {
    error("source-limit", "Source budget exhausted", 0, 0)
    return {
      tree: @cst.Node::new([{ kind: Error, text: source, offset: 0, }]),
      ast: None,
      diagnostics: ReadOnlyArray::from_array(diagnostics),
    }
  }
  if limits.depth < 1 ||
    limits.states < 1 ||
    limits.regions < 1 ||
    limits.transitions < 1 ||
    limits.work < 1 ||
    limits.diagnostics < 1 {
    error("invalid-limits", "All processing limits must be positive", 0, 0)
    return {
      tree: @cst.Node::new([{ kind: Error, text: source, offset: 0, }]),
      ast: None,
      diagnostics: ReadOnlyArray::from_array(diagnostics),
    }
  }
  if source.length() > limits.work {
    error("work-limit", "Reader work budget exhausted", 0, 0)
    return {
      tree: @cst.Node::new([{ kind: Error, text: source, offset: 0, }]),
      ast: None,
      diagnostics: ReadOnlyArray::from_array(diagnostics),
    }
  }
  work = source.length()
  for i in 0..<source.length() {
    if source.code_unit_at(i).to_int() == 10 {
      line_starts.push(i + 1)
    }
  }
  while offset < source.length() && !fatal {
    let start = offset
    let mut end = offset
    let mut quote = false
    let mut descriptive = false
    let mut first_newline : Int32? = None
    // Preserve metadata and description bodies as lines. Braces only delimit
    // actual composite statements, never label or presentation text.
    let mut begin = start
    while begin < source.length() &&
          [9, 13, 32].contains(source.code_unit_at(begin).to_int()) {
      begin += 1
    }
    let tail = source[begin:].to_owned().to_lower()
    let plain = [
        "%%", "#", "classDef ", "class ", "style ", "click ", "accTitle", "accDescr",
        "note ",
      ]
      .iter()
      .any(p => tail.has_prefix(p.to_lower()))
    while end < source.length() {
      work += 1
      if work > limits.work {
        error("work-limit", "Reader work budget exhausted", start, end)
        fatal = true
        break
      }
      let n = source.code_unit_at(end).to_int()
      if n == 10 {
        if first_newline == None {
          first_newline = Some(end)
        }
        if !quote {
          break
        }
      }
      if !plain && n == 34 {
        quote = !quote
      }
      if !plain &&
        !quote &&
        n == 58 &&
        !source[end:].has_prefix(":::") &&
        (end == 0 || source.code_unit_at(end - 1).to_int() != 58) {
        descriptive = true
      }
      if !plain && !descriptive && !quote && n == 123 {
        end += 1
        break
      }
      if !plain && !descriptive && !quote && n == 125 {
        if end == begin {
          end += 1
        }
        break
      }
      end += 1
    }
    if fatal {
      break
    }
    if quote && end == source.length() {
      if first_newline is Some(line) {
        end = line
      }
    }
    let mut text = trim(source[start:end].to_owned())
    let lower = text.to_lower()
    let mut kind : @cst.TokenKind = Statement
    if text == "---" && header == None && front_matter == None {
      let mut close = if end < source.length() { end + 1 } else { end }
      let mut found = false
      while close < source.length() {
        let mut e = close
        while e < source.length() && source.code_unit_at(e).to_int() != 10 {
          e += 1
        }
        if trim(source[close:e].to_owned()) == "---" {
          end = e
          found = true
          break
        }
        close = e + 1
      }
      if found {
        front_matter = Some(source[start:end].to_owned())
        kind = FrontMatter
      } else {
        error("syntax", "Unterminated front matter", start, end)
        kind = Error
      }
    } else if text.has_prefix("%%{") {
      match source[start:].find("}%%") {
        Some(i) => {
          end = start + i + 3
          directives.push(source[start:end].to_owned())
          kind = Directive
        }
        None => {
          error("syntax", "Unterminated directive", start, end)
          kind = Error
        }
      }
    } else if text == "" {
      kind = Whitespace
    } else if text.has_prefix("%%") || text.has_prefix("#") {
      kind = Comment
      statements.push({ kind: Comment(text), span: span(start, end), })
    } else if header == None {
      let candidate = ["stateDiagram-v2", "stateDiagram"]
        .iter()
        .find_first(h => {
          text == h || text.has_prefix(h + " ") || text.has_prefix(h + "\t")
        })
      if candidate is Some(h) {
        header = Some(h)
        kind = Header
        let suffix = trim(text[h.length():].to_owned())
        if suffix != "" {
          // Return the suffix to the statement scanner without dropping bytes.
          end = start + source[start:end].find(h).unwrap() + h.length()
        }
      } else {
        error("header", "Expected stateDiagram or stateDiagram-v2", start, end)
        kind = Error
      }
    } else {
      if !lower.has_prefix("note ") && outside(text, "%%") is Some(comment) {
        text = trim(text[:comment].to_owned())
      }
      if lower.has_prefix("note ") &&
        !text.contains(":") &&
        !lower.has_prefix("note \"") {
        let mut close = if end < source.length() { end + 1 } else { end }
        let body_start = close
        let mut found = false
        while close < source.length() {
          let mut e = close
          while e < source.length() && source.code_unit_at(e).to_int() != 10 {
            e += 1
          }
          if trim(source[close:e].to_owned()).to_lower() == "end note" {
            text += ": " + trim(source[body_start:close].to_owned())
            end = e
            found = true
            break
          }
          close = e + 1
        }
        if !found {
          error("syntax", "Unterminated note", start, end)
          kind = Error
        }
      }
      if metadata_prefix(text, "accdescr") && text.contains("{") {
        let open = start + source[start:end].find("{").unwrap()
        match source[open + 1:].find("}") {
          Some(i) => {
            end = open + 1 + i + 1
            text = "accDescr: " + trim(source[open + 1:end - 1].to_owned())
          }
          None => {
            error(
              "syntax", "Unterminated accessibility description", start, end,
            )
            kind = Error
          }
        }
      }
      if kind != Error {
        match statement(text) {
          Some(value) => {
            match value {
              Composite(..) => {
                depth += 1
                regions += 1
                states += 1
              }
              EndComposite =>
                if depth == 0 {
                  error("syntax", "Unexpected closing composite", start, end)
                  kind = Error
                } else {
                  depth -= 1
                }
              Concurrent => {
                if depth == 0 {
                  error(
                    "syntax", "Concurrent separators require a composite", start,
                    end,
                  )
                  kind = Error
                }
                regions += 1
              }
              State(..) | Description(..) => states += 1
              Transition(..) => transitions += 1
              _ => ()
            }
            if kind != Error {
              statements.push({ kind: value, span: span(start, end), })
            }
          }
          None => {
            error("syntax", "Invalid state statement", start, end)
            kind = Error
          }
        }
      }
    }
    if kind == Error {
      statements.push({ kind: Invalid(text), span: span(start, end), })
    }
    if depth > limits.depth {
      error("depth-limit", "Composite nesting budget exhausted", start, end)
      fatal = true
    }
    if states > limits.states {
      error("state-limit", "State statement budget exhausted", start, end)
      fatal = true
    }
    if regions > limits.regions {
      error("region-limit", "Region budget exhausted", start, end)
      fatal = true
    }
    if transitions > limits.transitions {
      error("transition-limit", "Transition budget exhausted", start, end)
      fatal = true
    }
    work += (end - start).max(0)
    if work > limits.work {
      error("work-limit", "Reader work budget exhausted", start, end)
      fatal = true
    }
    offset = if end < source.length() && source.code_unit_at(end).to_int() == 10 {
      end + 1
    } else {
      end
    }
    tokens.push({ kind, text: source[start:offset].to_owned(), offset: start, })
  }
  if offset < source.length() {
    tokens.push({ kind: Error, text: source[offset:].to_owned(), offset, })
  }
  if header == None {
    error("header", "Missing state header", 0, 0)
  }
  if depth != 0 {
    error("syntax", "Unclosed composite", source.length(), source.length())
    statements.push({
      kind: Invalid("unclosed composite"),
      span: span(source.length(), source.length()),
    })
  }
  {
    tree: @cst.Node::new(tokens),
    ast: if fatal || header == None {
      None
    } else {
      Some(
        @ast.Diagram::new(
          statements,
          header=header.unwrap(),
          front_matter?,
          directives~,
        ),
      )
    },
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}

///|
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "state/syntax", "state/header", "state/source-limit", "state/output-limit", "state/state-limit",
  "state/region-limit", "state/transition-limit", "state/depth-limit", "state/work-limit",
  "state/diagnostic-limit", "state/invalid-limits", "state/invalid-ast",
]

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend ReadResult with Eq::{equal, not_equal}

///|
pub extend ReadResult with @debug.Debug::{to_repr}
