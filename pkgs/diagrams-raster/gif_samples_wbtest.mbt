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

///|
test "decision SVG PNG and GIF consume identical final anchors paths and masks" {
  let view = @swimlane.Swimlane::new(
    "decision exports",
    [
      @swimlane.Node::new("A", shape="diamond"),
      @swimlane.Node::new("B"),
      @swimlane.Node::new("C"),
    ],
    [
      @swimlane.Connection::new("AB", "A", "B"),
      @swimlane.Connection::new("AC", "A", "C"),
    ],
  )
  for style in [@svg.ConnectorStyle::Elbow, Rounded, Curved] {
    let renderer = @svg.SvgRenderer::new(
      mode=Fixed(Light),
      connectors=@svg.ConnectorOptions::new(style~),
    )
    let diagram = @render.Diagram::Swimlane(view)
    let scene = renderer.scene(diagram).scene.unwrap()
    let canonical = @render.Renderer::render(renderer, diagram).output.unwrap()
    assert_eq(scene.canonical_svg, canonical)
    let paths = @svg.inspect_connectors(canonical)
    let key = scene.catalog.connection("AB").unwrap().key
    let plan = @animation.PlaybackPlan::scenario(scene.catalog, Step(key, 100L)).plan.unwrap()
    let options = GifOptions::new(size=Width(64), frame_rate=10)
    let sampler = GifSampler::new(
      scene,
      plan,
      options~,
      limits=gif_test_limits(),
    ).sampler.unwrap()
    let frame = sampler.frame(1).frame.unwrap()
    for occurrence in frame.occurrences {
      guard occurrence.target is Connection(id~, path~, mask~, point~) else {
        abort("expected connection")
      }
      let selected = paths.iter().find_first(p => p.id == id).unwrap()
      assert_eq(path, selected.path.svg())
      assert_eq(mask, selected.mask)
      let sampled = gif_path(selected.path, 8192)
      assert_eq(point, sampled.point(1.0))
    }
    let still = rasterize(canonical, options=StillOptions::new(size=Width(64)))
    assert_true(still.image is Some(_), msg=@debug.to_string(still.diagnostics))
    let gif = export_gif(scene, plan, options~, limits=gif_test_limits())
    assert_true(gif.image is Some(_), msg=@debug.to_string(gif.diagnostics))
    assert_eq(gif.image.unwrap().media_type, "image/gif")
    assert_eq(scene.canonical_svg, canonical)
  }
}
