///|
priv enum Tok {
  LParen
  RParen
  LBracket
  RBracket
  Colon
  Bang
  Dot
  Quantifier
  Capture(String)
  Hash(String)
  Ident(String)
  Qualified(String, String)
  Str(String)
  End
}

///|
priv struct Token {
  tok : Tok
  start : Int
  end : Int
}

///|
priv suberror ParseError {
  ParseError(String, String, Int, Int)
}

///|
fn String::code_unit_at_int(self : String, i : Int) -> Int {
  self.code_unit_at(i).to_int()
}

///|
fn is_name_start(unit : Int) -> Bool {
  (unit >= 'a' && unit <= 'z') || (unit >= 'A' && unit <= 'Z') || unit == '_'
}

///|
fn is_name_unit(unit : Int) -> Bool {
  is_name_start(unit) || (unit >= '0' && unit <= '9') || unit == '-'
}

///|
fn is_space(unit : Int) -> Bool {
  unit == ' ' || unit == '\t' || unit == '\n' || unit == '\r'
}

///|
/// True when `text` is a version 1 identifier.
pub fn is_identifier(text : String) -> Bool {
  text.length() > 0 &&
  is_name_start(text.code_unit_at_int(0)) &&
  text.iter().all(c => c.to_int() < 128 && is_name_unit(c.to_int()))
}

///|
/// True when `text` is a valid capture name (an identifier that may also
/// contain dots after its first character).
pub fn is_capture_name(text : String) -> Bool {
  text.length() > 0 &&
  is_name_start(text.code_unit_at_int(0)) &&
  text.iter().all(c => c.to_int() < 128 && (is_name_unit(c.to_int()) || c == '.'))
}

///|
priv struct Lexer {
  source : String
  mut at : Int
}

///|
fn Lexer::unit(self : Lexer, i : Int) -> Int {
  if i < self.source.length() {
    self.source.code_unit_at_int(i)
  } else {
    -1
  }
}

///|
fn Lexer::name_end(self : Lexer, start : Int, dots : Bool) -> Int {
  let mut i = start
  while is_name_unit(self.unit(i)) || (dots && self.unit(i) == '.') {
    i += 1
  }
  i
}

///|
fn Lexer::string(self : Lexer, start : Int) -> Token raise ParseError {
  let buffer = StringBuilder()
  let mut i = start + 1
  while true {
    let unit = self.unit(i)
    if unit == -1 {
      raise ParseError(
        "query/unterminated-string",
        "The string has no closing quote.",
        start,
        i,
      )
    }
    if unit == '"' {
      return { tok: Str(buffer.to_string()), start, end: i + 1 }
    }
    if unit < 0x20 {
      raise ParseError(
        "query/invalid-string",
        "A string cannot contain an unescaped control character.",
        i,
        i + 1,
      )
    }
    if unit != '\\' {
      buffer.write_char(Int::unsafe_to_char(unit))
      i += 1
      continue
    }
    let escape = self.unit(i + 1)
    let simple = match escape {
      '"' => Some('"')
      '\\' => Some('\\')
      '/' => Some('/')
      'b' => Some('\b')
      'f' => Some('\u{0C}')
      'n' => Some('\n')
      'r' => Some('\r')
      't' => Some('\t')
      _ => None
    }
    if simple is Some(c) {
      buffer.write_char(c)
      i += 2
      continue
    }
    guard escape == 'u' else {
      raise ParseError(
        "query/invalid-string",
        "The string has an invalid escape.",
        i,
        i + 2,
      )
    }
    let mut value = 0
    for k in 0..<4 {
      let digit = self.unit(i + 2 + k)
      let v = if digit >= '0' && digit <= '9' {
        digit - '0'
      } else if digit >= 'a' && digit <= 'f' {
        digit - 'a' + 10
      } else if digit >= 'A' && digit <= 'F' {
        digit - 'A' + 10
      } else {
        raise ParseError(
          "query/invalid-string",
          "A \\u escape needs four hexadecimal digits.",
          i,
          i + 2 + k,
        )
      }
      value = value * 16 + v
    }
    buffer.write_char(Int::unsafe_to_char(value))
    i += 6
  }
  panic()
}

///|
fn Lexer::next(self : Lexer) -> Token raise ParseError {
  while true {
    let unit = self.unit(self.at)
    if is_space(unit) {
      self.at += 1
    } else if unit == ';' {
      while self.unit(self.at) != -1 &&
            self.unit(self.at) != '\n' &&
            self.unit(self.at) != '\r' {
        self.at += 1
      }
    } else {
      break
    }
  }
  let start = self.at
  let unit = self.unit(start)
  let single = match unit {
    -1 => Some(Tok::End)
    '(' => Some(LParen)
    ')' => Some(RParen)
    '[' => Some(LBracket)
    ']' => Some(RBracket)
    ':' => Some(Colon)
    '!' => Some(Bang)
    '.' => Some(Dot)
    '*' | '+' | '?' => Some(Quantifier)
    _ => None
  }
  if single is Some(tok) {
    let end = if unit == -1 { start } else { start + 1 }
    self.at = end
    return { tok, start, end }
  }
  let token = if unit == '"' {
    self.string(start)
  } else if unit == '@' {
    guard is_name_start(self.unit(start + 1)) else {
      raise ParseError(
        "query/invalid-name",
        "A capture name must start with a letter or an underscore.",
        start,
        start + 1,
      )
    }
    let end = self.name_end(start + 1, true)
    { tok: Capture(self.source.view(start_offset=start + 1, end_offset=end).to_owned()), start, end }
  } else if unit == '#' {
    let mut end = self.name_end(start + 1, false)
    if self.unit(end) == '?' || self.unit(end) == '!' {
      end += 1
    }
    { tok: Hash(self.source.view(start_offset=start + 1, end_offset=end).to_owned()), start, end }
  } else if is_name_start(unit) {
    let end = self.name_end(start, false)
    let first = self.source.view(start_offset=start, end_offset=end).to_owned()
    if self.unit(end) == '.' && is_name_start(self.unit(end + 1)) {
      let local_end = self.name_end(end + 1, false)
      if self.unit(local_end) == '.' && is_name_start(self.unit(local_end + 1)) {
        raise ParseError(
          "query/invalid-name",
          "A qualified name has exactly one prefix.",
          start,
          self.name_end(local_end + 1, true),
        )
      }
      let local_name = self.source
        .view(start_offset=end + 1, end_offset=local_end).to_owned()
      { tok: Qualified(first, local_name), start, end: local_end }
    } else {
      { tok: Ident(first), start, end }
    }
  } else if (unit >= '0' && unit <= '9') || unit == '-' {
    raise ParseError(
      "query/invalid-name",
      "A name must start with a letter or an underscore.",
      start,
      self.name_end(start, true),
    )
  } else {
    let width = if unit >= 0xD800 && unit <= 0xDBFF { 2 } else { 1 }
    raise ParseError(
      "query/syntax",
      "Unexpected character.",
      start,
      start + width,
    )
  }
  self.at = token.end
  token
}

///|
priv struct Parser {
  tokens : Array[Token]
  mut at : Int
  spans : Array[(Int, Int)]
  limits : CompileLimits
  mut depth : Int
  mut nodes : Int
  mut captures : Int
  mut predicates : Int
  mut last_end : Int
}

///|
fn Parser::peek(self : Parser, ahead? : Int = 0) -> Token {
  let i = self.at + ahead
  if i < self.tokens.length() {
    self.tokens[i]
  } else {
    self.tokens[self.tokens.length() - 1]
  }
}

///|
fn Parser::take(self : Parser) -> Token {
  let token = self.peek()
  if self.at < self.tokens.length() - 1 {
    self.at += 1
  }
  self.last_end = token.end
  token
}

///|
fn Parser::reserve(self : Parser) -> Int {
  self.spans.push((0, 0))
  self.spans.length() - 1
}

///|
fn Parser::fail(self : Parser, token : Token, what : String) -> ParseError {
  ignore(self)
  match token.tok {
    End =>
      ParseError("query/syntax", "The query ends early; expected \{what}.", token.start, token.end)
    Quantifier =>
      ParseError(
        "query/unsupported-quantifier", "Quantifiers are not supported in query version 1.",
        token.start, token.end,
      )
    Dot =>
      ParseError(
        "query/unsupported-anchor", "Anchors are not supported in query version 1.", token.start,
        token.end,
      )
    Str(_) =>
      ParseError(
        "query/unsupported-anonymous-node", "Anonymous string nodes are not supported in query version 1.",
        token.start, token.end,
      )
    _ => ParseError("query/syntax", "Unexpected token; expected \{what}.", token.start, token.end)
  }
}

///|
fn Parser::expect(self : Parser, tok : Tok, what : String) -> Token raise ParseError {
  let token = self.peek()
  let same = match (token.tok, tok) {
    (RParen, RParen) | (RBracket, RBracket) | (Colon, Colon) => true
    _ => false
  }
  guard same else { raise self.fail(token, what) }
  self.take()
}

///|
fn Parser::enter(self : Parser, token : Token) -> Unit raise ParseError {
  self.depth += 1
  self.nodes += 1
  if self.depth > self.limits.nesting {
    raise ParseError(
      "query/nesting-limit", "The pattern nesting exceeds the compile limit.", token.start, token.end,
    )
  }
  if self.nodes > self.limits.pattern_nodes {
    raise ParseError(
      "query/pattern-limit", "The number of patterns exceeds the compile limit.", token.start,
      token.end,
    )
  }
}

///|
/// captured := node capture*
fn Parser::captured(self : Parser) -> Pattern raise ParseError {
  let open = self.peek()
  let slot = self.reserve()
  let pattern = match open.tok {
    LParen => {
      self.enter(open)
      self.take() |> ignore
      let selector_token = self.take()
      self.spans.push((selector_token.start, selector_token.end))
      let selector = match selector_token.tok {
        Ident("_") => Selector::Wildcard
        Ident(name) => Kind(QName::new(name))
        Qualified("category", name) => Category(name)
        Qualified(prefix, name) => Kind(QName::new(name, prefix~))
        Hash(_) =>
          raise ParseError(
            "query/syntax", "A predicate needs a pattern before it.", selector_token.start,
            selector_token.end,
          )
        LParen | LBracket =>
          raise ParseError(
            "query/unsupported-grouping", "Sibling groups are not supported in query version 1.",
            open.start, selector_token.end,
          )
        _ => raise self.fail(selector_token, "a kind, category or _")
      }
      let parts : Array[Part] = []
      while true {
        let token = self.peek()
        match token.tok {
          RParen => break
          LParen | LBracket => parts.push(Child(self.captured()))
          Bang => {
            self.take() |> ignore
            let name_token = self.take()
            self.spans.push((name_token.start, name_token.end))
            parts.push(Absent(self.field_name(name_token)))
          }
          Ident(_) | Qualified(_, _) if self.peek(ahead=1).tok is Colon => {
            let name_token = self.take()
            self.take() |> ignore
            self.spans.push((name_token.start, name_token.end))
            let field = self.field_name(name_token)
            let next = self.peek()
            guard next.tok is (LParen | LBracket) else {
              raise self.fail(next, "a pattern after the field name")
            }
            parts.push(Field(field, self.captured()))
          }
          Ident("_") =>
            raise ParseError(
              "query/syntax", "Write the wildcard child as (_).", token.start, token.end,
            )
          _ => raise self.fail(token, "a child pattern, field or )")
        }
      }
      let close = self.expect(RParen, ")")
      self.spans[slot] = (open.start, close.end)
      self.depth -= 1
      Pattern::node(selector, parts~)
    }
    LBracket => {
      self.enter(open)
      self.take() |> ignore
      let branches : Array[Pattern] = []
      while !(self.peek().tok is RBracket) {
        let token = self.peek()
        guard token.tok is (LParen | LBracket) else {
          raise self.fail(token, "an alternative pattern or ]")
        }
        branches.push(self.captured())
      }
      let close = self.expect(RBracket, "]")
      if branches.is_empty() {
        raise ParseError(
          "query/syntax", "An alternation needs at least one pattern.", open.start, close.end,
        )
      }
      self.spans[slot] = (open.start, close.end)
      self.depth -= 1
      Pattern::alternation(branches)
    }
    _ => raise self.fail(open, "( or [")
  }
  if self.peek().tok is Quantifier {
    raise self.fail(self.peek(), "")
  }
  let captures : Array[String] = []
  while self.peek().tok is Capture(name) {
    let token = self.take()
    self.captures += 1
    if self.captures > self.limits.captures {
      raise ParseError(
        "query/capture-limit", "The number of captures exceeds the compile limit.", token.start,
        token.end,
      )
    }
    self.spans.push((token.start, token.end))
    captures.push(name)
  }
  if self.peek().tok is Quantifier {
    raise self.fail(self.peek(), "")
  }
  match pattern {
    Node(selector, parts, _) => Node(selector, parts, ReadOnlyArray::from_array(captures))
    Alternation(branches, _) => Alternation(branches, ReadOnlyArray::from_array(captures))
  }
}

///|
fn Parser::field_name(self : Parser, token : Token) -> QName raise ParseError {
  match token.tok {
    Ident("_") => raise self.fail(token, "a field name")
    Ident(name) => QName::new(name)
    Qualified("category", _) =>
      raise ParseError(
        "query/syntax", "category is not a field prefix.", token.start, token.end,
      )
    Qualified(prefix, name) => QName::new(name, prefix~)
    _ => raise self.fail(token, "a field name")
  }
}

///|
/// Gives the stable diagnostic of a predicate name that version 1 refuses.
fn unsupported_predicate(name : String) -> (String, String)? {
  if name.has_suffix("!") {
    return Some(
      ("query/unsupported-directive", "Directives are not supported in query version 1."),
    )
  }
  let regex = [
    "match?", "not-match?", "any-match?", "any-not-match?", "lua-match?", "vim-match?",
  ]
  if regex.contains(name) {
    return Some(
      (
        "query/unsupported-regex", "Regular-expression predicates are not supported in query version 1.",
      ),
    )
  }
  None
}

///|
/// predicate := '(' '#' name capture string* ')'
fn Parser::predicate(self : Parser) -> Predicate raise ParseError {
  let open = self.take()
  let slot = self.reserve()
  let name_token = self.take()
  guard name_token.tok is Hash(name) else {
    raise ParseError(
      "query/unsupported-grouping", "Sibling groups are not supported in query version 1.", open.start,
      name_token.end,
    )
  }
  if unsupported_predicate(name) is Some((code, message)) {
    raise ParseError(code, message, open.start, name_token.end)
  }
  let capture_token = self.take()
  guard capture_token.tok is Capture(capture) else {
    raise ParseError(
      "query/predicate-arity", "A predicate needs a capture as its first operand.", name_token.start,
      capture_token.end,
    )
  }
  let operands : Array[String] = []
  while self.peek().tok is Str(value) {
    self.take() |> ignore
    operands.push(value)
  }
  let close = self.peek()
  guard close.tok is RParen else {
    match close.tok {
      Capture(_) =>
        raise ParseError(
          "query/predicate-arity", "Predicate operands after the capture must be strings.",
          close.start, close.end,
        )
      _ => raise self.fail(close, "a string or )")
    }
  }
  self.take() |> ignore
  self.predicates += 1 + operands.length()
  if self.predicates > self.limits.predicates {
    raise ParseError(
      "query/pattern-limit", "The number of predicates exceeds the compile limit.", open.start,
      close.end,
    )
  }
  self.spans[slot] = (open.start, close.end)
  Predicate::new(name, capture, operands~)
}

///|
/// rule := captured | '(' captured predicate+ ')'
fn Parser::rule(self : Parser, index : Int) -> Rule raise ParseError {
  let open = self.peek()
  if index >= self.limits.patterns {
    raise ParseError(
      "query/pattern-limit", "The number of patterns exceeds the compile limit.", open.start,
      open.end,
    )
  }
  let slot = self.reserve()
  let grouped = open.tok is LParen && self.peek(ahead=1).tok is (LParen | LBracket)
  if !grouped {
    let pattern = self.captured()
    self.spans[slot] = (open.start, self.last_end)
    return Rule::new(pattern)
  }
  self.take() |> ignore
  let pattern = self.captured()
  let predicates : Array[Predicate] = []
  while self.peek().tok is LParen {
    predicates.push(self.predicate())
  }
  let close = self.peek()
  guard close.tok is RParen else { raise self.fail(close, "a predicate or )") }
  if predicates.is_empty() {
    raise ParseError(
      "query/unsupported-grouping", "Sibling groups are not supported in query version 1; a parenthesized pattern needs predicates.",
      open.start, close.end,
    )
  }
  self.take() |> ignore
  self.spans[slot] = (open.start, close.end)
  Rule::new(pattern, predicates~)
}

///|
/// Parses version 1 query text into its typed form, without schema checks.
/// The form keeps source spans for the diagnostics of `compile_form`.
pub fn parse(
  source : String,
  limits? : CompileLimits = CompileLimits::new(),
) -> Result[QueryForm, ReadOnlyArray[QueryDiagnostic]] {
  if !limits.valid() {
    return Err([invalid_limits()])
  }
  let lines = LineMap::new(source)
  if source.length() > limits.source_units {
    return Err([
      error(
        "query/source-limit",
        "The query text exceeds the compile limit.",
        Some(lines.span(limits.source_units, source.length())),
      ),
    ])
  }
  let lexer = Lexer::{ source, at: 0 }
  let parser = Parser::{
    tokens: [],
    at: 0,
    spans: [],
    limits,
    depth: 0,
    nodes: 0,
    captures: 0,
    predicates: 0,
    last_end: 0,
  }
  let result = try {
    while true {
      let token = lexer.next()
      parser.tokens.push(token)
      if token.tok is End {
        break
      }
    }
    let rules : Array[Rule] = []
    while !(parser.peek().tok is End) {
      rules.push(parser.rule(rules.length()))
    }
    if rules.is_empty() {
      raise ParseError("query/empty-query", "The query has no pattern.", 0, source.length())
    }
    rules
  } catch {
    ParseError(code, message, start, end) =>
      return Err([error(code, message, Some(lines.span(start, end)))])
  }
  Ok({
    rules: ReadOnlyArray::from_array(result),
    spans: ReadOnlyArray::from_array(parser.spans.map(s => lines.span(s.0, s.1))),
  })
}

///|
fn invalid_limits() -> QueryDiagnostic {
  error("query/invalid-limits", "Every compile limit must be positive and nesting at most 1000.", None)
}
