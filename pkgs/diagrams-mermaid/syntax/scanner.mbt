///|
/// The arrows of the Mermaid 12.2.0 sequence grammar. The scanner takes the
/// longest arrow that matches.
pub let arrows : ReadOnlyArray[String] = [
  "->>", "<<->>", "-->>", "<<-->>", "->", "-->", "-x", "--x", "-)", "--)", "--|\\",
  "--|/", "--\\\\", "--//", "/|--", "\\|--", "//--", "\\\\--", "-|\\", "-|/", "-\\\\",
  "-//", "/|-", "\\|-", "//-", "\\\\-",
]

///|
/// The texts after which a participant name in a message cannot go on, from
/// the `ACTOR` rule of the grammar.
let name_stops : Array[String] = [
  "-x", "--x", "-)", "--)", "-|\\", "-\\", "-/", "-//", "-|/", "/|-", "\\|-", "//-",
  "\\\\-", "--|\\", "--", "()",
]

///|
/// A cursor over the whole source. It makes tokens with UTF-16 offsets.
priv struct Scanner {
  src : String
  mut pos : Int
  diagnostics : Array[@diagrams.Diagnostic]
}

///|
fn Scanner::new(src : String) -> Scanner {
  { src, pos: 0, diagnostics: [] }
}

///|
fn Scanner::at_end(self : Scanner) -> Bool {
  self.pos >= self.src.length()
}

///|
/// The code unit at `i`, or -1 after the end.
fn Scanner::cu(self : Scanner, i : Int) -> Int {
  if i >= 0 && i < self.src.length() {
    self.src.at(i).to_int()
  } else {
    -1
  }
}

///|
fn Scanner::slice(self : Scanner, start : Int, end : Int) -> String {
  self.src.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn Scanner::token(
  self : Scanner,
  kind : @cst.TokenKind,
  start : Int,
  end : Int,
) -> @cst.Element {
  Token(@cst.Token::new(kind, self.slice(start, end), start))
}

///|
fn Scanner::error(
  self : Scanner,
  code : String,
  message : String,
  start : Int,
  end : Int,
) -> Unit {
  self.diagnostics.push(
    @diagrams.Diagnostic::error(code, message, span=@cst.span(self.src, start, end)),
  )
}

///|
fn is_hspace(c : Int) -> Bool {
  c == ' '.to_int() || c == '\t'.to_int() || c == 0x0b || c == 0x0c
}

///|
fn is_newline(c : Int) -> Bool {
  c == '\n'.to_int() || c == '\r'.to_int()
}

///|
fn is_word(c : Int) -> Bool {
  (c >= 'a'.to_int() && c <= 'z'.to_int()) ||
  (c >= 'A'.to_int() && c <= 'Z'.to_int()) ||
  (c >= '0'.to_int() && c <= '9'.to_int()) ||
  c == '_'.to_int()
}

///|
fn is_digit(c : Int) -> Bool {
  c >= '0'.to_int() && c <= '9'.to_int()
}

///|
fn lower(c : Int) -> Int {
  if c >= 'A'.to_int() && c <= 'Z'.to_int() {
    c + 32
  } else {
    c
  }
}

///|
fn one_of(c : Int, chars : String) -> Bool {
  for i in 0..<chars.length() {
    if chars.at(i).to_int() == c {
      return true
    }
  }
  false
}

///|
/// True when the source at `i` starts with `word`.
fn Scanner::starts(self : Scanner, i : Int, word : String) -> Bool {
  i >= 0 && self.src.view(start_offset=i).has_prefix(word)
}

///|
/// True when the source at `i` starts with `word`, without regard to ASCII
/// letter case.
fn Scanner::starts_ci(self : Scanner, i : Int, word : String) -> Bool {
  if i + word.length() > self.src.length() {
    return false
  }
  for k in 0..<word.length() {
    if lower(self.cu(i + k)) != lower(word.at(k).to_int()) {
      return false
    }
  }
  true
}

///|
/// True when the keyword `word` is at `i`: the text matches without regard to
/// case, and no word character follows it.
fn Scanner::keyword_at(self : Scanner, i : Int, word : String) -> Bool {
  self.starts_ci(i, word) && !is_word(self.cu(i + word.length()))
}

///|
/// The length of an entity code such as `#9829;` or `#infin;` at `i`, or 0.
/// Mermaid encodes these codes before it parses, so a `#` or `;` in them does
/// not start a comment or end a statement.
fn Scanner::entity_at(self : Scanner, i : Int) -> Int {
  guard self.cu(i) == '#'.to_int() else { return 0 }
  let mut j = i + 1
  while is_word(self.cu(j)) {
    j += 1
  }
  if j > i + 1 && self.cu(j) == ';'.to_int() {
    j + 1 - i
  } else {
    0
  }
}

///|
/// True when a comment starts at `i`: `%%` that is not a directive, or `#`
/// that is not an entity code.
fn Scanner::comment_at(self : Scanner, i : Int) -> Bool {
  (self.starts(i, "%%") && !self.starts(i, "%%{")) ||
  (self.cu(i) == '#'.to_int() && self.entity_at(i) == 0)
}

///|
/// The offset of the end of the line that `i` is on, before its line break.
fn Scanner::line_end(self : Scanner, i : Int) -> Int {
  let mut j = i
  while j < self.src.length() && !is_newline(self.cu(j)) {
    j += 1
  }
  j
}

///|
/// `end` moved back over spaces and tabs, but not before `start`.
fn Scanner::trim_back(self : Scanner, start : Int, end : Int) -> Int {
  let mut e = end
  while e > start && is_hspace(self.cu(e - 1)) {
    e -= 1
  }
  e
}

///|
/// The end of a text that stops at a comment, a semicolon or a line break.
/// Entity codes are part of the text.
fn Scanner::text_end(self : Scanner, i : Int) -> Int {
  let mut j = i
  while j < self.src.length() {
    let c = self.cu(j)
    let entity = self.entity_at(j)
    if entity > 0 {
      j += entity
    } else if is_newline(c) || c == ';'.to_int() || c == '#'.to_int() {
      break
    } else {
      j += 1
    }
  }
  j
}

///|
/// Take spaces and tabs at the cursor as one whitespace token.
fn Scanner::space(self : Scanner, out : Array[@cst.Element]) -> Bool {
  let start = self.pos
  while is_hspace(self.cu(self.pos)) {
    self.pos += 1
  }
  guard self.pos > start else { return false }
  out.push(self.token(Whitespace, start, self.pos))
  true
}

///|
/// Take the keyword `word` at the cursor.
fn Scanner::keyword(
  self : Scanner,
  out : Array[@cst.Element],
  word : String,
) -> Bool {
  guard self.keyword_at(self.pos, word) else { return false }
  out.push(self.token(Keyword, self.pos, self.pos + word.length()))
  self.pos += word.length()
  true
}

///|
/// Take a text token from the cursor to `end`, without the spaces at its end.
/// An empty text gives no token.
fn Scanner::text_to(
  self : Scanner,
  out : Array[@cst.Element],
  end : Int,
) -> Unit {
  let e = self.trim_back(self.pos, end)
  if e > self.pos {
    out.push(self.token(Text, self.pos, e))
    self.pos = e
  }
}

///|
/// The rest of a frame line, as the grammar's `restOfLine`: spaces, then a
/// text up to a comment, a semicolon or a line break.
fn Scanner::rest_of_line(self : Scanner, out : Array[@cst.Element]) -> Unit {
  ignore(self.space(out))
  if self.comment_at(self.pos) {
    return
  }
  self.text_to(out, self.text_end(self.pos))
}

///|
/// A message or note text: optional spaces, `:`, then a text up to a comment,
/// a semicolon or a line break. The text can be empty.
fn Scanner::colon_text(self : Scanner, out : Array[@cst.Element]) -> Bool {
  let save = self.pos
  let mark = out.length()
  ignore(self.space(out))
  guard self.cu(self.pos) == ':'.to_int() else {
    self.pos = save
    out.truncate(mark)
    return false
  }
  out.push(self.token(Colon, self.pos, self.pos + 1))
  self.pos += 1
  ignore(self.space(out))
  self.text_to(out, self.text_end(self.pos))
  true
}

///|
/// The longest arrow at `i`, or `None`.
fn Scanner::arrow_at(self : Scanner, i : Int) -> String? {
  let mut best : String? = None
  for a in arrows {
    if self.starts(i, a) {
      match best {
        Some(b) if b.length() >= a.length() => ()
        _ => best = Some(a)
      }
    }
  }
  best
}

///|
/// A participant name in a message, a note or a link, as the grammar's
/// `ACTOR` rule. The name can have spaces and single dashes. Spaces at its
/// end are not part of it.
fn Scanner::name(self : Scanner, out : Array[@cst.Element]) -> Bool {
  let start = self.pos
  let n = self.src.length()
  let mut i = start
  while i < n {
    let entity = self.entity_at(i)
    if entity > 0 {
      i += entity
      continue
    }
    let c = self.cu(i)
    if is_newline(c) || one_of(c, "/\\+()<=>-:,;") {
      break
    }
    i += 1
  }
  if self.trim_back(start, i) == start {
    return false
  }
  while i < n {
    if name_stops.iter().any(s => self.starts(i, s)) {
      break
    }
    let mut j = i
    while self.cu(j) == '-'.to_int() {
      j += 1
    }
    let mut k = j
    while k < n {
      let entity = self.entity_at(k)
      if entity > 0 {
        k += entity
        continue
      }
      let c = self.cu(k)
      if is_newline(c) || one_of(c, "+<=>-:,;") {
        break
      }
      k += 1
    }
    if k == j {
      break
    }
    i = k
  }
  let end = self.trim_back(start, i)
  out.push(self.token(Identifier, start, end))
  self.pos = end
  true
}
