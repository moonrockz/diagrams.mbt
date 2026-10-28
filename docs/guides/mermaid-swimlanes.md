---
title: Mermaid swimlanes
summary: Read native responsibility diagrams, render vector SVG and explore directed interactions offline.
order: 3
---
# Mermaid swimlanes

Use native Mermaid 12.2.0 `swimlane-beta` input. Top-level subgraphs are ordered
responsibility lanes; nested subgraphs remain groups. Nodes outside every lane
stay unowned. This format describes steps and interactions without BPMN execution
semantics. Ordinary `flowchart` and `graph` headers remain unsupported inputs.

```mermaid
swimlane-beta LR
  subgraph Customer[Customer]
    A([Request])
  end
  subgraph Support[Support]
    B{Review}
    C((Complete))
  end
  A <-->|review or return| B
  B -->|approve| C
```

`TB` is the default direction. `TD` aliases `TB`; `BT`, `LR` and `RL` reverse
or rotate the flow axis. Lane order stays left-to-right for vertical flow and
top-to-bottom for horizontal flow, including reverse directions. Local directions
belong to their lane or group. They never change a connection's logical endpoints.

## Read, print and render

The [Mermaid module guide](../../pkgs/diagrams-mermaid/README.mbt.md) contains
compiled examples of `read_diagram`, `print_diagram` and `to_swimlane`. The new
parsed-diagram union dispatches sequence and swimlane source. Existing `read`,
`print`, `ReadResult`, sequence AST/CST types and `to_sequence` retain their
sequence-only contracts. `render_svg(source)` dispatches both supported kinds
and returns diagnostics with absent output on failure.

Source reproduction keeps all original text, including malformed regions,
comments, CRLF, front matter and quote spelling. Canonical printing writes one
statement per line with two-space group indentation and preserves statement order.
Diagnostic spans use half-open UTF-16 offsets and one-based line/column positions.

The model keeps distinct parallel connections, endpoint markers, line style,
minimum-length hints, shape identities and decoded labels. Generated identities
are deterministic. Repeated lane declarations merge membership while retaining
the first completed database registration's title, direction and position. A
nested repeat can complete before its outer declaration.

## Static views

Compare the review example in [dark](/assets/examples/swimlane-review-dark.svg)
and [light](/assets/examples/swimlane-review-light.svg), or read the
[native source](/assets/examples/swimlane-review.mmd). The gallery also contains
all four effective directions and empty, unowned, nested and collapsed scopes.

The [SVG module guide](../../pkgs/diagrams-svg/README.mbt.md) describes geometry,
themes, limits and the public legibility checker. Static output is standalone,
script-free SVG. Explicit ID prefixes isolate inline copies. Shared connector
updates deliberately change affected sequence, BPMN and swimlane SVG bytes for
default bridge hops and longer marked approaches. Explicit styles also change
display geometry. Source identities, semantic endpoints and query results stay
stable; portable snapshots and browser checks qualify the visual updates.

Built-in vector shapes and their aliases use the shared diagram palettes.
Image/icon assets and unknown shapes return explicit errors without output or
resource fetches. Markdown and HTML labels use safe text projection, with
diagnostics for unsupported formatting. Author CSS, callbacks and Mermaid renderer
configuration remain source metadata; they do not execute or override explicit
library renderer options.

## Follow interactions

Open the review player in [dark](/assets/examples/swimlane-review-dark.html) or
[light](/assets/examples/swimlane-review-light.html), or inspect an explicit
[reverse traversal](/assets/examples/swimlane-reverse.html) or a finite
[concurrent scenario](/assets/examples/swimlane-scenario.html). Play, pause, seek,
speed, keyboard controls, reduced motion and hidden-page suspension use the same
offline player as sequence and BPMN. Download SVG returns the canonical static
bytes without overlays and preserves viewer state.

Choose a specific Connection and Show connection to inspect a parallel handoff by
its own ID; Play then follows only that connection. Structural routes follow endpoint markers. A marker on one end points toward that
end; markers at both ends permit either traversal. Headless connections are
available only with the explicit unheaded-connection option. Invisible connections
constrain layout but create no playback occurrence or route. Lane membership and
visual proximity never add a path.

`Catalog::swimlane` retains typed source connections. `Route.reversed` records
the orientation of every route edge. `Motion::OrientedStep` samples a path in that
orientation without changing its endpoint markers. `Motion::Step` keeps its
existing forward-path behavior. Finite scenarios can repeat an occurrence or use
concurrent branches. Neither routes nor scenarios evaluate conditions, execute
callbacks, simulate tokens or assert a feasible business process.

Collapsed groups show their label and boundary. Cross-boundary handoffs attach
visually to the nearest visible ancestor while retaining their logical endpoints.
Hidden descendants remain outside route-query scope. An explicitly declared
group endpoint is distinct from an anchor used only for display.

## Compatibility and qualification

Callers with exhaustive matches must handle `Diagram::Swimlane`, the new animation
occurrence/endpoint/edge kinds, `Motion::OrientedStep` and the SVG binding variant.
The shared browser runtime can change old animated HTML bytes; old sequence/BPMN
playback contracts and static SVG bytes remain covered by qualification.

The native beta grammar and test oracle are pinned to Mermaid 12.2.0. Production
code does not invoke Mermaid or JavaScript. Library tests cover wasm, wasm-gc,
js and native. Run `mise run gallery` to generate review artifacts, `mise run
test:svg` for static browser checks and `mise run test:animation` for offline
motion and canonical export. Limits reject excessive source, nesting, expanded
edges, work and output rather than presenting partial output as complete.
