///|
pub struct PrintResult {
  output : String?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
fn quote(value : String) -> String {
  "\"" +
  value.replace_all(old="\\", new="\\\\").replace_all(old="\"", new="\\\"") +
  "\""
}

///|
fn label(value : String?) -> String {
  match value {
    Some(v) => "[" + quote(v) + "]"
    None => ""
  }
}

///|
fn icon(value : String?) -> String {
  match value {
    Some(v) => "(" + v + ")"
    None => ""
  }
}

///|
fn parent(value : String?) -> String {
  match value {
    Some(v) => " in " + v
    None => ""
  }
}

///|
pub fn print(
  diagram : @ast.Diagram,
  limits~ : @syntax.Limits = @syntax.Limits::new(),
) -> PrintResult {
  let out = StringBuilder()
  let mut work = 0
  let mut units = 18
  if diagram.front_matter is Some(raw) {
    out.write_string(raw + "\n")
    units += raw.length() + 1
  }
  for raw in diagram.directives {
    out.write_string(raw + "\n")
    units += raw.length() + 1
  }
  out.write_string("architecture-beta\n")
  for statement in diagram.statements {
    let line = match statement.kind {
      Group(id~, icon=i, label=l, parent=p) =>
        "group " + id + icon(i) + label(l) + parent(p)
      Service(id~, icon=i, icon_text~, label=l, parent=p) =>
        "service " +
        id +
        (match icon_text {
          Some(v) => " " + quote(v)
          None => icon(i)
        }) +
        label(l) +
        parent(p)
      Junction(id~, parent=p) => "junction " + id + parent(p)
      Edge(source~, target~, label=l, source_head~, target_head~) =>
        source.id +
        (if source.group { "{group}" } else { "" }) +
        ":" +
        source.side.to_string() +
        (if source_head { "<" } else { "" }) +
        "-" +
        label(l) +
        "-" +
        (if target_head { ">" } else { "" }) +
        target.side.to_string() +
        ":" +
        target.id +
        (if target.group { "{group}" } else { "" })
      Alignment(axis~, members~) =>
        "align " +
        (match axis {
          Row => "row"
          Column => "column"
        }) +
        " " +
        members.iter().to_array().join(" ")
      Title(v) => "title " + v
      AccTitle(v) => "accTitle: " + v
      AccDescription(v) =>
        if v.contains("\n") {
          "accDescr {" + v + "}"
        } else {
          "accDescr: " + v
        }
      Comment(v) => v
    }
    work += line.length() + 1
    units += line.length() + 1
    if work > limits.work || units > limits.output {
      return {
        output: None,
        diagnostics: [
          @diagrams.Diagnostic::error(
            if work > limits.work {
              "architecture/work-limit"
            } else {
              "architecture/output-limit"
            },
            "Printer budget exhausted",
          ),
        ],
      }
    }
    out.write_string(line + "\n")
  }
  if units > limits.output {
    return {
      output: None,
      diagnostics: [
        @diagrams.Diagnostic::error(
          "architecture/output-limit", "Printer output budget exhausted",
        ),
      ],
    }
  }
  { output: Some(out.to_string()), diagnostics: [], }
}
