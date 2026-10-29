///|
fn swimlane_fixture(direction : @swimlane.Direction) -> @swimlane.Swimlane {
  @swimlane.Swimlane::new(
    "Review",
    [
      @swimlane.Node::new(
        "A",
        label="Request",
        lane="Customer",
        shape="stadium",
      ),
      @swimlane.Node::new("B", label="Review", lane="Support", shape="diamond"),
      @swimlane.Node::new("C", label="Complete", lane="Support", shape="circle"),
    ],
    [
      @swimlane.Connection::new(
        "AB",
        "A",
        "B",
        label="review or return",
        source_marker=Arrow,
      ),
      @swimlane.Connection::new("BC", "B", "C", label="approve"),
      @swimlane.Connection::new(
        "CA",
        "C",
        "A",
        label="related",
        target_marker=None,
      ),
      @swimlane.Connection::new(
        "parallel",
        "A",
        "B",
        label="expedite",
        style=Dotted,
      ),
      @swimlane.Connection::new("constraint", "A", "C", style=Invisible),
    ],
    direction~,
    lanes=[
      @swimlane.Lane::new("Customer", label="Customer requests and corrections"),
      @swimlane.Lane::new("Support", label="Support review"),
    ],
    title="Request review and return",
  )
}

///|
test "every vector shape has portable themed SVG and attached paths" {
  let frames : Array[Json] = []
  for shape in @swimlane.built_in_shapes {
    let model = @swimlane.Swimlane::new(
      shape,
      [
        @swimlane.Node::new("A", label=shape, shape~, lane="L"),
        @swimlane.Node::new("B", label="Next", lane="L"),
      ],
      [
        @swimlane.Connection::new(
          "AB",
          "A",
          "B",
          label="next",
          source_marker=Circle,
        ),
      ],
      lanes=[@swimlane.Lane::new("L", label="Responsibility")],
      direction=LR,
    )
    for
      (mode, name) in [
        (@svg.Mode::Adaptive, "adaptive"),
        (Fixed(Dark), "dark"),
        (Fixed(Light), "light"),
      ] {
      let result = @svg.render_swimlane(model, mode~)
      assert_true(
        result.output != None,
        msg=shape + @debug.to_string(result.diagnostics),
      )
      assert_eq(
        result.diagnostics,
        [],
        msg=shape + @debug.to_string(result.diagnostics),
      )
      let svg = result.output.unwrap()
      assert_true(svg.contains("data-shape=\"" + shape + "\""))
      assert_false(svg.contains("<script"))
      assert_false(svg.contains("href="))
      assert_true(svg.contains("data-swimlane-id=\"AB\""))
      frames.push(Json([shape, name, svg]))
    }
  }
  let t = @test.Test("swimlane vector catalog")
  t.write(Json(frames).stringify())
  t.snapshot(filename="swimlane-shapes.json")
}

///|
test "direction and marker fixtures have stable geometry and scene paths" {
  let frames : Array[Json] = []
  for
    (direction, name) in [
      (@swimlane.Direction::TB, "tb"),
      (BT, "bt"),
      (LR, "lr"),
      (RL, "rl"),
    ] {
    let view = swimlane_fixture(direction)
    for
      (mode, name_mode) in [
        (@svg.Mode::Adaptive, "adaptive"),
        (Fixed(Dark), "dark"),
        (Fixed(Light), "light"),
      ] {
      let renderer = @svg.SvgRenderer::new(mode~)
      let result = renderer.render(Swimlane(view))
      assert_eq(
        result.diagnostics,
        [],
        msg=@debug.to_string(result.diagnostics),
      )
      let svg = result.output.unwrap()
      assert_false(svg.contains("data-swimlane-id=\"constraint\""))
      let scene = renderer.scene(Swimlane(view)).scene.unwrap()
      assert_eq(scene.canonical_svg, svg)
      assert_eq(scene.paths.length(), 4)
      for binding in scene.paths {
        assert_true(svg.contains("d=\"" + binding.path + "\""))
      }
      frames.push(Json([name, name_mode, svg]))
    }
  }
  let t = @test.Test("swimlane flow directions")
  t.write(Json(frames).stringify())
  t.snapshot(filename="swimlane-directions.json")
}

///|
test "all endpoint markers retain their distinct vector glyphs" {
  let markers = []
  for
    (marker, name) in [
      (@swimlane.Marker::Arrow, "arrow"),
      (Circle, "circle"),
      (Cross, "cross"),
      (None, "none"),
    ] {
    let model = @swimlane.Swimlane::new(
      name,
      [@swimlane.Node::new("A", lane="L"), @swimlane.Node::new("B", lane="L")],
      [
        @swimlane.Connection::new(
          "AB",
          "A",
          "B",
          source_marker=marker,
          target_marker=marker,
          style=Thick,
        ),
      ],
      lanes=[@swimlane.Lane::new("L")],
    )
    let svg = @svg.render_swimlane(model).output.unwrap()
    markers.push(Json([name, "adaptive", svg]))
  }
  let t = @test.Test("swimlane endpoint markers")
  t.write(Json(markers).stringify())
  t.snapshot(filename="swimlane-markers.json")
}

///|
test "safe text metadata asset errors explicit limits and prefixed inline copies" {
  let raw = "<script>boom</script> & \"quote\" 😀"
  let properties = @swimlane.RenderProperties::new(
    link="javascript:<unsafe>&\"",
    metadata=[("onload='evil'", "<callback>&")],
  )
  let model = @swimlane.Swimlane::new(
    "unsafe",
    [@swimlane.Node::new("A<&", label=raw, properties~)],
    [],
    title=raw,
    accessibility_description=raw,
  )
  let a = @svg.render_swimlane(model, id_prefix="a<&😀").output.unwrap()
  let b = @svg.render_swimlane(model, id_prefix="b").output.unwrap()
  assert_true(a != b)
  assert_false(a.contains("<script>"))
  assert_false(a.contains("href="))
  assert_false(a.contains("onload="))
  assert_true(a.contains("&lt;script&gt;boom&lt;/script&gt;"))
  assert_true(a.contains("data-link=\"javascript:&lt;unsafe&gt;&amp;&quot;\""))
  for shape in ["image", "icon", "future"] {
    let result = @svg.render_swimlane(
      @swimlane.Swimlane::new("p", [@swimlane.Node::new("A", shape~)], []),
    )
    assert_eq(result.output, None)
    assert_true(
      result.diagnostics.iter().any(d => d.code == "swimlane/unsupported-shape"),
    )
  }
  let result = @svg.render_swimlane(
    model,
    limits=@swimlane_layout.Limits::new(output_units=20),
  )
  assert_eq(result.output, None)
  let invalid = @svg.render_swimlane(
    @swimlane.Swimlane::new(
      "invalid",
      [@swimlane.Node::new("A", label="bad\u0001text")],
      [],
    ),
  )
  assert_eq(invalid.output, None)
  assert_eq(
    invalid.diagnostics.last().unwrap().code,
    "swimlane/invalid-xml-character",
  )
  let t = @test.Test("safe inline swimlanes")
  t.write(Json([a, b]).stringify())
  t.snapshot(filename="swimlane-inline.json")
}

///|
test "ID prefix expansion is bounded before rewriting scoped SVG copies" {
  let model = swimlane_fixture(LR)
  let result = @svg.render_swimlane(
    model,
    id_prefix=String::make(10000, 'x'),
    limits=@swimlane_layout.Limits::new(output_units=30000),
  )
  assert_eq(result.output, None)
  assert_eq(result.diagnostics.last().unwrap().code, "swimlane/render-limit")
}

///|
test "decision anchors final styles and playback retain the same geometry and identity" {
  for direction in [@swimlane.Direction::TB, BT, LR, RL] {
    for style in [@svg.ConnectorStyle::Elbow, Rounded, Curved] {
      for minimum in [24.0, 72.0] {
        let view = swimlane_fixture(direction)
        let source = @debug.to_string(view)
        let renderer = @svg.SvgRenderer::new(
          mode=Fixed(Light),
          connectors=@svg.ConnectorOptions::new(
            style~,
            minimum_approach=minimum,
          ),
        )
        let result = renderer.render(Swimlane(view))
        assert_true(
          result.output != None,
          msg=@debug.to_string((direction, style, minimum, result.diagnostics)),
        )
        let svg = result.output.unwrap()
        let paths = @svg.inspect_connectors(svg)
        let scene = renderer.scene(Swimlane(view)).scene.unwrap()
        assert_eq(scene.canonical_svg, svg)
        assert_eq(paths, renderer.connector_geometry(Swimlane(view)).paths)
        assert_eq(scene.paths.length(), paths.length())
        for binding in scene.paths {
          let path = paths
            .iter()
            .find_first(p => {
              scene.catalog.connection(p.id) == Some(binding.occurrence)
            })
            .unwrap()
          assert_eq(binding.path, path.path.svg())
          assert_eq(binding.mask, path.mask)
        }
        let laid_out = @swimlane_layout.layout(
          view,
          limits=@swimlane_layout.Limits::new(minimum_approach=minimum),
        ).geometry.unwrap()
        let diamond = laid_out.shapes
          .iter()
          .find_first(s => s.id == "B")
          .unwrap().outline_box
        for edge in laid_out.connections {
          let p = if edge.target == "B" {
            Some(edge.line[edge.line.length() - 1])
          } else if edge.source == "B" {
            Some(edge.line[0])
          } else {
            None
          }
          if p is Some(p) {
            let cardinal = (p.x - diamond.x - diamond.width / 2.0).abs() < 0.001 ||
              (p.y - diamond.y - diamond.height / 2.0).abs() < 0.001
            assert_true(
              cardinal,
              msg=@debug.to_string((direction, edge.connection.id, p)),
            )
          }
        }
        assert_eq(@debug.to_string(view), source)
        // An actual collision still fails even at a preferred decision point.
        let path = paths[0]
        let first = laid_out.connections[0].line[0]
        let findings = @svg.check_connectors(
          [path],
          [
            @svg.ConnectorObstacle::{
              owner: "unrelated",
              x: first.x - 2.0,
              y: first.y - 2.0,
              width: 4.0,
              height: 4.0,
            },
          ],
          width=laid_out.width.to_double(),
          height=laid_out.height.to_double(),
        )
        assert_true(
          findings.iter().any(d => d.code == "connector/routing-conflict"),
        )
      }
    }
  }
}
