///|
/// The native line types of the pinned YAML profile.
priv enum Ty {
  Empty
  TextOnly
  Dash
  Item
  KeyOnly
  KeyValue
  Block
  Folded
  Flow
} derive(Eq)

///|
/// One classified line. Positions are indexes into the expanded text, in
/// which every tab is four spaces, as in the native profile.
priv struct Class {
  ty : Ty
  /// Leading spaces before any dash.
  count : Int32
  t_end : Int32
  /// The end of the content after comment removal.
  c_end : Int32
  dash : Int32
  key_start : Int32
  key_end : Int32
  colon : Int32
  value_start : Int32
  value_end : Int32
  key : Scalar
  value : Scalar
  flow : Array[String]
}

///|
fn Class::native_indent(self : Class) -> Int32 {
  match self.ty {
    Empty => 0
    Dash => self.count + 1
    _ => if self.dash >= 0 { self.count + 2 } else { self.count }
  }
}

///|
/// True for a code unit that Java `String.trim` removes.
fn is_trim_unit(c : Int32) -> Bool {
  c <= 32
}

///|
/// The text without leading and trailing code units up to U+0020, as Java
/// `String.trim` gives.
pub fn java_trim(text : String) -> String {
  let (a, b) = trim_range(text, 0, text.length())
  @cst.slice(text, a, b)
}

///|
fn trim_range(text : String, start : Int32, end : Int32) -> (Int32, Int32) {
  let mut a = start
  let mut b = end
  while a < b && is_trim_unit(text.code_unit_at(a).to_int()) {
    a += 1
  }
  while b > a && is_trim_unit(text.code_unit_at(b - 1).to_int()) {
    b -= 1
  }
  (a, b)
}

///|
/// The text with each tab replaced by four spaces, and the source offset of
/// each boundary of the expanded text. A boundary inside a tab maps to the
/// offset after the tab.
fn expand(text : String) -> (String, Array[Int32]) {
  let out = StringBuilder()
  let origin = []
  let mut run = 0
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() == 9 {
      out.write_string(@cst.slice(text, run, i))
      out.write_string("    ")
      run = i + 1
      origin.push(i)
      origin.push(i + 1)
      origin.push(i + 1)
      origin.push(i + 1)
    } else {
      origin.push(i)
    }
  }
  out.write_string(@cst.slice(text, run, text.length()))
  origin.push(text.length())
  (out.to_string(), origin)
}

///|
/// Remove one pair of matching outer quotes, as the native profile does.
fn unquote(text : String) -> String {
  let n = text.length()
  if n < 2 {
    return text
  }
  let first = text.code_unit_at(0).to_int()
  let last = text.code_unit_at(n - 1).to_int()
  if (first == 34 && last == 34) || (first == 39 && last == 39) {
    @cst.slice(text, 1, n - 1)
  } else {
    text
  }
}

///|
fn is_quote(c : Int32) -> Bool {
  c == 34 || c == 39
}

///|
/// Split the inside of a flow list as the native profile does: commas
/// separate items, a quote at the start of an item starts a quoted item, and
/// a backslash keeps the next code unit.
fn to_list(text : String) -> Array[String] {
  let result = []
  let current = StringBuilder()
  let mut in_quote = 0
  let mut quoted_item = false
  let n = text.length()
  let mut i = 0
  fn finish() {
    let value = current.to_string()
    result.push(if quoted_item { value } else { java_trim(value) })
    current.reset()
    quoted_item = false
  }
  while i < n {
    let c = text.code_unit_at(i).to_int()
    if in_quote != 0 {
      if c == 92 {
        if i + 1 < n {
          current.write_string(@cst.slice(text, i + 1, i + 2))
          i += 1
        }
      } else if c == in_quote {
        in_quote = 0
      } else {
        current.write_string(@cst.slice(text, i, i + 1))
      }
    } else if !quoted_item &&
      is_quote(c) &&
      java_trim(current.to_string()).is_empty() {
      in_quote = c
      quoted_item = true
      current.reset()
    } else if c == 44 {
      finish()
    } else if c == 92 {
      if i + 1 < n {
        current.write_string(@cst.slice(text, i + 1, i + 2))
        i += 1
      }
    } else {
      current.write_string(@cst.slice(text, i, i + 1))
    }
    i += 1
  }
  finish()
  result
}

///|
/// Classify one expanded line with the native rules.
fn classify(e : String) -> Class {
  let n = e.length()
  let mut count = 0
  while count < n && e.code_unit_at(count).to_int() == 32 {
    count += 1
  }
  let (t_start, t_end) = trim_range(e, count, n)
  let empty : Class = {
    ty: Empty,
    count,
    t_end,
    c_end: t_start,
    dash: -1,
    key_start: t_start,
    key_end: t_start,
    colon: -1,
    value_start: t_start,
    value_end: t_start,
    key: Scalar::new(""),
    value: Scalar::new(""),
    flow: [],
  }
  if t_start == t_end {
    return empty
  }
  // Comment removal: `#` at the start, or ` #` outside quotes.
  let mut c_end = t_end
  if e.code_unit_at(t_start).to_int() == 35 {
    c_end = t_start
  } else {
    let mut in_quote = 0
    for i in t_start..<t_end {
      let c = e.code_unit_at(i).to_int()
      if is_quote(c) {
        if in_quote == 0 {
          in_quote = c
        } else if c == in_quote {
          in_quote = 0
        }
      }
      if in_quote == 0 &&
        i < t_end - 1 &&
        c == 32 &&
        e.code_unit_at(i + 1).to_int() == 35 {
        c_end = i
        break
      }
    }
  }
  let base = { ..empty, c_end, }
  if c_end == t_start {
    return base
  }
  if c_end - t_start == 1 && e.code_unit_at(t_start).to_int() == 45 {
    return { ..base, ty: Dash, dash: t_start, }
  }
  let item = c_end - t_start >= 2 &&
    e.code_unit_at(t_start).to_int() == 45 &&
    e.code_unit_at(t_start + 1).to_int() == 32
  let body = if item { t_start + 2 } else { t_start }
  let dash = if item { t_start } else { -1 }
  let mut colon = -1
  {
    let mut in_quote = 0
    for i in body..<c_end {
      let c = e.code_unit_at(i).to_int()
      if in_quote != 0 {
        if c == in_quote {
          in_quote = 0
        }
      } else if is_quote(c) {
        in_quote = c
      } else if c == 58 {
        colon = i
        break
      }
    }
  }
  if colon < 0 {
    let raw = @cst.slice(e, body, c_end)
    return {
      ..base,
      ty: if item {
        Item
      } else {
        TextOnly
      },
      dash,
      value_start: body,
      value_end: c_end,
      value: { text: unquote(raw), raw: Some(raw), },
    }
  }
  let (key_start, key_end) = trim_range(e, body, colon)
  let (value_start, value_end) = trim_range(e, colon + 1, c_end)
  let raw_key = @cst.slice(e, key_start, key_end)
  let raw_value = @cst.slice(e, value_start, value_end)
  let key : Scalar = { text: unquote(raw_key), raw: Some(raw_key), }
  let parts = {
    ..base,
    dash,
    key_start,
    key_end,
    colon,
    value_start,
    value_end,
    key,
  }
  if raw_value.is_empty() {
    return { ..parts, ty: KeyOnly, }
  }
  if raw_value == "|" {
    return { ..parts, ty: Block, }
  }
  if raw_value == ">" {
    return { ..parts, ty: Folded, }
  }
  if raw_value.has_prefix("[") &&
    raw_value.has_suffix("]") &&
    raw_value.length() >= 2 {
    return {
      ..parts,
      ty: Flow,
      value: { text: raw_value, raw: Some(raw_value), },
      flow: to_list(@cst.slice(raw_value, 1, raw_value.length() - 1)),
    }
  }
  {
    ..parts,
    ty: KeyValue,
    value: { text: unquote(raw_value), raw: Some(raw_value), },
  }
}

///|
/// The typed content of a classified line, or `None` for a comment-only
/// line. A block line has no content lines yet.
fn Class::content(self : Class) -> Content? {
  let item = self.dash >= 0
  match self.ty {
    Empty => None
    Dash => Some(Dash)
    TextOnly => Some(Text(self.value))
    Item => Some(Item(self.value))
    KeyOnly => Some(Pair(item, self.key, Empty))
    KeyValue => Some(Pair(item, self.key, Value(self.value)))
    Block => Some(Pair(item, self.key, Block([])))
    Folded => Some(Pair(item, self.key, Folded))
    Flow =>
      Some(Pair(item, self.key, Flow(ReadOnlyArray::from_array(self.flow))))
  }
}

///|
fn quoted_value(e : String, start : Int32, end : Int32) -> Bool {
  let (a, b) = trim_range(e, start, end)
  b - a >= 2 &&
  is_quote(e.code_unit_at(a).to_int()) &&
  e.code_unit_at(a).to_int() == e.code_unit_at(b - 1).to_int()
}

///|
/// The lossless tokens of one classified line.
fn line_tokens(
  line : @envelope.Line,
  e : String,
  origin : Array[Int32],
  class : Class,
) -> Array[@cst.Element] {
  let marks : Array[(Int32, Int32, @cst.TokenKind)] = []
  fn mark(start : Int32, end : Int32, kind : @cst.TokenKind) {
    if end > start {
      marks.push((start, end, kind))
    }
  }
  fn scalar(start : Int32, end : Int32) {
    let (a, b) = trim_range(e, start, end)
    mark(a, b, if quoted_value(e, a, b) { String } else { Text })
  }
  if class.dash >= 0 {
    mark(class.dash, class.dash + 1, Punctuation)
  }
  match class.ty {
    Empty | Dash => ()
    TextOnly | Item => scalar(class.value_start, class.value_end)
    _ => {
      mark(class.key_start, class.key_end, Name)
      mark(class.colon, class.colon + 1, Punctuation)
      match class.ty {
        KeyValue => scalar(class.value_start, class.value_end)
        Block | Folded => mark(class.value_start, class.value_end, Operator)
        Flow => {
          mark(class.value_start, class.value_start + 1, Punctuation)
          mark(class.value_start + 1, class.value_end - 1, Text)
          mark(class.value_end - 1, class.value_end, Punctuation)
        }
        _ => ()
      }
    }
  }
  if class.c_end < class.t_end {
    let start = if e.code_unit_at(class.c_end).to_int() == 35 {
      class.c_end
    } else {
      class.c_end + 1
    }
    mark(start, class.t_end, Comment)
  }
  marks_to_tokens(line, e.length(), origin, marks)
}

///|
/// Tokens for the marks, with whitespace tokens in the gaps. Expanded
/// positions map back to source offsets; empty tokens are dropped.
fn marks_to_tokens(
  line : @envelope.Line,
  length : Int32,
  origin : Array[Int32],
  marks : Array[(Int32, Int32, @cst.TokenKind)],
) -> Array[@cst.Element] {
  let out : Array[@cst.Element] = []
  let text = line.text
  fn emit(start : Int32, end : Int32, kind : @cst.TokenKind) {
    let a = origin[start]
    let b = origin[end]
    if b > a {
      out.push(
        Token(@cst.Token::new(kind, @cst.slice(text, a, b), line.offset + a)),
      )
    }
  }
  let mut at = 0
  for item in marks {
    let (start, end, kind) = item
    if start > at {
      emit(at, start, Whitespace)
    }
    emit(start, end, kind)
    at = end
  }
  if at < length {
    emit(at, length, Whitespace)
  }
  if !line.newline.is_empty() {
    out.push(
      Token(@cst.Token::new(Newline, line.newline, line.offset + text.length())),
    )
  }
  out
}

///|
/// Classify a source line: expand tabs, then apply the native rules.
fn classify_line(text : String) -> (String, Array[Int32], Class) {
  let (e, origin) = expand(text)
  (e, origin, classify(e))
}
