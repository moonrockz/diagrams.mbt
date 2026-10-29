///|
test "GIF scene sampler preserves repeated concurrent and reversed pure samples" {
  let view = @swimlane.Swimlane::new(
    "review",
    [@swimlane.Node::new("A"), @swimlane.Node::new("B")],
    [@swimlane.Connection::new("AB", "A", "B", source_marker=Arrow)],
  )
  let renderer = @svg.SvgRenderer::new(
    connectors=@svg.ConnectorOptions::new(style=Curved),
  )
  let scene = renderer.scene(@render.Diagram::Swimlane(view)).scene.unwrap()
  let key = scene.catalog.connection("AB").unwrap().key
  let plan = @animation.PlaybackPlan::scenario(
    scene.catalog,
    @animation.Motion::serial([
      Step(key, 200L),
      @animation.Motion::parallel([
        Step(key, 200L),
        OrientedStep(key, 200L, true),
      ]),
      Step(key, 200L),
    ]),
  ).plan.unwrap()
  let sampler = GifSampler::new(
    scene,
    plan,
    options=GifOptions::new(frame_rate=20),
    limits=gif_test_limits(),
  ).sampler.unwrap()
  for index in 0..<sampler.frame_count {
    let frame = sampler.frame(index).frame.unwrap()
    assert_eq(frame.sample, plan.sample_at(frame.time_ms))
    assert_eq(frame.occurrences.length(), frame.sample.active.length())
  }
  let concurrent = sampler.frame(5).frame.unwrap()
  assert_eq(concurrent.occurrences.length(), 2)
  let unchanged = scene.display_svg
  let decorated = gif_frame_svg(scene, concurrent, gif_test_limits())
  let tree = parse_svg_xml(decorated)
  assert_eq(
    tree.iter().filter(node => gif_class(node, "gif-motion-overlay")).count(),
    2,
  )
  assert_eq(scene.display_svg, unchanged)
  assert_true(!concurrent.occurrences[0].occurrence.reversed)
  assert_true(concurrent.occurrences[1].occurrence.reversed)
  let terminal_sample = sampler.frame(sampler.frame_count - 1).frame.unwrap()
  assert_eq(terminal_sample.time_ms, plan.duration_ms)
  assert_true(terminal_sample.sample.finished)
  assert_true(sampler.frame(-1).frame is None)
  let other = @svg.SvgRenderer::new().scene(
    @render.Diagram::Swimlane(
      @swimlane.Swimlane::new("other", [@swimlane.Node::new("A")], []),
    ),
  ).scene.unwrap()
  let mismatch = GifSampler::new(other, plan, limits=gif_test_limits())
  assert_true(mismatch.sampler is None)
  assert_eq(mismatch.diagnostics[0].code, "raster/plan-mismatch")
}

///|
test "GIF node visits retain bound terms without synthetic paths" {
  let regex = @regex.Regex::new("pattern", "term", [
    @regex.Node::new("term", Literal("a")),
  ])
  let scene = @svg.SvgRenderer::new().scene(@render.Diagram::Regex(regex)).scene.unwrap()
  let key = @animation.railroad_key("pattern", "term")
  let plan = @animation.PlaybackPlan::scenario(scene.catalog, Visit(key, 200L)).plan.unwrap()
  let sampler = GifSampler::new(scene, plan, limits=gif_test_limits()).sampler.unwrap()
  let frame = sampler.frame(1).frame.unwrap()
  assert_eq(frame.sample, plan.sample_at(100L))
  assert_eq(frame.occurrences.length(), 1)
  assert_true(frame.occurrences[0].target is Visit(_))
  let unchanged = scene.display_svg
  let decorated = gif_frame_svg(scene, frame, gif_test_limits())
  assert_true(decorated.contains("gif-visit-overlay"))
  assert_true(decorated.contains("stroke=\"#2563eb\""))
  assert_eq(scene.display_svg, unchanged)
  let repeating = plan.repeating().plan.unwrap()
  let period = GifSampler::new(scene, repeating, limits=gif_test_limits()).sampler.unwrap()
  assert_eq(
    period.frame(period.frame_count - 1).frame.unwrap().sample,
    repeating.sample_at(200L),
  )
}
