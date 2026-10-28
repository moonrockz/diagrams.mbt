///|
test "malformed zero-duration or empty worker schedules fail before frame work" {
  let view = @swimlane.Swimlane::new(
    "wire-bounds",
    [@swimlane.Node::new("A"), @swimlane.Node::new("B")],
    [@swimlane.Connection::new("AB", "A", "B")],
  )
  let scene = @svg.SvgRenderer::new().scene(@render.Diagram::Swimlane(view)).scene.unwrap()
  let plan = @animation.PlaybackPlan::illustrative(
    scene.catalog,
    duration_ms=100L,
  ).plan.unwrap()
  for duration in [0, 100] {
    let data = gif_export_data(scene, plan).data.unwrap()
    guard data is Object(fields) && fields["plan"] is Object(schedule) else {
      fail("Missing generated worker plan")
    }
    schedule["mode"] = Json("illustrative")
    schedule["duration_ms"] = Json(duration.to_string())
    schedule["steps"] = Json::array([])
    let result = Rasterizer::new(FontSet::new([])).export_gif_data(
      data,
      options=GifOptions::new(interval=Interval(start_ms=0L, end_ms=100L)),
    )
    assert_true(result.image is None)
    assert_eq(result.diagnostics[0].code, "raster/gif-data")
  }
}

///|
test "aggregate groups fail before group values fonts or frame work" {
  let view = @swimlane.Swimlane::new(
    "group-budget",
    [@swimlane.Node::new("A"), @swimlane.Node::new("B")],
    [@swimlane.Connection::new("AB", "A", "B")],
  )
  let scene = @svg.SvgRenderer::new().scene(@render.Diagram::Swimlane(view)).scene.unwrap()
  let key = scene.catalog.connection("AB").unwrap().key
  let plan = @animation.PlaybackPlan::scenario(
    scene.catalog,
    @animation.Motion::parallel(
      Array::make(10, @animation.Motion::Step(key, 100L)),
    ),
  ).plan.unwrap()
  let limits = { ..RasterLimits::default(), max_svg_nodes: 22, }
  // 1 path + 2 nodes + 10 steps + 10 group memberships exceeds 22.
  let produced = gif_export_data(scene, plan, limits~)
  assert_true(produced.data is None)
  assert_eq(produced.diagnostics[0].code, "raster/gif-data")
  let data = gif_export_data(scene, plan).data.unwrap()
  let result = Rasterizer::new(FontSet::new([]), limits~).export_gif_data(data)
  assert_eq(result.diagnostics[0].code, "raster/gif-data")
  guard data is Object(fields) &&
    fields["plan"] is Object(schedule) &&
    schedule["steps"] is Array(steps) else {
    fail("Missing generated schedule")
  }
  for step in steps {
    guard step is Object(fields) else { fail("Missing step") }
    fields["groups"] = Json::array(Array::make(20, Json("not an integer")))
  }
  let result = Rasterizer::new(FontSet::new([]), limits~).export_gif_data(data)
  assert_eq(
    result.diagnostics[0].message,
    "GIF aggregate binding/step/group budget exhausted",
  )
}

///|
test "repeated path metadata is charged before path parsing" {
  let source = "<svg width=\"1\" height=\"1\"/>"
  let source_id = gif_source_id(source, source)
  let path = "M0 0 ".repeat(100)
  let binding : Json = {
    "key": "alias",
    "id": "absent",
    "path": Json(path),
    "mask": null,
  }
  let paths : Array[Json] = Array::make(4, binding)
  let data : Json = {
    "version": 1,
    "source_id": Json(source_id),
    "canonical": Json(source),
    "display": Json(source),
    "paths": Json(paths),
    "nodes": [],
    "plan": {
      "source_id": Json(source_id),
      "mode": "finite",
      "duration_ms": "100",
      "steps": [
        {
          "key": "alias",
          "ordinal": 0,
          "start_ms": "0",
          "duration_ms": "100",
          "reversed": false,
          "visit": false,
          "groups": [],
        },
      ],
    },
  }
  let result = Rasterizer::new(FontSet::new([]), limits={
    ..RasterLimits::default(),
    max_source_units: 1000,
  }).export_gif_data(data)
  assert_eq(result.diagnostics[0].code, "raster/source-limit")
  assert_eq(
    result.diagnostics[0].message,
    "GIF aggregate binding text budget exhausted",
  )
}

///|
test "node binding index preserves all kinds first match and sequential frames" {
  let tree = parse_svg_xml(
    "<svg><g class=\"bpmn-shape\" data-id=\"b\"/><g class=\"message\" data-index=\"0\"/><g class=\"message\" data-index=\"00\"/><rect class=\"frame\"/><rect/><rect class=\"frame\"/><g class=\"swimlane-node\" data-swimlane-id=\"s\"/><g class=\"swimlane-node\" data-swimlane-id=\"s\"/><g class=\"flowchart-lane\" data-flowchart-id=\"f\"/><g class=\"state-group\" data-state-id=\"st\"/><g class=\"architecture-junction\" data-id=\"a\"/><g class=\"rr-term\" data-term=\"t\"/><g class=\"data-row\" data-member=\"r\"/><g class=\"data-box\" data-node=\"d\"/></svg>",
  )
  let indices = gif_visit_indices(tree)
  let kinds : Array[@svg.NodeBindingKind] = [
    Bpmn("b"),
    Message(0),
    Frame(0),
    Frame(1),
    Swimlane("s"),
    Flowchart("f"),
    State("st"),
    Architecture("a"),
    RailroadTerm("t"),
    DataRow("r"),
    DataBox("d"),
  ]
  assert_eq(indices.length(), kinds.length())
  for kind in kinds {
    assert_true(indices.contains(gif_kind_key(kind)))
  }
  assert_true(indices[gif_kind_key(Frame(0))] < indices[gif_kind_key(Frame(1))])
  assert_eq(indices[gif_kind_key(Swimlane("s"))], 8)
}

///|
test "many aliases reuse a single node index and reach font validation" {
  let source = "<svg width=\"1\" height=\"1\">" +
    "<g/>".repeat(5000) +
    "<g class=\"swimlane-node\" data-swimlane-id=\"A\"/></svg>"
  let source_id = gif_source_id(source, source)
  let nodes : Array[Json] = []
  for i in 0..<10000 {
    nodes.push(
      Json({ "key": Json("alias" + i.to_string()), "kind": ["swimlane", "A"] }),
    )
  }
  let data : Json = {
    "version": 1,
    "source_id": Json(source_id),
    "canonical": Json(source),
    "display": Json(source),
    "paths": [],
    "nodes": Json(nodes),
    "plan": {
      "source_id": Json(source_id),
      "mode": "finite",
      "duration_ms": "100",
      "steps": [
        {
          "key": "alias0",
          "ordinal": 0,
          "start_ms": "0",
          "duration_ms": "100",
          "reversed": false,
          "visit": true,
          "groups": [],
        },
      ],
    },
  }
  let result = Rasterizer::new(FontSet::new([])).export_gif_data(data)
  assert_eq(result.diagnostics[0].code, "raster/font-limit")
  let tree = parse_svg_xml(source)
  let indices = gif_visit_indices(tree)
  assert_eq(indices.length(), 1)
  let paints : Array[GifPaint] = [
    {
      target: Visit(Swimlane("A")),
      numerator: 0L,
      denominator: 100L,
      reversed: false,
    },
  ]
  let decorated = gif_paint_svg(
    source,
    source_id,
    paints,
    RasterLimits::default(),
    visit_indices=indices,
  )
  assert_true(decorated.contains("gif-visit-overlay"))
}
