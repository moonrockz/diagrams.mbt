# Pure motion and structural exploration

`moonrockz/diagrams/animation` builds immutable catalogs and finite or illustrative
plans over BPMN and sequence models. It reads no clock, DOM, environment or
network. A sample takes explicit integer milliseconds and returns active
occurrence keys, playback ordinals and integer progress fractions.

`PlaybackPlan` is the full API. The earlier `MotionPlan` constructor and its
single-flow `sample` remain available for the initial HTML tracer. `moonrockz/diagrams-svg` scenes and `moonrockz/diagrams-animated` HTML consume
`PlaybackPlan` with the same source checks.

## Explicit scenarios

A `Catalog` binds occurrence keys to an immutable source diagram. BPMN keys name
render connections while retaining their original source identity and flow value.
Sequence keys name containment paths through events, frame sections and nested
events. Repeated playback of one source occurrence has distinct step ordinals.

`Motion::serial` orders children. `Motion::parallel` starts children together and
waits for the longest branch before the next serial child. Parallel branches can
contain their own serial order; they do not wait at artificial per-message barriers.
Constructors copy input arrays. A completed finite plan has no active occurrences.

```mbt check
///|
test "sample an explicit concurrent scenario" {
  let view=@bpmn.Bpmn::new("P",[
    @bpmn.Node::new("A",Task),@bpmn.Node::new("B",Task),
  ],[@bpmn.Flow::new("AB","A","B",condition="amount > 0"),@bpmn.Flow::new("BA","B","A")])
  let catalog=@animation.Catalog::bpmn(view).catalog.unwrap()
  let a=catalog.flow("AB").unwrap().key
  let b=catalog.flow("BA").unwrap().key
  let motion=@animation.Motion::serial([
    @animation.Motion::parallel([Step(a,1000L),Step(b,500L)]),Step(a,1000L),
  ])
  let plan=@animation.PlaybackPlan::scenario(catalog,motion).plan.unwrap()
  assert_eq(plan.duration_ms,2000L)
  assert_eq(plan.sample_at(250L).active.length(),2)
  assert_eq(plan.sample_at(1000L).active[0].ordinal,2)
  assert_true(plan.sample_at(2000L).finished)
  assert_eq(catalog.flow("AB").unwrap().flow.unwrap().condition,Some("amount > 0"))
}
```

`PlaybackPlan::illustrative` visits selected authored connections independently
and repeats its period. It includes sequence messages and, by default, BPMN
sequence/message flows. Other BPMN connection kinds can be selected explicitly.
Alternative sections shown in this mode are separate illustrations, not one
asserted execution. Sampling wraps at the period; negative time starts at zero.
Finite scenarios clamp at their end. Conditions and event settings stay text.
No plan evaluates conditions, schedules timers or reports execution outcomes.

`matches(catalog)` compares the view identity and immutable source diagram.
A route supplied to another source produces `animation/plan-mismatch`, even if
local element IDs happen to match. The HTML renderer makes the same check before emitting output.

## Sequence frames and choices

The catalog retains the complete frame tree, section labels and message paths.
`PlaybackPlan::sequence` requires explicit `Selection` values for encountered alt,
opt and loop frames. Choose one alt section, include or skip an opt frame, and
provide a finite loop count. Zero repetitions are valid. Unselected branches
remain part of the source model, but contribute no scheduled steps. Choices for
nested frames are required only when that branch is selected.

Par and par-over sections become concurrent branches with their own order.
Other frame kinds retain grouping and authored order. Frame labels remain
descriptions; the planner does not interpret break conditions or model runtime
cancellation or locking.

```mbt check
///|
test "choose a bounded sequence loop" {
  let message=@sequence.Event::Message(@sequence.Message::new("A","A","retry"))
  let sequence=@sequence.Sequence::new([@sequence.Participant::new("A")],[
    Frame(@sequence.Frame::new(Loop,@sequence.Section::new([message],label="retry condition"))),
  ])
  let catalog=@animation.Catalog::sequence(sequence,view_id="Retry").catalog.unwrap()
  let selection=@animation.Selection::new(catalog.frames[0].key,Repetitions(2))
  let plan=@animation.PlaybackPlan::sequence(catalog,selections=[selection]).plan.unwrap()
  assert_eq(plan.steps.length(),2)
  assert_eq(plan.steps[0].occurrence.path,[0,0,0])
  assert_eq(plan.steps[0].occurrence.key,plan.steps[1].occurrence.key)
  assert_eq(plan.steps[1].ordinal,1)
}
```

## Structural queries

`catalog.graph` exposes immutable nodes and edges. `route` returns one directed
shortest route with authored edge order as the tie-breaker. `reachable` returns
breadth-first discovery including the start once. Both accept explicit kinds,
forward/reverse/both direction and limits. They distinguish invalid endpoints,
endpoints outside the selected view, exhausted bounds and unreachable targets.

BPMN defaults to sequence flows. Message flows are opt-in; associations and data
associations never become control transitions. Graph endpoints match actual
semantic source identities within their process instance. A pool, collapsed
subprocess or activity used as a display anchor never becomes a replacement
semantic endpoint. Hidden actual endpoints stay outside the graph, while a drawn
connection can still be a motion occurrence. Diagram queries are tested against
the standalone document graph, including imports, shared process instances,
cycles and equal-length ties.

Sequence graph vertices are message occurrences and frame controls. They preserve
alternative/parallel branches and one authored structural loop iteration. Finite
repetitions come from scenario choices. `A -> B -> A` does not create a participant
cycle. `PlaybackPlan::route` can illustrate a selected structural route. Reverse
queries retain authored connection direction; they never reverse an arrow.
A structural path makes no claim that gateway conditions or synchronization permit
an execution.

## Bounds and findings

Durations use `Int64` milliseconds. Each step must be positive; the total must be
at most `9007199254740991`, JavaScript's largest exact integer. Plans contain at
most 100,000 steps. Defaults also bound catalogs/queries to 10,000 nodes, 50,000
edges, 10,000 results, one million work units and depth 256. Work can exhaust
before a size bound; increase `Limits` explicitly when needed. Exhaustion returns
no partial catalog or plan. Empty finite scenarios finish immediately.

Planning diagnostics include `animation/invalid-identity`, `ambiguous-endpoint`,
`invalid-duration`, `invalid-selection`, `selection-required`, `plan-mismatch`,
`plan-limit` and `no-flow`, all under the `animation/` prefix. BPMN scope validation
also retains `bpmn/invalid-reference` and `bpmn/layout-limit`. Query failures are
typed values rather than unreachable results.

BPMN visibility comes from `moonrockz/diagrams/bpmn.Bpmn::scope`, shared with SVG
geometry. Ownership, collapsed/black-box flags and attachments determine it;
category groups never hide their members. A boundary follows its attached
activity's visibility, while a boundary on a visible collapsed subprocess stays
visible outside that subprocess. The standalone XML module has no dependency on
this package or SVG.
