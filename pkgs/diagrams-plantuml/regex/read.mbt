///|
/// The stable diagnostic codes of the regex reader and writer.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "regex/missing-pattern", "regex/multiple-patterns", "regex/syntax", "regex/unclosed-group",
  "regex/unmatched-parenthesis", "regex/empty-group", "regex/bad-quantifier", "regex/unclosed-set",
  "regex/empty-set", "regex/invalid-posix", "regex/unclosed-comment", "regex/unsupported-escape",
  "regex/unsupported-group", "regex/limit", "regex/unrepresentable",
]

///|
priv enum Open {
  Plain
  NonCapturing
  /// The parenthesis that follows a lookaround or named-group marker.
  Marked
}

///|
priv enum Lex {
  Char(String, Bool)
  Class(@model.ClassKind)
  Backref(String)
  Set(Bool, ReadOnlyArray[@model.SetItem])
  Anchor(@model.AnchorKind)
  Quantifier(@model.Bounds)
  Alternative
  Open(Open)
  Close
  Concat
  Look(@model.Look, Bool)
  Named(String)
  /// Output only: wrap the operand in a group of this kind.
  GroupMark(@model.GroupKind)
}

///|
priv struct Tok {
  lex : Lex
  start : Int
  end : Int
}

///|
priv struct Failure {
  code : String
  message : String
  start : Int
  end : Int
}

///|
fn is_letter_unit(c : Int) -> Bool {
  (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
}

///|
fn is_name_char(c : Int) -> Bool {
  // Character.isLetter for the pinned reader; ASCII and non-ASCII letters.
  is_letter_unit(c) || (c >= 0xc0 && c != 0xd7 && c != 0xf7 && c < 0xd800)
}

///|
fn hex(c : Int) -> Bool {
  (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)
}

///|
/// The code point at `i` of `text` as a string, and its UTF-16 width.
fn code_point(text : String, i : Int) -> (String, Int) {
  let c = text.code_unit_at(i).to_int()
  if c >= 0xd800 && c <= 0xdbff && i + 1 < text.length() {
    let d = text.code_unit_at(i + 1).to_int()
    if d >= 0xdc00 && d <= 0xdfff {
      return (@cst.slice(text, i, i + 2), 2)
    }
  }
  (@cst.slice(text, i, i + 1), 1)
}

///|
fn shorthand(c : Int) -> Bool {
  // \d \D \w \W \s \S \h \H \v \V \R \X \N \t \n \r \f \e \a
  [100, 68, 119, 87, 115, 83, 104, 72, 118, 86, 82, 88, 78, 116, 110, 114, 102, 101, 97].contains(
    c,
  )
}

///|
fn parse_int(text : String) -> Int? {
  if text.is_empty() || text.length() > 10 {
    return None
  }
  let mut value = 0L
  for i in 0..<text.length() {
    let c = text.code_unit_at(i).to_int()
    if c < 48 || c > 57 {
      return None
    }
    value = value * 10L + (c - 48).to_int64()
  }
  if value > 2147483647L {
    None
  } else {
    Some(value.to_int())
  }
}

///|
/// Read the bracketed set content, already without its brackets.
fn set_items(content : String) -> Array[@model.SetItem] {
  let items : Array[@model.SetItem] = []
  let n = content.length()
  let mut i = 0
  fn item_at(at : Int) -> (String, Int, Bool) {
    // A character, its width and whether it was escaped.
    if content.code_unit_at(at).to_int() == 92 && at + 1 < n {
      let (c, w) = code_point(content, at + 1)
      (c, w + 1, true)
    } else {
      let (c, w) = code_point(content, at)
      (c, w, false)
    }
  }
  while i < n {
    let (first, width, escaped) = item_at(i)
    if escaped && first.length() == 1 &&
      is_letter_unit(first.code_unit_at(0).to_int()) {
      items.push(Escape("\\" + first))
      i += width
      continue
    }
    let dash = i + width
    if dash + 1 < n && content.code_unit_at(dash).to_int() == 45 {
      let (last, w, _) = item_at(dash + 1)
      items.push(Range(first, last))
      i = dash + 1 + w
      continue
    }
    items.push(Char(first))
    i += width
  }
  items
}

///|
/// Tokenize one pattern line. `base` is the source offset of `text`.
fn tokenize(text : String, base : Int) -> Result[Array[Tok], Failure] {
  let out : Array[Tok] = []
  let n = text.length()
  let mut i = 0
  fn at(k : Int) -> Int {
    if k < n {
      text.code_unit_at(k).to_int()
    } else {
      0
    }
  }
  fn push(lex : Lex, start : Int, end : Int) {
    out.push({ lex, start: base + start, end: base + end })
  }
  fn fail(code : String, message : String, start : Int, end : Int) -> Result[
    Array[Tok],
    Failure,
  ] {
    Err({ code, message, start: base + start, end: base + end })
  }
  while i < n {
    let c = at(i)
    let start = i
    if c == 94 {
      push(Anchor(LineStart), i, i + 1)
      i += 1
    } else if c == 36 {
      push(Anchor(LineEnd), i, i + 1)
      i += 1
    } else if c == 92 && i + 1 >= n {
      return fail("regex/syntax", "A backslash ends the pattern", i, i + 1)
    } else if c == 92 {
      let d = at(i + 1)
      match d {
        65 => push(Anchor(InputStart), i, i + 2)
        90 => push(Anchor(InputEndBeforeNewline), i, i + 2)
        122 => push(Anchor(InputEnd), i, i + 2)
        71 => push(Anchor(PreviousMatchEnd), i, i + 2)
        98 => push(Anchor(WordBoundary), i, i + 2)
        66 => push(Anchor(NonWordBoundary), i, i + 2)
        112 | 120 if at(i + 2) == 123 => {
          let mut k = i + 3
          while k < n && at(k) != 125 {
            k += 1
          }
          if k >= n {
            return fail(
              "regex/unsupported-escape", "Unclosed escape braces", i, n,
            )
          }
          let inner = @cst.slice(text, i + 3, k)
          if inner.is_empty() {
            return fail("regex/unsupported-escape", "Empty escape braces", i, k + 1)
          }
          push(
            Class(
              if d == 112 {
                Property(inner)
              } else {
                CodePoint("\\x{" + inner + "}")
              },
            ),
            i,
            k + 1,
          )
          i = k + 1
          continue
        }
        81 => {
          // \Q quotes text up to \E or the end of the pattern.
          let mut k = i + 2
          while k < n && !(at(k) == 92 && at(k + 1) == 69) {
            let (ch, w) = code_point(text, k)
            push(Char(ch, ch.length() == 1 && !is_letter_unit(ch.code_unit_at(0).to_int()) && !(ch.code_unit_at(0).to_int() >= 48 && ch.code_unit_at(0).to_int() <= 57)), k, k + w)
            k += w
          }
          i = if k < n { k + 2 } else { n }
          continue
        }
        117 => {
          if !(hex(at(i + 2)) && hex(at(i + 3)) && hex(at(i + 4)) && hex(at(i + 5))) {
            return fail(
              "regex/unsupported-escape", "\\u needs four hexadecimal digits", i, (i + 6).min(n),
            )
          }
          push(Class(CodePoint(@cst.slice(text, i, i + 6))), i, i + 6)
          i += 6
          continue
        }
        48 => {
          let octal = k => at(k) >= 48 && at(k) <= 55
          if !(octal(i + 2) && octal(i + 3) && octal(i + 4)) {
            return fail(
              "regex/unsupported-escape", "\\0 needs three octal digits", i, (i + 5).min(n),
            )
          }
          push(Class(CodePoint(@cst.slice(text, i, i + 5))), i, i + 5)
          i += 5
          continue
        }
        _ =>
          if d >= 49 && d <= 57 {
            push(Backref(@cst.slice(text, i + 1, i + 2)), i, i + 2)
          } else if is_letter_unit(d) {
            if !shorthand(d) {
              return fail(
                "regex/unsupported-escape",
                "Unsupported escape \\\{@cst.slice(text, i + 1, i + 2)}",
                i,
                i + 2,
              )
            }
            push(Class(Shorthand(Int::unsafe_to_char(d))), i, i + 2)
          } else {
            let (ch, w) = code_point(text, i + 1)
            push(Char(ch, true), i, i + 1 + w)
            i += 1 + w
            continue
          }
      }
      i += 2
    } else if c == 124 {
      push(Alternative, i, i + 1)
      i += 1
    } else if c == 91 && at(i + 1) == 91 && at(i + 2) == 58 {
      let mut k = i + 3
      while k < n && at(k) != 58 {
        k += 1
      }
      if k + 2 >= n || at(k + 1) != 93 || at(k + 2) != 93 || k == i + 3 {
        return fail(
          "regex/invalid-posix", "Expected a POSIX class such as [[:alpha:]]", i, n,
        )
      }
      push(Class(Posix(@cst.slice(text, i + 3, k))), i, k + 3)
      i = k + 3
    } else if c == 91 {
      let mut k = i + 1
      while k < n && at(k) != 93 {
        if at(k) == 92 {
          k += 1
        }
        k += 1
      }
      if k >= n {
        return fail("regex/unclosed-set", "Unclosed character set", i, n)
      }
      let content = @cst.slice(text, i + 1, k)
      let negated = content.has_prefix("^")
      let body = if negated {
        @cst.slice(content, 1, content.length())
      } else {
        content
      }
      if body.is_empty() {
        return fail("regex/empty-set", "A character set needs an item", i, k + 1)
      }
      push(Set(negated, ReadOnlyArray::from_array(set_items(body))), i, k + 1)
      i = k + 1
    } else if c == 40 && at(i + 1) == 63 && at(i + 2) == 35 {
      let mut k = i + 3
      while k < n && at(k) != 41 {
        k += 1
      }
      if k >= n {
        return fail("regex/unclosed-comment", "Unclosed comment", i, n)
      }
      i = k + 1
    } else if c == 40 && at(i + 1) == 63 && (at(i + 2) == 61 || at(i + 2) == 33) {
      push(Look(Ahead, at(i + 2) == 61), i, i + 3)
      push(Open(Marked), i, i + 3)
      i += 3
    } else if c == 40 &&
      at(i + 1) == 63 &&
      at(i + 2) == 60 &&
      (at(i + 3) == 61 || at(i + 3) == 33) {
      push(Look(Behind, at(i + 3) == 61), i, i + 4)
      push(Open(Marked), i, i + 4)
      i += 4
    } else if c == 40 && at(i + 1) == 63 && at(i + 2) == 60 {
      let mut k = i + 3
      while k < n && is_name_char(at(k)) {
        k += 1
      }
      if k == i + 3 || at(k) != 62 {
        return fail(
          "regex/unsupported-group", "A named group needs a letter name and '>'", i, (k + 1).min(n),
        )
      }
      push(Named(@cst.slice(text, i + 3, k)), i, k + 1)
      push(Open(Marked), i, k + 1)
      i = k + 1
    } else if c == 40 && at(i + 1) == 63 && at(i + 2) == 58 {
      push(Open(NonCapturing), i, i + 3)
      i += 3
    } else if c == 40 && at(i + 1) == 63 {
      return fail(
        "regex/unsupported-group", "Unsupported group form", i, (i + 3).min(n),
      )
    } else if c == 40 {
      push(Open(Plain), i, i + 1)
      i += 1
    } else if c == 41 {
      push(Close, i, i + 1)
      i += 1
    } else if c == 42 || c == 43 || c == 63 || c == 123 {
      let mut k = i + 1
      if c == 123 {
        while k < n && at(k) != 125 {
          k += 1
        }
        if k >= n {
          return fail("regex/bad-quantifier", "Unclosed quantifier braces", i, n)
        }
        k += 1
      }
      let reluctant = at(k) == 63
      let end = if reluctant { k + 1 } else { k }
      let spelling = @cst.slice(text, i, end)
      let bounds = if c == 42 {
        @model.Bounds::new(0, reluctant~, spelling~)
      } else if c == 43 {
        @model.Bounds::new(1, reluctant~, spelling~)
      } else if c == 63 {
        @model.Bounds::new(0, max=1, reluctant~, spelling~)
      } else {
        if reluctant {
          return fail(
            "regex/bad-quantifier", "Bad quantifier \{spelling}", i, end,
          )
        }
        let inner = @cst.slice(text, i + 1, k - 1)
        let parts = inner.split(",").map(p => p.to_owned()).collect()
        let valid = inner.length() > 0 &&
          inner.iter().all(ch => (ch >= '0' && ch <= '9') || ch == ',')
        if !valid {
          return fail(
            "regex/bad-quantifier", "Bad quantifier \{spelling}", i, end,
          )
        }
        if parts.length() > 2 {
          return fail(
            "regex/bad-quantifier", "A quantifier has at most one comma: \{spelling}",
            i, end,
          )
        }
        let min = if parts[0].is_empty() { Some(0) } else { parse_int(parts[0]) }
        let max = if parts.length() == 1 {
          min
        } else if parts[1].is_empty() {
          None
        } else {
          parse_int(parts[1])
        }
        guard min is Some(min) else {
          return fail(
            "regex/bad-quantifier", "Quantifier bound is too large: \{spelling}",
            i, end,
          )
        }
        if parts.length() == 2 && !parts[1].is_empty() && max is None {
          return fail(
            "regex/bad-quantifier", "Quantifier bound is too large: \{spelling}",
            i, end,
          )
        }
        if max is Some(m) && m < min {
          return fail(
            "regex/bad-quantifier", "The upper bound is less than the lower bound: \{spelling}",
            i, end,
          )
        }
        @model.Bounds::new(min, max?, spelling~)
      }
      push(Quantifier(bounds), i, end)
      i = end
    } else if c == 46 {
      push(Class(Any), i, i + 1)
      i += 1
    } else {
      let (ch, w) = code_point(text, i)
      push(Char(ch, false), i, i + w)
      i += w
    }
    ignore(start)
  }
  Ok(out)
}

///|
fn needs_concat(a : Lex, b : Lex) -> Bool {
  match (a, b) {
    (Look(_, _) | Named(_), _) => false
    (Alternative, _) | (_, Alternative) => false
    (_, Quantifier(_)) => false
    (Open(_), _) => false
    (_, Close) => false
    _ => true
  }
}

///|
priv struct Item {
  expr : Expr
  start : Int
  end : Int
  depth : Int
}

///|
/// Parse one pattern line into an expression. The order of operations is the
/// shunting-yard order of the pinned reader, so the structure agrees with it.
fn parse_pattern(
  text : String,
  base : Int,
  span : (Int, Int) -> @diagrams.Span,
  limits : @envelope.Limits,
) -> Result[Expr, Failure] {
  let tokens = match tokenize(text, base) {
    Ok(tokens) => tokens
    Err(failure) => return Err(failure)
  }
  if tokens.length() > limits.nodes {
    return Err({
      code: "regex/limit",
      message: "Regex token limit exceeded",
      start: base,
      end: base + text.length(),
    })
  }
  let joined : Array[Tok] = []
  for tok in tokens {
    if joined.last() is Some(last) && needs_concat(last.lex, tok.lex) {
      joined.push({ lex: Concat, start: tok.start, end: tok.start })
    }
    joined.push(tok)
  }
  let output : Array[Tok] = []
  let operators : Array[Tok] = []
  let mut depth = 0
  for tok in joined {
    match tok.lex {
      Char(_, _) | Class(_) | Backref(_) | Set(_, _) | Anchor(_) | Quantifier(_) =>
        output.push(tok)
      Look(_, _) | Named(_) | Concat => operators.push(tok)
      Alternative => {
        while operators.last() is Some({ lex: Concat, .. }) {
          output.push(operators.pop().unwrap())
        }
        operators.push(tok)
      }
      Open(_) => {
        depth += 1
        if depth > limits.depth {
          return Err({
            code: "regex/limit",
            message: "Regex nesting limit exceeded",
            start: tok.start,
            end: tok.end,
          })
        }
        operators.push(tok)
      }
      Close => {
        while operators.last() is Some(top) && !(top.lex is Open(_)) {
          output.push(operators.pop().unwrap())
        }
        guard operators.pop() is Some(open) else {
          return Err({
            code: "regex/unmatched-parenthesis",
            message: "Closing parenthesis without an opening parenthesis",
            start: tok.start,
            end: tok.end,
          })
        }
        depth -= 1
        match open.lex {
          Open(Plain) =>
            output.push({ lex: GroupMark(Capturing), start: open.start, end: tok.end })
          Open(NonCapturing) =>
            output.push({ lex: GroupMark(NonCapturing), start: open.start, end: tok.end })
          _ =>
            if operators.last() is Some(marker) &&
              (marker.lex is (Look(_, _) | Named(_))) {
              output.push({ ..operators.pop().unwrap(), end: tok.end })
            }
        }
      }
      GroupMark(_) => ()
    }
  }
  while operators.pop() is Some(tok) {
    output.push(tok)
  }
  let stack : Array[Item] = []
  fn fail(message : String, tok : Tok) -> Result[Expr, Failure] {
    Err({ code: "regex/syntax", message, start: tok.start, end: tok.end })
  }
  fn leaf(expr : Expr, tok : Tok) -> Unit {
    stack.push({ expr, start: tok.start, end: tok.end, depth: 1 })
  }
  for tok in output {
    let s = Some(span(tok.start, tok.end))
    match tok.lex {
      Char(c, escaped) => leaf(Char(c, escaped, s), tok)
      Class(kind) => leaf(Class(kind, s), tok)
      Backref(n) => leaf(Backreference(n, s), tok)
      Set(negated, items) => leaf(Set(negated, items, s), tok)
      Anchor(kind) => leaf(Anchor(kind, s), tok)
      Open(_) =>
        return Err({
          code: "regex/unclosed-group",
          message: "Unclosed group",
          start: tok.start,
          end: tok.end,
        })
      Concat | Alternative => {
        guard stack.pop() is Some(right) && stack.pop() is Some(left) else {
          return fail(
            if tok.lex is Concat {
              "Missing operand"
            } else {
              "An alternative is empty"
            },
            tok,
          )
        }
        let parts = []
        let flatten = (item : Item) => match (tok.lex, item.expr) {
          (Concat, Concat(items)) | (Alternative, Alt(items)) =>
            for e in items {
              parts.push(e)
            }
          _ => parts.push(item.expr)
        }
        flatten(left)
        flatten(right)
        let items = ReadOnlyArray::from_array(parts)
        let depth = left.depth.max(right.depth) + 1
        if depth > limits.depth {
          return Err({
            code: "regex/limit",
            message: "Regex depth limit exceeded",
            start: left.start,
            end: right.end,
          })
        }
        stack.push({
          expr: if tok.lex is Concat { Concat(items) } else { Alt(items) },
          start: left.start,
          end: right.end,
          depth,
        })
      }
      Quantifier(_) | Look(_, _) | Named(_) | GroupMark(_) => {
        guard stack.pop() is Some(inner) else {
          return Err({
            code: if tok.lex is GroupMark(_) {
              "regex/empty-group"
            } else {
              "regex/syntax"
            },
            message: if tok.lex is Quantifier(_) {
              "A quantifier has no operand"
            } else {
              "A group is empty"
            },
            start: tok.start,
            end: tok.end,
          })
        }
        let depth = inner.depth + 1
        if depth > limits.depth {
          return Err({
            code: "regex/limit",
            message: "Regex depth limit exceeded",
            start: inner.start,
            end: tok.end,
          })
        }
        let start = inner.start.min(tok.start)
        let end = inner.end.max(tok.end)
        let whole = Some(span(start, end))
        let expr : Expr = match tok.lex {
          Quantifier(bounds) => Quantified(inner.expr, bounds, whole)
          Look(look, positive) => Look(look, positive, inner.expr, whole)
          Named(name) => Group(Named(name), inner.expr, whole)
          GroupMark(kind) => Group(kind, inner.expr, whole)
          _ => inner.expr
        }
        stack.push({ expr, start, end, depth })
      }
      Close => ()
    }
  }
  match stack {
    [item] => Ok(item.expr)
    [] =>
      Err({
        code: "regex/missing-pattern",
        message: "The pattern is empty",
        start: base,
        end: base,
      })
    _ =>
      Err({
        code: "regex/syntax",
        message: "The pattern has an unexpected structure",
        start: base,
        end: base + text.length(),
      })
  }
}

///|
pub struct ReadResult {
  nodes : Array[@cst.Node]
  document : Document?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
fn pattern_node(line : @envelope.Line) -> @cst.Node {
  let children : Array[@cst.Element] = []
  let text = line.text
  let mut lead = 0
  while lead < text.length() &&
    (text.code_unit_at(lead).to_int() == 32 || text.code_unit_at(lead).to_int() == 9) {
    lead += 1
  }
  let mut tail = text.length()
  while tail > lead &&
    (
      text.code_unit_at(tail - 1).to_int() == 32 ||
      text.code_unit_at(tail - 1).to_int() == 9
    ) {
    tail -= 1
  }
  if lead > 0 {
    children.push(
      Token(@cst.Token::new(Whitespace, @cst.slice(text, 0, lead), line.offset)),
    )
  }
  if tail > lead {
    let body = @cst.slice(text, lead, tail)
    let offset = line.offset + lead
    match tokenize(body, offset) {
      Ok(tokens) => {
        let mut cursor = 0
        for tok in tokens {
          let a = tok.start - offset
          let b = tok.end - offset
          if a > cursor {
            children.push(
              Token(@cst.Token::new(Comment, @cst.slice(body, cursor, a), offset + cursor)),
            )
          }
          if b > a && a >= cursor {
            let kind : @cst.TokenKind = match tok.lex {
              Char(_, false) => Text
              Char(_, true) | Class(_) | Backref(_) => Escape
              Set(_, _) => String
              Anchor(_) | Quantifier(_) | Alternative => Operator
              Open(_) | Close | Look(_, _) | Named(_) => Punctuation
              _ => Text
            }
            children.push(Token(@cst.Token::new(kind, @cst.slice(body, a, b), tok.start)))
            cursor = b
          }
        }
        if cursor < body.length() {
          children.push(
            Token(
              @cst.Token::new(Comment, @cst.slice(body, cursor, body.length()), offset + cursor),
            ),
          )
        }
      }
      Err(_) =>
        children.push(Token(@cst.Token::new(Error, body, offset)))
    }
  }
  if tail < text.length() {
    children.push(
      Token(
        @cst.Token::new(Whitespace, @cst.slice(text, tail, text.length()), line.offset + tail),
      ),
    )
  }
  if !line.newline.is_empty() {
    children.push(
      Token(
        @cst.Token::new(Newline, line.newline, line.offset + text.length()),
      ),
    )
  }
  @cst.Node::new(if tail > lead { Pattern } else { Blank }, children)
}

///|
/// Read the body of a scanned regex block. The block has exactly one pattern
/// line; further pattern lines are an error.
pub fn read(
  scan : @envelope.Scan,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> ReadResult {
  let diagnostics = scan.diagnostics.iter().to_array()
  let nodes = scan.line_nodes(line => Some(pattern_node(line)))
  let patterns = scan.lines
    .iter()
    .filter(line => line.role is Body && !@envelope.trim(line.text).is_empty())
    .to_array()
  fn done(document : Document?) -> ReadResult {
    let failed = diagnostics.iter().any(d => d.severity == Error)
    {
      nodes,
      document: if failed { None } else { document },
      diagnostics: ReadOnlyArray::from_array(diagnostics),
    }
  }
  if patterns.is_empty() {
    diagnostics.push(
      @diagrams.Diagnostic::error(
        "regex/missing-pattern",
        "A regex block needs one pattern line",
        span=scan.span(scan.source.length(), scan.source.length()),
      ),
    )
    return done(None)
  }
  for extra in patterns[1:] {
    diagnostics.push(
      @diagrams.Diagnostic::error(
        "regex/multiple-patterns",
        "A regex block has one pattern line; PlantUML 1.2026.9 draws only the last one",
        span=scan.span(extra.offset, extra.offset + extra.text.length()),
      ),
    )
  }
  let line = patterns[0]
  let text = line.text
  let mut lead = 0
  while lead < text.length() &&
    (text.code_unit_at(lead).to_int() == 32 || text.code_unit_at(lead).to_int() == 9) {
    lead += 1
  }
  let body = @envelope.trim(text)
  let offset = line.offset + lead
  match parse_pattern(body, offset, (a, b) => scan.span(a, b), limits) {
    Ok(pattern) =>
      done(
        Some({
          name: scan.name,
          statements: scan.statements,
          pattern,
          text: body,
          span: Some(scan.span(offset, offset + body.length())),
        }),
      )
    Err(failure) => {
      diagnostics.push(
        @diagrams.Diagnostic::error(
          failure.code,
          failure.message,
          span=scan.span(failure.start, failure.end),
        ),
      )
      done(None)
    }
  }
}
