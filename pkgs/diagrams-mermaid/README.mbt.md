# moonrockz/diagrams-mermaid

Mermaid for diagrams.mbt. This module reads Mermaid sequence diagrams into a
lossless syntax tree and a typed AST, prints canonical Mermaid, and converts the
AST to the format-independent `Sequence` model of `moonrockz/diagrams`.
`render_svg` renders a source as SVG with `moonrockz/diagrams-svg`.

The reader follows the sequence diagram grammar of Mermaid 12.2.0. The syntax
tree has every statement, every arrow, comments, directives and front matter.
It reads each sequence example of the Mermaid 12.2.0 documentation without a
diagnostic. Today the typed AST and the model have participants, actors and
messages; the other statements come in the next parts of the OpenSpec change
`add-mermaid-sequence`.

These rules of Mermaid apply:

- A `;` ends a statement, as a line break does.
- `#` starts a comment, also in a message text, but an entity code such as
  `#9829;` is text.
- `%%` at the start of a statement starts a comment, and `%%{...}%%` is a
  directive.
- Keywords do not depend on letter case.

## Read, print and convert

The text of the syntax tree is always equal to the source, also when the source
has errors. The AST does not keep spaces or comments, so the printer writes
canonical text.

```mbt check
///|
test {
  let source = "sequenceDiagram\n%% the client calls the API\nparticipant  Client\nClient ->> API :GET /forecast\n"
  let r = @mermaid.read(source)
  assert_eq(r.tree.text(), source)
  assert_eq(r.diagnostics.length(), 0)
  let ast = r.ast.unwrap()
  assert_eq(
    @mermaid.print(ast),
    "sequenceDiagram\n  participant Client\n  Client->>API: GET /forecast\n",
  )
  let model = @mermaid.to_sequence(ast).sequence
  assert_eq(model.participants.length(), 2)
}
```

## Diagnostics

A statement that does not parse gives a diagnostic with a stable code and a
span. The reader continues at the next statement, so one read reports every
problem. Lines and columns start at 1, and columns count UTF-16 code units.

```mbt check
///|
test {
  let r = @mermaid.read("sequenceDiagram\nA->>B: hi\nfrobnicate A\n")
  let d = r.diagnostics[0]
  assert_eq(d.code, "mermaid/unknown-statement")
  assert_eq(d.span.unwrap().start.line, 3)
  assert_eq(r.ast.unwrap().statements.length(), 1)
}
```

| Code | Meaning |
| --- | --- |
| `mermaid/missing-header` | The source does not start with `sequenceDiagram`. There is no AST. |
| `mermaid/unexpected-header` | The source has a second `sequenceDiagram`. |
| `mermaid/unknown-statement` | The statement is not one that the grammar knows. |
| `mermaid/missing-message-text` | A message has no `:` and text. |
| `mermaid/invalid-message` | A message has no receiver. |
| `mermaid/invalid-participant` | A `participant`, `actor`, `create`, `destroy`, `activate` or `deactivate` statement has no valid name, or its `@{...}` configuration is not closed. |
| `mermaid/invalid-note` | A note has no placement, no participant or no text, or `left of` or `right of` has two participants. |
| `mermaid/invalid-autonumber` | `autonumber` has something other than a start, a step or `off`. |
| `mermaid/invalid-link` | A `link`, `links`, `properties` or `details` statement has no participant or no text. |
| `mermaid/invalid-title` | A `title` has no text. |
| `mermaid/missing-end` | A frame, such as `loop` or `box`, has no `end`. The span is the frame keyword. |
| `mermaid/unexpected-end` | An `end` has no open frame. |
| `mermaid/misplaced-section` | `else` is not in `alt`, `and` is not in `par`, or `option` is not in `critical`. |
| `mermaid/invalid-in-box` | A `box` has a statement that is not a participant declaration. |
| `mermaid/unclosed-directive` | A `%%{` directive has no closing `}%%`. |
| `mermaid/unclosed-description` | An `accDescr {` has no closing `}`. |

The table lists every code. This check keeps it current:

```mbt check
///|
test {
  assert_eq(@mermaid.diagnostic_codes.iter().to_array(), [
    "mermaid/missing-header", "mermaid/unexpected-header", "mermaid/unknown-statement",
    "mermaid/missing-message-text", "mermaid/invalid-message", "mermaid/invalid-participant",
    "mermaid/invalid-note", "mermaid/invalid-autonumber", "mermaid/invalid-link", "mermaid/invalid-title",
    "mermaid/missing-end", "mermaid/unexpected-end", "mermaid/misplaced-section", "mermaid/invalid-in-box",
    "mermaid/unclosed-directive", "mermaid/unclosed-description",
  ])
}
```

## Render as SVG

```mbt check
///|
test {
  let r = @mermaid.render_svg("sequenceDiagram\nClient->>API: GET /forecast\n")
  assert_eq(r.media_type, "image/svg+xml")
  assert_true(r.output.unwrap().has_prefix("<svg xmlns=\"http://www.w3.org/2000/svg\""))
}
```
