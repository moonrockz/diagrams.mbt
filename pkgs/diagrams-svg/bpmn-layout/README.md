# BPMN geometry

`layout(view, policy=PreferDi, limits=Limits::new())` is a pure operation over
`moonrockz/diagrams/bpmn`. It returns optional immutable geometry and diagnostics.
It has no XML parser, DOM, clock or I/O dependency.

- `PreferDi` uses complete supplied geometry or computes the entire view when
  bounds or waypoints are missing. Invalid supplied values are errors.
- `RequireDi` returns no geometry unless required supplied geometry is complete.
- `Automatic` ignores supplied coordinates and computes the entire view.

`Geometry.shapes` and `connections` retain source model values, exact bounds and
waypoints alongside numeric boxes. Labels retain exact bounds and font settings.
A single `translate_x`/`translate_y` and canvas extent enclose every visible shape,
label and waypoint with padding. Renderers apply that translation once. Hidden
subprocess contents are omitted. Message connections may use visible display
anchors while their source flow keeps its original semantic endpoint identities.

Supplied numeric tokens are preserved verbatim. Layout calculations require
finite coordinates of magnitude at most one billion and positive shape extents.
`svg_number` formats generated numbers to three decimal places with deterministic
half-away-from-zero rounding. Limits bound visible nodes, edges, work and output.
Failure returns no partial geometry. The initial automatic fallback measures
labels, places containment scopes, attaches boundary events and draws orthogonal
connections. Topology-aware ranking and obstacle routing belong to group 10.

`check(geometry, palette)` returns bounded, read-only findings for unintended
shape, label and route intersections, text fit and minimum size, contrast,
ownership containment, boundary attachment and endpoint attachment. Exhaustion
is explicit. Supplied geometry is never changed. Pools, lanes, expanded scopes,
groups and their contained artifacts can overlap intentionally. Data and artifacts
inside lanes use visual containment because they cannot have a flowNodeRef.

Use `bpmn_palette(theme.dark)` or its light counterpart to obtain the shared BPMN
family hues with text shades that meet 4.5:1 against background and family fill.
The sequence renderer continues to use its existing palettes and layout package.
