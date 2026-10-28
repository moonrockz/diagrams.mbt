///|
/// Exact fixture: site/examples/connectors/crossing.mmd. The gallery task checks
/// this source before copying the download.
let connector_crossing_source : String = "flowchart LR\nA[Input A] --> C[Output C]\nB[Input B] --> D[Output D]\nA --> D\nB --> C\nC --> E[After C]\nD --> E\nE --> A\n"

///|
test "connector tracer has unrelated interior crossings" {
  let read = @mermaid.read_diagram(connector_crossing_source)
  guard read.ast is Some(Flowchart(ast)) else { fail("expected flowchart") }
  assert_false(read.diagnostics.iter().any(d => d.severity == Error))
  let converted = @mermaid.to_flowchart(ast, id="connector-crossing")
  assert_false(converted.diagnostics.iter().any(d => d.severity == Error))
  let view = converted.flowchart.unwrap()
  let model = @render.Diagram::Flowchart(view)
  let result = @svg.SvgRenderer::new().render(model)
  assert_true(
    result.output is Some(_),
    msg=result.diagnostics.iter().map(d => d.message).to_array().join("; "),
  )
  assert_true(
    result.output.unwrap().contains("<mask"),
    msg="tracer must actually cross",
  )
  let paths = @svg.inspect_connectors(result.output.unwrap())
  assert_eq(paths.length(), view.connections.length())
  for connection in view.connections {
    let resolved = paths.iter().find_first(p => p.id == connection.id).unwrap()
    assert_eq(resolved.source, connection.source)
    assert_eq(resolved.target, connection.target)
    if !(connection.target_marker is None) {
      let commands = resolved.path.commands
      assert_true(commands.length() >= 2, msg=connection.id)
      guard commands[commands.length() - 1] is Line(endpoint) else {
        fail(
          "Marked connector lacks a final straight approach: " + connection.id,
        )
      }
      let previous = match commands[commands.length() - 2] {
        Move(p) | Line(p) | Quadratic(_, p) | Cubic(_, _, p) => p
      }
      let dx = endpoint.x - previous.x
      let dy = endpoint.y - previous.y
      assert_true(
        dx * dx + dy * dy >= 24.0 * 24.0 - 0.000001,
        msg=connection.id,
      )
    }
  }
}

///|
fn connector_comparisons(rows : Array[Json]) -> Unit raise {
  let read = @mermaid.read_diagram(connector_crossing_source)
  guard read.ast is Some(Flowchart(ast)) else {
    fail("expected comparison flowchart")
  }
  let model = @render.Diagram::Flowchart(
    @mermaid.to_flowchart(ast, id="connector-crossing").flowchart.unwrap(),
  )
  rows.push(
    Json(["connector-crossing.mmd", "text/plain", connector_crossing_source]),
  )
  for
    (style_name, style) in [
      ("elbow", @svg.ConnectorStyle::Elbow),
      ("rounded", Rounded),
      ("curved", Curved),
    ] {
    for
      (crossing_name, crossing) in [
        ("bridge", @svg.CrossingMode::Bridge),
        ("plain", Plain),
      ] {
      let id = "connector-" + style_name + "-" + crossing_name
      let connectors = @svg.ConnectorOptions::new(style~, crossing~)
      for
        (variant, mode) in [
          ("light", @svg.Mode::Fixed(Light)),
          ("dark", @svg.Mode::Fixed(Dark)),
          ("adaptive", @svg.Mode::Adaptive),
        ] {
        let renderer = @svg.SvgRenderer::new(
          connectors~,
          mode~,
          id_prefix=id + "-" + variant,
        )
        let rendered = renderer.render(model)
        assert_true(
          rendered.output is Some(_),
          msg=id +
            ": " +
            rendered.diagnostics
            .iter()
            .map(d => d.message)
            .to_array()
            .join("; "),
        )
        assert_eq(
          rendered.output.unwrap().contains("<mask"),
          crossing == Bridge,
          msg=id,
        )
        rows.push(
          Json([
            id + "-" + variant + ".svg",
            "image/svg+xml",
            rendered.output.unwrap(),
          ]),
        )
        if variant != "adaptive" {
          let scene = renderer.scene(model)
          assert_true(scene.scene is Some(_), msg=id)
          let paths = scene.scene.unwrap().paths
          if style == Rounded {
            assert_true(
              paths.iter().any(binding => binding.path.contains("Q")),
              msg=id,
            )
          } else if style == Curved {
            assert_true(
              paths.iter().any(binding => binding.path.contains("C")),
              msg=id,
            )
          }
          assert_eq(
            scene.scene.unwrap().canonical_svg,
            rendered.output.unwrap(),
          )
          let player = @render.Renderer::render(
            @animated.AnimatedRenderer::new(svg=renderer),
            model,
          )
          assert_true(
            player.output is Some(_),
            msg=id +
              ": " +
              player.diagnostics
              .iter()
              .map(d => d.message)
              .to_array()
              .join("; "),
          )
          rows.push(
            Json([
              id + "-" + variant + ".html",
              "text/html",
              player.output.unwrap(),
            ]),
          )
        }
      }
    }
  }
}

///|
fn connector_inventory() -> Array[Json] {
  let inventory : Array[Json] = []
  for
    (style_name, style) in [
      ("elbow", @svg.ConnectorStyle::Elbow),
      ("rounded", Rounded),
      ("curved", Curved),
    ] {
    for
      (crossing_name, crossing) in [
        ("bridge", @svg.CrossingMode::Bridge),
        ("plain", Plain),
      ] {
      let id = "connector-" + style_name + "-" + crossing_name
      let api_style = match style {
        Elbow => "Elbow"
        Rounded => "Rounded"
        Curved => "Curved"
      }
      let api_crossing = match crossing {
        Bridge => "Bridge"
        Plain => "Plain"
      }
      let description = "Same Mermaid source. ConnectorStyle::" +
        api_style +
        ", CrossingMode::" +
        api_crossing +
        "; minimum_approach=24.0, corner_radius=8.0, bridge_radius=5.0."
      inventory.push({
        "id": id,
        "family": "flowchart",
        "title": "Connector comparison: " + style_name + " / " + crossing_name,
        "status": "implemented",
        "description": description,
        "scope": "Display options for one source model. Crossings add no graph connectivity. Structural playback does not execute conditions or workflows.",
        "sources": [gallery_file("connector-crossing.mmd", "text/plain")],
        "preview": gallery_file(id + "-light.svg", "image/svg+xml"),
        "preview_dark": gallery_file(id + "-dark.svg", "image/svg+xml"),
        "player": gallery_file(id + "-light.html", "text/html"),
        "companions": [
          gallery_file(id + "-dark.html", "text/html"),
          gallery_file(id + "-adaptive.svg", "image/svg+xml"),
        ],
      })
    }
  }
  inventory
}
