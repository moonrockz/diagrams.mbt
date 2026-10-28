# Swimlane geometry

This package lays out the immutable `diagrams/swimlane` model. Inputs and output
are explicit values. It imports no Mermaid or BPMN document module.

```mbt check
///|
test "measured lanes retain source order and expose checker findings" {
  let view = @model.Swimlane::new(
    "review",
    [
      @model.Node::new("A", lane="Customer"),
      @model.Node::new("B", lane="Support"),
    ],
    [@model.Connection::new("AB", "A", "B")],
    direction=LR,
    lanes=[@model.Lane::new("Customer"), @model.Lane::new("Support")],
  )
  let result = @layout.layout(view)
  let geometry = result.geometry.unwrap()
  let customer = geometry.shapes
    .iter()
    .find_first(s => s.id == "Customer")
    .unwrap()
  let support = geometry.shapes
    .iter()
    .find_first(s => s.id == "Support")
    .unwrap()
  assert_true(customer.box.y < support.box.y)
  assert_eq(geometry.connections[0].connection.id, "AB")
  assert_eq(
    @layout.check(geometry, @layout.palette(@theme.Theme::classic().light)),
    [],
  )
  assert_eq(
    @layout.layout(view, limits=@layout.Limits::new(work=1)).geometry,
    None,
  )
}
```

`layout` walks nested scopes with an explicit stack. It measures labels, keeps
empty lanes, packs unowned nodes separately and ranks condensed cycles. Local
scope directions are independent of the global flow direction. Reversing flow
never reverses source lane order or connection identities. Minimum-length hints
reserve additional rank gaps. Disconnected children retain declaration order.

Each vector silhouette and edge port share `outline`. Routing uses bounded
orthogonal search around unrelated shapes and label boxes. Return edges,
self-loops and parallel handoffs retain distinct paths and ports. Visible edges
that cross a collapsed boundary attach to that ancestor while their stored
connection keeps its logical endpoints. Hidden internal edges are omitted.
Invisible connections constrain placement but do not paint or animate.

`Limits::new(minimum_approach=24.0)` reserves every straight endpoint corridor
before routing middle segments or placing connection labels. This prevents an
earlier edge from blocking a later marker approach. Return and parallel routes
use separate collinear channels, while transverse crossings remain available
for display bridges. Compact symbols with external labels use a clear side;
concave silhouettes retain their actual outline attachment. Larger minima
increase the automatic scope spacing. Existing route points remain available
separately from the renderer's final styled paths.

Side ports follow the other endpoints' cross-axis order, with declaration order
breaking ties for parallel identities. The bounded grid search indexes obstacle
rows and columns and caches segment checks. Optional channels keep room beside
existing spans for safe bends and bridges; actual endpoint coordinates stay fixed.

`Limits::new` defaults to 10,000 elements, 50,000 connections, depth 256,
1,000,000 work units and 16 Mi UTF-16 output units. Ownership or reference errors,
unsupported shapes and exhausted work return no partial geometry. Routing can
fail explicitly when those bounds cannot find a clear path.

`check` reports `Overlap`, `Fit`, `Size`, `Contrast`, `Containment`, `Endpoint`
and `Limit` findings. Intended container ownership is permitted. It does not
move or repair supplied geometry. Use `palette` on the shared theme palette to
apply the exact ink shades used by the swimlane painter. Derived SVG numbers
have at most three fractional digits and are stable on all four backends.
