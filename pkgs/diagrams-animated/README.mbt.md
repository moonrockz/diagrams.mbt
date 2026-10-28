# moonrockz/diagrams-animated

`AnimatedRenderer` returns one standalone `text/html` artifact for BPMN, sequence or swimlane
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
  let sequence = @sequence.Sequence::new(
    [@sequence.Participant::new("Client"), @sequence.Participant::new("API")],
    [
      Message(@sequence.Message::new("Client", "API", "request")),
      Message(@sequence.Message::new("API", "API", "work")),
      Message(@sequence.Message::new("API", "Client", "reply")),
    ],
  )
  let result = @animated.AnimatedRenderer::new().render(Sequence(sequence))
  assert_eq(result.media_type, "text/html")
  assert_true(result.output.unwrap().contains("data-control=\"seek\""))
  assert_true(result.output.unwrap().contains("Download SVG"))
}
```

Save the string as an HTML file and open it in a browser. There are no external
scripts, fonts, requests or storage requirements. Source text is escaped SVG and
script-context JSON data, including script terminators and Unicode separators.
It never becomes active markup or code.

Use `svg=` to choose the shared theme, adaptive/fixed mode, BPMN geometry policy,
geometry limits, connector options and an ID prefix. Different prefixes isolate adjacent copies.
`playback=` accepts the full immutable `PlaybackPlan`; source mismatch produces
`animation/plan-mismatch` with no HTML. The earlier `plan=` first-flow BPMN API
remains supported. Supply one plan input. The default sequence view ID is
`sequence`; an explicit playback plan supplies its own view ID unless overridden
with `sequence_view_id=`.

```mbt check
///|
test "render a finite concurrent BPMN scenario" {
  let view = @model.Bpmn::new(
    "P",
    [
      @model.Node::new("A", Task, label="Review"),
      @model.Node::new("B", Task, label="Record"),
    ],
    [@model.Flow::new("AB", "A", "B"), @model.Flow::new("BA", "B", "A")],
  )
  let catalog = @animation.Catalog::bpmn(view).catalog.unwrap()
  let a = catalog.flow("AB").unwrap().key
  let b = catalog.flow("BA").unwrap().key
  let playback = @animation.PlaybackPlan::scenario(
    catalog,
    @animation.Motion::serial([
      @animation.Motion::parallel([Step(a, 1000L), Step(b, 500L)]),
      Step(a, 1000L),
    ]),
  ).plan.unwrap()
  let result = @animated.AnimatedRenderer::new(playback~).render(Bpmn(view))
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

Connector options belong to the supplied `SvgRenderer`. Elbow, rounded-elbow and
smooth-curve output use the same final paths for the static drawing and motion.
Bridges are the default for unrelated crossings. The underpass mask also applies
to the progress line, moving dot and selected connector, including reverse
traversal and repeated occurrences. Crossing geometry adds no graph edges.
Supplied BPMN waypoints remain unstyled unless display styling is explicitly
enabled. Connector styling does not rewrite source points or invoke a provider.

```mbt check
///|
test "play a curved sequence with the same canonical SVG" {
  let model = @sequence.Sequence::new([@sequence.Participant::new("Worker")], [
    Message(@sequence.Message::new("Worker", "Worker", "retry")),
  ])
  let svg = @svg.SvgRenderer::new(
    connectors=@svg.ConnectorOptions::new(style=Curved),
  )
  let diagram = @render.Diagram::Sequence(model)
  let scene = svg.scene(diagram).scene.unwrap()
  assert_eq(scene.canonical_svg, svg.render(diagram).output.unwrap())
  assert_true(scene.paths[0].path.contains("C"))
  let output = @animated.AnimatedRenderer::new(svg~).render(diagram)
  assert_true(output.output is Some(_))
}
```

Download SVG saves the stored canonical bytes from the ordinary SVG renderer.
It excludes display instrumentation, controls, highlights and motion, and keeps
the current playback position, occurrence, selection and speed. Configured static
trace highlights remain part of the canonical bytes. Canonical and display copies use
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

Trusted runtime sources live in `assets/player.js`, `assets/player.css`,
`assets/viewer.js` and `assets/viewer.css`.
After an intentional change run `mise run animation-assets:generate`; normal
validation rejects stale embedding. No module publication or release is performed
by these tasks.

## Viewport and theme styling

The stage provides Fullscreen, Zoom in, Zoom out and Fit. Zoom ranges from
25 to 800 percent of the fitted diagram. Fit resets pan and shows the complete
drawing. Drag an enlarged drawing with a mouse or one touch pointer. Focus the
stage to pan with the arrow keys. Viewport changes move SVG and overlays
together and preserve playback and canonical downloads.

Fullscreen uses the browser API when available. If it is denied, the stage
opens as a modal overlay. Escape or Exit closes it, restores page scrolling
and returns focus to the initiating button. Printing removes transforms,
controls and transient motion. With scripts disabled, the static SVG remains
visible and no viewport toolbar is inserted.

The shell follows the site's `site-theme` preference when storage is available,
then the system preference. Set `data-viewer-theme="light"`, `"dark"` or
`"system"` on the viewer root to override that policy per instance. This changes
the shell independently from fixed SVG colors. Blocked storage is harmless.

The root hooks are `.diagram-viewer` and `[data-diagram-viewer]`. Stable part
classes are `.diagram-viewer__header`, `.diagram-viewer__viewport`,
`.diagram-viewer__content`, `.diagram-viewer__toolbar`,
`.diagram-viewer__playback`, `.diagram-viewer__timeline`,
`.diagram-viewer__status`, `.diagram-viewer__exploration` and
`.diagram-viewer__export`. Gallery viewers omit playback parts. Use custom
properties on the root rather than private descendant selectors. Properties
inherit into the stage, including fullscreen and its modal fallback.

| Property | Default and purpose |
| --- | --- |
| `--diagram-viewer-bg` | Light `#f9fafb`, dark `#0f1014`, shell background |
| `--diagram-viewer-surface` | Light `#ffffff`, dark `#17181f`, panels |
| `--diagram-viewer-ink` | Light `#111827`, dark `#e5e7eb`, control text |
| `--diagram-viewer-muted` | Light `#6b7280`, dark `#9ca3af`, descriptions |
| `--diagram-viewer-border` | Light `#d1d5db`, dark `#374151`, boundaries |
| `--diagram-viewer-accent` | Light `#4f46e5`, dark `#a5b4fc`, primary action |
| `--diagram-viewer-accent-ink` | Light `#ffffff`, dark `#111827`, primary text |
| `--diagram-viewer-canvas-bg` | Surface, diagram stage |
| `--diagram-viewer-toolbar-bg` | Surface, fixed viewport toolbar |
| `--diagram-viewer-focus` | Accent, visible keyboard focus |
| `--diagram-viewer-font` | `system-ui, sans-serif` |
| `--diagram-viewer-font-size` | `15px` |
| `--diagram-viewer-space` | `.75rem`, panel gaps and padding |
| `--diagram-viewer-control-radius` | `.5rem`, controls |
| `--diagram-viewer-panel-radius` | `.75rem`, stage and panels |
| `--diagram-viewer-height` | `clamp(18rem, 60vh, 48rem)`, fitted stage height |

For two adjacent player roots, assign `id="review-player"` to only the player
that needs this skin. The other root retains its defaults. Controls retain
44 CSS pixel targets; keep sufficient color contrast when overriding colors.

```css
#review-player {
  --diagram-viewer-accent: #9d174d;
  --diagram-viewer-accent-ink: #ffffff;
  --diagram-viewer-surface: #fff1f2;
  --diagram-viewer-ink: #1f2937;
  --diagram-viewer-font: Georgia, serif;
  --diagram-viewer-space: 1rem;
  --diagram-viewer-control-radius: .8rem;
  --diagram-viewer-panel-radius: 1rem;
}
```


## Swimlane playback

Swimlane scenes use the same offline controls. Directed and bidirectional routes
retain traversal orientation. The direction selector also applies to swimlane
routes; the unheaded-connection option explicitly includes undirected edges.
Markers and canonical SVG never change as a route travels backward. Lane
membership never implies a connection and collapsed descendants stay outside
query scope. Parallel connection IDs remain independently bound to their paths. The Connection
selector and Show connection button select one exact occurrence independently
of endpoint-route tie-breaking.

```mbt check
///|
test "render a finite reverse swimlane scenario" {
  let view = @swimlane.Swimlane::new(
    "Review",
    [@swimlane.Node::new("A"), @swimlane.Node::new("B")],
    [@swimlane.Connection::new("AB", "A", "B", source_marker=Arrow)],
  )
  let catalog = @animation.Catalog::swimlane(view).catalog.unwrap()
  guard catalog.graph.route("B", "A") is Found(route) else {
    fail("missing return")
  }
  let playback = @animation.PlaybackPlan::route(catalog, route).plan.unwrap()
  let output = @animated.AnimatedRenderer::new(playback~).render(Swimlane(view))
  assert_true(output.output is Some(_))
  assert_eq(output.media_type, "text/html")
}
```

## Regex, EBNF and data playback

Regex, EBNF and data scenes use the same offline controls. A connector step
animates the drawn railroad or data connector path. A node visit highlights the
visited term, row or box with the `motion-visit` class and a
`data-motion-progress` value; it draws no path. Visits obey the same seeking,
speed, reduced-motion, hidden-page and print rules as connector steps. The From
and To lists contain railroad points and data values. A railroad route follows
drawn connectors and term visits; a hierarchy route visits rows and follows
connectors only where they are drawn.

Static trace highlights from `SvgRenderer::new(trace=...)` are part of the
canonical SVG. Playback overlays stay separate from them, and Download SVG
returns the canonical bytes with the configured highlights. Playback never calls
a trace provider.

```mbt check
///|
test "play a regex railroad with term visits" {
  let model = @regex.Regex::new("ab", "s", [
    @regex.Node::new("s", Sequence(["a", "b"])),
    @regex.Node::new("a", Literal("a")),
    @regex.Node::new("b", Literal("b")),
  ])
  let output = @render.Renderer::render(
    @animated.AnimatedRenderer::new(),
    Regex(model),
  )
  let html = output.output.unwrap()
  assert_true(html.contains("\"visit\":true"))
  assert_true(html.contains("no input is matched or parsed"))
}
```

## Raster downloads

PNG, JPEG and animated GIF use `moonrockz/diagrams-raster` in an embedded offline
worker. PNG defaults to transparency; JPEG requires the selected opaque
background and quality. GIF exports the submitted interval, frame rate and loop
setting from the current source-bound plan, including selected routes. Export
captures options before starting and preserves position, speed, selection and
viewport. Busy status, Cancel and errors remain in the export panel.

The renderer embeds validated default-font subsets for its canonical labels.
Pass `raster_fonts=` to provide a supported `FontSet` for other labels. Missing
glyphs or unsupported shaping disable raster export with a diagnostic while
canonical SVG remains available. GIF preparation errors leave still downloads
available. The browser needs Worker, Blob, object URLs and
`DecompressionStream('deflate')`; no external font or conversion requests occur.
See [raster export](../../docs/guides/raster-export.md) for bounds, timing,
quantization and font coverage.
