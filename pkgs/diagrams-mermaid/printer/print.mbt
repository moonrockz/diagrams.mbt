///|
/// Canonical Mermaid text of `diagram`. The text starts with
/// `sequenceDiagram`. Each statement is on its own line with two spaces of
/// indentation and ends with `\n`. A message is `sender`, the arrow as written,
/// `receiver`, `: ` and its text.
pub fn print(diagram : @ast.Diagram) -> String {
  let buf = StringBuilder()
  buf.write_string("sequenceDiagram\n")
  for statement in diagram.statements {
    buf.write_string("  ")
    match statement {
      Participant(p) => {
        buf.write_string(
          match p.keyword {
            Participant => "participant "
            Actor => "actor "
          },
        )
        buf.write_string(p.id)
        if p.label is Some(label) {
          buf.write_string(" as \{label}")
        }
      }
      Message(m) => {
        buf.write_string("\{m.sender}\{m.arrow}\{m.receiver}:")
        if m.text != "" {
          buf.write_string(" \{m.text}")
        }
      }
    }
    buf.write_string("\n")
  }
  buf.to_string()
}
