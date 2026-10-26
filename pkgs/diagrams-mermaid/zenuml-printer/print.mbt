///|
pub struct Printed {
  output : String?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub extend Printed with Eq::{equal, not_equal}

///|
pub extend Printed with @debug.Debug::{to_repr}

///|
/// Print native syntax from typed fields; source spans never supply output.
pub fn print(
  diagram : @ast.Diagram,
  limits~ : @syntax.Limits = @syntax.Limits::new(),
) -> Printed {
  let lines : Array[String] = []
  let mut total = 7
  let mut depth = 0
  let mut work = 0
  let mut header = false
  fn fail(code : String, message : String) -> Printed {
    {
      output: None,
      diagnostics: [@diagrams.Diagnostic::error("zenuml/" + code, message)],
    }
  }
  if limits.output < 7 ||
    limits.depth < 0 ||
    limits.work < 0 ||
    diagram.statements.length() > limits.events {
    return fail("output-limit", "Invalid printer limits")
  }
  for statement in diagram.statements {
    work += 1
    if work > limits.work {
      return fail("work-limit", "Printer work limit exceeded")
    }
    if statement.kind is End {
      depth -= 1
      if depth < 0 {
        return fail("nesting", "Unmatched closing statement")
      }
    }
    let before_header = statement.kind is Metadata(_) && !header
    if !header && !before_header {
      lines.push("zenuml\n")
      header = true
    }
    let out = StringBuilder()
    out.write_string("    ".repeat(depth))
    match statement.kind {
      Participant(id~, label~, annotator~) => {
        if annotator is Some(key) {
          out.write_string("@" + key + " ")
        }
        out.write_string(id)
        if label is Some(text) {
          if text.contains("\n") || text.contains("\r") {
            return fail("invalid-ast", "An alias cannot contain a line break")
          }
          out.write_string(
            " as \"" + text.replace_all(old="\"", new="\"\"") + "\"",
          )
        }
      }
      Call(sender~, receiver~, operation~, assignment~, creation~, scope~) => {
        if assignment is Some(value) {
          out.write_string(value + " = ")
        }
        if sender is Some(value) {
          out.write_string(value + "->")
        }
        if creation {
          out.write_string("new ")
        }
        out.write_string(receiver)
        if !creation {
          out.write_string(".")
        }
        out.write_string(operation)
        if scope {
          out.write_string(" {")
          depth += 1
        }
      }
      Async(sender~, receiver~, label~, reply~) => {
        if reply {
          out.write_string("@return ")
        }
        out.write_string(sender + "->" + receiver + ": " + label)
      }
      Starter(id) => out.write_string("@Starter(" + id + ")")
      Return(text) =>
        out.write_string("return" + (if text == "" { "" } else { " " + text }))
      Begin(keyword~, expression~) | Section(keyword~, expression~) => {
        out.write_string(
          keyword + (if expression == "" { "" } else { " " + expression }),
        )
        out.write_string(" {")
        depth += 1
      }
      End => out.write_string("}")
      Comment(text) => out.write_string("// " + text)
      Title(text) => out.write_string("title " + text)
      Metadata(text) => out.write_string(text)
    }
    out.write_char('\n')
    let line = out.to_string()
    let length = line.length()
    work += length
    total += length
    lines.push(line)
    if work > limits.work {
      return fail("work-limit", "Printer work limit exceeded")
    }
    if total > limits.output {
      return fail("output-limit", "Printer output limit exceeded")
    }
    if depth > limits.depth {
      return fail("depth-limit", "Printer depth limit exceeded")
    }
  }
  if depth != 0 {
    return fail("nesting", "Missing closing statement")
  }
  if !header {
    lines.push("zenuml\n")
  }
  { output: Some(lines.join("")), diagnostics: [], }
}

///|
/// Stable diagnostic codes emitted by this processing stage.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "zenuml/invalid-ast", "zenuml/depth-limit", "zenuml/nesting", "zenuml/output-limit",
  "zenuml/work-limit",
]
