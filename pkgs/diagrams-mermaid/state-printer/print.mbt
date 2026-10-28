///|
pub struct Printed {
  output : String?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
fn quoted(text : String) -> String {
  "\"" + text + "\""
}

///|
fn endpoint(id : String, classes : ReadOnlyArray[String]) -> String {
  id + (if classes.is_empty() { "" } else { ":::" + classes[0] })
}

///|
/// Canonical output is generated from typed statements and checked against the
/// native grammar. Invalid edits never fall back to the original source.
pub fn print(
  diagram : @ast.Diagram,
  limits~ : @syntax.Limits = @syntax.Limits::new(),
) -> Printed {
  fn failed(code : String, message : String) -> Printed {
    { output: None, diagnostics: [@diagrams.Diagnostic::error(code, message)], }
  }
  if !["stateDiagram", "stateDiagram-v2"].contains(diagram.header) {
    return failed("state/invalid-ast", "Invalid state header")
  }
  if limits.output < 0 ||
    limits.work < 1 ||
    diagram.statements.length() > limits.work {
    return failed("state/work-limit", "Printer work budget exhausted")
  }
  let out = StringBuilder()
  let mut length = 0
  let mut work = 0
  let mut exceeded = false
  fn emit(text : String) {
    if exceeded {
      return
    }
    if text.length() > limits.output - length {
      exceeded = true
      return
    }
    length += text.length()
    work += text.length()
    if work > limits.work {
      exceeded = true
      return
    }
    out.write_string(text)
  }
  if diagram.front_matter is Some(text) {
    emit(text + "\n")
  }
  for text in diagram.directives {
    emit(text + "\n")
  }
  emit(diagram.header + "\n")
  let mut depth = 0
  for statement in diagram.statements {
    work += 1
    if work > limits.work {
      return failed("state/work-limit", "Printer work budget exhausted")
    }
    if statement.kind == EndComposite {
      depth -= 1
    }
    if depth < 0 || depth > limits.depth {
      return failed("state/invalid-ast", "Invalid composite boundaries")
    }
    let indent = StringBuilder()
    for _ in 0..<depth {
      indent.write_string("  ")
    }
    emit(indent.to_string())
    match statement.kind {
      State(id~, label~, role~, description~, classes~) => {
        if classes.length() > 1 {
          return failed(
            "state/invalid-ast", "Only one inline state class is representable",
          )
        }
        if label != None || role != None {
          emit("state ")
        }
        if label is Some(label) {
          emit(quoted(label) + " as ")
        }
        emit(endpoint(id, classes))
        if role is Some(role) {
          emit(" <<" + role + ">>")
        }
        if description is Some(description) {
          emit(":" + description)
        }
      }
      Composite(id~, label~) => {
        emit("state ")
        if label is Some(label) {
          emit(quoted(label) + " as ")
        }
        emit(id + " {")
        depth += 1
      }
      EndComposite => emit("}")
      Concurrent => emit("--")
      Transition(source~, target~, label~, source_classes~, target_classes~) => {
        if source_classes.length() > 1 || target_classes.length() > 1 {
          return failed(
            "state/invalid-ast", "Only one inline endpoint class is representable",
          )
        }
        emit(
          endpoint(source, source_classes) +
          " --> " +
          endpoint(target, target_classes),
        )
        if label is Some(label) {
          emit(" : " + label)
        }
      }
      Description(id~, text~) => emit(id + " : " + text)
      Note(target~, placement~, text~) =>
        emit("note " + placement + " of " + target + "\n" + text + "\nend note")
      FloatingNote(id~, text~) => emit("note " + quoted(text) + " as " + id)
      Direction(d) => emit("direction " + d)
      AccTitle(text) => emit("accTitle: " + text)
      AccDescription(text) => emit("accDescr {\n" + text + "\n}")
      Presentation(text) | Comment(text) => emit(text)
      Invalid(_) =>
        return failed(
          "state/invalid-ast", "Cannot print an invalid source statement",
        )
    }
    emit("\n")
  }
  if exceeded {
    return failed(
      if work > limits.work {
        "state/work-limit"
      } else {
        "state/output-limit"
      },
      "Canonical output budget exhausted",
    )
  }
  if depth != 0 {
    return failed("state/invalid-ast", "Unclosed composite")
  }
  let output = out.to_string()
  let checked = @syntax.read(
    output,
    limits=@syntax.Limits::new(
      source=limits.output,
      output=limits.output,
      states=limits.states,
      regions=limits.regions,
      transitions=limits.transitions,
      depth=limits.depth,
      diagnostics=limits.diagnostics,
      work=limits.work,
    ),
  )
  if checked.diagnostics.iter().any(d => d.severity == Error) ||
    checked.ast != Some(diagram) {
    return failed(
      "state/invalid-ast", "Typed values cannot be represented by native Mermaid state syntax",
    )
  }
  { output: Some(output), diagnostics: [], }
}
