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
| `moonrockz/diagrams/flowchart` | Immutable actions, control regions, graph connections, groups, explicit lanes, notes and validation |
| `moonrockz/diagrams/regex` | Immutable regex expressions: literals, classes, sets, anchors, groups, lookarounds, alternatives and symbolic repeats |
| `moonrockz/diagrams/ebnf` | Immutable grammars: ordered rules and notes, terminals, symbolic references, options, repetitions, counts and exclusions |
| `moonrockz/diagrams/data-tree` | Immutable ordered data: objects, arrays, exact-number scalars, member identities and view highlights |
| `moonrockz/diagrams/railroad-trace` | Railroad topology, immutable trace values, the `RailroadTraceProvider` trait and trace validation |
| `moonrockz/diagrams/animation` | Source-bound catalogs, oriented routes and explicit-time motion |
| `moonrockz/diagrams/render` | The `Renderer` trait, the `Diagram` enum and the `Rendered` result |

`moonrockz/diagrams-mermaid` reads Mermaid and `moonrockz/diagrams-plantuml` reads
PlantUML into these models, and
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

## Regex, EBNF and data-tree compatibility

`Diagram` now includes `Regex(model)`, `Ebnf(grammar)` and `DataTree(tree)`.
Callers with exhaustive `Diagram` matches must add these cases. The three models
are flat, immutable arenas: composite nodes name their children by identity, so
`validate` and `Index::build` find missing nodes, containment cycles and orphans
without recursion. Constructors copy caller arrays. Identities come from
ownership paths or explicit caller values, never from labels.

- Regex bounds are symbolic; `{1000000}` is one node. Assertions are
  constraints, not alternatives.
- EBNF references resolve by name. A missing or repeated name is a warning and
  stays a visible nonterminal; an explicit target identity that names no rule is
  an error. Recursive references never expand. An exclusion constrains its left
  term.
- Data trees keep member order, repeated names and exact number lexemes. Scalar
  text is never a reference.

The animation package adds `OccurrenceKind::Railroad`, `DataConnector` and
`Visit`, the `VisitKind` enum, `Motion::Visit`, `NodeKind::RailroadPoint` and
`DataValue`, `EdgeKind::Railroad` and `Containment`, and the `visit` field of
`ScheduledStep` and `Active`. `Occurrence` has four new optional fields. Callers
with exhaustive matches, or with record literals of these types, must add the new
cases and fields. Existing connection steps, orientation and BPMN, sequence and
swimlane behavior are unchanged.

```moonbit notest
///|
test "a constructed grammar keeps a recursive reference symbolic" {
  let grammar = @ebnf.Grammar::new(
    "lists",
    [Rule(@ebnf.Rule::new("r", "list", body="s"))],
    [
      @ebnf.Node::new("s", Sequence(["x", "o"])),
      @ebnf.Node::new("x", Terminal("x", Double)),
      @ebnf.Node::new("o", Optional("again")),
      @ebnf.Node::new("again", Reference("list", None)),
    ],
  )
  let index = @ebnf.Index::build(grammar).index.unwrap()
  assert_eq(index.resolution("again"), Some(Resolved("r")))
  assert_eq(grammar.nodes.length(), 4)
}
```

## Flowchart compatibility

`Diagram::Flowchart(view)` uses the same format-independent model for Mermaid
flowcharts and both PlantUML activity dialects. Nodes keep shape identity
separate from typed control roles; plain Mermaid diamonds do not acquire
execution semantics. Notes distinguish node targets from connection targets.
Connection direction hints affect placement without reversing semantic endpoints.
Constructors and transformations copy mutable input collections.

Exhaustive consumers must add the flowchart renderer, catalog, node/visit and
scene variants. Mermaid dispatch and PlantUML document/kind enums also have new
variants. Existing named APIs and sequence, BPMN, swimlane, architecture,
railroad and data-tree contracts remain available. Read the checked
[model guide](flowchart/README.mbt.md) and
[playback guide](../../docs/guides/flowcharts-and-animation.md).
