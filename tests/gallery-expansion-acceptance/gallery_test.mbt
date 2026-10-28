///|
fn gallery_model(example : GalleryCase) -> @render.Diagram raise {
  if example.extension == "bpmn" {
    let read = @bpmn.read(example.source)
    assert_false(read.diagnostics.iter().any(d => d.severity == Error))
    let converted = @adapter.to_diagram(read.document.unwrap())
    assert_false(
      converted.diagnostics.iter().any(d => d.severity == Error),
      msg=example.id +
        ": " +
        converted.diagnostics.iter().map(d => d.message).to_array().join("; "),
    )
    converted.diagram.unwrap()
  } else if example.extension == "puml" {
    let read = @plantuml.read(example.source)
    assert_false(
      read.diagnostics.iter().any(d => d.severity == Error),
      msg=example.id,
    )
    assert_eq(read.tree.text(), example.source)
    let converted = @plantuml.to_diagram(read.document.unwrap(), id=example.id)
    assert_false(
      converted.diagnostics.iter().any(d => d.severity == Error),
      msg=example.id,
    )
    converted.diagram.unwrap()
  } else {
    let read = @mermaid.read_diagram(example.source)
    assert_false(
      read.diagnostics.iter().any(d => d.severity == Error),
      msg=example.id +
        ": " +
        read.diagnostics.iter().map(d => d.message).to_array().join("; "),
    )
    assert_eq(read.tree.text(), example.source)
    match read.ast.unwrap() {
      State(ast) => State(@mermaid.to_state(ast, id=example.id).state.unwrap())
      Sequence(ast) => Sequence(@mermaid.to_sequence(ast).sequence)
      Zenuml(ast) =>
        Sequence(@mermaid.to_zenuml_sequence(ast).sequence.unwrap())
      Architecture(ast) =>
        Architecture(
          @mermaid.to_architecture(ast, id=example.id).architecture.unwrap(),
        )
      Swimlane(ast) =>
        Swimlane(@mermaid.to_swimlane(ast, id=example.id).swimlane.unwrap())
      Flowchart(ast) =>
        Flowchart(@mermaid.to_flowchart(ast, id=example.id).flowchart.unwrap())
    }
  }
}

///|
fn gallery_file(path : String, media_type : String) -> Json {
  { "path": path, "media_type": media_type }
}

///|
test "thirty distinct sources add three examples to each of ten families" {
  let examples = gallery_cases()
  assert_eq(examples.length(), 30)
  let ids : Array[String] = []
  let sources : Array[String] = []
  for example in examples {
    assert_false(ids.contains(example.id))
    assert_false(sources.contains(example.source))
    ids.push(example.id)
    sources.push(example.source)
  }
  for
    family in [
      "sequence", "ZenUML", "architecture", "BPMN", "swimlane", "flowchart", "regex",
      "EBNF", "JSON", "YAML",
    ] {
    assert_eq(examples.iter().filter(e => e.family == family).count(), 3)
  }
}

///|
fn render_expanded_gallery() -> Array[Json] raise {
  let rows : Array[Json] = []
  for example in gallery_cases() {
    let source_name = example.id + "." + example.extension
    let source_type = if example.extension == "bpmn" {
      "application/xml"
    } else {
      "text/plain"
    }
    rows.push(Json([source_name, source_type, example.source]))
    let model = gallery_model(example)
    for
      (variant, mode) in [
        ("light", @svg.Mode::Fixed(Light)),
        ("dark", @svg.Mode::Fixed(Dark)),
        ("adaptive", @svg.Mode::Adaptive),
      ] {
      let renderer = @svg.SvgRenderer::new(
        mode~,
        id_prefix=example.id + "-" + variant,
      )
      let rendered = @render.Renderer::render(renderer, model)
      assert_false(
        rendered.diagnostics.iter().any(d => d.severity == Error),
        msg=example.id +
          ": " +
          rendered.diagnostics.iter().map(d => d.message).to_array().join("; "),
      )
      let output = rendered.output.unwrap()
      assert_false(output.contains("<script"))
      rows.push(
        Json([example.id + "-" + variant + ".svg", "image/svg+xml", output]),
      )
      if variant != "adaptive" {
        let scene = renderer.scene(model)
        assert_true(
          scene.scene is Some(_),
          msg=example.id +
            ": " +
            scene.diagnostics.iter().map(d => d.message).to_array().join("; "),
        )
        assert_eq(scene.scene.unwrap().canonical_svg, output)
        let player = @render.Renderer::render(
          @animated.AnimatedRenderer::new(svg=renderer),
          model,
        )
        assert_false(
          player.diagnostics.iter().any(d => d.severity == Error),
          msg=example.id,
        )
        rows.push(
          Json([
            example.id + "-" + variant + ".html",
            "text/html",
            player.output.unwrap(),
          ]),
        )
      }
    }
  }
  connector_comparisons(rows)
  rows
}

///|
test "expanded sources retain exact reader text and convert through public adapters" {
  for example in gallery_cases() {
    ignore(gallery_model(example))
  }
}

///|
test "all expanded examples render without connector conflicts" {
  let failures : Array[String] = []
  for example in gallery_cases() {
    let rendered = @svg.SvgRenderer::new().render(gallery_model(example))
    if rendered.output is None ||
      rendered.diagnostics.iter().any(d => d.code.has_suffix("/legibility")) {
      failures.push(
        example.id +
        ": " +
        rendered.diagnostics.iter().map(d => d.message).to_array().join("; "),
      )
    }
  }
  assert_eq(failures, [])
}

///|
test "expanded sources produce portable themes scenes and offline players" (
  t : @test.Test,
) {
  let rows = render_expanded_gallery()
  t.write(Json(rows).stringify(indent=1))
  t.snapshot(filename="expanded-gallery.json")
}

///|
test "qualified expanded inventory preserves reproducible source and render options" (
  t : @test.Test,
) {
  let inventory = expanded_inventory()
  t.write(Json(inventory).stringify(indent=2))
  t.snapshot(filename="expanded-inventory.json")
}

///|
fn expanded_inventory() -> Array[Json] {
  let inventory : Array[Json] = []
  for example in gallery_cases() {
    let source_name = example.id + "." + example.extension
    let source_type = if example.extension == "bpmn" {
      "application/xml"
    } else {
      "text/plain"
    }
    inventory.push({
      "id": example.id,
      "family": example.family,
      "title": example.title,
      "status": "implemented",
      "description": example.description,
      "scope": example.scope,
      "sources": [gallery_file(source_name, source_type)],
      "preview": gallery_file(example.id + "-light.svg", "image/svg+xml"),
      "preview_dark": gallery_file(example.id + "-dark.svg", "image/svg+xml"),
      "player": gallery_file(example.id + "-light.html", "text/html"),
      "companions": [
        gallery_file(example.id + "-dark.html", "text/html"),
        gallery_file(example.id + "-adaptive.svg", "image/svg+xml"),
      ],
    })
  }
  inventory.append(connector_inventory())
  inventory
}
