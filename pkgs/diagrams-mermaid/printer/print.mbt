///|
fn line(buf : StringBuilder, depth : Int, text : String) -> Unit {
  for _ in 0..<depth {
    buf.write_string("  ")
  }
  buf.write_string(text)
  buf.write_string("\n")
}

///|
/// `keyword`, then a space and `text` when `text` is not empty.
fn with_text(keyword : String, text : String) -> String {
  if text == "" {
    keyword
  } else {
    "\{keyword} \{text}"
  }
}

///|
/// `head`, `:`, then a space and `text` when `text` is not empty.
fn colon(head : String, text : String) -> String {
  if text == "" {
    "\{head}:"
  } else {
    "\{head}: \{text}"
  }
}

///|
fn frame_keyword(kind : @ast.FrameKind) -> String {
  match kind {
    Loop => "loop"
    Rect => "rect"
    Opt => "opt"
    Alt => "alt"
    Par => "par"
    ParOver => "par_over"
    Critical => "critical"
    Break => "break"
  }
}

///|
fn section_keyword(kind : @ast.FrameKind) -> String {
  match kind {
    Alt => "else"
    Critical => "option"
    _ => "and"
  }
}

///|
fn statements(
  buf : StringBuilder,
  depth : Int,
  list : ReadOnlyArray[@ast.Statement],
) -> Unit {
  for s in list {
    statement(buf, depth, s.kind)
  }
}

///|
fn statement(buf : StringBuilder, depth : Int, kind : @ast.StatementKind) -> Unit {
  match kind {
    Participant(p) => {
      let head = (if p.created { "create " } else { "" }) +
        (match p.keyword {
          Participant => "participant "
          Actor => "actor "
        }) +
        p.id
      let config = match p.config {
        Some(c) => "@{ \{c} }"
        None => ""
      }
      let label = match p.label {
        Some(l) => " as \{l}"
        None => ""
      }
      line(buf, depth, head + config + label)
    }
    Destroy(id) => line(buf, depth, "destroy \{id}")
    Activate(id) => line(buf, depth, "activate \{id}")
    Deactivate(id) => line(buf, depth, "deactivate \{id}")
    Message(m) => {
      let before = if m.central_before { "()" } else { "" }
      let after = match m.activation {
        Some(Activate) => "+"
        Some(Deactivate) => "-"
        None => ""
      }
      let central = if m.central_after { "()" } else { "" }
      line(
        buf,
        depth,
        colon("\{m.sender}\{before}\{m.arrow}\{after}\{central}\{m.receiver}", m.text),
      )
    }
    Note(n) => {
      let placement = match n.placement {
        LeftOf => "left of"
        RightOf => "right of"
        Over => "over"
      }
      let names = n.participants.iter().to_array().join(",")
      line(buf, depth, colon("note \{placement} \{names}", n.text))
    }
    Link(l) => {
      let keyword = match l.kind {
        Link => "link"
        Links => "links"
        Properties => "properties"
        Details => "details"
      }
      line(buf, depth, colon("\{keyword} \{l.participant}", l.text))
    }
    Title(t) => line(buf, depth, "title \{t}")
    AccTitle(t) => line(buf, depth, colon("accTitle", t))
    AccDescr(t) =>
      if t.contains("\n") {
        line(buf, depth, "accDescr {")
        buf.write_string(t)
        buf.write_string("\n")
        line(buf, depth, "}")
      } else {
        line(buf, depth, colon("accDescr", t))
      }
    Autonumber(Off) => line(buf, depth, "autonumber off")
    Autonumber(On(start~, step~)) => {
      let numbers = match (start, step) {
        (Some(a), Some(b)) => " \{a} \{b}"
        (Some(a), None) => " \{a}"
        _ => ""
      }
      line(buf, depth, "autonumber\{numbers}")
    }
    Frame(f) => {
      for i, s in f.sections {
        let keyword = if i == 0 {
          frame_keyword(f.kind)
        } else {
          section_keyword(f.kind)
        }
        line(buf, depth, with_text(keyword, s.label))
        statements(buf, depth + 1, s.statements)
      }
      line(buf, depth, "end")
    }
    Box(b) => {
      line(buf, depth, with_text("box", b.label))
      statements(buf, depth + 1, b.statements)
      line(buf, depth, "end")
    }
  }
}

///|
/// Canonical Mermaid text of `diagram`, with these rules:
///
/// - The front matter comes first, then each directive on its own line, then
///   `sequenceDiagram`.
/// - Each statement is on its own line and ends with `\n`. Statements have two
///   spaces of indentation for each level: one under the header, and one more
///   in each frame and box.
/// - Keywords are in lower case, except `sequenceDiagram`, `accTitle` and
///   `accDescr`. `title: text` becomes `title text`.
/// - A message is the sender, `()` when it has one before the arrow, the arrow
///   as written, `+` or `-`, `()` when it has one after the arrow, the
///   receiver, `:`, and a space and the text when the text is not empty.
/// - Notes and link statements have the same `: text` form. Two note
///   participants are joined by `,` without spaces.
/// - A participant configuration is `@{ ` and its text and ` }`.
/// - A description with a line break uses the `accDescr { ... }` form, with
///   its lines as written; others use `accDescr: text`.
/// - Comments are not printed, because the AST does not keep them.
pub fn print(diagram : @ast.Diagram) -> String {
  let buf = StringBuilder()
  if diagram.front_matter is Some(f) {
    buf.write_string(f)
    buf.write_string("\n")
  }
  for d in diagram.directives {
    buf.write_string(d)
    buf.write_string("\n")
  }
  buf.write_string("sequenceDiagram\n")
  statements(buf, 1, diagram.statements)
  buf.to_string()
}
