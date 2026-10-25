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
subprocess contents are omitted using the core model's shared `Bpmn::scope`
visibility. Boundary events inherit their activity's visibility. Message connections may use visible display
anchors while their source flow keeps its original semantic endpoint identities.

Supplied numeric tokens are preserved verbatim. Layout calculations require
finite coordinates of magnitude at most one billion and positive shape extents.
`svg_number` formats generated numbers to three decimal places with deterministic
half-away-from-zero rounding. Limits bound visible nodes, edges, work and output.
Failure returns no partial geometry.

## Automatic layout

Each containment scope uses iterative strongly connected component condensation
and ranks the resulting acyclic graph. Source order breaks ties. Measured task
labels and external captions determine column widths and row heights. Pools and
nested lanes form bands; expanded subprocesses have their own scopes. Connected
data/artifacts can follow flow nodes into lanes while keeping their subprocess
ownership. Category membership in `Ownership.groups` reserves shared member bands
and determines group frames. Disconnected components pack in source order.

Boundary events are placed after their activity and reserve caption space.
Connections use actual shape ports, with distinct ports for parallel edges.
Circles, diamonds and stores use their outlines rather than bounding-box corners.
The orthogonal router tries simple channels, then a bounded coordinate-grid A*
search around unrelated shapes and label boxes. Return edges and self-loops can
use outer channels. Connections whose endpoints share a pool or expanded scope
stay within that scope. Cross-pool messages keep their declared visible endpoints.
Connection labels avoid shapes, other labels and previously routed segments;
subsequent connections route around them. No external layout service is used.

The default bounds are 10,000 visible nodes, 50,000 connections, one million work
units and 16 Mi UTF-16 output units. Increase `Limits` explicitly for larger
searches. A dense graph can exhaust search before it reaches a node/edge bound;
that produces `bpmn/layout-limit` and no partial layout. The frozen corpus has no
legibility findings in either palette. Arbitrary inputs are not promised an
optimal embedding or zero line crossings.

`check(geometry, palette)` returns bounded, read-only findings for unintended
shape, label and route intersections, text fit and minimum size, contrast,
ownership containment, boundary attachment and endpoint attachment. Exhaustion
is explicit. Supplied geometry is never changed. Pools, lanes, expanded scopes,
groups and their contained artifacts can overlap intentionally. Data and artifacts
inside lanes use visual containment because they cannot have a flowNodeRef.

Use `bpmn_palette(theme.dark)` or its light counterpart to obtain the shared BPMN
family hues with text shades that meet 4.5:1 against background and family fill.
The sequence renderer continues to use its existing palettes and layout package.

## Example

```mbt check
///|
test "compute and check a semantic view without DI" {
  let view=@model.Bpmn::new("P",[
    @model.Node::new("Start",StartEvent,label="Start"),
    @model.Node::new("Review",UserTask,label="Review request"),
  ],[@model.Flow::new("Request","Start","Review",label="request")])
  let result=@layout.layout(view,policy=Automatic)
  let geometry=result.geometry.unwrap()
  assert_eq(result.diagnostics,[])
  assert_eq(geometry.source,Automatic)
  assert_eq(@layout.check(geometry,@layout.bpmn_palette(@theme.Theme::classic().dark)),[])
}
```
