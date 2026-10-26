///|
/// The spellings of a scalar, in order of preference: plain, double quotes,
/// single quotes. The native profile removes one pair of outer quotes and
/// has no escapes.
fn spellings(text : String) -> Array[String] {
  ["\{text}", "\"\{text}\"", "'\{text}'"]
}

///|
/// A flow item inside quotes, with backslash escapes for the quote and the
/// backslash, as the native flow splitter reads them.
fn flow_quoted(text : String, quote : Char) -> String {
  let out = StringBuilder()
  out.write_char(quote)
  for c in text {
    if c == quote || c == '\\' {
      out.write_char('\\')
    }
    out.write_char(c)
  }
  out.write_char(quote)
  out.to_string()
}

///|
fn flow_plain_safe(text : String) -> Bool {
  !text.is_empty() &&
  java_trim(text) == text &&
  !text.contains(",") &&
  !text.contains("\\") &&
  !is_quote(text.code_unit_at(0).to_int())
}

///|
/// The flow list spellings: plain items where that is safe, then all items
/// in double quotes, then all items in single quotes.
fn flow_spellings(items : ReadOnlyArray[String]) -> Array[String] {
  let mixed = items
    .iter()
    .map(item => {
      if flow_plain_safe(item) {
        item
      } else {
        flow_quoted(item, '"')
      }
    })
  let double = items.iter().map(item => flow_quoted(item, '"'))
  let single = items.iter().map(item => flow_quoted(item, '\''))
  [
    "[" + mixed.to_array().join(", ") + "]",
    "[" + double.to_array().join(", ") + "]",
    "[" + single.to_array().join(", ") + "]",
  ]
}

///|
/// True when the shared envelope keeps the line as one YAML body line, even
/// at the start of a body, where statements such as `title` are read.
fn body_line(text : String) -> Bool {
  let scan = @envelope.scan_body(Yaml, text)
  scan.diagnostics.is_empty() &&
  scan.lines.length() == 1 &&
  scan.lines[0].role is Body
}

///|
/// True when `text` reads back as one line with this indentation and content.
/// Block content lines are checked separately.
fn reads_as(text : String, indent : Int32, content : Content) -> Bool {
  if !body_line(text) {
    return false
  }
  let (_, _, class) = classify_line(text)
  guard class.content() is Some(actual) else { return false }
  let expected = match content {
    Pair(item, key, Block(_)) => Pair(item, key, Block([]))
    other => other
  }
  class.count == indent && content_logical_equal(actual, expected)
}

///|
/// The source text of one line, with block content lines after a `|` line.
fn spell_line(line : Line) -> Result[String, String] {
  if line.indent < 0 {
    return Err("A line cannot have a negative indentation")
  }
  let lead = String::make(line.indent, ' ')
  let candidates : Array[String] = match line.content {
    Dash => [lead + "-"]
    Item(value) => spellings(value.text).map(v => lead + "- " + v)
    Text(value) => spellings(value.text).map(v => lead + v)
    Pair(item, key, entry) => {
      let head = lead + (if item { "- " } else { "" })
      let tails = match entry {
        Empty => [":"]
        Value(value) => spellings(value.text).map(v => ": " + v)
        Flow(items) => flow_spellings(items).map(v => ": " + v)
        Block(_) => [": |"]
        Folded => [": >"]
      }
      let out = []
      for k in spellings(key.text) {
        for tail in tails {
          out.push(head + k + tail)
        }
      }
      out
    }
  }
  guard candidates
    .iter()
    .find_first(text => reads_as(text, line.indent, line.content))
    is Some(text) else {
    return Err(
      "The value has no spelling that the native YAML profile reads back",
    )
  }
  guard line.content is Pair(_, _, Block(contents)) else { return Ok(text) }
  let out = StringBuilder()
  out.write_string(text)
  let native = line.native_indent()
  let pad = String::make(native + 2, ' ')
  for content in contents {
    let spelled = pad + content
    let (_, _, class) = classify_line(spelled)
    if content.is_empty() ||
      java_trim(content) != content ||
      content.contains("\n") ||
      content.contains("\r") ||
      !body_line(spelled) ||
      (
        class.ty != TextOnly &&
        class.ty != Empty &&
        class.native_indent() <= native
      ) {
      return Err(
        "A block content line must be non-empty, have no outer spaces and be a body line",
      )
    }
    out.write_char('\n')
    out.write_string(spelled)
  }
  Ok(out.to_string())
}

///|
/// Write the canonical body of a YAML block from the typed lines: one
/// `#highlight` line for each selector, then each line with its indentation,
/// the first scalar spelling that reads back to the same value, and no
/// comments or blank lines. Every line ends with a line break. The text has
/// no block markers and no shared statements. A value that the native
/// profile cannot express gives an error; there is no partial output and
/// no source fallback.
pub fn print_body(
  document : Document,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
  if !limits.valid() {
    return Err([
      @diagrams.Diagnostic::error(
        "yaml/invalid-limits", "YAML limits must be positive",
      ),
    ])
  }
  let out = StringBuilder()
  let mut units = 0
  fn emit(text : String) -> Bool {
    if text.length() + 1 > limits.output - units {
      return false
    }
    units += text.length() + 1
    out.write_string(text)
    out.write_char('\n')
    true
  }
  let output_failure : ReadOnlyArray[@diagrams.Diagnostic] = [
    @diagrams.Diagnostic::error(
      "yaml/output-limit", "Canonical YAML exceeds the output limit",
    ),
  ]
  for selector in document.highlights {
    let line = selector.to_line()
    match @data.parse_selector(line) {
      Ok(parsed) if parsed.logical_equal(selector) => ()
      _ =>
        return Err([
          @diagrams.Diagnostic::error(
            "yaml/unrepresentable-value", "A highlight selector cannot be written in the native profile",
          ),
        ])
    }
    if !emit(line) {
      return Err(output_failure)
    }
  }
  if document.lines.length() > limits.nodes {
    return Err([
      @diagrams.Diagnostic::error(
        "yaml/node-limit", "YAML data exceeds the node limit",
      ),
    ])
  }
  for line in document.lines {
    match spell_line(line) {
      Ok(text) => if !emit(text) { return Err(output_failure) }
      Err(message) =>
        return Err([
          @diagrams.Diagnostic::error(
            "yaml/unrepresentable-value",
            message,
            span?=line.span,
          ),
        ])
    }
  }
  let body = out.to_string()
  // Read the whole body back. Each line passed its own check; this also
  // proves that lines do not change the meaning of their neighbours.
  let reread = read(@envelope.scan_body(Yaml, body), limits~)
  let same = match reread.document {
    Some(back) => {
      let mut equal = back.lines.length() == document.lines.length() &&
        back.highlights.length() == document.highlights.length()
      if equal {
        for i in 0..<back.lines.length() {
          equal = equal && back.lines[i].logical_equal(document.lines[i])
        }
        for i in 0..<back.highlights.length() {
          equal = equal &&
            back.highlights[i].logical_equal(document.highlights[i])
        }
      }
      equal
    }
    None => false
  }
  if !same {
    return Err([
      @diagrams.Diagnostic::error(
        "yaml/unrepresentable-document", "The lines do not read back to the same document in the native YAML profile",
      ),
    ])
  }
  Ok(body)
}
