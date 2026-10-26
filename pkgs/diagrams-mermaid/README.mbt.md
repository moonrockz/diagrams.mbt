# moonrockz/diagrams-mermaid

Mermaid for diagrams.mbt. This module reads Mermaid sequence and native swimlane
diagrams into lossless syntax and typed AST values, prints canonical Mermaid,
and converts them to format-independent models in `moonrockz/diagrams`.
`render_svg` dispatches both supported kinds to `moonrockz/diagrams-svg`. Existing
`read`, `print`, `ReadResult` and `to_sequence` remain sequence-specific.

The reader follows the sequence diagram grammar of Mermaid 12.2.0. The syntax
tree has every statement, every arrow, comments, directives and front matter.
It reads each sequence example of the Mermaid 12.2.0 documentation without a
diagnostic. The typed AST has every statement, with frames and boxes as nested
values. Conversion keeps all sequence events, nested frames and sections,
participant kinds and boxes, title and accessibility fields, and numbering
changes. It also adds links and reports semantic problems with source spans.

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
    printed, "sequenceDiagram\n  alt Is sick\n    B->>-A: Not so good\n  else is well\n    note over A,B: fine\n  end\n",
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
    "mermaid/invalid-note", "mermaid/invalid-autonumber", "mermaid/invalid-link",
    "mermaid/invalid-title", "mermaid/missing-end", "mermaid/unexpected-end", "mermaid/misplaced-section",
    "mermaid/invalid-in-box", "mermaid/unclosed-directive", "mermaid/unclosed-description",
  ])
}
```

## Sequence model and semantics

Conversion adds undeclared participants at their first use. Participant metadata
accepts JSON and YAML scalar `type` and `alias` fields. An explicit `as` label
wins over the metadata alias. The types are `participant`, `actor`, `boundary`,
`control`, `entity`, `database`, `collections`, `queue`, `service`, `resource`
and `client`. A box has a stable ID within one conversion, its label and its
optional leading CSS colour. Boxes with equal labels remain distinct groups.

Each arrow has a solid or dotted line and independent heads at its sender and
receiver. Heads include filled, open, cross, async, filled and unfilled half
arrows, and central connections. `par_over` remains a distinct frame kind.
A `rect` frame stores its colour separately from section labels.

`A->>+B` starts an activation on `B` after the message; `B-->>-A` ends an
activation on `B` after the reply. Activations can nest. Creation is an event
before its message. A `destroy B` statement waits for the next message, which
must involve `B`, then adds the destruction event after that message. Events
that use `B` after its destruction give a diagnostic.

Autonumber changes remain in event order, including inside frames. Each message
has its visible number or `None`. The counter advances even while numbers are
hidden. Turning numbering on without a start or step resumes the counter and
step. Nonzero explicit values replace them. The counter rounds to two decimal
places after each message, as Mermaid does.

Conversion has a separate code list, `conversion_diagnostic_codes`:

| Code | Meaning |
| --- | --- |
| `mermaid/inactive-deactivation` | The participant has no active activation. |
| `mermaid/destroyed-participant` | A statement uses a destroyed participant. |
| `mermaid/conflicting-participant-kind` | A declaration changes an already declared kind. |
| `mermaid/invalid-participant-config` | A configuration has invalid fields or an unknown kind. |
| `mermaid/missing-destroying-message` | A destroy statement has no associated next message involving its participant. |
| `mermaid/invalid-links` | A `links` value is not a JSON object. |
| `mermaid/conflicting-box-group` | A participant is declared in two different boxes. |
| `mermaid/duplicate-creation` | A create statement names an existing participant. |

## Links

A known URL scheme in `link` or `links` attaches a model link to the participant.
The schemes are `smithy:` and `openrpc:`. Other URLs stay in the AST. A `links`
object selects its first URL with a known scheme in source order; later link
statements can replace that selection.

Smithy IDs use `/` in Mermaid, because `#` starts a comment. A participant link
such as `smithy:example.weather/Weather` becomes the canonical target
`example.weather#Weather`. A whole message label such as
`example.weather/GetForecast` also becomes a Smithy link. The label stays as
written. Message labels require at least two namespace identifiers, so
`read/write` stays plain text. Names follow the
[Smithy 2.0 shape ID grammar](https://smithy.io/2.0/spec/model.html#shape-id-abnf),
including an optional `$member`. An `openrpc:` URL stays an opaque target;
message labels do not infer OpenRPC links.

```mbt check
///|
test {
  let source = "sequenceDiagram\nparticipant W\nlink W: shape @ smithy:example.weather/Weather\nC->>W: example.weather/GetForecast\n"
  let converted = @mermaid.to_sequence(@mermaid.read(source).ast.unwrap())
  assert_eq(converted.diagnostics.length(), 0)
  assert_eq(
    converted.sequence.participant("W").unwrap().link.unwrap().target,
    "example.weather#Weather",
  )
}
```

The independent fixtures for the 38 frozen examples come from
`moonbit-community/mermaid@0.2.0`. Refresh them with `mise run corpus:reference`.
Normal tests read the committed JSON and compare participant order, labels,
kinds, messages, arrow forms, central connections and nested frame boundaries.

## Render as SVG

The SVG renderer draws every sequence element, including nested frames,
activations, notes, self-messages, creation and destruction. Its adaptive theme
follows the viewer's light preference. Use `moonrockz/diagrams-svg` directly
for fixed dark or light colours and public layout and legibility checks.
Run `mise run gallery` to compare all 38 frozen corpus diagrams in both themes.

```mbt check
///|
test {
  let r = @mermaid.render_svg("sequenceDiagram\nClient->>API: GET /forecast\n")
  assert_eq(r.media_type, "image/svg+xml")
  assert_true(
    r.output.unwrap().has_prefix("<svg xmlns=\"http://www.w3.org/2000/svg\""),
  )
}
```


## Native swimlane API

The native header is `swimlane-beta`. The compatibility profile is Mermaid
12.2.0, with global `TB` by default, `TD` as its alias, and `BT`, `LR` and `RL`.
Top-level subgraphs become ordered responsibility lanes; nested groups keep their
own ownership. Unowned nodes remain outside lanes. Ordinary `flowchart` and
`graph` inputs return `mermaid/unsupported-diagram` from the new dispatch API.

`read_diagram` returns a `ParsedDiagram::Sequence` or `ParsedDiagram::Swimlane`
AST with the corresponding `DiagramTree` and diagnostics. `tree.text()` always
reproduces the complete source. `print_diagram` returns optional canonical text
and diagnostics. `to_swimlane` converts the swimlane AST to immutable model values.
Syntax locations use half-open UTF-16 offsets and one-based line/column values.
Canonical AST equality ignores positions and incidental source spelling.

The following tracer covers two lanes and one cross-lane connection. The full
corpus separately covers all grammar productions, shape forms and metadata.

```mbt check
///|
test "read print and render a native two-lane swimlane" {
  let source = "swimlane-beta LR\nsubgraph Customer\nA([Request])\nend\nsubgraph Support\nB{Review}\nend\nA handoff@--> B\n"
  let result = @mermaid.read_diagram(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics, [])
  guard result.ast is Some(parsed) else { fail("missing AST") }
  let printed = @mermaid.print_diagram(parsed)
  assert_eq(@mermaid.read_diagram(printed.output.unwrap()).ast, Some(parsed))
  guard parsed is Swimlane(ast) else { fail("wrong kind") }
  let converted = @mermaid.to_swimlane(ast)
  assert_eq(converted.diagnostics, [])
  let view = converted.swimlane.unwrap()
  assert_eq(view.lanes.length(), 2)
  assert_eq(view.nodes[0].lane, Some("Customer"))
  assert_eq(view.nodes[1].lane, Some("Support"))
  assert_eq(view.connections[0].id, "handoff")
  let rendered = @mermaid.render_svg(source)
  assert_eq(rendered.media_type, "image/svg+xml")
  assert_true(rendered.output is Some(_))
}
```

### Normalization and retained data

Implicit endpoints appear in reference-defined order. Repeated subgraph IDs
merge members while retaining the first completed database registration's title,
direction and position. A nested registration can complete before its outer
one. Group membership follows the database's accepted closed members rather than
last textual mention. A style declaration can create an implicit unowned node.

Explicit and generated edge IDs follow the pinned database, including collision
counters and the one explicit-ID slot in grouped expansion. Parallel edges keep
distinct IDs. Endpoint markers determine structural traversal independently of
layout direction: one marked end points toward that end, two marked ends permit
both directions, and no marked end requires undirected route selection.

Node and edge labels retain Text, Markdown or Html kind. YAML shape data uses
pinned portable `moonbit-community/yaml@0.0.8` events to check expanded alias weight
and logical depth before `moonbitstack/moonyaml@0.1.1` resolves values. Both obey
explicit budgets with Mermaid-compatible JSON-schema behavior. Raw syntax remains in the
CST; typed values drive canonical printing. Nested metadata stays data.

Classes, style, click callbacks, links and renderer configuration read and print
without execution or resource loads. Conversion reports unapplied presentation
behavior. SVG uses explicit library options and safe label projection. Asset
and unknown shapes retain their identities, then fail rendering explicitly.

```mbt check
///|
test "grouped expansion retains one native explicit ID and every occurrence" {
  let read = @mermaid.read_diagram("swimlane-beta\nA & B e@--> C & D\n")
  guard read.ast is Some(Swimlane(ast)) else { fail("missing AST") }
  let view = @mermaid.to_swimlane(ast).swimlane.unwrap()
  assert_eq(view.nodes.length(), 4)
  assert_eq(view.connections.length(), 4)
  assert_eq(view.connections.iter().filter(edge => edge.id == "e").count(), 1)
}
```

### Swimlane diagnostics and limits

The existing sequence inventories retain their meanings. New
`swimlane_diagnostic_codes` and `swimlane_conversion_diagnostic_codes` expose the
native reader and conversion inventories. Constructed-model validation has a
separate `diagrams/swimlane.diagnostic_codes` inventory. The low-level
`swimlane-printer.diagnostic_codes` inventory contains `swimlane/print-limit` and
`swimlane/invalid-ast`.

| Code | Meaning |
| --- | --- |
| `swimlane/source-limit` | Source exceeds its configured UTF-16 limit. |
| `swimlane/work-limit` | Reading or conversion exhausts its work budget. |
| `swimlane/depth-limit` | Nesting exceeds the configured bound. |
| `swimlane/unsupported-header` | The swimlane reader receives another header. |
| `swimlane/directive` | A source directive is unclosed. |
| `swimlane/unexpected-end` | No group is open for `end`. |
| `swimlane/syntax` | A statement or its shape data is malformed. |
| `swimlane/missing-end` | A group has no closing `end`. |
| `swimlane/node-limit` | Normalized node count exceeds its bound. |
| `swimlane/edge-limit` | Expanded connections exceed their bound. |
| `swimlane/direction` | A declared direction has no supported model value. |
| `swimlane/ownership-cycle` | Normalized ownership is cyclic. |
| `swimlane/ownership` | Ownership references a missing group. |
| `swimlane/invalid-ast` | Typed values are inconsistent or cannot print as an equivalent native AST. |
| `swimlane/presentation-metadata` | A renderer-only feature remains unapplied source data. |
| `swimlane/print-limit` | Canonical printing exceeds a configured bound. |
| `mermaid/unsupported-diagram` | Kind dispatch receives an unsupported header. |
| `mermaid/print-limit` | Sequence output exceeds the new dispatch printer's bound. |

```mbt check
///|
test "documented native diagnostic inventories match exported code" {
  assert_eq(@mermaid.swimlane_diagnostic_codes, [
    "swimlane/source-limit", "swimlane/work-limit", "swimlane/depth-limit", "swimlane/unsupported-header",
    "swimlane/directive", "swimlane/unexpected-end", "swimlane/syntax", "swimlane/missing-end",
  ])
  assert_eq(@mermaid.swimlane_conversion_diagnostic_codes, [
    "swimlane/work-limit", "swimlane/node-limit", "swimlane/edge-limit", "swimlane/depth-limit",
    "swimlane/direction", "swimlane/ownership-cycle", "swimlane/ownership", "swimlane/invalid-ast",
    "swimlane/presentation-metadata",
  ])
}
```

`swimlane-syntax.Limits::new` supplies explicit limits to reading, printing and
conversion. Defaults are 16 Mi UTF-16 source/output units, 10,000 nodes, 50,000
expanded connections, nesting 256, one million work units and 256 diagnostics.
Metadata has separate `metadata_depth` and `metadata_work` settings. Metadata
depth supports 1 through 256 and defaults to 256; unsupported settings fail with
a depth-limit finding before processing. The positive metadata work budget
defaults to one million units and also obeys the overall work budget. Diagram
group depth remains independently configurable. Nested metadata prints in block
YAML where the pinned native lexer requires it.

Limit exhaustion returns a distinct finding without apparently complete output.
The renderer propagates failed-stage diagnostics without returning empty text as
successful SVG.

The test-only reference harness pins Mermaid 12.2.0 and its lockfile. Run
`mise run swimlane-corpus:reference -- --check` to check normalized nodes, labels, shapes,
connections, IDs, styles, markers, lengths, directions and ownership against the
real parser/database. Omit `--check` when intentionally refreshing reference
fixtures. `mise run validate:swimlane-corpus` verifies source digests
and portable generated fixtures; `swimlane-corpus:generate` refreshes embeddings.
The frozen grammar-production and shape manifests describe coverage. Mermaid
and its JavaScript dependencies are used only by the test oracle.

## Native ZenUML interactions

`zenuml` uses a separate typed reader and canonical printer. Its conversion
produces the shared sequence model. Participant icon references preserve all
523 keys in the pinned annotator registry, separately from semantic kinds.
Nested calls create scoped activations. Try/catch/finally sections keep their
explicit roles. The existing sequence-only APIs keep their types.

```mbt check
///|
test {
  let source = "zenuml\n@Actor User\n@PostgreSQL Store\nUser->Store: query\n"
  let parsed = @mermaid.read_diagram(source)
  assert_eq(parsed.tree.text(), source)
  guard parsed.ast is Some(@mermaid.ParsedDiagram::Zenuml(ast)) else {
    fail("ZenUML expected")
  }
  let converted = @mermaid.to_zenuml_sequence(ast)
  assert_eq(converted.sequence.unwrap().participants.length(), 2)
  assert_eq(
    converted.sequence.unwrap().participants[0].icon.unwrap().key,
    "actor",
  )
  assert_true(@mermaid.render_svg(source).output is Some(_))
}
```

See [Mermaid ZenUML](../../docs/guides/mermaid-zenuml.md) for the profile,
limits, diagnostics, icon provenance and exhaustive-match migration.

## Native architecture diagrams

`architecture-beta` uses typed groups, services, junctions, explicit ports,
labelled connections, group-boundary attachments and row/column alignments.
`read_diagram` returns `ParsedDiagram::Architecture` and
`DiagramTree::Architecture`. `to_architecture` returns an optional immutable
architecture model with diagnostics. `print_diagram` prints typed AST fields.
Existing sequence-specific entry points keep their original types.

The reader has a separate optional `architecture_limits` value. Its defaults
bound source and output to 16,777,216 UTF-16 units, nodes and alignments to
10,000, connections to 50,000, depth to 256, diagnostics to 256 and work to
1,000,000. Codes use the stable `architecture/` prefix. Syntax/header, source,
output, node, edge, alignment, depth, diagnostic and work failures are distinct.
Conversion adds duplicate-ID, invalid-parent, ownership-cycle, invalid-endpoint,
invalid-group-attachment and invalid-alignment findings. Source metadata is
retained with `architecture/metadata-option`; it never controls library layout.

See [the architecture guide](../../docs/guides/mermaid-architecture.md) for the
frozen reference profile, symbols, rendering limits, playback and enum migration.
