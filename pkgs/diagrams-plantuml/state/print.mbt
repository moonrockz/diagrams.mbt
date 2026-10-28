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
fn Kind::text(self : Kind, explicit_label : Bool) -> String {
  match self {
    Declaration(code, label, decoration, composite) =>
      "state " +
      (if explicit_label { quoted(label) + " as " + code } else { code }) +
      (if decoration.is_empty() { "" } else { " " + decoration }) +
      (if composite { " {" } else { "" })
    Close => "}"
    Separator(vertical) => if vertical { "||" } else { "--" }
    Description(code, text) => code + " : " + text
    Transition(from, arrow, target, label) =>
      from +
      " " +
      arrow +
      " " +
      target +
      (if label.is_empty() { "" } else { " : " + label })
    Note(placement, target, text, code) =>
      match code {
        Some(code) => "note " + quoted(text) + " as " + code
        None =>
          (if target == Some("@link") {
            "note on link"
          } else {
            "note " + placement + target.map(t => " of " + t).unwrap_or("")
          }) +
          "\n" +
          text +
          "\nend note"
      }
    Direction(direction) =>
      match direction {
        LR => "left to right direction"
        TB => "top to bottom direction"
        _ => "invalid direction"
      }
    Presentation(text) => text
  }
}

///|
/// Canonical source is derived from edited values and checked for representability.
pub fn print_body(
  document : Document,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
  fn refused(
    text : String,
  ) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
    Err([@diagrams.Diagnostic::error("state/invalid-ast", text)])
  }
  if !document.complete {
    return refused("Recovered state document is incomplete")
  }
  if !limits.valid() || document.items.length() > limits.nodes {
    return Err([
      @diagrams.Diagnostic::error(
        "state/limit", "Invalid limits or too many statements",
      ),
    ])
  }
  let out = StringBuilder()
  let mut size = 0
  let mut work = 0
  for item in document.items {
    let values : Array[String] = match item.kind {
      Declaration(a, b, c, _) => [a, b, c]
      Description(a, b) => [a, b]
      Transition(a, b, c, d) => [a, b, c, d]
      Note(a, b, c, d) => [a, b.unwrap_or(""), c, d.unwrap_or("")]
      Presentation(a) => [a]
      _ => []
    }
    for value in values {
      if value.length() > limits.output || value.length() > limits.work - work {
        return Err([
          @diagrams.Diagnostic::error(
            "state/limit", "Typed value exceeds printing limits",
          ),
        ])
      }
      work += value.length()
    }
    let text = item.kind.text(item.explicit_label)
    size += text.length() + 1
    work += text.length() + 1
    if size > limits.output || work > limits.work {
      return Err([
        @diagrams.Diagnostic::error(
          "state/limit", "Printing output or work limit exceeded",
        ),
      ])
    }
    out.write_string(text)
    out.write_char('\n')
  }
  let text = out.to_string()
  let check_limits = @envelope.Limits::new(
    source=limits.output,
    output=limits.output,
    depth=limits.depth,
    nodes=limits.nodes,
    regions=limits.regions,
    edges=limits.edges,
    work=limits.work,
    diagnostics=limits.diagnostics,
  )
  let check = read(
    @envelope.scan_body(State, text, limits=check_limits),
    limits=check_limits,
  )
  if check.diagnostics.iter().any(d => d.severity == Error) {
    return refused("Typed state values are not representable as native source")
  }
  guard check.document is Some(parsed) else {
    return refused("Invalid typed state values")
  }
  if parsed.items.iter().map(s => (s.kind, s.explicit_label)).to_array() !=
    document.items.iter().map(s => (s.kind, s.explicit_label)).to_array() {
    return refused("Typed state values do not survive canonical reading")
  }
  Ok(text)
}
