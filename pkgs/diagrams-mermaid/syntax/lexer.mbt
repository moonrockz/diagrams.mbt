///|
/// The arrows that this reader knows, longest first.
let arrows : Array[String] = ["->>"]

///|
/// One line of the source: its content without the line break, the line
/// break, and the UTF-16 offset of the content.
priv struct Line {
  content : String
  newline : String
  offset : Int
}

///|
/// The lines of `source`. The line breaks `\r\n`, `\n` and `\r` stay with
/// their lines, so the lines together are equal to the source.
fn lines(source : String) -> Array[Line] {
  let out = []
  let n = source.length()
  let mut start = 0
  let mut i = 0
  while i < n {
    let c = source.at(i).to_int()
    if c == '\n'.to_int() || c == '\r'.to_int() {
      let end = if c == '\r'.to_int() &&
        i + 1 < n &&
        source.at(i + 1).to_int() == '\n'.to_int() {
        i + 2
      } else {
        i + 1
      }
      out.push({
        content: slice(source, start, i),
        newline: slice(source, i, end),
        offset: start,
      })
      start = end
      i = end
    } else {
      i += 1
    }
  }
  if start < n {
    out.push({ content: slice(source, start, n), newline: "", offset: start })
  }
  out
}

///|
fn slice(s : String, start : Int, end : Int) -> String {
  s.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn is_space(c : Int) -> Bool {
  c == ' '.to_int() || c == '\t'.to_int()
}

///|
/// A cursor over the content of one line that makes tokens.
priv struct Cursor {
  text : String
  base : Int
  mut pos : Int
  tokens : Array[@cst.Element]
}

///|
fn Cursor::new(text : String, base : Int) -> Cursor {
  { text, base, pos: 0, tokens: [] }
}

///|
fn Cursor::at_end(self : Cursor) -> Bool {
  self.pos >= self.text.length()
}

///|
fn Cursor::peek(self : Cursor, ahead? : Int = 0) -> Int {
  let i = self.pos + ahead
  if i < self.text.length() {
    self.text.at(i).to_int()
  } else {
    -1
  }
}

///|
fn Cursor::looking_at(self : Cursor, word : String) -> Bool {
  self.text.view(start_offset=self.pos).has_prefix(word)
}

///|
/// Make a token of kind `kind` from the current position to `end`.
fn Cursor::take(self : Cursor, kind : @cst.TokenKind, end : Int) -> String {
  let text = slice(self.text, self.pos, end)
  self.tokens.push(Token(@cst.Token::new(kind, text, self.base + self.pos)))
  self.pos = end
  text
}

///|
/// Make a whitespace token when the cursor is at spaces or tabs.
fn Cursor::space(self : Cursor) -> Bool {
  let mut end = self.pos
  while end < self.text.length() && is_space(self.text.at(end).to_int()) {
    end += 1
  }
  guard end > self.pos else { return false }
  ignore(self.take(Whitespace, end))
  true
}

///|
/// Make a keyword token when the cursor is at `word` and a space or the end
/// follows it.
fn Cursor::keyword(self : Cursor, word : String) -> Bool {
  guard self.looking_at(word) else { return false }
  let next = self.peek(ahead=word.length())
  guard next == -1 || is_space(next) else { return false }
  ignore(self.take(Keyword, self.pos + word.length()))
  true
}

///|
/// True when the code unit at `i` starts an arrow.
fn Cursor::arrow_at(self : Cursor, i : Int) -> Bool {
  let rest = self.text.view(start_offset=i)
  arrows.iter().any(a => rest.has_prefix(a))
}

///|
/// Make an identifier token. An identifier ends at a space, at `:`, `,`, `;`,
/// `+` or `>`, or where an arrow starts.
fn Cursor::identifier(self : Cursor) -> String? {
  let mut end = self.pos
  while end < self.text.length() {
    let c = self.text.at(end).to_int()
    if is_space(c) ||
      c == ':'.to_int() ||
      c == ','.to_int() ||
      c == ';'.to_int() ||
      c == '+'.to_int() ||
      c == '>'.to_int() ||
      self.arrow_at(end) {
      break
    }
    end += 1
  }
  guard end > self.pos else { return None }
  Some(self.take(Identifier, end))
}

///|
/// Make an arrow token when the cursor is at a known arrow.
fn Cursor::arrow(self : Cursor) -> String? {
  for a in arrows {
    if self.looking_at(a) {
      return Some(self.take(Arrow, self.pos + a.length()))
    }
  }
  None
}

///|
/// Make a text token up to the last non-space code unit of the line, and a
/// whitespace token for the spaces after it.
fn Cursor::text_to_end(self : Cursor) -> Unit {
  let mut end = self.text.length()
  while end > self.pos && is_space(self.text.at(end - 1).to_int()) {
    end -= 1
  }
  if end > self.pos {
    ignore(self.take(Text, end))
  }
  ignore(self.space())
}
