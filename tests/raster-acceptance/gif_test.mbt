///|
/// Portable source-bound exports retained for independent browser decoding.
fn gif_fixture(
  name : String,
  scene : @svg.Scene,
  plan : @animation.PlaybackPlan,
  loop_behavior : @raster.GifLoop,
) -> Json raise {
  let options = @raster.GifOptions::new(
    size=Width(160),
    frame_rate=10,
    loop_behavior~,
  )
  let fonts = @raster.FontSet::default().subset_for_svg(scene.canonical_svg).fonts.unwrap()
  let before = scene.canonical_svg
  let result = @raster.export_gif(scene, plan, options~, fonts~)
  assert_eq(
    result.diagnostics.length(),
    0,
    msg=Json(result.diagnostics.iter().map(d => Json(d.message)).to_array()).stringify(),
  )
  let image = result.image.unwrap()
  let wire = @raster.gif_export_data(scene, plan).data.unwrap()
  let decoded = @raster.Rasterizer::new(fonts).export_gif_data(wire, options~)
  assert_eq(
    decoded.diagnostics.length(),
    0,
    msg=Json(decoded.diagnostics.iter().map(d => Json(d.message)).to_array()).stringify(),
  )
  assert_eq(decoded.image.unwrap().bytes, image.bytes)
  let prepared = @raster.GifSampler::new(scene, plan, options~).sampler.unwrap()
  let samples : Array[Json] = []
  for index in 0..<prepared.frame_count {
    let frame = prepared.frame(index).frame.unwrap()
    assert_eq(frame.sample, plan.sample_at(frame.time_ms))
    let active : Array[Json] = []
    for item in frame.occurrences {
      let target = match item.target {
        Connection(id~, point~, mask~, ..) =>
          Json({
            "id": Json(id),
            "x": Json(point.x),
            "y": Json(point.y),
            "mask": mask.map(value => Json(value)).unwrap_or(Json(null)),
          })
        Visit(_) => Json(null)
      }
      active.push(
        Json({
          "key": Json(item.occurrence.key),
          "ordinal": Json(item.occurrence.ordinal),
          "reversed": Json(item.occurrence.reversed),
          "visit": Json(item.occurrence.visit),
          "numerator": Json(item.occurrence.numerator.to_string()),
          "denominator": Json(item.occurrence.denominator.to_string()),
          "target": target,
        }),
      )
    }
    samples.push(
      Json({
        "time": Json(frame.time_ms.to_string()),
        "delay": Json(frame.delay_centiseconds),
        "active": Json(active),
      }),
    )
  }
  let canonical = @raster.rasterize(
    scene.canonical_svg,
    options=@raster.StillOptions::new(
      size=Width(160),
      background=@raster.Rgba::white(),
    ),
    fonts~,
  ).image.unwrap()
  assert_eq(image.width, canonical.width)
  assert_eq(image.height, canonical.height)
  assert_eq(image.media_type, "image/gif")
  assert_eq(scene.canonical_svg, before)
  Json({
    "name": Json(name),
    "svg": Json(scene.display_svg),
    "wire": wire,
    "gif": Json(@base64.encode(image.bytes)),
    "canonical_png": Json(@base64.encode(canonical.bytes)),
    "width": Json(image.width),
    "height": Json(image.height),
    "samples": Json(samples),
  })
}

///|
test "source-bound GIF frames loops and paths are deterministic on every target" {
  let model = @swimlane.Swimlane::new(
    "gif-review",
    [@swimlane.Node::new("A"), @swimlane.Node::new("B")],
    [@swimlane.Connection::new("AB", "A", "B", source_marker=Arrow)],
  )
  let scene = @svg.SvgRenderer::new(
    connectors=@svg.ConnectorOptions::new(style=Curved),
  ).scene(@render.Diagram::Swimlane(model)).scene.unwrap()
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
  let regex = @regex.Regex::new("gif-visits", "terms", [
    @regex.Node::new("terms", Sequence(["a", "b"])),
    @regex.Node::new("a", Literal("a")),
    @regex.Node::new("b", Literal("b")),
  ])
  let visit_scene = @svg.SvgRenderer::new().scene(@render.Diagram::Regex(regex)).scene.unwrap()
  let visits = @animation.PlaybackPlan::scenario(
    visit_scene.catalog,
    @animation.Motion::serial([
      Visit(@animation.railroad_key("gif-visits", "a"), 200L),
      Visit(@animation.railroad_key("gif-visits", "b"), 200L),
    ]),
  ).plan.unwrap()
  let history = @plantuml.read(
    "@startuml\nstate Service {\nstate Worker\n[*] --> Worker\nWorker --> Worker : work\n--\nstate Monitor\n[*] --> Monitor\nMonitor --> Monitor : check\n}\nstate Paused\n[*] --> Service\nService --> Paused : pause\nPaused --> Service[H] : resume\nPaused --> Service[H*] : deep resume\n@enduml",
  )
  let history_model = @plantuml.to_diagram(history.document.unwrap()).diagram.unwrap()
  let masked = @svg.SvgRenderer::new().scene(history_model).scene.unwrap()
  let binding = masked.paths
    .iter()
    .find_first(path => path.mask is Some(_))
    .unwrap()
  let masked_plan = @animation.PlaybackPlan::scenario(
    masked.catalog,
    Step(binding.occurrence.key, 200L),
  ).plan.unwrap()
  let rows = [
    gif_fixture("finite-once", scene, plan, Once),
    gif_fixture("repeat-twice", scene, plan, Repeat(2)),
    gif_fixture(
      "illustrative-forever",
      scene,
      plan.repeating().plan.unwrap(),
      Forever,
    ),
    gif_fixture("node-visits", visit_scene, visits, Once),
    gif_fixture("masked-connector", masked, masked_plan, Once),
  ]
  let snapshot = @test.Test("portable GIF exports")
  snapshot.write(Json(rows).stringify())
  snapshot.snapshot(filename="gif.json")
}

///|
test "GIF budgets reject excessive work and invalid finite intervals without payloads" {
  let model = @swimlane.Swimlane::new(
    "gif-limits",
    [@swimlane.Node::new("A"), @swimlane.Node::new("B")],
    [@swimlane.Connection::new("AB", "A", "B")],
  )
  let scene = @svg.SvgRenderer::new().scene(@render.Diagram::Swimlane(model)).scene.unwrap()
  let plan = @animation.PlaybackPlan::illustrative(
    scene.catalog,
    duration_ms=200L,
  ).plan.unwrap()
  let limits = @raster.RasterLimits::default()
  for
    constrained in [
      { ..limits, max_frames: 1, },
      { ..limits, max_cumulative_pixels: 1L, },
      { ..limits, max_output_bytes: 1, },
    ] {
    let result = @raster.export_gif(
      scene,
      plan,
      options=@raster.GifOptions::new(size=Width(32)),
      limits=constrained,
    )
    assert_true(result.image is None)
    assert_true(result.diagnostics.length() > 0)
  }
  let finite = @animation.PlaybackPlan::scenario(
    scene.catalog,
    Step(scene.catalog.connection("AB").unwrap().key, 100L),
  ).plan.unwrap()
  let invalid = @raster.export_gif(
    scene,
    finite,
    options=@raster.GifOptions::new(interval=Interval(start_ms=0L, end_ms=101L)),
  )
  assert_true(invalid.image is None)
}
