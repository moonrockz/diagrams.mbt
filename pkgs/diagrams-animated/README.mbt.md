# moonrockz/diagrams-animated

`AnimatedRenderer` returns one standalone `text/html` artifact for BPMN or sequence
diagrams. It includes a script-free display SVG, a source-bound pure plan and an
offline player. It starts paused. Its overlay follows the actual rendered paths;
removing the overlay leaves the complete static diagram.

The default illustrates authored sequence messages or BPMN sequence/message flows
in source order and repeats. Alternative branches are separate illustrations,
not one asserted execution. Explicit finite scenarios preserve the caller's order,
repetitions and concurrent branches. Conditions, timer text and event descriptions
are data. No process execution, token simulation or expression evaluation occurs.

## Generate an artifact

```mbt check
///|
test "render an offline sequence illustration" {
  let sequence=@sequence.Sequence::new([
    @sequence.Participant::new("Client"),@sequence.Participant::new("API"),
  ],[
    Message(@sequence.Message::new("Client","API","request")),
    Message(@sequence.Message::new("API","API","work")),
    Message(@sequence.Message::new("API","Client","reply")),
  ])
  let result=@animated.AnimatedRenderer::new().render(Sequence(sequence))
  assert_eq(result.media_type,"text/html")
  assert_true(result.output.unwrap().contains("data-control=\"seek\""))
  assert_true(result.output.unwrap().contains("Download SVG"))
}
```

Save the string as an HTML file and open it in a browser. There are no external
scripts, fonts, requests or storage requirements. Source text is escaped SVG and
script-context JSON data, including script terminators and Unicode separators.
It never becomes active markup or code.

Use `svg=` to choose the shared theme, adaptive/fixed mode, BPMN geometry policy,
geometry limits and an ID prefix. Different prefixes isolate adjacent copies.
`playback=` accepts the full immutable `PlaybackPlan`; source mismatch produces
`animation/plan-mismatch` with no HTML. The earlier `plan=` first-flow BPMN API
remains supported. Supply one plan input. The default sequence view ID is
`sequence`; an explicit playback plan supplies its own view ID unless overridden
with `sequence_view_id=`.

```mbt check
///|
test "render a finite concurrent BPMN scenario" {
  let view=@model.Bpmn::new("P",[
    @model.Node::new("A",Task,label="Review"),@model.Node::new("B",Task,label="Record"),
  ],[@model.Flow::new("AB","A","B"),@model.Flow::new("BA","B","A")])
  let catalog=@animation.Catalog::bpmn(view).catalog.unwrap()
  let a=catalog.flow("AB").unwrap().key
  let b=catalog.flow("BA").unwrap().key
  let playback=@animation.PlaybackPlan::scenario(catalog,
    @animation.Motion::serial([@animation.Motion::parallel([Step(a,1000L),Step(b,500L)]),Step(a,1000L)]),
  ).plan.unwrap()
  let result=@animated.AnimatedRenderer::new(playback~).render(Bpmn(view))
  assert_true(result.output != None)
  assert_true(result.output.unwrap().contains("Explicit scenario"))
}
```

## Controls and exploration

Play/Pause, Restart, Step, Speed and Position are keyboard-operable. Step advances
to the next scheduled step start, or completion. Seeking while paused stays
paused; speed changes preserve logical position. Reduced motion prevents
continuous playback and permits explicit steps/seeks. A hidden page suspends
frames without advancing through hidden time. Printing shows the static diagram
without controls, selection effects or overlays.

Choose endpoints to show one deterministic shortest structural route or upstream,
downstream or bidirectional reachability. Message flows are opt-in. Associations
are excluded from control routes. The runtime uses the catalog's actual semantic
endpoints and never substitutes a pool or collapsed scope for a hidden activity.
Sequence queries use message occurrences and frame controls, not participant
cycles. Limit exhaustion and unreachable results are distinct. Selecting a route
replaces the active plan/overlay without changing the source, layout or canonical
SVG. Reset view restores the original supplied plan.

Download SVG saves the stored canonical bytes from the ordinary SVG renderer.
It excludes display instrumentation, controls, highlights and motion, and keeps
the current playback position and selection. Canonical and display copies use
the same measured geometry. Both SVG APIs remain script-free.

## Bounds, browsers and verification

`limits=` controls catalog/plan bounds; `query_limits=` controls browser searches
independently. `output_units=` is a conservative escaped UTF-16 allocation budget,
defaulting to 32 Mi units for the HTML and embedded data. Invalid plans, missing
bindings and exhausted bounds return diagnostics without partial HTML. Geometry
has its own limits on the supplied `SvgRenderer`. All inputs remain immutable.

A browser needs SVG path geometry methods, animation frames, media queries,
JavaScript Map and Blob/object-URL downloads. CI qualifies the locked Playwright
Chromium. Planning, sampling, scene creation and HTML construction remain pure;
only the generated browser runtime reads a clock or DOM.

`mise run test:animation` qualifies current-commit stored artifacts without a
workspace or site rebuild. It uses the existing locked Playwright/Chromium. The
Site CI job runs the same harness and is required by `ci-ok`. Tests compare
browser state against MoonBit samples/routes and cover path/viewport equality,
self-messages, concurrent/repeated occurrences, hostile labels, all controls,
visibility, reduced motion, print, independent viewers and exact downloads.
Portable tests compare complete scene/HTML bytes on all four targets.

Trusted runtime sources live in `assets/player.js` and `assets/player.css`.
After an intentional change run `mise run animation-assets:generate`; normal
validation rejects stale embedding. No module publication or release is performed
by these tasks.
