# moonrockz/diagrams-mermaid

Mermaid for diagrams.mbt. This module reads Mermaid sequence diagrams into a
lossless syntax tree and a typed AST, prints canonical Mermaid, and converts the
AST to the format-independent `Sequence` model of `moonrockz/diagrams`.
`render_svg` renders a source as SVG with `moonrockz/diagrams-svg`.

This is the first part of the OpenSpec change `add-mermaid-sequence`. Today the
reader knows the `sequenceDiagram` header, `participant`, `actor` with an
optional `as` label, `%%` comments and messages with the `->>` arrow. The other
statements and arrows come in the next parts of the change.

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

A line that is not a statement gives a diagnostic with a stable code and a span.
The reader continues at the next line, so one read reports every bad line.
Lines and columns start at 1, and columns count UTF-16 code units.

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
| `mermaid/unknown-statement` | The line is not a statement that the reader knows. |

## Render as SVG

```mbt check
///|
test {
  let r = @mermaid.render_svg("sequenceDiagram\nClient->>API: GET /forecast\n")
  assert_eq(r.media_type, "image/svg+xml")
  assert_true(r.output.unwrap().has_prefix("<svg xmlns=\"http://www.w3.org/2000/svg\""))
}
```
