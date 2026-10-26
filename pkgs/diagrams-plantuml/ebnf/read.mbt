///|
/// The stable diagnostic codes of the EBNF reader and writer.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "ebnf/missing-rule", "ebnf/syntax", "ebnf/unparsable", "ebnf/unterminated-string",
  "ebnf/invalid-count", "ebnf/dropped-note", "ebnf/trailing-text", "ebnf/interrupted-block",
  "ebnf/limit", "ebnf/unrepresentable",
]

///|
priv enum Sym {
  Literal
  Definition
  Concatenation
  Alternation
  OptionalOpen
  OptionalClose
  OptionalMark
  RepetitionSymbol
  RepetitionOpen
  RepetitionClose
  RepetitionMinusClose
  ZeroMark
  OneMark
  GroupOpen
  GroupClose
  Terminal1
  Terminal2
  CommentToken
  CommentAbove
  CommentBelow
  SpecialSeq
  NotMark
} derive(Eq)

///|
priv struct Tok {
  sym : Sym
  data : String
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
fn letter_or_digit(c : Int) -> Bool {
  (c >= 48 && c <= 57) ||
  (c >= 65 && c <= 90) ||
  (c >= 97 && c <= 122) ||
  (c >= 0xaa && c != 0xd7 && c != 0xf7 && (c < 0xd800 || c > 0xdfff) && c != 0xfeff &&
  !(c >= 0x2000 && c <= 0x206f) &&
  !(c >= 0x3000 && c <= 0x303f))
}

///|
fn literal_char(c : Int) -> Bool {
  c == 45 || c == 95 || letter_or_digit(c)
}

///|
/// Text with a source offset for each UTF-16 unit.
priv struct Source {
  text : String
  offsets : Array[Int]
}

///|
fn Source::offset(self : Source, i : Int) -> Int {
  if i < self.offsets.length() {
    self.offsets[i]
  } else if self.offsets.is_empty() {
    0
  } else {
    self.offsets[self.offsets.length() - 1] + 1
  }
}

///|
/// Tokenize an expression the way the pinned reader does, from the rule name
/// up to the first `;`. Units in `skip` read as spaces.
fn tokenize(
  source : Source,
  from : Int,
  skip : ArrayView[(Int, Int)],
) -> Result[(Array[Tok], Int), Failure] {
  let text = source.text
  let n = text.length()
  let out : Array[Tok] = []
  let mut i = from
  fn at(k : Int) -> Int {
    if k < n {
      text.code_unit_at(k).to_int()
    } else {
      0
    }
  }
  fn skipped(k : Int) -> Bool {
    skip.iter().any(r => k >= r.0 && k < r.1)
  }
  fn tok(sym : Sym, data : String, a : Int, b : Int) -> Tok {
    { sym, data, start: source.offset(a), end: source.offset(b - 1) + 1 }
  }
  while i < n {
    let c = at(i)
    if skipped(i) || c == 32 || c == 9 || c == 10 || c == 13 {
      i += 1
      continue
    }
    if c == 45 {
      out.push(tok(NotMark, "", i, i + 1))
      i += 1
    } else if literal_char(c) {
      let start = i
      while i < n && literal_char(at(i)) && !skipped(i) {
        i += 1
      }
      out.push(tok(Literal, @cst.slice(text, start, i), start, i))
    } else if c == 42 {
      out.push(tok(RepetitionSymbol, "", i, i + 1))
      i += 1
    } else if c == 40 && at(i + 1) == 42 {
      let start = i
      i += 2
      while i < n && !(at(i) == 42 && at(i + 1) == 41) {
        i += 1
      }
      let content = @cst.slice(text, start + 2, i.min(n))
      if i < n {
        i += 2
      }
      if !@envelope.trim(content).is_empty() {
        out.push(tok(CommentToken, content, start, i))
      }
    } else if c == 44 {
      out.push(tok(Concatenation, "", i, i + 1))
      i += 1
    } else if c == 124 {
      out.push(tok(Alternation, "", i, i + 1))
      i += 1
    } else if c == 61 {
      out.push(tok(Definition, "", i, i + 1))
      i += 1
    } else if c == 40 {
      out.push(tok(GroupOpen, "", i, i + 1))
      i += 1
    } else if c == 41 {
      out.push(tok(GroupClose, "", i, i + 1))
      i += 1
    } else if c == 91 {
      out.push(tok(OptionalOpen, "", i, i + 1))
      i += 1
    } else if c == 93 {
      out.push(tok(OptionalClose, "", i, i + 1))
      i += 1
    } else if c == 123 {
      out.push(tok(RepetitionOpen, "", i, i + 1))
      i += 1
    } else if c == 125 && at(i + 1) == 45 {
      out.push(tok(RepetitionMinusClose, "", i, i + 2))
      i += 2
    } else if c == 125 {
      out.push(tok(RepetitionClose, "", i, i + 1))
      i += 1
    } else if c == 59 {
      return Ok((out, i + 1))
    } else if c == 34 || c == 39 || c == 63 {
      let start = i
      i += 1
      while i < n && at(i) != c {
        i += 1
      }
      if i >= n {
        return Err({
          code: "ebnf/unterminated-string",
          message: "Unterminated string or special sequence",
          start: source.offset(start),
          end: source.offset(n - 1) + 1,
        })
      }
      let data = @cst.slice(text, start + 1, i)
      out.push(
        tok(
          if c == 34 {
            Terminal1
          } else if c == 39 {
            Terminal2
          } else {
            SpecialSeq
          },
          data,
          start,
          i + 1,
        ),
      )
      i += 1
    } else {
      return Err({
        code: "ebnf/unparsable",
        message: "Unparsable expression",
        start: source.offset(i),
        end: source.offset(i) + 1,
      })
    }
  }
  Ok((out, n))
}

///|
fn priority(sym : Sym) -> Int {
  match sym {
    RepetitionSymbol => 3
    Concatenation => 2
    _ => 1
  }
}

///|
fn operator(sym : Sym) -> Bool {
  sym == Concatenation || sym == Alternation || sym == RepetitionSymbol
}

///|
/// Order the tokens as the pinned shunting-yard reader does. `None` is the
/// syntax error that PlantUML draws as "Syntax error!".
fn shunting(tokens : ArrayView[Tok]) -> Array[Tok]? {
  let output : Array[Tok] = []
  let stack : Array[Tok] = []
  fn top_is(sym : Sym) -> Bool {
    stack.last().map(t => t.sym == sym).unwrap_or(false)
  }
  fn pop_below() -> Unit {
    let t = stack.pop().unwrap()
    output.push(if t.sym == CommentToken { { ..t, sym: CommentBelow } } else { t })
  }
  fn pop_above() -> Unit {
    let t = stack.pop().unwrap()
    output.push(if t.sym == CommentToken { { ..t, sym: CommentAbove } } else { t })
  }
  for token in tokens {
    match token.sym {
      Literal | Terminal1 | Terminal2 | SpecialSeq => {
        output.push(token)
        while top_is(CommentToken) {
          pop_above()
        }
      }
      CommentToken => stack.push(token)
      NotMark => {
        stack.push({ ..token, sym: Concatenation })
        stack.push(token)
      }
      Concatenation | Alternation | RepetitionSymbol => {
        while (stack.last() is Some(top) &&
          operator(top.sym) &&
          priority(top.sym) > priority(token.sym)) ||
          top_is(CommentToken) {
          pop_below()
        }
        stack.push(token)
      }
      GroupOpen => stack.push(token)
      GroupClose => {
        while stack.last() is Some(top) && top.sym != GroupOpen {
          pop_below()
        }
        if stack.pop() is None {
          return None
        }
      }
      OptionalOpen => stack.push({ ..token, sym: OptionalMark })
      RepetitionOpen => stack.push({ ..token, sym: ZeroMark })
      OptionalClose | RepetitionClose | RepetitionMinusClose => {
        while (stack.last() is Some(top) && operator(top.sym)) ||
          top_is(CommentToken) {
          pop_below()
        }
        guard stack.pop() is Some(first) else { return None }
        let expected = if token.sym == OptionalClose {
          OptionalMark
        } else {
          ZeroMark
        }
        if first.sym != expected {
          return None
        }
        output.push(
          if token.sym == RepetitionMinusClose {
            { ..first, sym: OneMark, end: token.end }
          } else {
            { ..first, end: token.end }
          },
        )
        while top_is(CommentToken) {
          pop_above()
        }
      }
      _ => return None
    }
  }
  while stack.pop() is Some(t) {
    match t.sym {
      OptionalMark | OneMark | ZeroMark => return None
      CommentToken => output.push({ ..t, sym: CommentBelow })
      _ => output.push(t)
    }
  }
  if output.is_empty() {
    None
  } else {
    Some(output)
  }
}

///|
priv struct Entry {
  expr : Expr
  start : Int
  end : Int
  depth : Int
}

///|
priv struct Built {
  rule : Rule
  warnings : Array[(String, String, Int, Int)]
}

///|
fn is_decimal(text : String) -> Bool {
  !text.is_empty() && text.iter().all(c => c >= '0' && c <= '9')
}

///|
/// Build one rule from its source text.
fn build_rule(
  source : Source,
  from : Int,
  skip : ArrayView[(Int, Int)],
  above : String?,
  below : String?,
  span : (Int, Int) -> @diagrams.Span,
  limits : @envelope.Limits,
) -> Result[Built, Failure] {
  let (tokens, stop) = match tokenize(source, from, skip) {
    Ok(result) => result
    Err(failure) => return Err(failure)
  }
  let whole_start = source.offset(from)
  let whole_end = source.offset(stop - 1) + 1
  fn syntax(message : String) -> Result[Built, Failure] {
    Err({ code: "ebnf/syntax", message, start: whole_start, end: whole_end })
  }
  if tokens.length() > limits.nodes {
    return Err({
      code: "ebnf/limit",
      message: "EBNF token limit exceeded",
      start: whole_start,
      end: whole_end,
    })
  }
  // Text after the terminating semicolon is ignored by PlantUML 1.2026.9.
  let rest = @envelope.trim(@cst.slice(source.text, stop.min(source.text.length()), source.text.length()))
  if !rest.is_empty() {
    return Err({
      code: "ebnf/trailing-text",
      message: "Text after the semicolon of a rule",
      start: source.offset(stop),
      end: whole_end.max(source.offset(source.text.length() - 1) + 1),
    })
  }
  guard tokens.length() >= 2 &&
    tokens[0].sym == Literal &&
    tokens[1].sym == Definition else {
    return syntax("A rule needs a name and '='")
  }
  let name = tokens[0].data
  let warnings = []
  if tokens.length() == 2 {
    return Ok({
      rule: { name, body: None, above, below, span: Some(span(whole_start, whole_end)) },
      warnings,
    })
  }
  guard shunting(tokens[2:]) is Some(postfix) else {
    return syntax("The rule has a syntax error")
  }
  let stack : Array[Entry] = []
  fn leaf(expr : Expr, t : Tok) {
    stack.push({ expr, start: t.start, end: t.end, depth: 1 })
  }
  for t in postfix {
    let s = Some(span(t.start, t.end))
    match t.sym {
      Literal => leaf(Name(t.data, no_note, s), t)
      Terminal1 => leaf(Terminal(t.data, Double, no_note, s), t)
      Terminal2 => leaf(Terminal(t.data, Single, no_note, s), t)
      SpecialSeq => leaf(Special(t.data, no_note, s), t)
      CommentAbove | CommentBelow => {
        guard stack.pop() is Some(top) else {
          return syntax("A note has no term")
        }
        let text = @envelope.trim(t.data)
        fn noted(n : Notes) -> Notes {
          if t.sym == CommentAbove {
            { ..n, above: Some(text) }
          } else {
            { ..n, below: Some(text) }
          }
        }
        let expr : Expr = match top.expr {
          Terminal(x, q, n, sp) => Terminal(x, q, noted(n), sp)
          Name(x, n, sp) => Name(x, noted(n), sp)
          Special(x, n, sp) => Special(x, noted(n), sp)
          other => {
            warnings.push(
              (
                "ebnf/dropped-note", "PlantUML 1.2026.9 shows notes only on terms; this note is not shown",
                t.start, t.end,
              ),
            )
            other
          }
        }
        stack.push({ ..top, expr, })
      }
      Alternation | Concatenation => {
        guard stack.pop() is Some(right) && stack.pop() is Some(left) else {
          return syntax("An operator has a missing operand")
        }
        let parts = []
        for item in [left, right] {
          match (t.sym, item.expr) {
            (Concatenation, Concat(items)) | (Alternation, Alt(items)) =>
              for e in items {
                parts.push(e)
              }
            _ => parts.push(item.expr)
          }
        }
        let items = ReadOnlyArray::from_array(parts)
        let depth = left.depth.max(right.depth) + 1
        if depth > limits.depth {
          return Err({
            code: "ebnf/limit",
            message: "EBNF depth limit exceeded",
            start: left.start,
            end: right.end,
          })
        }
        stack.push({
          expr: if t.sym == Concatenation { Concat(items) } else { Alt(items) },
          start: left.start.min(right.start),
          end: left.end.max(right.end),
          depth,
        })
      }
      OptionalMark | ZeroMark | OneMark | NotMark | RepetitionSymbol => {
        guard stack.pop() is Some(inner) else {
          return syntax("An operator has a missing operand")
        }
        let start = inner.start.min(t.start)
        let mut end = inner.end.max(t.end)
        let whole = Some(span(start, end))
        let expr : Expr = match t.sym {
          OptionalMark => Optional(inner.expr, whole)
          ZeroMark => ZeroOrMore(inner.expr, whole)
          OneMark => OneOrMore(inner.expr, whole)
          NotMark => Not(inner.expr, whole)
          _ => {
            guard stack.pop() is Some(count) else {
              return syntax("A repetition count is missing")
            }
            guard count.expr is Name(text, _, _) && is_decimal(text) else {
              return Err({
                code: "ebnf/invalid-count",
                message: "A repetition count must be a decimal number",
                start: count.start,
                end: count.end,
              })
            }
            end = end.max(count.end)
            Count(text, inner.expr, Some(span(count.start, end)))
          }
        }
        let depth = inner.depth + 1
        if depth > limits.depth {
          return Err({
            code: "ebnf/limit",
            message: "EBNF depth limit exceeded",
            start,
            end,
          })
        }
        stack.push({ expr, start, end, depth })
      }
      _ => return syntax("The rule has a syntax error")
    }
  }
  guard stack is [body] else { return syntax("The rule has a syntax error") }
  Ok({
    rule: {
      name,
      body: Some(body.expr),
      above,
      below,
      span: Some(span(whole_start, whole_end)),
    },
    warnings,
  })
}

///|
/// Find the last `*)` in `text` between `from` and `limit` whose comment has
/// visible text. Returns the index of `*`.
fn comment_ends(text : String, from : Int, limit : Int) -> Array[Int] {
  let ends = []
  let mut k = limit - 2
  while k >= from {
    if text.code_unit_at(k).to_int() == 42 && text.code_unit_at(k + 1).to_int() == 41 {
      if !@envelope.trim(@cst.slice(text, from, k)).is_empty() {
        ends.push(k)
      }
    }
    k -= 1
  }
  ends
}

///|
priv struct SingleRule {
  name_start : Int
  above : String?
  below : String?
  skip : Array[(Int, Int)]
}

///|
/// Match the single-line rule command on a trimmed line.
fn single_rule(text : String) -> SingleRule? {
  let n = text.length()
  if n == 0 || text.code_unit_at(n - 1).to_int() != 59 {
    return None
  }
  fn space(k : Int) -> Bool {
    k < n &&
    (text.code_unit_at(k).to_int() == 32 || text.code_unit_at(k).to_int() == 9)
  }
  fn after_name(start : Int, above : String?, skip : Array[(Int, Int)]) -> SingleRule? {
    if start >= n {
      return None
    }
    let c = text.code_unit_at(start).to_int()
    if !(letter_or_digit(c) || c == 95) {
      return None
    }
    let mut k = start
    while k < n && literal_char(text.code_unit_at(k).to_int()) {
      k += 1
    }
    let mut j = k
    while space(j) {
      j += 1
    }
    if j < n && text.code_unit_at(j).to_int() == 61 {
      return Some({ name_start: start, above, below: None, skip })
    }
    if j + 1 < n &&
      text.code_unit_at(j).to_int() == 40 &&
      text.code_unit_at(j + 1).to_int() == 42 {
      for e in comment_ends(text, j + 2, n) {
        let mut m = e + 2
        while space(m) {
          m += 1
        }
        if m < n && text.code_unit_at(m).to_int() == 61 {
          let s = skip.copy()
          s.push((j, e + 2))
          return Some({
            name_start: start,
            above,
            below: Some(@envelope.trim(@cst.slice(text, j + 2, e))),
            skip: s,
          })
        }
      }
    }
    None
  }
  if n >= 2 && text.code_unit_at(0).to_int() == 40 && text.code_unit_at(1).to_int() == 42 {
    for e in comment_ends(text, 2, n) {
      let mut m = e + 2
      while space(m) {
        m += 1
      }
      if after_name(m, Some(@envelope.trim(@cst.slice(text, 2, e))), [(0, e + 2)])
        is Some(rule) {
        return Some(rule)
      }
    }
  }
  after_name(0, None, [])
}

///|
fn multi_rule_start(text : String) -> Bool {
  let n = text.length()
  if n == 0 {
    return false
  }
  let c = text.code_unit_at(0).to_int()
  if !(letter_or_digit(c) || c == 95) {
    return false
  }
  let mut k = 0
  while k < n &&
    (letter_or_digit(text.code_unit_at(k).to_int()) || text.code_unit_at(k).to_int() == 95 ||
    text.code_unit_at(k).to_int() == 45) {
    k += 1
  }
  while k < n &&
    (text.code_unit_at(k).to_int() == 32 || text.code_unit_at(k).to_int() == 9) {
    k += 1
  }
  k < n && text.code_unit_at(k).to_int() == 61
}

///|
pub struct ReadResult {
  nodes : Array[@cst.Node]
  document : Document?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Read the body of a scanned EBNF block. Statements dispatch in the order of
/// the pinned reader: whole-line notes, multi-line notes, single-line rules
/// and multi-line rules. A rule that PlantUML draws as "Syntax error!" is an
/// error here.
pub fn read(
  scan : @envelope.Scan,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> ReadResult {
  let diagnostics = scan.diagnostics.iter().to_array()
  let lines = scan.lines
  let n = lines.length()
  let items : Array[Item_] = []
  let roles : Array[@cst.NodeKind?] = Array::make(n, None)
  fn report(code : String, message : String, start : Int, end : Int) {
    if diagnostics.length() < limits.diagnostics {
      diagnostics.push(
        @diagrams.Diagnostic::error(code, message, span=scan.span(start, end)),
      )
    }
  }
  fn body(k : Int) -> Bool {
    k < n && lines[k].role is Body
  }
  fn trimmed(k : Int) -> String {
    @envelope.trim(lines[k].text)
  }
  // The first non-trivia line at or after `k` that `test` accepts, within
  // consecutive body lines.
  fn find_end(k : Int, accept : (String) -> Bool) -> Int? {
    let mut j = k
    while j < n {
      if !body(j) {
        return None
      }
      if accept(trimmed(j)) {
        return Some(j)
      }
      j += 1
    }
    None
  }
  let mut i = 0
  while i < n {
    if !body(i) {
      i += 1
      continue
    }
    let line = lines[i]
    let t = trimmed(i)
    if t.is_empty() {
      roles[i] = Some(Blank)
      i += 1
      continue
    }
    let lead = line.text.length() - line.text.iter().drop_while(c => c == ' ' || c == '\t').count()
    // A whole-line note.
    if t.has_prefix("(*") {
      let mut close : Int? = None
      let mut k = 2
      while k + 1 < t.length() {
        if t.code_unit_at(k).to_int() == 42 && t.code_unit_at(k + 1).to_int() == 41 {
          close = Some(k)
          break
        }
        k += 1
      }
      if close is Some(c) && @envelope.trim(@cst.slice(t, c + 2, t.length())).is_empty() {
        items.push(Note_([@envelope.trim(@cst.slice(t, 2, c))], line.offset + lead, line.offset + line.text.length()))
        roles[i] = Some(Note)
        i += 1
        continue
      }
      let width = if t.has_prefix("(**") { 3 } else { 2 }
      let ending = if width == 3 {
        (s : String) => s.has_suffix("**)")
      } else {
        (s : String) => s.has_suffix("*)")
      }
      if find_end(i + 1, ending) is Some(last) {
        let notes = []
        for k in i..=last {
          let mut s = trimmed(k)
          if k == i {
            s = @cst.slice(s, width, s.length())
          }
          if k == last {
            s = @cst.slice(s, 0, (s.length() - width).max(0))
          }
          notes.push(@envelope.trim(s))
        }
        items.push(Note_(notes, line.offset + lead, lines[last].offset + lines[last].text.length()))
        for k in i..=last {
          roles[k] = Some(Note)
        }
        i = last + 1
        continue
      }
    }
    let base = line.offset + lead
    let one : Source = { text: t, offsets: Array::makei(t.length(), k => base + k) }
    match single_rule(t) {
      Some(rule) => {
        items.push(Rule_(one, rule.name_start, rule.skip, rule.above, rule.below, i))
        roles[i] = Some(Rule)
        i += 1
        continue
      }
      None => ()
    }
    if multi_rule_start(t) {
      match find_end(i, s => s.has_suffix(";")) {
        Some(last) => {
          let text = StringBuilder()
          let offsets = []
          for k in i..=last {
            let raw = lines[k]
            let lk = raw.text.length() - raw.text.iter().drop_while(c => c == ' ' || c == '\t').count()
            let s = trimmed(k)
            if k > i {
              text.write_char('\n')
              offsets.push(raw.offset)
            }
            text.write_string(s)
            for u in 0..<s.length() {
              offsets.push(raw.offset + lk + u)
            }
            roles[k] = Some(Rule)
          }
          items.push(Rule_({ text: text.to_string(), offsets }, 0, [], None, None, i))
          i = last + 1
          continue
        }
        None => ()
      }
    }
    report(
      "ebnf/syntax", "Expected a rule or a note",
      line.offset, line.offset + line.text.length(),
    )
    roles[i] = Some(Error)
    i += 1
  }
  let out_items : Array[Item] = []
  for item in items {
    match item {
      Note_(texts, a, b) =>
        out_items.push(Note(ReadOnlyArray::from_array(texts), Some(scan.span(a, b))))
      Rule_(source, from, skip, above, below, _) =>
        match build_rule(source, from, skip, above, below, (a, b) => scan.span(a, b), limits) {
          Ok(built) => {
            for w in built.warnings {
              diagnostics.push(
                @diagrams.Diagnostic::warning(w.0, w.1, span=scan.span(w.2, w.3)),
              )
            }
            out_items.push(Rule(built.rule))
          }
          Err(failure) =>
            report(failure.code, failure.message, failure.start, failure.end)
        }
    }
  }
  if out_items.is_empty() && !diagnostics.iter().any(d => d.severity == Error) {
    report(
      "ebnf/missing-rule", "An EBNF block needs a rule or a note",
      scan.source.length(), scan.source.length(),
    )
  }
  let nodes = []
  for k, line in lines {
    match line.role {
      Statement(node) => nodes.push(node)
      Continuation => ()
      Body => {
        let kind = roles[k].unwrap_or(Blank)
        let token : @cst.TokenKind = match kind {
          Note => Comment
          Error => Error
          Blank => Whitespace
          _ => Text
        }
        nodes.push(@cst.Node::new(kind, line.tokens(token)))
      }
    }
  }
  let failed = diagnostics.iter().any(d => d.severity == Error)
  {
    nodes,
    document: if failed {
      None
    } else {
      Some({ name: scan.name, statements: scan.statements, items: ReadOnlyArray::from_array(out_items) })
    },
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}

///|
priv enum Item_ {
  Note_(Array[String], Int, Int)
  Rule_(Source, Int, Array[(Int, Int)], String?, String?, Int)
}
