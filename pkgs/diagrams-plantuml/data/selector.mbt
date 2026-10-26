///|
/// One segment of a `#highlight` path.
pub(all) enum Segment {
  /// A member name or an array position. Both compare as text, so `0`
  /// selects array position 0 and also an object member named `0`.
  Name(String)
  /// The `n`-th member, from 1, that has this name in its container. The
  /// source spelling is a quoted name followed by `#n`, as in `"item"#2`.
  Occurrence(String, Int32)
  /// `*`: one member with any name or position.
  Any
  /// `**`: zero or more member levels. At the end of a path, every member
  /// below the current container.
  Deep
} derive(Eq, Debug)

///|
pub extend Segment with Eq::{equal, not_equal}

///|
pub extend Segment with @debug.Debug::{to_repr}

///|
/// A typed `#highlight` selector. The stereotype is inert author metadata;
/// library themes paint every highlight.
pub struct Selector {
  segments : ReadOnlyArray[Segment]
  /// The text between `<<` and `>>`, without the outer markers.
  stereotype : String?
  span : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Selector with Eq::{equal, not_equal}

///|
pub extend Selector with @debug.Debug::{to_repr}

///|
/// A selector. The constructor copies `segments`.
pub fn Selector::new(
  segments : ArrayView[Segment],
  stereotype? : String,
  span? : @diagrams.Span,
) -> Selector {
  { segments: ReadOnlyArray::from_array(segments), stereotype, span, }
}

///|
/// Equality without the source span.
pub fn Selector::logical_equal(self : Selector, other : Selector) -> Bool {
  self.segments == other.segments && self.stereotype == other.stereotype
}

///|
/// True when the selector has no wildcard and no occurrence number.
pub fn Selector::is_plain(self : Selector) -> Bool {
  self.segments.iter().all(segment => segment is Name(_))
}

///|
let highlight_word = "#highlight "

///|
/// True when the trimmed line is a `#highlight` statement.
pub fn is_highlight_line(text : String) -> Bool {
  @envelope.trim(text).has_prefix(highlight_word)
}

///|
fn quoted(text : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for c in text {
    if c == '"' || c == '\\' || ((text == "*" || text == "**") && c == '*') {
      out.write_char('\\')
    }
    out.write_char(c)
  }
  out.write_char('"')
  out.to_string()
}

///|
/// The canonical source line of the selector, without a line break. Names
/// are quoted, so `/`, `*` and `<` in a name stay literal.
pub fn Selector::to_line(self : Selector) -> String {
  let out = StringBuilder()
  out.write_string(highlight_word)
  for i, segment in self.segments {
    if i > 0 {
      out.write_string(" / ")
    }
    match segment {
      Name(name) => out.write_string(quoted(name))
      Occurrence(name, n) => {
        out.write_string(quoted(name))
        out.write_string("#\{n}")
      }
      Any => out.write_string("*")
      Deep => out.write_string("**")
    }
  }
  if self.stereotype is Some(text) {
    out.write_string(" <<\{text}>>")
  }
  out.to_string()
}

///|
fn is_blank_unit(c : Int32) -> Bool {
  c == 32 || c == 9
}

///|
/// Parse the text of a `#highlight` line. A quoted segment keeps `/`, `<`
/// and `>` inside the segment and accepts `\"`, `\\` and `\*` escapes. A
/// quoted `*` or `**` without escapes is a wildcard, as upstream. Upstream
/// PlantUML splits on every `/` before it removes quotes; this library does
/// not, so a quoted name that contains `/` selects one member.
pub fn parse_selector(line : String) -> Result[Selector, String] {
  let t = @envelope.trim(line)
  guard t.has_prefix(highlight_word) else {
    return Err("A highlight starts with '#highlight '")
  }
  let text = @envelope.trim(@cst.slice(t, highlight_word.length(), t.length()))
  let n = text.length()
  let segments : Array[Segment] = []
  let mut stereotype : String? = None
  let mut i = 0
  fn unit(at : Int32) -> Int32 {
    text.code_unit_at(at).to_int()
  }
  while true {
    while i < n && is_blank_unit(unit(i)) {
      i += 1
    }
    if i + 1 < n && unit(i) == 60 && unit(i + 1) == 60 {
      // `<<` starts the stereotype; it runs to the end of the line.
      let rest = @cst.slice(text, i, n)
      let rest = @envelope.trim(rest)
      if rest.length() < 4 || !rest.has_suffix(">>") {
        return Err("A highlight stereotype must end with '>>'")
      }
      if segments.is_empty() {
        return Err("A highlight needs a path before its stereotype")
      }
      stereotype = Some(@cst.slice(rest, 2, rest.length() - 2))
      break
    }
    if i >= n {
      return Err(
        if segments.is_empty() {
          "A highlight needs a path"
        } else {
          "A highlight path has an empty segment"
        },
      )
    }
    if unit(i) == 34 {
      let name = StringBuilder()
      let mut j = i + 1
      let mut run = j
      let mut closed = false
      let mut escaped = false
      while j < n {
        let c = unit(j)
        if c == 92 &&
          j + 1 < n &&
          (unit(j + 1) == 34 || unit(j + 1) == 92 || unit(j + 1) == 42) {
          name.write_string(@cst.slice(text, run, j))
          escaped = true
          run = j + 1
          j += 2
        } else if c == 34 {
          name.write_string(@cst.slice(text, run, j))
          closed = true
          j += 1
          break
        } else {
          j += 1
        }
      }
      if !closed {
        return Err("A quoted highlight segment has no closing quote")
      }
      let mut occurrence : Int32? = None
      if j < n && unit(j) == 35 {
        let mut k = j + 1
        let mut value = 0
        while k < n && unit(k) >= 48 && unit(k) <= 57 && k - j <= 9 {
          value = value * 10 + (unit(k) - 48)
          k += 1
        }
        if k == j + 1 || value < 1 {
          return Err("An occurrence number after '#' must be 1 or more")
        }
        occurrence = Some(value)
        j = k
      }
      while j < n && is_blank_unit(unit(j)) {
        j += 1
      }
      // As upstream, a quoted `*` or `**` is a wildcard. Write `\*` for a
      // literal star.
      let segment : Segment = match (occurrence, name.to_string()) {
        (Some(value), text) => Occurrence(text, value)
        (None, "*") if !escaped => Any
        (None, "**") if !escaped => Deep
        (None, text) => Name(text)
      }
      segments.push(segment)
      i = j
    } else {
      let start = i
      while i < n &&
            unit(i) != 47 &&
            !(i + 1 < n && unit(i) == 60 && unit(i + 1) == 60) {
        if unit(i) == 60 || unit(i) == 62 {
          return Err(
            "Quote a highlight name that contains '<' or '>'; '<<' starts a stereotype",
          )
        }
        i += 1
      }
      let raw = @envelope.trim(@cst.slice(text, start, i))
      if raw.is_empty() {
        return Err("A highlight path has an empty segment")
      }
      segments.push(
        match raw {
          "*" => Any
          "**" => Deep
          _ => Name(raw)
        },
      )
    }
    while i < n && is_blank_unit(unit(i)) {
      i += 1
    }
    if i >= n {
      break
    }
    if unit(i) == 47 {
      i += 1
      continue
    }
    if i + 1 < n && unit(i) == 60 && unit(i + 1) == 60 {
      continue
    }
    return Err("Expected '/' or '<<' after a highlight segment")
  }
  Ok(Selector::new(segments, stereotype?))
}

///|
/// Read the selectors of the `#highlight` statement lines of a scan. A line
/// that does not parse gives an error with the code `<prefix>/invalid-highlight`.
pub fn read_selectors(
  scan : @envelope.Scan,
  prefix : String,
) -> (Array[Selector], Array[@diagrams.Diagnostic]) {
  let selectors = []
  let diagnostics = []
  for line in scan.lines {
    guard line.role is Statement(node) && node.kind == Highlight else {
      continue
    }
    let span = scan.span(line.offset, line.offset + line.text.length())
    match parse_selector(line.text) {
      Ok(selector) => selectors.push({ ..selector, span: Some(span), })
      Err(message) =>
        diagnostics.push(
          @diagrams.Diagnostic::error(
            "\{prefix}/invalid-highlight",
            message,
            span~,
          ),
        )
    }
  }
  (selectors, diagnostics)
}
