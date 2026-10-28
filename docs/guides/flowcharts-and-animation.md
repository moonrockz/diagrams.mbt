# Flowcharts and animation

Flowcharts use the same SVG, pure motion, structural exploration and offline
player APIs as the other diagram families. Mermaid `flowchart`/`graph` source
and modern/legacy PlantUML activity source convert to the immutable
`moonrockz/diagrams/flowchart` model. No library package runs Mermaid JavaScript,
PlantUML, Java, Graphviz or an external rendering service.

Import `moonrockz/diagrams/flowchart` to construct and validate a model without a
reader or renderer. Nodes keep typed roles independently of their shapes.
Connections keep explicit identities, markers, directions and labels. Groups
and explicit lanes remain separate. Notes and condition/join text stay data.

## Read native source

For Mermaid, `read_diagram(source)` returns `ParsedDiagram::Flowchart(ast)` and a
lossless source tree. `print_diagram` writes canonical typed source and
`to_flowchart` produces the model. Existing sequence-only entry points keep
their contracts. The [Mermaid flowchart guide](mermaid-flowcharts.md) describes
the pinned 12.2.0 profile, source locations and presentation limits.

For PlantUML, `read(source)` identifies activity documents inside `@startuml`
blocks. `to_diagram(document)` returns `Diagram::Flowchart(model)` and `print`
writes the same activity dialect. Dedicated activity/envelope packages support
reader-only use. Explicit body reading requires a kind and activity dialect.
The PlantUML profile stays pinned to 1.2026.9. A shared UML envelope alone does
not make class or sequence diagrams supported.

Inspect diagnostics before rendering. Invalid input, unsupported resource
requests and exhausted limits return explicit errors. Source trees preserve
invalid regions. Partial readable syntax does not assert a complete model.
Canonical printing reflects typed edits and has its own output/work bounds.

## Render and inspect geometry

Pass `Diagram::Flowchart(model)` to `SvgRenderer`, or use `render_flowchart`.
Choose adaptive, fixed light or fixed dark mode and an explicit ID prefix when
embedding copies. The result is complete standalone script-free SVG.

`moonrockz/diagrams-svg/flowchart-layout` exposes geometry and legibility checks.
Checks cover containment, endpoint attachment, label fit, unintended overlaps,
text size and contrast. All supported frozen vector corpus examples pass in
both fixed themes. Cycles and parallel edges keep separate routes. Invisible
connections constrain layout without becoming visible or playable edges.
Unsupported assets produce rendering errors and no external fetch.

Collapsed groups retain semantic endpoint identities, with crossing display
paths attached to the collapsed boundary. Hidden descendants remain outside
the visible query scope. Group or lane membership never creates a route edge.

Branch, loop and parallel regions retain condition and join-specification text
as inspectable typed catalog values. A visible region uses its actual entry or
member shape as the scene anchor. Region membership adds no graph edge and does
not assert that any branch is feasible or synchronized.

## Build a finite scenario

The following uses the same APIs as the executable fresh-player consumer:

```mbt
let catalog = @animation.Catalog::flowchart(model).catalog.unwrap()
let a = catalog.flow("AB").unwrap().key
let b = catalog.flow("BA").unwrap().key
let playback = @animation.PlaybackPlan::scenario(
  catalog,
  @animation.Motion::serial([
    @animation.Motion::parallel([Step(a, 1000L), Step(b, 500L)]),
    Step(a, 1000L),
  ]),
).plan.unwrap()
let html = @render.Renderer::render(
  @animated.AnimatedRenderer::new(playback~),
  Flowchart(model),
)
```

An explicit scenario names connection occurrences or visible node visits. It
keeps chosen branches, durations, finite loop repetitions and concurrent groups.
Repeated steps refer to one authored connection while keeping separate playback
ordinals. Default flowchart illustrations use a finite ordered occurrence set;
they do not unfold graph cycles into an unbounded timeline. Planning and
sampling use explicit inputs and elapsed time and read no clock or environment.

A structural path does not prove feasible execution. Guards are not evaluated,
actions are not run and forks do not synchronize tokens. Caller-supplied
parallel groups describe the illustration's timing. Labels and typed control
roles remain available for inspection.

## Explore and export offline

The standalone HTML contains its SVG, controls, runtime and motion data. It
starts still and needs no network, font service or UI framework. Play, pause,
restart, step, speed and seek controls support the keyboard and state feedback.
Reduced-motion preference prevents continuous animation. Hidden pages stop
animated work, and printing shows the complete static diagram.

Route and reachability queries follow actual connection direction and explicit
bounds. Reverse/bidirectional traversal retains the resolved direction.
Unheaded connections require opt-in undirected exploration. Invisible layout
constraints and note attachments are excluded. Unreachable, invalid,
outside-view and exhausted results stay distinct. Isolated visible nodes can
receive timed visits without a fabricated path.

Download SVG returns the exact canonical static bytes for the same model and
renderer options. Transient selection, route and progress overlays stay in the
viewer. Export preserves its logical position, occurrence, selection and speed.

Pass connector options through the `svg` argument of `AnimatedRenderer::new`.
The selected elbow, rounded-elbow or smooth-curve path, including bridge hops,
is shared by the static diagram, motion and canonical download. The progress
line and moving dot retain the final path's local underpass mask. Selecting a
connection keeps this separation too. Reverse routes follow the same visible
path in reverse; crossing another connection never creates a reachable endpoint.

## Verify a consumer or artifact

`mise run test:flowchart-consumer` creates fresh temporary workspaces outside
the repository and runs model-only, dedicated native-reader and SVG/player
consumers on wasm, wasm-gc, js and native. The model-only workspace includes
only the core library; the script rejects parser, renderer, host and UI
module dependencies there.

`mise run test:flowchart` qualifies stored standalone SVG and HTML without a
workspace/site rebuild. It checks both themes, script-free SVG, actual motion
paths, finite repeats, reverse traversal, isolated visits, keyboard and other
controls, reduced motion, hidden pages, print and exact downloads.

`mise run gallery -- --qualify --site-assets` checks the review gallery and
updates its checked site assets. It includes exact Mermaid and both PlantUML
source forms, adaptive/light/dark SVG and offline players. The site family
provides stable pages, source and SVG downloads and qualified player links.

Consumers with exhaustive matches must add the new flowchart cases to the
renderer diagram, Mermaid parsed/tree dispatch and scene bindings, plus the
activity cases to PlantUML document/kind values. Diagram entry points, source
identities and semantic playback contracts remain stable. Default bridge hops,
longer marked approaches and explicit connector styles change affected SVG and
HTML bytes. Reviewed portable snapshots and browser checks qualify these visual
updates and the shared player runtime.
