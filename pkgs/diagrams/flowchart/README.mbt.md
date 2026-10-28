# Flowchart values

`moonrockz/diagrams/flowchart` provides immutable flowchart models without a
syntax reader, renderer, host adapter or UI dependency. Mermaid flowcharts and
both PlantUML activity dialects convert to this model. Callers can also construct
it directly. Constructors copy caller-owned mutable collections.

```mbt check
///|
test "construct an immutable flowchart with ordinary groups" {
  let nodes = [
    @flowchart.Node::new("Read", label="Read request", groups=["Work"]),
    @flowchart.Node::new("Save", label="Save", groups=["Work"]),
  ]
  let view = @flowchart.Flowchart::new(
    "request",
    nodes[:],
    [@flowchart.Connection::new("save", "Read", "Save")],
    direction=LR,
    groups=[@flowchart.Group::new("Work")],
    notes=[
      @flowchart.Note::new("Detail", "Source text", targets=["Read"], groups=[
        "Work",
      ]),
    ],
  )
  nodes[0] = @flowchart.Node::new("Changed")
  assert_eq(view.nodes[0].id, "Read")
  assert_eq(view.lanes.length(), 0)
  assert_eq(view.groups[0].id, "Work")
  assert_eq(view.connections[0].source, "Read")
  assert_eq(@flowchart.validate(view), [])
}
```

Nodes keep stable IDs, label kinds, vector shape identity, metadata, group paths,
explicit lane ownership, typed roles, region membership and source bindings.
Shape identity and control role are separate. A generic Mermaid diamond remains
`Generic`; PlantUML conversion can supply `Decision`, `Merge`, `Fork`, `Join`,
`Start`, `ActivityFinal`, `FlowFinal`, `Connector` or `Action` explicitly.

Connections retain IDs, declared source/target, labels, line style, markers at
both ends, length/direction hints, typed role and origin. Equal labels never
merge separate occurrences. Global `TB`, `BT`, `LR` and `RL` affect placement
without reversing stored endpoints. Source conversion accepts `TD` as `TB`.

```mbt check
///|
test "control role and source identity are explicit values" {
  let origin = @flowchart.SourceBinding::new("caller", "actions/0")
  let action = @flowchart.Node::new("Review", role=Action, origin~)
  let view = @flowchart.Flowchart::new("review", [action], [])
  assert_eq(view.nodes[0].role, Action)
  assert_eq(view.nodes[0].origin.unwrap().path, "actions/0")
  assert_eq(view.nodes[0].origin.unwrap().span, None)
  assert_eq(@flowchart.validate(view), [])
  assert_true(!@flowchart.validate(view, work_limit=1).is_empty())
}
```

Groups retain their parent, label, optional local direction and expanded state.
Ordinary subgraphs stay groups. Lanes represent explicit responsibility
declarations and keep declared order. A PlantUML partition can span lane changes
without changing a node's semantic group path. Notes retain node and connection
attachments, text, placement and ownership. Note attachments are descriptive and
never become control-flow route edges.

Structured regions retain ordered branch and loop/parallel membership,
conditions, entry/exit references and join specifications. These values describe
source structure. The model never evaluates conditions, executes actions or
implements token or synchronization semantics.

`validate` uses explicit node, edge, depth and work limits. It reports duplicate
identities, missing endpoints/note targets, ownership cycles, invalid group
paths and inconsistent region references without repairing them. Source
bindings use the shared half-open UTF-16 span contract when a source position
exists. Construction, validation and transformations are deterministic on wasm,
wasm-gc, js and native.

Pass `Diagram::Flowchart(view)` to the shared SVG or animated renderer. Geometry,
scene bindings, finite plans, structural routes and reachability are separate
packages. See [flowcharts and animation](../../../docs/guides/flowcharts-and-animation.md)
and run `mise run test:flowchart-consumer` for fresh model-only, native-reader and
SVG/player consumers on all four targets.
