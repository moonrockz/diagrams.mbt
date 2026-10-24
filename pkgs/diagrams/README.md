# moonrockz/diagrams

Diagramming for MoonBit. The library will support formats such as Mermaid,
PlantUML, Draw.io and Graphviz DOT.

Each diagram kind has one model that does not depend on a format. All formats of
that kind read into it and write from it. The packages are:

| Package | Contents |
| --- | --- |
| `moonrockz/diagrams` | `Diagnostic`, `Severity`, `Span` and `Position`, which all modules use |
| `moonrockz/diagrams/sequence` | The immutable `Sequence` model, links, render properties and link resolution |
| `moonrockz/diagrams/render` | The `Renderer` trait, the `Diagram` enum and the `Rendered` result |

`moonrockz/diagrams-mermaid` reads Mermaid into these models, and
`moonrockz/diagrams-svg` renders them as SVG. Requirements come as OpenSpec
changes in `openspec/changes/`.

## Sequence values

`Sequence` holds ordered participants and events, a title and accessibility
fields. Events are messages, notes, activation starts and ends, creation,
destruction, nested frames and autonumber changes. Frames have one or more
sections; each section has an optional label and ordered events. Constructors
copy caller-owned arrays, including arrays nested in sections and notes.

Participants have a declared kind, an optional box group, a link and render
properties. Messages have a line style, a head at each end, an optional number,
a link and render properties. `Participant::with_properties` and
`Message::with_properties` return new values. `Participant::render_kind` chooses
the render property kind and otherwise returns the declared kind.

A `Link` has a typed `LinkScheme`, `Smithy` or `OpenRpc`, and a target string.
Smithy targets use canonical IDs such as `example.weather#Weather`.

Implement `LinkSource` for a pure source adapter and call `resolve(sequence,
source)`. Its `participant` and `message` methods return optional render
properties for a link. Resolution visits nested frame sections, returns a new
sequence and preserves participant and event order, labels, links, groups,
numbering and metadata. An absent target produces a warning with code
`sequence/unresolved-link` and the target, and preserves any existing
properties. Source adapters cannot replace the diagram structure through this
contract. The Smithy and OpenRPC adapters belong to later changes.
