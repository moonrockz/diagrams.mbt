///|
/// The stable diagnostic codes of the JSON reader, writer and converter.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "json/invalid-string", "json/invalid-escape", "json/invalid-number", "json/invalid-literal",
  "json/unexpected-character", "json/unexpected-token", "json/unexpected-comment",
  "json/missing-value", "json/trailing-content", "json/depth-limit", "json/node-limit",
  "json/work-limit", "json/output-limit", "json/invalid-limits", "json/diagnostic-limit",
  "json/invalid-highlight", "json/unresolved-highlight", "json/ambiguous-highlight",
  "json/unapplied-highlight-style", "json/invalid-model",
]

///|
priv enum Lexeme {
  Open(Bool)
  Close(Bool)
  Colon
  Comma
  Text(String)
  Num(String)
  Lit(ValueKind)
  Comment
  Bad
  End
}

///|
/// One significant token for the parser. `object` in `Open` and `Close` is
/// true for braces and false for brackets.
priv struct Tok {
  lexeme : Lexeme
  start : Int32
  end : Int32
  text : String
}

///|
priv struct Lexer {
  toks : Array[Tok]
  issues : Array[(String, String, Int32, Int32)]
}

///|
fn is_hex(c : Int32) -> Bool {
  (c >= 48 && c <= 57) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70)
}

///|
fn hex_value(c : Int32) -> Int32 {
  if c <= 57 {
    c - 48
  } else if c >= 97 {
    c - 87
  } else {
    c - 55
  }
}

///|
fn is_number_unit(c : Int32) -> Bool {
  (c >= 48 && c <= 57) || c == 45 || c == 43 || c == 46 || c == 101 || c == 69
}

///|
fn is_word_unit(c : Int32) -> Bool {
  (c >= 97 && c <= 122) ||
  (c >= 65 && c <= 90) ||
  (c >= 48 && c <= 57) ||
  c == 95
}

///|
/// Decode the string token that starts at `start` (a quote). The result is
/// the end offset, the decoded text and the first problem, if any.
fn decode_string(
  text : String,
  start : Int32,
) -> (Int32, String, (String, String)?) {
  let n = text.length()
  let out = StringBuilder()
  let mut problem : (String, String)? = None
  let mut i = start + 1
  let mut run = i
  while i < n {
    let c = text.code_unit_at(i).to_int()
    if c == 34 {
      out.write_string(@cst.slice(text, run, i))
      return (i + 1, out.to_string(), problem)
    }
    if c == 92 {
      out.write_string(@cst.slice(text, run, i))
      let e = if i + 1 < n { text.code_unit_at(i + 1).to_int() } else { -1 }
      match e {
        34 | 47 | 92 => {
          out.write_char(e.unsafe_to_char())
          i += 2
        }
        98 => {
          out.write_char('\b')
          i += 2
        }
        102 => {
          out.write_char('\u{0C}')
          i += 2
        }
        110 => {
          out.write_char('\n')
          i += 2
        }
        114 => {
          out.write_char('\r')
          i += 2
        }
        116 => {
          out.write_char('\t')
          i += 2
        }
        117 => {
          let mut value = 0
          let mut ok = true
          for k in 0..<4 {
            let at = i + 2 + k
            if at >= n || !is_hex(text.code_unit_at(at).to_int()) {
              ok = false
              break
            }
            value = value * 16 + hex_value(text.code_unit_at(at).to_int())
          }
          if ok {
            // A lone surrogate stays one UTF-16 code unit, as upstream.
            out.write_char(value.unsafe_to_char())
            i += 6
          } else {
            if problem is None {
              problem = Some(
                (
                  "json/invalid-escape", "A \\u escape needs four hexadecimal digits",
                ),
              )
            }
            i += 2
          }
        }
        _ => {
          if problem is None {
            problem = Some(
              (
                "json/invalid-escape", "Invalid escape sequence; use \\\" \\\\ \\/ \\b \\f \\n \\r \\t or \\uXXXX",
              ),
            )
          }
          i += if e == -1 { 1 } else { 2 }
        }
      }
      run = i
      continue
    }
    if c < 32 {
      if problem is None {
        problem = Some(
          (
            "json/invalid-string", "A JSON string cannot contain a control character; use an escape",
          ),
        )
      }
    }
    i += 1
  }
  out.write_string(@cst.slice(text, run, n))
  (
    n,
    out.to_string(),
    Some(("json/invalid-string", "The string has no closing quote on its line")),
  )
}

///|
/// Tokenize one body line. Tokens never cross a line: strings cannot hold a
/// raw line break and a `//` comment ends at the line break.
fn Lexer::line(self : Lexer, line : @envelope.Line) -> @cst.Node {
  let text = line.text
  let base = line.offset
  let n = text.length()
  let children : Array[@cst.Element] = []
  let mut blank = true
  fn token(kind : @cst.TokenKind, start : Int32, end : Int32) {
    children.push(
      Token(@cst.Token::new(kind, @cst.slice(text, start, end), base + start)),
    )
  }
  fn tok(lexeme : Lexeme, start : Int32, end : Int32) {
    self.toks.push({
      lexeme,
      start: base + start,
      end: base + end,
      text: @cst.slice(text, start, end),
    })
  }
  fn issue(code : String, message : String, start : Int32, end : Int32) {
    self.issues.push((code, message, base + start, base + end))
  }
  let mut i = 0
  while i < n {
    let c = text.code_unit_at(i).to_int()
    let start = i
    if c == 32 || c == 9 {
      while i < n &&
            (
              text.code_unit_at(i).to_int() == 32 ||
              text.code_unit_at(i).to_int() == 9
            ) {
        i += 1
      }
      token(Whitespace, start, i)
      continue
    }
    blank = false
    match c {
      123 | 91 => {
        i += 1
        token(Punctuation, start, i)
        tok(Open(c == 123), start, i)
      }
      125 | 93 => {
        i += 1
        token(Punctuation, start, i)
        tok(Close(c == 125), start, i)
      }
      58 => {
        i += 1
        token(Punctuation, start, i)
        tok(Colon, start, i)
      }
      44 => {
        i += 1
        token(Punctuation, start, i)
        tok(Comma, start, i)
      }
      34 => {
        let (end, decoded, problem) = decode_string(text, start)
        i = end
        match problem {
          None => {
            token(String, start, i)
            tok(Text(decoded), start, i)
          }
          Some((code, message)) => {
            token(Error, start, i)
            tok(Bad, start, i)
            issue(code, message, start, i)
          }
        }
      }
      47 =>
        if i + 1 < n && text.code_unit_at(i + 1).to_int() == 47 {
          i = n
          token(Comment, start, i)
          tok(Comment, start, i)
        } else {
          i += 1
          token(Error, start, i)
          tok(Bad, start, i)
          issue(
            "json/unexpected-character", "A comment starts with '//'", start, i,
          )
        }
      _ =>
        if c == 45 || (c >= 48 && c <= 57) {
          while i < n && is_number_unit(text.code_unit_at(i).to_int()) {
            i += 1
          }
          let lexeme = @cst.slice(text, start, i)
          if @data_tree.valid_number(lexeme) {
            token(Number, start, i)
            tok(Num(lexeme), start, i)
          } else {
            token(Error, start, i)
            tok(Bad, start, i)
            issue(
              "json/invalid-number",
              "'\{lexeme}' is not a valid JSON number",
              start,
              i,
            )
          }
        } else if is_word_unit(c) {
          while i < n && is_word_unit(text.code_unit_at(i).to_int()) {
            i += 1
          }
          let word = @cst.slice(text, start, i)
          let literal : ValueKind? = match word {
            "true" => Some(Boolean(true))
            "false" => Some(Boolean(false))
            "null" => Some(Null)
            _ => None
          }
          match literal {
            Some(kind) => {
              token(Literal, start, i)
              tok(Lit(kind), start, i)
            }
            None => {
              token(Error, start, i)
              tok(Bad, start, i)
              issue(
                "json/invalid-literal",
                "'\{word}' is not a JSON value; use true, false, null, a number or a quoted string",
                start,
                i,
              )
            }
          }
        } else {
          i += if c >= 0xd800 && c <= 0xdbff && i + 1 < n { 2 } else { 1 }
          token(Error, start, i)
          tok(Bad, start, i)
          issue(
            "json/unexpected-character",
            "Unexpected character '\{@cst.slice(text, start, i)}'",
            start,
            i,
          )
        }
    }
  }
  if !line.newline.is_empty() {
    children.push(Token(@cst.Token::new(Newline, line.newline, base + n)))
  }
  @cst.Node::new(if blank { Blank } else { Data }, children)
}

///|
/// The result of reading a JSON body.
pub struct ReadResult {
  /// The body nodes in source order, with shared statement nodes.
  nodes : Array[@cst.Node]
  document : Document?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
priv struct Frame {
  object : Bool
  start : Int32
  members : Array[Member]
  items : Array[Value]
  mut name : Str
  mut name_start : Int32
}

///|
priv enum Mode {
  NeedValue
  NeedName
  After(Value)
}

///|
/// Read the JSON body of a scanned block. The reader keeps every member
/// occurrence in order, exact number lexemes and decoded strings with their
/// spellings. It follows the pinned PlantUML profile: a `//` comment can
/// stand only before a member name or after a member value; malformed input
/// is refused with a diagnostic, never coerced.
pub fn read(
  scan : @envelope.Scan,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> ReadResult {
  let diagnostics = scan.diagnostics.iter().to_array()
  let lexer : Lexer = { toks: [], issues: [], }
  let nodes = scan.line_nodes(line => Some(lexer.line(line)))
  fn report(diagnostic : @diagrams.Diagnostic) {
    if diagnostics.length() < limits.diagnostics {
      diagnostics.push(diagnostic)
    } else if diagnostics.length() == limits.diagnostics {
      diagnostics.push(
        @diagrams.Diagnostic::error(
          "json/diagnostic-limit", "Diagnostic limit reached",
        ),
      )
    }
  }
  fn done(document : Document?) -> ReadResult {
    let failed = diagnostics.iter().any(d => d.severity == Error)
    {
      nodes,
      document: if failed {
        None
      } else {
        document
      },
      diagnostics: ReadOnlyArray::from_array(diagnostics),
    }
  }
  if !limits.valid() {
    report(
      @diagrams.Diagnostic::error(
        "json/invalid-limits", "JSON limits must be positive",
      ),
    )
    return done(None)
  }
  for issue in lexer.issues {
    let (code, message, start, end) = issue
    report(
      @diagrams.Diagnostic::error(code, message, span=scan.span(start, end)),
    )
  }
  let (selectors, highlight_issues) = @data.read_selectors(scan, "json")
  for diagnostic in highlight_issues {
    report(diagnostic)
  }
  let toks = lexer.toks
  let end_offset = scan.lines
    .iter()
    .fold(init=0, (at, line) => {
      if line.role is Body {
        line.offset + line.text.length()
      } else {
        at
      }
    })
  let mut pos = 0
  let mut work = 0
  let mut count = 0
  let end_tok : Tok = {
    lexeme: End,
    start: end_offset,
    end: end_offset,
    text: "",
  }
  fn next() -> Tok {
    if pos < toks.length() {
      pos += 1
      toks[pos - 1]
    } else {
      end_tok
    }
  }
  fn peek() -> Tok {
    if pos < toks.length() {
      toks[pos]
    } else {
      end_tok
    }
  }
  fn fail(tok : Tok, code : String, message : String) -> ReadResult {
    // A lexical error already has its own diagnostic.
    if !(tok.lexeme is Bad) {
      report(
        @diagrams.Diagnostic::error(
          code,
          message,
          span=scan.span(tok.start, tok.end),
        ),
      )
    }
    done(None)
  }
  fn describe(tok : Tok) -> String {
    match tok.lexeme {
      End => "the end of the data"
      _ => "'\{tok.text}'"
    }
  }
  let stack : Array[Frame] = []
  let mut mode = NeedValue
  let mut root : Value? = None
  while root is None {
    work += 1
    if work > limits.work {
      report(
        @diagrams.Diagnostic::error(
          "json/work-limit", "JSON reading exceeds its work limit",
        ),
      )
      return done(None)
    }
    match mode {
      NeedValue => {
        let tok = next()
        let kind : ValueKind? = match tok.lexeme {
          Text(decoded) => Some(String({ text: decoded, raw: Some(tok.text), }))
          Num(lexeme) => Some(Number(lexeme))
          Lit(kind) => Some(kind)
          _ => None
        }
        count += 1
        if count > limits.nodes {
          report(
            @diagrams.Diagnostic::error(
              "json/node-limit",
              "JSON data exceeds the node limit",
              span=scan.span(tok.start, tok.end),
            ),
          )
          return done(None)
        }
        match kind {
          Some(kind) =>
            mode = After({ kind, span: Some(scan.span(tok.start, tok.end)), })
          None =>
            match tok.lexeme {
              Open(object) => {
                if stack.length() >= limits.depth {
                  report(
                    @diagrams.Diagnostic::error(
                      "json/depth-limit",
                      "JSON nesting exceeds the depth limit of \{limits.depth}",
                      span=scan.span(tok.start, tok.end),
                    ),
                  )
                  return done(None)
                }
                stack.push({
                  object,
                  start: tok.start,
                  members: [],
                  items: [],
                  name: Str::new(""),
                  name_start: tok.start,
                })
                if peek().lexeme is Close(closing) && closing == object {
                  let close = next()
                  let frame = stack.unsafe_pop()
                  let kind : ValueKind = if object {
                    Object([])
                  } else {
                    Array([])
                  }
                  mode = After({
                    kind,
                    span: Some(scan.span(frame.start, close.end)),
                  })
                } else {
                  mode = if object { NeedName } else { NeedValue }
                }
              }
              End =>
                return fail(
                  tok,
                  "json/missing-value",
                  if stack.is_empty() {
                    "A JSON block needs a value"
                  } else {
                    "Expected a value before the end of the data"
                  },
                )
              Comment =>
                return fail(
                  tok, "json/unexpected-comment", "A comment cannot stand here; PlantUML allows one only before a member name or after a member value",
                )
              _ =>
                return fail(
                  tok,
                  "json/unexpected-token",
                  "Expected a value, found \{describe(tok)}",
                )
            }
        }
      }
      NeedName => {
        let mut tok = next()
        if tok.lexeme is Comment {
          tok = next()
        }
        guard tok.lexeme is Text(decoded) else {
          return fail(
            tok,
            if tok.lexeme is Comment {
              "json/unexpected-comment"
            } else {
              "json/unexpected-token"
            },
            "Expected a quoted member name, found \{describe(tok)}",
          )
        }
        let colon = next()
        guard colon.lexeme is Colon else {
          return fail(
            colon,
            "json/unexpected-token",
            "Expected ':' after the member name, found \{describe(colon)}",
          )
        }
        let frame = stack[stack.length() - 1]
        frame.name = { text: decoded, raw: Some(tok.text), }
        frame.name_start = tok.start
        mode = NeedValue
      }
      After(value) => {
        guard stack.last() is Some(frame) else {
          root = Some(value)
          break
        }
        if frame.object {
          frame.members.push({
            name: frame.name,
            value,
            span: Some(
              scan.span(
                frame.name_start,
                value.span.map(s => s.end.offset).unwrap_or(frame.name_start),
              ),
            ),
          })
          if peek().lexeme is Comment {
            ignore(next())
          }
        } else {
          frame.items.push(value)
        }
        let tok = next()
        match tok.lexeme {
          Comma => mode = if frame.object { NeedName } else { NeedValue }
          Close(closing) if closing == frame.object => {
            ignore(stack.pop())
            let kind : ValueKind = if frame.object {
              Object(ReadOnlyArray::from_array(frame.members))
            } else {
              Array(ReadOnlyArray::from_array(frame.items))
            }
            mode = After({ kind, span: Some(scan.span(frame.start, tok.end)), })
          }
          Comment =>
            return fail(
              tok, "json/unexpected-comment", "A comment cannot stand here; PlantUML allows one only before a member name or after a member value",
            )
          _ =>
            return fail(
              tok,
              "json/unexpected-token",
              "Expected ',' or '\{if frame.object { "}" } else { "]" }}', found \{describe(tok)}",
            )
        }
      }
    }
  }
  let rest = next()
  if !(rest.lexeme is End) {
    return fail(
      rest,
      "json/trailing-content",
      "Unexpected \{describe(rest)} after the JSON value",
    )
  }
  guard root is Some(value) else { return done(None) }
  done(
    Some({
      name: scan.name,
      statements: scan.statements,
      highlights: ReadOnlyArray::from_array(selectors),
      value,
    }),
  )
}
