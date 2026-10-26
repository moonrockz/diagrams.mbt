///|
/// Write a JSON string with its quotes. `%` before a name character is
/// written as `%`, so the line never looks like a preprocessor call.
fn write_string(out : StringBuilder, text : String) -> Unit {
  let n = text.length()
  out.write_char('"')
  let mut run = 0
  fn flush(at : Int32) {
    out.write_string(@cst.slice(text, run, at))
  }
  for i in 0..<n {
    let c = text.code_unit_at(i).to_int()
    let escape = match c {
      34 => Some("\\\"")
      92 => Some("\\\\")
      8 => Some("\\b")
      12 => Some("\\f")
      10 => Some("\\n")
      13 => Some("\\r")
      9 => Some("\\t")
      37 => {
        let next = if i + 1 < n { text.code_unit_at(i + 1).to_int() } else { 0 }
        if (next >= 97 && next <= 122) ||
          (next >= 65 && next <= 90) ||
          next == 95 {
          Some("\\u0025")
        } else {
          None
        }
      }
      _ =>
        if c < 32 ||
          (c >= 0xd800 && c <= 0xdbff && !paired_after(text, i)) ||
          (c >= 0xdc00 && c <= 0xdfff && !paired_before(text, i)) {
          Some("\\u" + hex4(c))
        } else {
          None
        }
    }
    if escape is Some(spelling) {
      flush(i)
      out.write_string(spelling)
      run = i + 1
    }
  }
  flush(n)
  out.write_char('"')
}

///|
fn paired_after(text : String, i : Int32) -> Bool {
  i + 1 < text.length() &&
  text.code_unit_at(i + 1).to_int() >= 0xdc00 &&
  text.code_unit_at(i + 1).to_int() <= 0xdfff
}

///|
fn paired_before(text : String, i : Int32) -> Bool {
  i > 0 &&
  text.code_unit_at(i - 1).to_int() >= 0xd800 &&
  text.code_unit_at(i - 1).to_int() <= 0xdbff
}

///|
fn hex4(c : Int32) -> String {
  let digits = "0123456789abcdef"
  let out = StringBuilder()
  for shift in [12, 8, 4, 0] {
    let d = (c >> shift) & 15
    out.write_string(@cst.slice(digits, d, d + 1))
  }
  out.to_string()
}

///|
priv enum Step {
  Open(Value, Int32)
  Close(Bool, Int32)
  Separator
  Name(String, Int32)
  Line(Int32)
}

///|
/// Write the canonical text of one value: two-space indentation, one member
/// or element on each line, `{}` and `[]` for empty containers. The output
/// has no trailing line break. Numbers keep their exact lexemes.
pub fn print_value(
  value : Value,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
  if !limits.valid() {
    return Err([
      @diagrams.Diagnostic::error(
        "json/invalid-limits", "JSON limits must be positive",
      ),
    ])
  }
  let out = StringBuilder()
  let mut units = 0
  let mut work = 0
  let stack : Array[Step] = [Open(value, 0)]
  fn indent(depth : Int32) -> String {
    String::make(depth * 2, ' ')
  }
  fn error(
    code : String,
    message : String,
  ) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
    Err([@diagrams.Diagnostic::error(code, message)])
  }
  fn emit(text : String) -> Bool {
    if text.length() > limits.output - units {
      return false
    }
    units += text.length()
    out.write_string(text)
    true
  }
  let output_failure = "Canonical JSON exceeds the output limit"
  while stack.pop() is Some(step) {
    work += 1
    if work > limits.work {
      return error("json/work-limit", "JSON writing exceeds its work limit")
    }
    match step {
      Separator =>
        if !emit(",") {
          return error("json/output-limit", output_failure)
        }
      Close(object, depth) =>
        if !emit("\n" + indent(depth) + (if object { "}" } else { "]" })) {
          return error("json/output-limit", output_failure)
        }
      Line(depth) =>
        if !emit("\n" + indent(depth)) {
          return error("json/output-limit", output_failure)
        }
      Name(name, depth) => {
        let part = StringBuilder()
        part.write_char('\n')
        part.write_string(indent(depth))
        write_string(part, name)
        part.write_string(": ")
        if !emit(part.to_string()) {
          return error("json/output-limit", output_failure)
        }
      }
      Open(value, depth) => {
        let text = match value.kind {
          String(s) => {
            let part = StringBuilder()
            write_string(part, s.text)
            Some(part.to_string())
          }
          Number(lexeme) =>
            if @data_tree.valid_number(lexeme) {
              Some(lexeme)
            } else {
              return error(
                "json/invalid-model",
                "'\{lexeme}' is not a valid JSON number lexeme",
              )
            }
          Boolean(true) => Some("true")
          Boolean(false) => Some("false")
          Null => Some("null")
          Object(members) if members.is_empty() => Some("{}")
          Array(items) if items.is_empty() => Some("[]")
          _ => None
        }
        match text {
          Some(text) =>
            if !emit(text) {
              return error("json/output-limit", output_failure)
            }
          None => {
            if depth >= limits.depth {
              return error(
                "json/depth-limit",
                "JSON nesting exceeds the depth limit of \{limits.depth}",
              )
            }
            match value.kind {
              Object(members) => {
                if !emit("{") {
                  return error("json/output-limit", output_failure)
                }
                stack.push(Close(true, depth))
                for i in 0..<members.length() {
                  let k = members.length() - 1 - i
                  stack.push(Open(members[k].value, depth + 1))
                  stack.push(Name(members[k].name.text, depth + 1))
                  if k > 0 {
                    stack.push(Separator)
                  }
                }
              }
              Array(items) => {
                if !emit("[") {
                  return error("json/output-limit", output_failure)
                }
                stack.push(Close(false, depth))
                for i in 0..<items.length() {
                  let k = items.length() - 1 - i
                  stack.push(Open(items[k], depth + 1))
                  stack.push(Line(depth + 1))
                  if k > 0 {
                    stack.push(Separator)
                  }
                }
              }
              _ => ()
            }
          }
        }
      }
    }
  }
  Ok(out.to_string())
}

///|
/// Write the canonical body of a JSON block: one `#highlight` line for each
/// selector, then the value. Every line ends with a line break. The text has
/// no block markers and no shared statements. On error there is no output.
pub fn print_body(
  document : Document,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
  let out = StringBuilder()
  let mut units = 0
  for selector in document.highlights {
    let line = selector.to_line()
    match @data.parse_selector(line) {
      Ok(parsed) if parsed.logical_equal(selector) => ()
      _ =>
        return Err([
          @diagrams.Diagnostic::error(
            "json/invalid-model", "A highlight selector cannot be written in the native profile",
          ),
        ])
    }
    units += line.length() + 1
    out.write_string(line)
    out.write_char('\n')
  }
  if units >= limits.output - 1 {
    return Err([
      @diagrams.Diagnostic::error(
        "json/output-limit", "Canonical JSON exceeds the output limit",
      ),
    ])
  }
  let value = print_value(
    document.value,
    limits=@envelope.Limits::new(
      source=limits.source,
      output=limits.output - units - 1,
      depth=limits.depth,
      nodes=limits.nodes,
      work=limits.work,
      diagnostics=limits.diagnostics,
    ),
  )
  match value {
    Err(diagnostics) => Err(diagnostics)
    Ok(text) => {
      out.write_string(text)
      out.write_char('\n')
      Ok(out.to_string())
    }
  }
}
