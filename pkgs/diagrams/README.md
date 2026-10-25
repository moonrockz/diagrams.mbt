# moonrockz/diagrams

Diagramming for MoonBit. The library will support formats such as Mermaid,
PlantUML, Draw.io and Graphviz DOT.

Each diagram kind has one model that does not depend on a format. All formats of
that kind read into it and write from it. The packages are:

| Package | Contents |
| --- | --- |
| `moonrockz/diagrams` | `Diagnostic`, `Severity`, `Span` and `Position`, which all modules use |
| `moonrockz/diagrams/sequence` | The immutable `Sequence` model, links, render properties and link resolution |
| `moonrockz/diagrams/bpmn` | Immutable process/collaboration views, graphical markers and ownership |
| `moonrockz/diagrams/swimlane` | Immutable responsibility lanes, groups, shapes, connections and validation |
| `moonrockz/diagrams/animation` | Source-bound catalogs, oriented routes and explicit-time motion |
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

## BPMN compatibility

`Diagram` now includes `Bpmn(view)`. Callers with exhaustive enum matches must
handle this case. The immutable visual values are in `moonrockz/diagrams/bpmn`;
source-bound motion plans and structural queries are in
`moonrockz/diagrams/animation`.
The independent BPMN document module does not depend on these packages. The
module guides describe document coverage, view selection and rendering policies.
Existing sequence models and static SVG bytes keep their current behavior.


## Swimlane compatibility

`Diagram::Swimlane(view)` adds responsibility-based diagrams alongside sequence
and BPMN. Callers with exhaustive `Diagram` matches must add this case. The
swimlane model depends on neither Mermaid spelling nor BPMN documents.
Constructors copy ordered collections. Global direction is independent of each
lane/group's local direction, and never reverses a connection's source/target.
Nodes can be unowned; nested groups do not create extra lanes. Asset-dependent
shape identities remain values and fail SVG rendering explicitly.

The animation package adds typed swimlane occurrences and endpoint kinds.
`Route.reversed` and `Motion::OrientedStep` retain traversal orientation while
ordinary `Motion::Step` retains its forward-path meaning. Headless connections
require `EdgeKind::Undirected` in structural route selection. Lane membership
never adds a path. Existing sequence-specific Mermaid APIs remain unchanged.
