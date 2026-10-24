///|
fn fixture() -> String { @corpus.inputs[5].source }

///|
fn diagram() -> @render.Diagram raise {
  let r = @bpmn.read(fixture())
  assert_eq(r.diagnostics.length(), 0)
  let c = @adapter.to_diagram(r.document.unwrap())
  assert_eq(c.diagnostics.length(), 0)
  c.diagram.unwrap()
}

///|
test "minimal source partitions, reproduces, round trips and walks its task" {
  let r = @bpmn.read(fixture())
  assert_eq(r.tree.text(), fixture())
  let mut end = 0
  for token in r.tree.tokens {
    assert_eq(token.span.start, end)
    assert_eq(token.text, fixture()[token.span.start:token.span.end].to_owned())
    end = token.span.end
  }
  assert_eq(end, fixture().length())
  let doc = r.document.unwrap()
  assert_eq(@bpmn.read(@bpmn.write(doc)).document, Some(doc))
  let ids : Array[String] = []
  let tasks : Array[String] = []
  doc.walk(e => {
    if e.attribute("id") is Some(id) { ids.push(id) }
    if e.kind == Task { tasks.push(e.attribute("name").unwrap()) }
  })
  assert_eq(tasks, ["Review request"])
  assert_eq(ids, ["Definitions_1", "Process_1", "Start", "Review", "End", "Flow_1", "Flow_2", "Diagram_1", "Plane_1", "Start_di", "Review_di", "End_di", "Flow_1_di", "Flow_2_di"])
}

///|
test "first BPMN static output uses the renderer contract and frozen bytes" {
  let d = diagram()
  let rendered = @svg.SvgRenderer::new().render(d)
  assert_eq(rendered.media_type, "image/svg+xml")
  assert_eq(rendered.diagnostics.length(), 0)
  let svg = rendered.output.unwrap()
  assert_false(svg.contains("<script"))
  assert_true(svg.contains("data-source-id=\"Review\""))
  assert_eq(@adapter.render_svg(fixture()).output, rendered.output)
  let t = @test.Test("bpmn-static")
  t.write(svg); t.snapshot(filename="minimal.svg")
}

///|
test "first BPMN animated output has frozen HTML bytes on every target" {
  let d = diagram()
  let animated = @animated.AnimatedRenderer::new().render(d)
  assert_eq(animated.media_type, "text/html")
  assert_eq(animated.diagnostics.length(), 0)
  let t = @test.Test("bpmn-animation")
  t.write(animated.output.unwrap()); t.snapshot(filename="minimal.html")
}

///|
test "pure plan samples exact progress and rejects invalid durations and bindings" {
  let plan = @animation.MotionPlan::new("Process_1", "Flow_1").unwrap()
  assert_eq(plan.sample(-1), (0, 1000))
  assert_eq(plan.sample(0), (0, 1000))
  assert_eq(plan.sample(250), (250, 1000))
  assert_eq(plan.sample(1000), (1000, 1000))
  assert_eq(plan.sample(2000), (1000, 1000))
  assert_eq(@animation.MotionPlan::new("P", "F", duration_ms=0), None)
  for p in [@animation.MotionPlan::new("other", "Flow_1").unwrap(), @animation.MotionPlan::new("Process_1", "missing").unwrap()] {
    let result = @animated.AnimatedRenderer::new(plan=p).render(diagram())
    assert_eq(result.output, None)
    assert_eq(result.diagnostics[0].code, "animation/plan-mismatch")
  }
  let result = @animated.AnimatedRenderer::new().render(Sequence(@sequence.Sequence::new([], [])))
  assert_eq(result.output, None)
  assert_eq(result.diagnostics[0].code, "render/unsupported-diagram")
}

///|
test "bad DI or endpoints never gives partial success" {
  for source in [fixture().replace(old="width=\"180\"", new="width=\"-1\""), fixture().replace(old="targetRef=\"Review\"", new="targetRef=\"absent\""), fixture().replace(old="bpmnElement=\"Review\"", new="bpmnElement=\"absent\"")] {
    let result = @adapter.render_svg(source)
    assert_eq(result.output, None)
    assert_true(result.diagnostics.length() > 0)
  }
}

///|
test "markup-like labels remain SVG text and never enter script context" {
  let hostile = fixture().replace(old="id=\"Review\" name=\"Review request\"", new="id=\"Review\" name=\"&lt;/script&gt;&lt;img onerror=&quot;boom&quot;&gt;😀 &amp; done\"")
  let read = @bpmn.read(hostile)
  assert_eq(read.diagnostics.length(), 0)
  let doc = read.document.unwrap()
  assert_eq(@bpmn.read(@bpmn.write(doc)).document, Some(doc))
  let d = @adapter.to_diagram(doc).diagram.unwrap()
  let html = @animated.AnimatedRenderer::new().render(d).output.unwrap()
  assert_false(html.contains("<img"))
  assert_true(html.contains("&lt;/script&gt;"))
  assert_eq(html.split("</script>").count(), 2)
}

///|
test "unsupported task markers are diagnosed instead of silently drawn as plain tasks" {
  let source = fixture().replace(old="id=\"Review\" name=", new="id=\"Review\" isForCompensation=\"true\" name=")
  let result = @adapter.render_svg(source)
  assert_eq(result.output, None)
  assert_eq(result.diagnostics[0].code, "bpmn/unsupported-view")
}
