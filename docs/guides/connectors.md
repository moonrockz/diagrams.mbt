# Connector paths

All SVG diagram kinds accept `ConnectorOptions` through `SvgRenderer::new` and
through the `render_*` convenience functions. Offline players accept the same
renderer through `AnimatedRenderer::new(svg=...)`.

```moonbit
let renderer = @svg.SvgRenderer::new(
  connectors=@svg.ConnectorOptions::new(
    style=Curved,
    crossing=Bridge,
    minimum_approach=24.0,
    corner_radius=8.0,
    bridge_radius=5.0,
  ),
)
```

Omit `style` to keep the family's natural form. `Elbow` uses sharp turns,
`Rounded` rounds local corners, and `Curved` uses cubic transitions with
continuous internal tangents. Curves shrink within their routing corridor when
a larger transition would touch a label or outline. A failed curved request
returns a routing diagnostic; it does not substitute an elbow path.

`Bridge` is the default. One connection makes a small rounded hop at an unrelated
interior crossing. A local SVG mask opens the underpass without painting a
background patch over a tinted group. `Plain` disables hops and masks. Stroke
colour, dashes, markers, connection identities and graph queries remain intact.
Crossings create no routes or reachable nodes. Lifelines, shape borders, lane
borders, actual endpoints, declared junctions and grammar branch joins do not
become crossing bridges. Shared semantic trunks remain connected. Unrelated
collinear overlap is a routing conflict.

Automatic graph routers reserve straight terminal corridors before routing the
middle of each edge. The effective approach is at least the caller's minimum
and enough for the marker and stroke. Layout also reserves transition space.
The default minimum is 24 SVG units. Both headed endpoints retain their actual
outline or explicit port. Longer reservations can increase layout spacing.
Natural data curves retain a straight marked terminal; railroad returns and
sequence self-messages reserve their approach in their own layout.

Automatic swimlane, flowchart and state attachments use measured shape profiles.
Automatic BPMN uses the same policy. Diamond and choice profiles prefer their
four points, including wide or shallow decisions. A clear single connection
uses the appropriate cardinal point and a straight axis approach. Box profiles
spread independent attachments evenly across a padded usable span. Rounded
boxes include their corner radius in that padding; circles and other outlines
retain their real perimeter projection. Larger marker reservations increase
padding within the bounded usable span.

Each decision endpoint offers at most four sides, ordered from the preferred
side with stable clockwise ties. The router checks complete candidate routes
against outlines, labels and containment before ranking them. The cost is 32
per existing incident at a preferred point, 4 per changed side, 1 per bend, plus
route length divided by the largest measured endpoint dimension. Candidate
checks and route search consume the existing layout work budget. Exhaustion
returns the family's layout-limit diagnostic with no successful partial output.

An occupied point can move an independent connection to another clear side.
When constraints or congestion require several connections on one side, the
router spreads their anchors along the real outline and reserves distinct
terminal corridors. Those fallback anchors can lie on a diamond's sloping edge.
The router orders each fan by the remote endpoint's cross-axis position, then
source declaration order. A self-loop uses two different terminal corridors.
No post-render snapping changes the selected route.

The review and escalation gallery examples reproduce the old side-fraction
problem. Review's diamond previously used sloping-edge endpoints at
`(88,386.889)` and `(216,386.889)`, roughly 9 units from the nearest point. Clear
sides now use measured diamond points; crowded or authored sides retain safe
outline fallbacks. Connector-only paths, label positions, masks and the viewport
needed to contain those routes can change. Source text and graph identities
remain unchanged.

| Example and connection | Previous diamond endpoint | Selected diamond point |
| --- | --- | --- |
| Review `AB` target | `(88,386.889)` | `(152,354)` top |
| Review `parallel` target | `(216,386.889)` | `(80,391)` left |
| Review `BC` source | `(224,391)` | `(224,391)` right |
| Escalation `L_B_C_0` source | `(88,395.111)` | `(152,428)` bottom |
| Escalation `L_C_B_0` target | `(216,395.111)` | `(224,391)` right |

Both examples retain diamond B's outline at `(152,354)`, `(224,391)`,
`(152,428)` and `(80,391)`. Escalation's `L_A_B_0` target retains the top point.

Automatic routing also considers spare top and bottom approaches for returns
and congested bundles; vertical layouts use the corresponding clear left and
right sides. Explicit architecture ports, edge direction hints and state
boundary targets retain their authored constraints. Junctions and grammar joins
remain shared semantic points. Architecture service ports use a 12-unit inset
at each end of the side. Group-boundary ports stay within the span adjacent to
their referenced service.

Complete supplied BPMN bounds and waypoints retain their display geometry by
default, under both prefer-supplied and require-supplied policies. Set
`style_supplied_bpmn=true` to opt into the selected display styles and crossing
mode. This changes display paths only. Source ASTs, source writing, supplied
waypoints and original route geometry stay unchanged. Unsafe requested display
geometry fails with a diagnostic. Automatic BPMN layout follows the ordinary
connector defaults.

Use `renderer.connector_geometry(diagram)` to render and inspect final immutable
`ResolvedConnector` values in one layout pass. Each value exposes its source
identity, semantic endpoints, untouched `route`, final `path` commands and an
optional local underpass `mask`. `inspect_connectors(svg)` reads the same values
from this renderer's canonical artifact. It accepts generated SVG, not arbitrary
external XML. Existing layout packages still expose the original route points.
`ConnectorPath::new` and `ConnectorPath::parse` refuse non-finite coordinates.

`check_connectors` checks final line and curve geometry against caller-supplied
`ConnectorObstacle` rectangles and viewport bounds. Endpoint attachment
exemptions use the obstacle's owner identity. An underpass does not exempt a
bridge from label or shape checking. Static painters also check their changed
paths against measured protected content before returning SVG.

`connector/invalid-option` reports non-finite or negative distances, non-positive
radii and invalid budgets. `connector/routing-conflict` reports unsafe geometry.
`connector/limit` reports exhausted candidate, subdivision, segment, crossing or
output work. `ConnectorLimits` bounds these costs for each render. Failures have
no successful partial SVG. Dense crossings can reduce a hop to its readable
stroke-aware minimum; unresolved placement fails explicitly.

Stable paint order chooses crossing priority, with the first safe owner used
when the preferred connection lacks room near a bend or marker. Curve
intersection uses deterministic subdivision to a 0.05-unit tolerance. Numeric
output uses three fractional digits on all four backends. Automatic resource
identity includes connector options. Supply different `id_prefix` values for
independent inline copies, as with other renderer resources.

Scenes, selection, moving tokens, progress and configured railroad trace
highlights use these same final paths and masks. Forward and reverse playback
follow the visible geometry. Static downloads contain the canonical SVG,
including configured trace evidence, and preserve viewer position, selection
and speed. They do not rebuild layout or invoke a trace provider.

Default bridges and improved marker approaches intentionally update affected
SVG and player snapshots. Source downloads and existing gallery routes retain
their identities. The gallery includes six views of one crossing graph with
visible style and crossing settings; these variants do not count as additional
source examples. Playback remains structural illustration and does not execute
workflows or evaluate conditions.
