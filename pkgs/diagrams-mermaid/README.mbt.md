# moonrockz/diagrams-mermaid

Mermaid for diagrams.mbt. This module reads Mermaid sequence diagrams into a
lossless syntax tree and a typed AST, prints canonical Mermaid, and converts the
AST to the format-independent `Sequence` model of `moonrockz/diagrams`.
`render_svg` renders a source as SVG with `moonrockz/diagrams-svg`.

The reader follows the sequence diagram grammar of Mermaid 12.2.0. The syntax
tree has every statement, every arrow, comments, directives and front matter.
It reads each sequence example of the Mermaid 12.2.0 documentation without a
diagnostic. The typed AST has every statement, with frames and boxes as nested
values. Today the conversion to the model reads participants, actors and
messages; the other statements come in the next part of the OpenSpec change
`add-mermaid-sequence`.

These rules of Mermaid apply:

- A `;` ends a statement, as a line break does. One exception comes from the
  grammar: an `autonumber` number must have a space or a line break after it,
  so `autonumber 10;` is an error in Mermaid and here, but `autonumber 10 ;` is
  not.
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

## Canonical printing

`print` writes canonical Mermaid from the AST. Reading the printed text gives an
equal AST, and printing that AST again gives the same text. AST equality does
not compare source positions. The rules are:

- The front matter comes first, then each `%%{...}%%` directive on its own
  line, then `sequenceDiagram`.
- Each statement is on its own line. Statements have two spaces of indentation
  for each level: one under the header, and one more in each frame and box.
- Keywords are in lower case, except `sequenceDiagram`, `accTitle` and
  `accDescr`. `title: text` becomes `title text`.
- A message is the sender, `()` if it has one before the arrow, the arrow as
  written, `+` or `-`, `()` if it has one after the arrow, the receiver, `:`,
  and a space and the text if the text is not empty. Notes and `link`,
  `links`, `properties` and `details` statements use the same `: text` form.
- Two note participants are joined by `,` with no spaces.
- A participant configuration is written `@{ ` and its text and ` }`.
- A `-` after an arrow that ends with `-`, such as `/|-`, has a space before it,
  because `/|--` is another arrow.
- A description with a line break (`\n` or `\r`) uses `accDescr { ... }` with
  its lines as written. Any other description uses `accDescr: text`.
- Comments are not printed, because the AST does not keep them.

```mbt check
///|
test {
  let source = "sequenceDiagram\nALT Is sick\n  B ->>- A : Not so good\nELSE is well\nNote Over A , B: fine\nEND\n"
  let printed = @mermaid.print(@mermaid.read(source).ast.unwrap())
  assert_eq(
    printed,
    "sequenceDiagram\n  alt Is sick\n    B->>-A: Not so good\n  else is well\n    note over A,B: fine\n  end\n",
  )
  assert_eq(@mermaid.read(printed).ast, @mermaid.read(source).ast)
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
