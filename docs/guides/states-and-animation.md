# States, geometry and illustrative playback

Mermaid `stateDiagram` and `stateDiagram-v2`, and PlantUML state blocks, convert
to `moonrockz/diagrams/state`. The model keeps source identities, ordered
states, composite ownership, concurrent regions, descriptions, notes and typed
pseudostates. Regions and internal descriptions never become transition edges.

Import only `moonrockz/diagrams/state` to construct a model. The executable
[model guide](../../pkgs/diagrams/state/README.mbt.md) shows copied inputs and
bounded validation. Dedicated readers avoid SVG and player dependencies.
The [Mermaid profile](mermaid-states.md) and
[PlantUML profile](plantuml-states.md) describe pinned syntax, canonical edits,
source recovery and explicit refusals. Check diagnostics before using a model.
A readable partial tree does not mean complete conversion succeeded.

## Render and inspect

Pass `State(model)` to `SvgRenderer`, or call `render_state(model)`. Adaptive,
fixed light and fixed dark modes use the shared themes. Supply a different
`id_prefix` for each inline copy. Labels remain escaped text. SVG contains no
script, external assets or executable source configuration.

`moonrockz/diagrams-svg/state-layout` exposes `layout`, immutable geometry and
`check`. State and region bounds, measured labels, original transition routes,
semantic endpoints and displayed endpoints remain available.
`Geometry.separators()` exposes the actual horizontal and vertical compartment
lines, including mixed orientations. `check` checks
containment, attachment, route collisions, 11 px minimum text and 4.5:1 minimum
contrast. `SvgRenderer.connector_geometry(State(model))` exposes final curves,
bridge hops and underpass masks; `inspect_connectors(svg)` inspects the same
canonical paths after rendering. `check_connectors` checks final paths against
explicit protected bounds with its own work budget.

State transitions use rounded elbows by default. `ConnectorOptions` selects
`Elbow`, `Rounded` or `Curved`; `crossing=Plain` opts out of default bridges.
The shared router reserves marked approaches and distributes attachments.
Region separators and shared fork/join endpoints are not unrelated crossings.

Set a composite state's `expanded=false` to collapse it. Hidden descendants
retain their model identity. A crossing display route meets the visible
composite outline, while its semantic target remains the original child.
Hidden descendants are outside the visible query and inspection scope.
Boundary symbols have explicit attachment points on their owning composite.
Unsupported symbols return diagnostics and no substitute rectangle.

Layout limits bound nodes, edges, depth, work, dimensions and SVG output.
Invalid input and exhausted limits return errors without successful partial
SVG. Model validation, readers, printers and animation each have explicit
budgets; do not treat an exhausted result as an empty successful diagram.

## Finite scenarios and structural queries

`Catalog::state(model)` creates stable identities for states, regions, notes
and transitions. Visible states and notes have visit occurrences. Regions stay
inspectable without acquiring transitions. Parallel transitions retain
separate occurrence keys even when both endpoints are equal.

A default illustration has a finite ordered occurrence set. Use
`PlaybackPlan::scenario` with `Motion::serial` and `Motion::parallel` for chosen
transitions, repeated self-loops, node visits and explicit concurrent groups.
`Step(key, duration)` names a transition; `Visit(key, duration)` names a visit.
Durations must be positive. Plans validate identities, source matching and
size/work budgets. Pure `sample_at` uses only supplied elapsed time.

`catalog.graph.route` and `reachable` follow explicit transitions. Reverse
queries keep reversed traversal and follow the actual rendered path backwards.
Unheaded relations require opt-in undirected exploration. Results distinguish
invalid endpoints, hidden endpoints, disconnection and exhaustion. Membership,
concurrency, entry/do/exit descriptions and history add no edges.

The executable [animation guide](../../pkgs/diagrams/animation/README.mbt.md)
and fresh consumer templates show the complete APIs. `AnimatedRenderer` uses
the SVG scene and a supplied plan. Its offline HTML starts still and provides
keyboard play/pause, stepping, seek, speed, inspection, route and reachability
controls. It respects reduced motion, hidden pages and printing.

Playback illustrates authored structure or caller-supplied scenarios. It does
not evaluate guards, run actions, process events, synchronize concurrent
regions, choose feasible branches or restore history. A transition to deep
history ends at the history symbol without selecting a previous child.

Downloading SVG returns the exact direct static render for the same model,
theme and connector options. Repetition, concurrency, visits, reverse paths
and current selection do not enter the download or change viewer position,
occurrence or speed.

## Migration and verification

Exhaustive matches must add `Diagram::State`, Mermaid state parsed/tree cases,
PlantUML `Kind::State` and `Document::State`, state occurrences, node/edge and
visit kinds, and SVG `NodeBindingKind::State`. Existing sequence-only APIs keep
their contracts. Ambiguous UML bodies require explicit family selection.

Run these commands from the repository root:

```shell
mise run state-mermaid-corpus:reference -- --check
mise run state-plantuml-corpus:reference -- --check
mise run validate:state-mermaid-corpus
mise run validate:state-plantuml-corpus
mise run test:state-consumer
mise run test:state
mise run gallery -- --existing-output --site-assets --qualify
mise run build:site
mise run check:site
mise run test:site
```

The reference tasks use pinned test-only Mermaid and PlantUML tools. Normal
portable tests use committed independent fixtures without JavaScript, Java,
Graphviz or network access. `test:state` qualifies stored artifacts without a
workspace or docs rebuild. After publication, `mise run test:state-consumer --
--published` checks fresh registry dependencies without workspace overrides.
