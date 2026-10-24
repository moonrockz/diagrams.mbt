# moonrockz/diagrams-bpmn

This adapter converts independent `moonrockz/bpmn` documents to
`Diagram::Bpmn` and offers `render_svg(source)`. The result uses the existing
renderer contract: optional output, media type and diagnostics.

The first implementation requires one process, one matching DI plane, unique
IDs, generic tasks, plain start/end events and sequence flows with complete
integer DI. It does not compute layout. Unsupported views, absent/invalid DI
and invalid endpoints return no diagram. Collaborations, markers, labels on
flows, view selectors, decimal render geometry and automatic layout follow in
later task groups. Choreography and conversation rendering stay deferred by the
full change; their document types follow separately.

```mbt check
///|
test "a semantic-only document needs DI in the first slice" {
  let result = @adapter.render_svg("<definitions xmlns=\"http://www.omg.org/spec/BPMN/20100524/MODEL\" targetNamespace=\"urn:example\"><process id=\"P\"><task id=\"T\"/></process></definitions>")
  assert_eq(result.media_type, "image/svg+xml")
  assert_eq(result.output, None)
  assert_eq(result.diagnostics[0].code, "bpmn/unsupported-view")
}
```

The complete DI example and its SVG/HTML snapshots are in
`tests/corpus/bpmn-2.0.2/minimal.bpmn` and `tests/bpmn-acceptance/__snapshot__/`.
The adapter does not change source documents or insert DI into them.

Adding `Bpmn` to the public `moonrockz/diagrams/render.Diagram` enum changes source
compatibility for exhaustive matches. Add a `Bpmn(view)` case or use the renderer's
unsupported-kind result. Existing sequence SVG bytes remain unchanged. No release
version change or publication is part of this slice.
