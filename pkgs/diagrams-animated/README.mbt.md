# moonrockz/diagrams-animated

`AnimatedRenderer` emits a standalone `text/html` artifact. It embeds the static
SVG and an offline browser runtime. Playback starts paused and illustrates one
authored BPMN connection. Play/Pause uses a separate overlay; static SVG output
stays script-free. This is an illustration, with no process execution, token
simulation, condition evaluation or event scheduling.

```mbt check
///|
test "construct a pure first-flow plan and render HTML" {
  let nodes = [
    @model.Node::new("A", StartEvent, bounds={ x: 20, y: 20, width: 36, height: 36 }),
    @model.Node::new("B", EndEvent, bounds={ x: 120, y: 20, width: 36, height: 36 }),
  ]
  let flow = @model.Flow::new("F", "A", "B", points=[{ x: 56, y: 38 }, { x: 120, y: 38 }])
  let view = @model.Bpmn::new("P", nodes, [flow])
  let plan = @animation.MotionPlan::new("P", "F").unwrap()
  assert_eq(plan.sample(250), (250, 1000))
  let result = @animated.AnimatedRenderer::new(plan~).render(Bpmn(view))
  assert_eq(result.media_type, "text/html")
  assert_true(result.output.unwrap().contains("<button"))
}
```

Save the returned string as an HTML file and open it in a browser. The button is
keyboard-operable. Reduced-motion preference allows explicit quarter-step
inspection; hidden pages suspend frames; print hides controls and overlays.
Only validated integer geometry enters JavaScript. Source labels stay escaped
SVG text. Neither planning nor rendering reads a clock or DOM.

This first slice supports BPMN only and one repeating connection, chosen by a
`MotionPlan` or the first flow. Full finite scenarios, concurrency, sequence
occurrences, structural routes, seek/speed/step controls, canonical downloads and
scene bindings follow in groups 11–12. It does not claim those APIs yet.
