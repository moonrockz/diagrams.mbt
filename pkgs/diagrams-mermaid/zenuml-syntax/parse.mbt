///|
pub struct Limits {
  source : Int32
  output : Int32
  participants : Int32
  events : Int32
  depth : Int32
  diagnostics : Int32
  work : Int32
} derive(Eq, Debug)

///|
pub fn Limits::new(
  source~ : Int32 = 16777216,
  output~ : Int32 = 16777216,
  participants~ : Int32 = 10000,
  events~ : Int32 = 50000,
  depth~ : Int32 = 256,
  diagnostics~ : Int32 = 256,
  work~ : Int32 = 1000000,
) -> Limits {
  { source, output, participants, events, depth, diagnostics, work, }
}

///|
pub struct ReadResult {
  tree : @cst.Node
  ast : @ast.Diagram?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
fn ch(s : String, i : Int32) -> Int32 {
  if i >= 0 && i < s.length() {
    s.at(i).to_int()
  } else {
    0
  }
}

///|
fn trim(s : String) -> String {
  s.trim().to_owned()
}

///|
fn cut(s : String, a : Int32, b : Int32) -> String {
  s[a:b].to_owned()
}

///|
fn find(s : String, part : String) -> Int32? {
  s.find(part)
}

///|
fn find_top(s : String, token : String) -> Int32? {
  let mut quote = 0
  let mut escape = false
  let mut depth = 0
  let mut i = 0
  while i < s.length() {
    let c = ch(s, i)
    if quote != 0 {
      if escape {
        escape = false
      } else if c == 92 {
        escape = true
      } else if c == quote {
        quote = 0
      }
      i += 1
      continue
    }
    if c == 34 || c == 39 || c == 96 {
      quote = c
      i += 1
      continue
    }
    if depth == 0 && s[i:].has_prefix(token) {
      return Some(i)
    }
    if c == 40 || c == 91 {
      depth += 1
    }
    if c == 41 || c == 93 {
      depth = max(0, depth - 1)
    }
    i += 1
  }
  None
}

///|
fn unquote(s : String) -> String {
  if s.length() >= 2 &&
    (
      (s.has_prefix("\"") && s.has_suffix("\"")) ||
      (s.has_prefix("'") && s.has_suffix("'"))
    ) {
    cut(s, 1, s.length() - 1).replace_all(old="\"\"", new="\"")
  } else {
    s
  }
}

///|
fn identifier(s : String) -> Bool {
  s.length() > 0 &&
  s
  .iter()
  .all(c => {
    ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) ||
    c == '_' ||
    c == '$'
  })
}

///|
/// A bounded scanner separates braces only outside strings, comments and expressions.
pub fn read(source : String, limits~ : Limits = Limits::new()) -> ReadResult {
  let line_starts = [0]
  if source.length() <= limits.source && source.length() <= limits.work {
    let mut at = 0
    while at < source.length() {
      let c = ch(source, at)
      if c == 13 && ch(source, at + 1) == 10 {
        at += 2
        line_starts.push(at)
      } else {
        at += 1
        if c == 10 || c == 13 {
          line_starts.push(at)
        }
      }
    }
  }
  fn position(offset : Int32) -> @diagrams.Position {
    let mut left = 0
    let mut right = line_starts.length()
    while left + 1 < right {
      let middle = (left + right) / 2
      if line_starts[middle] <= offset {
        left = middle
      } else {
        right = middle
      }
    }
    { offset, line: left + 1, column: offset - line_starts[left] + 1, }
  }
  fn span(a : Int32, b : Int32) -> @diagrams.Span {
    { start: position(a), end: position(b), }
  }
  let tree = @cst.Node::new(source)
  let diagnostics = []
  let statements : Array[@ast.Statement] = []
  let opens : Array[(@diagrams.Span, String)] = []
  let mut failed = false
  let mut work = 0
  let mut count = 0
  let mut declarations = 0
  let mut annotation : String? = None
  let mut reply = false
  fn error(code : String, message : String, a : Int32, b : Int32) {
    if diagnostics.length() < max(1, limits.diagnostics) {
      diagnostics.push(
        @diagrams.Diagnostic::error("zenuml/" + code, message, span=span(a, b)),
      )
    } else {
      failed = true
      diagnostics[diagnostics.length() - 1] = @diagrams.Diagnostic::error(
        "zenuml/diagnostic-limit",
        "Diagnostic limit exceeded",
        span=span(a, b),
      )
    }
  }
  fn append(kind : @ast.StatementKind, a : Int32, b : Int32) {
    if kind is Participant(..) {
      declarations += 1
      if declarations > limits.participants {
        error(
          "participant-limit", "Participant declaration limit exceeded", a, b,
        )
        failed = true
        return
      }
    }
    statements.push({ kind, span: span(a, b), })
    count += 1
  }
  if limits.source < 0 ||
    limits.events < 0 ||
    limits.depth < 0 ||
    limits.depth > 256 ||
    limits.work < 0 ||
    limits.diagnostics < 1 ||
    source.length() > limits.source ||
    source.length() > limits.work {
    error(
      if source.length() > limits.work {
        "work-limit"
      } else {
        "source-limit"
      },
      "Invalid limits or source/work limit exceeded",
      0,
      0,
    )
    return {
      tree,
      ast: None,
      diagnostics: ReadOnlyArray::from_array(diagnostics),
    }
  }
  let tokens : Array[(String, Int32, Int32, Bool)] = []
  let mut start = 0
  let mut i = 0
  let mut quote = 0
  let mut escape = false
  let mut parens = 0
  let mut async_text = false
  while i < source.length() {
    work += 1
    if work > limits.work {
      error("work-limit", "Scanner work limit exceeded", i, i)
      failed = true
      break
    }
    let c = ch(source, i)
    if i == 0 && c == 65279 {
      i += 1
      start = i
      continue
    }
    // EVENT_PAYLOAD_LXR consumes everything after an async colon to EOL.
    // Payload punctuation cannot reopen the statement scanner's lexical modes.
    if async_text {
      if c == 10 || c == 13 {
        tokens.push((trim(cut(source, start, i)), start, i, false))
        async_text = false
        parens = 0
        i += 1
        start = i
      } else {
        i += 1
      }
      continue
    }
    if quote != 0 && (c == 10 || c == 13) {
      error(
        "unterminated-string", "Quoted statement does not close on this line", start,
        i,
      )
      quote = 0
      escape = false
    }
    if quote != 0 {
      if escape {
        escape = false
      } else if c == 92 {
        escape = true
      } else if c == quote {
        quote = 0
      }
      i += 1
      continue
    }
    if i == start &&
      source[i:].has_prefix("---") &&
      (ch(source, i + 3) == 10 || ch(source, i + 3) == 13) {
      let a = i
      i += 3
      while i < source.length() {
        if (ch(source, i - 1) == 10 || ch(source, i - 1) == 13) &&
          source[i:].has_prefix("---") {
          i += 3
          break
        }
        i += 1
      }
      tokens.push((cut(source, a, i), a, i, false))
      work += i - a
      start = i
      continue
    }
    if c == 37 && ch(source, i + 1) == 37 {
      if trim(cut(source, start, i)) != "" {
        tokens.push((trim(cut(source, start, i)), start, i, false))
      }
      let a = i
      if ch(source, i + 2) == 123 {
        i += 3
        while i < source.length() && !source[i:].has_prefix("}%%") {
          i += 1
        }
        if i < source.length() {
          i += 3
        }
      } else {
        while i < source.length() && ch(source, i) != 10 && ch(source, i) != 13 {
          i += 1
        }
      }
      tokens.push((cut(source, a, i), a, i, false))
      work += i - a
      start = i
      continue
    }
    if c == 34 || c == 39 || c == 96 {
      quote = c
      i += 1
      continue
    }
    if c == 47 && ch(source, i + 1) == 47 {
      if trim(cut(source, start, i)) != "" {
        tokens.push((trim(cut(source, start, i)), start, i, false))
      }
      let a = i
      while i < source.length() && ch(source, i) != 10 && ch(source, i) != 13 {
        i += 1
      }
      tokens.push((cut(source, a, i), a, i, false))
      start = i
      continue
    }
    if c == 58 && parens == 0 && cut(source, start, i).contains("->") {
      async_text = true
    }
    if (c == 10 || c == 13) && parens > 0 {
      let mut next = i + 1
      if c == 13 && ch(source, next) == 10 {
        next += 1
      }
      let mut end = next
      while end < source.length() &&
            ch(source, end) != 10 &&
            ch(source, end) != 13 {
        end += 1
      }
      let next_line = trim(cut(source, next, end))
      let message_boundary = match find_top(next_line, "->") {
        Some(arrow) => identifier(trim(cut(next_line, 0, arrow)))
        None => false
      }
      if message_boundary {
        error(
          "unclosed-expression", "Expression does not close before the next message",
          start, i,
        )
        parens = 0
      }
    }
    if !async_text {
      if c == 40 {
        parens += 1
      }
      if c == 41 {
        parens = max(0, parens - 1)
      }
    }
    if ((c == 123 || c == 125) && parens == 0 && !async_text) ||
      ((c == 10 || c == 13) && (parens == 0 || async_text)) ||
      (c == 59 && parens == 0) {
      let text = trim(cut(source, start, i))
      if text != "" {
        tokens.push((text, start, i, c == 123))
      }
      if c == 125 {
        tokens.push(("}", i, i + 1, false))
      }
      if c == 10 || c == 13 {
        parens = 0
        async_text = false
      }
      i += 1
      start = i
      continue
    }
    i += 1
  }
  if quote != 0 {
    error(
      "unterminated-string",
      "Quoted statement has no closing quote",
      start,
      source.length(),
    )
  }
  if parens > 0 {
    error(
      "unclosed-expression",
      "Expression has no closing parenthesis",
      start,
      source.length(),
    )
  }
  if start < source.length() {
    let text = trim(cut(source, start, source.length()))
    if text != "" {
      tokens.push((text, start, source.length(), false))
    }
  }
  let mut header = false
  for (raw, begin, b, scope) in tokens {
    let mut a = begin
    while a < b && [9, 10, 13, 32].contains(ch(source, a)) {
      a += 1
    }
    work += raw.length() + 1
    if work > limits.work || count >= limits.events {
      error(
        if work > limits.work {
          "work-limit"
        } else {
          "event-limit"
        },
        "Statement processing budget exceeded",
        a,
        b,
      )
      failed = true
      break
    }
    let text = trim(raw)
    if text == "zenuml" {
      if header {
        error("header", "Duplicate header", a, b)
      }
      header = true
      continue
    }
    if text.has_prefix("---") || text.has_prefix("%%") {
      append(Metadata(text), a, b)
      continue
    }
    if !header {
      error("header", "Expected zenuml header", a, b)
      continue
    }
    if text.has_prefix("//") {
      append(Comment(trim(cut(text, 2, text.length()))), a, b)
      continue
    }
    if text == "}" {
      if opens.pop() is None {
        error(
          "unexpected-brace", "Closing brace has no opening statement", a, b,
        )
      } else {
        append(End, a, b)
      }
      continue
    }
    if text.has_prefix("title ") {
      append(Title(trim(cut(text, 6, text.length()))), a, b)
      continue
    }
    let mut text = text
    if text.has_prefix("@Starter(") || text.has_prefix("@starter(") {
      if text.has_suffix(")") {
        append(Starter(trim(cut(text, 9, text.length() - 1))), a, b)
      } else {
        error("starter", "Malformed starter declaration", a, b)
      }
      continue
    }
    if ["@return", "@reply", "@Return", "@Reply"]
      .iter()
      .any(key => {
        text == key || text.has_prefix(key + " ") || text.has_prefix(key + "\t")
      }) {
      let n = if text.has_prefix("@return") || text.has_prefix("@Return") {
        7
      } else {
        6
      }
      reply = true
      text = trim(cut(text, n, text.length()))
      if text == "" {
        continue
      }
    } else if text.has_prefix("@") {
      let mut end = 1
      while end < text.length() && ch(text, end) != 32 && ch(text, end) != 9 {
        end += 1
      }
      annotation = Some(cut(text, 1, end))
      text = trim(cut(text, end, text.length()))
      if text == "" {
        continue
      }
    }
    if text.has_prefix("return") && (text == "return" || ch(text, 6) == 32) {
      append(Return(trim(cut(text, 6, text.length()))), a, b)
      continue
    }
    let words = [
      "else if", "else", "catch", "finally", "while", "forEach", "foreach", "for",
      "loop", "if", "opt", "par", "try", "break",
    ]
    let fragment = words
      .iter()
      .find_first(word => {
        text == word ||
        text.has_prefix(word + "(") ||
        text.has_prefix(word + " ")
      })
    if fragment is Some(keyword) {
      if !scope {
        error("expected-brace", "Control statement requires a body", a, b)
        continue
      }
      let expression = trim(cut(text, keyword.length(), text.length()))
      append(
        if ["else if", "else", "catch", "finally"].contains(keyword) {
          Section(keyword~, expression~)
        } else {
          Begin(keyword~, expression~)
        },
        a,
        b,
      )
      opens.push((span(a, b), keyword))
      if opens.length() > limits.depth {
        error("depth-limit", "Nesting depth limit exceeded", a, b)
        failed = true
        break
      }
      continue
    }
    if find_top(text, "->") is Some(arrow) {
      let sender = trim(cut(text, 0, arrow))
      let tail = trim(cut(text, arrow + 2, text.length()))
      if find_top(tail, ":") is Some(colon) {
        let receiver = trim(cut(tail, 0, colon))
        if !identifier(sender) || !identifier(receiver) {
          error("identifier", "Invalid message endpoint", a, b)
        } else {
          append(
            Async(
              sender~,
              receiver~,
              label=trim(cut(tail, colon + 1, tail.length())),
              reply~,
            ),
            a,
            b,
          )
        }
        reply = false
        continue
      }
    }
    let mut assignment = None
    let mut call = text
    if find_top(call, "=") is Some(eq) {
      assignment = Some(trim(cut(call, 0, eq)))
      call = trim(cut(call, eq + 1, call.length()))
    }
    let mut sender = None
    if find_top(call, "->") is Some(arrow) {
      sender = Some(trim(cut(call, 0, arrow)))
      call = trim(cut(call, arrow + 2, call.length()))
    }
    let creation = call.has_prefix("new ")
    if creation {
      call = trim(cut(call, 4, call.length()))
    }
    if creation {
      let end = find(call, "(").unwrap_or(call.length())
      let receiver = trim(cut(call, 0, end))
      let operation = cut(call, end, call.length())
      if !identifier(receiver) {
        error("identifier", "Invalid created participant", a, b)
      } else {
        append(
          Call(sender~, receiver~, operation~, assignment~, creation~, scope~),
          a,
          b,
        )
      }
      if scope {
        opens.push((span(a, b), "call"))
      }
    } else if find_top(call, ".") is Some(dot) {
      let receiver = trim(cut(call, 0, dot))
      let operation = trim(cut(call, dot + 1, call.length()))
      if !identifier(receiver) || operation == "" {
        error("call", "Invalid synchronous call", a, b)
      } else {
        append(
          Call(sender~, receiver~, operation~, assignment~, creation~, scope~),
          a,
          b,
        )
      }
      if scope {
        opens.push((span(a, b), "call"))
      }
    } else {
      let label = find_top(text, " as ")
      let id = trim(if label is Some(end) { cut(text, 0, end) } else { text })
      let label = label.map(end => {
        unquote(trim(cut(text, end + 4, text.length())))
      })
      if identifier(id) && !scope && assignment == None {
        append(Participant(id~, label~, annotator=annotation), a, b)
        annotation = None
      } else {
        error(
          "unsupported-statement",
          "Unsupported or malformed statement: " + text,
          a,
          b,
        )
      }
    }
    if opens.length() > limits.depth {
      error("depth-limit", "Nesting depth limit exceeded", a, b)
      failed = true
      break
    }
  }
  if annotation is Some(_) {
    error(
      "identifier",
      "Participant annotator has no participant",
      source.length(),
      source.length(),
    )
  }
  if reply {
    error(
      "unsupported-statement",
      "Reply annotator has no asynchronous message",
      source.length(),
      source.length(),
    )
  }
  if !header {
    error("header", "Expected zenuml header", 0, 0)
  }
  for (span, _) in opens {
    if diagnostics.length() < limits.diagnostics {
      diagnostics.push(
        @diagrams.Diagnostic::error(
          "zenuml/missing-brace",
          "Opening statement has no closing brace",
          span~,
        ),
      )
    }
  }
  {
    tree,
    ast: if failed {
      None
    } else {
      Some(@ast.Diagram::new(statements))
    },
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}

///|
fn max(a : Int32, b : Int32) -> Int32 {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend ReadResult with Eq::{equal, not_equal}

///|
pub extend ReadResult with @debug.Debug::{to_repr}

///|
/// Stable diagnostic codes emitted by this processing stage.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "zenuml/call", "zenuml/depth-limit", "zenuml/diagnostic-limit", "zenuml/event-limit",
  "zenuml/expected-brace", "zenuml/header", "zenuml/identifier", "zenuml/missing-brace",
  "zenuml/participant-limit", "zenuml/source-limit", "zenuml/starter", "zenuml/unclosed-expression",
  "zenuml/unexpected-brace", "zenuml/unsupported-statement", "zenuml/unterminated-string",
  "zenuml/work-limit",
]
