# Immutable state diagrams

`moonrockz/diagrams/state` stores state diagrams without a syntax reader, renderer,
host adapter or UI dependency. Constructors copy arrays. State IDs, region IDs,
note IDs and transition IDs are distinct identities within a diagram. Equal
labels and parallel transitions keep separate IDs.

```mbt check
///|
test "construct nested concurrent regions and preserve their order" {
  let states = [
    @state.State::new("Session", role=Composite),
    @state.State::new("Idle", region="control", descriptions=["entry / log"]),
    @state.State::new("History", region="control", role=DeepHistory),
    @state.State::new("Listening", region="network"),
  ]
  let view = @state.StateDiagram::new(
    "session",
    states,
    [
      @state.Transition::new(
        "remember",
        "Idle",
        "History",
        label="resume [ready] / log",
      ),
    ],
    regions=[
      @state.Region::new("root"),
      @state.Region::new("control", owner="Session"),
      @state.Region::new("network", owner="Session", separator=Vertical),
    ],
    notes=[
      @state.Note::new(
        "detail",
        "Description only",
        targets=["Idle"],
        region="control",
      ),
    ],
  )
  states.clear()
  assert_eq(view.states.length(), 4)
  assert_eq(view.regions[1].members, ["Idle", "History"])
  assert_eq(view.regions[2].separator, Vertical)
  assert_eq(@state.validate(view), [])
  assert_eq(view.with_direction(RL).transitions, view.transitions)
}
```

Every state has one owning region. Each non-root region names a composite owner.
A composite can own several ordered concurrent regions or an empty region.
`Region.members` preserves member order. When a caller omits it, construction
fills it from state order and `State.region`. Explicit membership must agree
with those assignments. `Horizontal` and `Vertical` retain separator orientation.
A composite's `expanded=false` hides descendants in the rendered view, while the
source model and semantic transition endpoints stay intact.

`Role` distinguishes `Simple`, `Composite`, `Initial`, `Final`, `Choice`, `Fork`,
`Join`, `ShallowHistory`, `DeepHistory`, `EntryPoint`, `ExitPoint`, `InputPin`,
`OutputPin`, `ExpansionInput` and `ExpansionOutput`. `Unsupported(symbol)` retains a source symbol for explicit renderer refusal. History retains its owning
region and does not restore a prior state. Description lines retain entry, do,
exit and internal behavior as ordered text. They never add transitions.

Transitions retain declared source and target, ID, label, line style, source and
target markers, minimum length, direction hint and optional UTF-16 source binding.
Directions and marker types use the existing pure `flowchart` value types.
Global layout direction does not reverse transition endpoints. `Note.targets`
names states; `Note.connection_targets` names transitions for link notes. Neither
kind of attachment adds a route edge.

`validate` checks duplicate IDs, missing endpoints, ownership cycles, missing
owners, membership, note targets and source spans. It validates drawn structure,
not executable UML semantics. The caller controls node, transition, region,
depth, diagnostic and work limits. `state/invalid-limits` rejects invalid options.
`state/model-limit`, `state/depth-limit`, `state/diagnostic-limit` and
`state/work-limit` report exhausted budgets. A nonempty diagnostic array is a
failed validation result. No repair or successful partial model is implied.

```mbt check
///|
test "reject invalid references and distinguish exhausted validation" {
  let view = @state.StateDiagram::new("invalid", [@state.State::new("A")], [
    @state.Transition::new("missing", "A", "B"),
  ])
  assert_true(
    @state.validate(view).any(d => d.code == "state/missing-endpoint"),
  )
  assert_eq(@state.validate(view, work_limit=1)[0].code, "state/work-limit")
  assert_eq(@state.fresh_id("A", ["A", "A:1"]).unwrap(), "A:2")
}
```

Pass `Diagram::State(view)` to a renderer. Source readers live in the Mermaid and
PlantUML modules. Geometry, scenes, finite scenarios and queries remain separate
APIs. All pure state operations run on wasm, wasm-gc, js and native. Run
`mise run test:state-consumer` to verify fresh model, dedicated-reader and player
consumers; append `-- --published` after release to use registry dependencies.
