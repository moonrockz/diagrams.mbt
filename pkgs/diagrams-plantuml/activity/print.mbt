///|
fn quoted(value : String) -> String {
  "\"" +
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n") +
  "\""
}

///|
fn Endpoint::text(self : Endpoint) -> String {
  match self {
    Start(top) => if top { "(*top)" } else { "(*)" }
    Final => "(*)"
    Action(text, code, decoration) =>
      quoted(text) +
      code.map(code => " as " + code).unwrap_or("") +
      optional_text(decoration, " ", "")
    Alias(code) => code
    Synchronization(code) => "===" + code + "==="
  }
}

///|
fn optional_text(value : String, before : String, after : String) -> String {
  if value.is_empty() {
    ""
  } else {
    before + value + after
  }
}

///|
fn Kind::text(self : Kind) -> String {
  match self {
    Action(text, end, decoration) =>
      if decoration.has_prefix("after:") {
        ":" + text + end + " " + after(decoration, "after:")
      } else {
        decoration + ":" + text + end
      }
    Start => "start"
    Stop => "stop"
    End => "end"
    If(condition, label) =>
      "if (" + condition + ") then" + optional_text(label, " (", ")")
    ElseIfIncoming(incoming, condition, label) =>
      "(" +
      incoming +
      ") elseif (" +
      condition +
      ") then" +
      optional_text(label, " (", ")")
    ElseIf(condition, label) =>
      "elseif (" + condition + ") then" + optional_text(label, " (", ")")
    Else(label) => "else" + optional_text(label, " (", ")")
    EndIf => "endif"
    Switch(condition) => "switch (" + condition + ")"
    Case(label) => "case (" + label + ")"
    EndSwitch => "endswitch"
    While(condition, label) =>
      "while (" + condition + ")" + optional_text(label, " is (", ")")
    EndWhile(label) => "endwhile" + optional_text(label, " (", ")")
    Repeat(action) => "repeat" + optional_text(action, " ", "")
    RepeatWhile(condition, yes, no) =>
      "repeat while (" +
      condition +
      ")" +
      optional_text(yes, " is (", ")") +
      optional_text(no, " not (", ")")
    Backward(text) => "backward:" + text + ";"
    Break => "break"
    Fork => "fork"
    ForkAgain => "fork again"
    EndFork(merge, label) =>
      if merge {
        "end merge"
      } else {
        "end fork" + optional_text(label, " {", "}")
      }
    Split => "split"
    SplitAgain => "split again"
    EndSplit => "end split"
    Kill => "kill"
    Detach => "detach"
    Connector(label) => "(" + label + ")"
    Label(name) => "label " + name
    Goto(name) => "goto " + name
    Group(kind, label, before, decoration) =>
      kind +
      " " +
      optional_text(before, "", " ") +
      quoted(label) +
      optional_text(decoration, " ", "") +
      " {"
    EndGroup => "}"
    Lane(code, label, color) =>
      "|" +
      optional_text(color, "", "|") +
      code +
      "|" +
      (if label == code { "" } else { " " + label })
    Note(placement, text, code, decoration) =>
      (if placement == "floating" {
        "floating note"
      } else {
        "note " + placement
      }) +
      code.map(code => " as " + code).unwrap_or("") +
      optional_text(decoration, " ", "") +
      "\n" +
      text +
      "\nend note"
    NoteOnLink(text, decoration) =>
      "note on link" +
      optional_text(decoration, " ", "") +
      "\n" +
      text +
      "\nend note"
    Arrow(_, text) => text + (if text.has_suffix(";") { "" } else { ";" })
    Edge(from, arrow, target, label) =>
      from.map(e => e.text() + " ").unwrap_or("") +
      arrow +
      (if label.is_empty() { " " } else { "[" + label + "] " }) +
      target.text()
    ActionList(text, depth) => "*".repeat(depth) + " " + text
    LegacyDecision(from, arrow, condition, label) =>
      from.map(e => e.text() + " ").unwrap_or("") +
      arrow +
      optional_text(label, "[", "]") +
      " if " +
      quoted(condition) +
      " then"
    LegacyIf(condition) => "if " + quoted(condition) + " then"
    Presentation(text) => text
  }
}

///|
/// Write the body from typed values. Invalid delimiters cannot be represented
/// safely and return a finding rather than stale source.
pub fn print_body(
  document : Document,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
  fn fail(
    message : String,
  ) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
    Err([@diagrams.Diagnostic::error("activity/invalid-ast", message)])
  }
  if !limits.valid() || document.items.length() > limits.nodes {
    return fail("Invalid limits or too many activity statements")
  }
  let out = StringBuilder()
  let mut used = 0
  for statement in document.items {
    let text = statement.kind.text()
    used += text.length() + 1
    if used > limits.output || used > limits.work {
      return Err([
        @diagrams.Diagnostic::error(
          "activity/limit", "Activity print limit exceeded",
        ),
      ])
    }
    if text.contains("@start") || text.contains("@end") {
      return fail("Block markers are not activity values")
    }
    match statement.kind {
      Action(_, end, _) =>
        if ![";", "]", "}", "/", "|", ">", "<"].contains(end) {
          return fail("Invalid action delimiter")
        }
      _ => ()
    }
    out.write_string(text)
    out.write_char('\n')
  }
  let output = out.to_string()
  let parsed = read(
    @envelope.scan_body(Activity, output, limits~),
    limits~,
    dialect=document.dialect,
  )
  if parsed.diagnostics.iter().any(d => d.severity == Error) {
    return fail("Typed activity values cannot be read in their dialect")
  }
  match parsed.document {
    Some(value) if value.items.iter().map(s => s.kind).to_array() ==
      document.items.iter().map(s => s.kind).to_array() => Ok(output)
    _ => fail("Typed activity values are not canonically representable")
  }
}
