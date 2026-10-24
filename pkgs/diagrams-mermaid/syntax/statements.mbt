///|
/// What a statement does to the frame structure.
priv enum Event {
  Plain
  Header
  Open(String)
  Section(String)
  Close
}

///|
/// A statement that did not parse: the diagnostic code and message.
priv struct Failed {
  code : String
  message : String
}

///|
fn fail(code : String, message : String) -> Failed {
  { code: "mermaid/\{code}", message }
}

///|
/// The keywords that open a frame. `par_over` comes before `par`.
let openers : Array[String] = [
  "box", "loop", "rect", "opt", "alt", "par_over", "par", "critical", "break",
]

///|
/// The keywords that start a new section of a frame.
let sections : Array[String] = ["else", "and", "option"]

///|
/// A name in the grammar's `ID` state, after `participant`, `actor`,
/// `destroy`, `activate` and `deactivate`. With `config`, the name can have a
/// `@{...}` configuration. With `alias`, it can have `as` and a label.
fn Scanner::id_name(
  self : Scanner,
  out : Array[@cst.Element],
  config~ : Bool,
  as_label~ : Bool,
) -> Failed? {
  let start = self.pos
  let n = self.src.length()
  let bad = "<>:,;@"
  let mut e1 = start
  while e1 < n &&
        !is_hspace(self.cu(e1)) &&
        !is_newline(self.cu(e1)) &&
        !one_of(self.cu(e1), bad) {
    e1 += 1
  }
  let mut k = e1
  while is_hspace(self.cu(k)) {
    k += 1
  }
  if e1 > start && config && self.starts(k, "@{") {
    out.push(self.token(Identifier, start, e1))
    if k > e1 {
      out.push(self.token(Whitespace, e1, k))
    }
    out.push(self.token(ConfigOpen, k, k + 2))
    let mut close = k + 2
    while close < n && self.cu(close) != '}'.to_int() {
      close += 1
    }
    guard close < n && close > k + 2 else {
      return Some(fail("invalid-participant", "the configuration has no closing `}`"))
    }
    out.push(self.token(Config, k + 2, close))
    out.push(self.token(ConfigClose, close, close + 1))
    self.pos = close + 1
    if as_label {
      ignore(self.as_label(out))
    }
    return None
  }
  if e1 > start && as_label && k > e1 && self.alias_at(k) {
    out.push(self.token(Identifier, start, e1))
    self.pos = e1
    ignore(self.as_label(out))
    return None
  }
  let mut r = start
  while r < n {
    let entity = self.entity_at(r)
    if entity > 0 {
      r += entity
      continue
    }
    let c = self.cu(r)
    if is_newline(c) || one_of(c, bad) {
      break
    }
    r += 1
  }
  let c = self.cu(r)
  let p = if c == -1 || is_newline(c) || c == ';'.to_int() {
    r
  } else {
    let mut h = r - 1
    while h >= start && !(self.cu(h) == '#'.to_int() && self.entity_at(h) == 0) {
      h -= 1
    }
    if h < start {
      return Some(fail("invalid-participant", "this is not a participant name"))
    }
    h
  }
  let end = self.trim_back(start, p)
  guard end > start else {
    return Some(fail("invalid-participant", "a participant name is missing"))
  }
  out.push(self.token(Identifier, start, end))
  self.pos = end
  None
}

///|
/// True when `as` and a space or a line break are at `i`.
fn Scanner::alias_at(self : Scanner, i : Int) -> Bool {
  self.starts_ci(i, "as") &&
  (is_hspace(self.cu(i + 2)) || is_newline(self.cu(i + 2)))
}

///|
/// Take spaces, `as` and the label of an alias, when they follow.
fn Scanner::as_label(self : Scanner, out : Array[@cst.Element]) -> Bool {
  let mut k = self.pos
  while is_hspace(self.cu(k)) {
    k += 1
  }
  guard k > self.pos && self.alias_at(k) else { return false }
  out.push(self.token(Whitespace, self.pos, k))
  out.push(self.token(Keyword, k, k + 2))
  self.pos = k + 2
  self.rest_of_line(out)
  true
}

///|
/// `participant`, `actor`, `create participant` and `create actor`.
fn Scanner::participant(self : Scanner, out : Array[@cst.Element]) -> Failed? {
  if self.keyword(out, "create") {
    guard self.space(out) else {
      return Some(fail("invalid-participant", "`create` needs `participant` or `actor`"))
    }
    guard self.keyword_at(self.pos, "participant") || self.keyword_at(self.pos, "actor") else {
      return Some(fail("invalid-participant", "`create` needs `participant` or `actor`"))
    }
  }
  ignore(self.keyword(out, "participant") || self.keyword(out, "actor"))
  guard self.space(out) else {
    return Some(fail("invalid-participant", "a participant name is missing"))
  }
  self.id_name(out, config=true, as_label=true)
}

///|
/// `destroy`, `activate` or `deactivate` and a name.
fn Scanner::id_statement(
  self : Scanner,
  out : Array[@cst.Element],
  word : String,
) -> Failed? {
  ignore(self.keyword(out, word))
  guard self.space(out) else {
    return Some(fail("invalid-participant", "`\{word}` needs a participant name"))
  }
  self.id_name(out, config=false, as_label=false)
}

///|
/// `note`, a placement, one or two names, and a text.
fn Scanner::note(self : Scanner, out : Array[@cst.Element]) -> Failed? {
  let bad = fail(
    "invalid-note", "a note is `note left of A: text`, `note right of A: text` or `note over A[,B]: text`",
  )
  ignore(self.keyword(out, "note"))
  guard self.space(out) else { return Some(bad) }
  let over = if self.starts_ci(self.pos, "left of") ||
    self.starts_ci(self.pos, "right of") {
    let len = if self.starts_ci(self.pos, "left of") { 7 } else { 8 }
    guard !is_word(self.cu(self.pos + len)) else { return Some(bad) }
    out.push(self.token(Keyword, self.pos, self.pos + len))
    self.pos += len
    false
  } else if self.keyword(out, "over") {
    true
  } else {
    return Some(bad)
  }
  ignore(self.space(out))
  guard self.name(out) else { return Some(bad) }
  ignore(self.space(out))
  if self.cu(self.pos) == ','.to_int() {
    guard over else { return Some(bad) }
    out.push(self.token(Comma, self.pos, self.pos + 1))
    self.pos += 1
    ignore(self.space(out))
    guard self.name(out) else { return Some(bad) }
  }
  guard self.colon_text(out) else { return Some(bad) }
  None
}

///|
/// `link`, `links`, `properties` or `details`, a name and a text.
fn Scanner::link(
  self : Scanner,
  out : Array[@cst.Element],
  word : String,
) -> Failed? {
  let bad = fail("invalid-link", "`\{word}` needs a participant name, `:` and a text")
  ignore(self.keyword(out, word))
  ignore(self.space(out))
  guard self.name(out) else { return Some(bad) }
  guard self.colon_text(out) else { return Some(bad) }
  None
}

///|
/// True when `word` at `i` is the start of a `link`-like statement: it is
/// followed by spaces and a character that can start a name.
fn Scanner::link_at(self : Scanner, i : Int, word : String) -> Bool {
  guard self.keyword_at(i, word) else { return false }
  let mut k = i + word.length()
  guard is_hspace(self.cu(k)) else { return false }
  while is_hspace(self.cu(k)) {
    k += 1
  }
  let c = self.cu(k)
  c != -1 && !is_newline(c) && !one_of(c, "/\\+()<>:,;-")
}

///|
/// `title text` or `title: text`.
fn Scanner::title(self : Scanner, out : Array[@cst.Element]) -> Failed? {
  let bad = fail("invalid-title", "a title needs a text")
  ignore(self.keyword(out, "title"))
  if self.cu(self.pos) == ':'.to_int() {
    out.push(self.token(Colon, self.pos, self.pos + 1))
    self.pos += 1
  }
  guard self.space(out) else { return Some(bad) }
  let end = self.text_end(self.pos)
  guard self.trim_back(self.pos, end) > self.pos else { return Some(bad) }
  self.text_to(out, end)
  None
}

///|
/// `accTitle: text`, `accDescr: text` or `accDescr { text }`. The text of
/// the one-line forms goes to the end of the line.
fn Scanner::accessibility(
  self : Scanner,
  out : Array[@cst.Element],
  word : String,
) -> Failed? {
  out.push(self.token(Keyword, self.pos, self.pos + word.length()))
  self.pos += word.length()
  ignore(self.space(out))
  if self.cu(self.pos) == '{'.to_int() {
    let open = self.pos
    out.push(self.token(OpenBrace, open, open + 1))
    let mut close = open + 1
    while close < self.src.length() && self.cu(close) != '}'.to_int() {
      close += 1
    }
    if close > open + 1 {
      out.push(self.token(Text, open + 1, close))
    }
    if close >= self.src.length() {
      self.pos = close
      self.error(
        "mermaid/unclosed-description", "the description has no closing `}`",
        open,
        open + 1,
      )
      return None
    }
    out.push(self.token(CloseBrace, close, close + 1))
    self.pos = close + 1
    return None
  }
  out.push(self.token(Colon, self.pos, self.pos + 1))
  self.pos += 1
  ignore(self.space(out))
  self.text_to(out, self.line_end(self.pos))
  None
}

///|
/// True when `accTitle` or `accDescr` at `i` starts its statement.
fn Scanner::accessibility_at(self : Scanner, i : Int, word : String) -> Bool {
  guard self.starts_ci(i, word) else { return false }
  let mut k = i + word.length()
  while is_hspace(self.cu(k)) {
    k += 1
  }
  self.cu(k) == ':'.to_int() ||
  (word == "accDescr" && self.cu(k) == '{'.to_int())
}

///|
/// A number of `autonumber` at the cursor, as the grammar's `NUM`.
fn Scanner::number(self : Scanner, out : Array[@cst.Element]) -> Bool {
  let start = self.pos
  let mut i = start
  while is_digit(self.cu(i)) {
    i += 1
  }
  let whole = i > start
  if self.cu(i) == '.'.to_int() && is_digit(self.cu(i + 1)) {
    i += 2
    if is_digit(self.cu(i)) {
      i += 1
    }
  } else if !whole {
    return false
  }
  let after = self.cu(i)
  guard after == -1 || is_hspace(after) || is_newline(after) else { return false }
  out.push(self.token(Number, start, i))
  self.pos = i
  true
}

///|
/// `autonumber`, `autonumber N`, `autonumber N M` or `autonumber off`.
fn Scanner::autonumber(self : Scanner, out : Array[@cst.Element]) -> Failed? {
  ignore(self.keyword(out, "autonumber"))
  let save = self.pos
  let mark = out.length()
  if self.space(out) {
    if self.keyword(out, "off") {
      ()
    } else if self.number(out) {
      let save2 = self.pos
      let mark2 = out.length()
      if !(self.space(out) && self.number(out)) {
        self.pos = save2
        out.truncate(mark2)
      }
    } else {
      self.pos = save
      out.truncate(mark)
    }
  }
  let mut k = self.pos
  while is_hspace(self.cu(k)) {
    k += 1
  }
  let c = self.cu(k)
  guard c == -1 || is_newline(c) || c == ';'.to_int() || self.comment_at(k) else {
    return Some(fail("invalid-autonumber", "`autonumber` takes a start, a step, or `off`"))
  }
  None
}

///|
/// A message: a sender, an arrow with its modifiers, a receiver and a text.
fn Scanner::message(self : Scanner, out : Array[@cst.Element]) -> Failed? {
  let unknown = fail("unknown-statement", "this is not a sequence diagram statement")
  guard self.name(out) else { return Some(unknown) }
  ignore(self.space(out))
  let pre = self.starts(self.pos, "()")
  if pre {
    out.push(self.token(Modifier, self.pos, self.pos + 2))
    self.pos += 2
    ignore(self.space(out))
  }
  guard self.arrow_at(self.pos) is Some(arrow) else { return Some(unknown) }
  out.push(self.token(Arrow, self.pos, self.pos + arrow.length()))
  self.pos += arrow.length()
  ignore(self.space(out))
  if self.starts(self.pos, "()") {
    out.push(self.token(Modifier, self.pos, self.pos + 2))
    self.pos += 2
  } else if !pre &&
    (self.cu(self.pos) == '+'.to_int() || self.cu(self.pos) == '-'.to_int()) {
    out.push(self.token(Modifier, self.pos, self.pos + 1))
    self.pos += 1
  }
  ignore(self.space(out))
  guard self.name(out) else {
    return Some(fail("invalid-message", "the message has no receiver"))
  }
  guard self.colon_text(out) else {
    return Some(fail("missing-message-text", "a message needs `:` and a text"))
  }
  None
}

///|
/// Read one statement at the cursor. Gives the node kind, the frame event, and
/// the failure when the statement did not parse.
fn Scanner::statement(
  self : Scanner,
  out : Array[@cst.Element],
) -> (@cst.NodeKind, Event, Failed?) {
  let i = self.pos
  if self.keyword(out, "sequenceDiagram") {
    return (Header, Header, None)
  }
  if self.keyword_at(i, "participant") ||
    self.keyword_at(i, "actor") ||
    self.keyword_at(i, "create") {
    return (Participant, Plain, self.participant(out))
  }
  for pair in [
    ("destroy", @cst.NodeKind::Destroy),
    ("activate", Activate),
    ("deactivate", Deactivate),
  ] {
    if self.keyword_at(i, pair.0) {
      return (pair.1, Plain, self.id_statement(out, pair.0))
    }
  }
  for word in openers {
    if self.keyword(out, word) {
      self.rest_of_line(out)
      return (BlockStart, Open(word), None)
    }
  }
  for word in sections {
    if self.keyword(out, word) {
      self.rest_of_line(out)
      return (Section, Section(word), None)
    }
  }
  if self.keyword(out, "end") {
    return (BlockEnd, Close, None)
  }
  if self.keyword_at(i, "note") {
    return (Note, Plain, self.note(out))
  }
  for pair in [
    ("links", @cst.NodeKind::Links),
    ("link", Link),
    ("properties", Properties),
    ("details", Details),
  ] {
    if self.link_at(i, pair.0) {
      return (pair.1, Plain, self.link(out, pair.0))
    }
  }
  if self.keyword_at(i, "title") &&
    (is_hspace(self.cu(i + 5)) || self.cu(i + 5) == ':'.to_int()) {
    return (Title, Plain, self.title(out))
  }
  if self.accessibility_at(i, "accTitle") {
    return (AccTitle, Plain, self.accessibility(out, "accTitle"))
  }
  if self.accessibility_at(i, "accDescr") {
    return (AccDescr, Plain, self.accessibility(out, "accDescr"))
  }
  if self.keyword_at(i, "autonumber") {
    return (Autonumber, Plain, self.autonumber(out))
  }
  (Message, Plain, self.message(out))
}
