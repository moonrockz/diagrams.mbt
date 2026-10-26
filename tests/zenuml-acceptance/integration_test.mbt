///|
fn source() -> String {
  "zenuml\n@Actor Client as API user\n@PostgreSQL Store\n@Kubernetes Worker\nClient->Service.request() {\n new Worker() {\n Worker->Store: save\n }\n try {\n Service->Store: query\n } catch(missing) {\n Service->Client: missing\n } catch(busy) {\n Service->Client: retry\n } finally {\n Service->Store: close\n }\n return result\n}"
}

///|
test "annotated calls creation and exception roles render through public dispatch" {
  let source = source()
  let result = @mermaid.render_svg(source)
  assert_true(result.output is Some(_))
  assert_true(result.diagnostics.iter().all(d => d.severity != Error))
  let output = result.output.unwrap()
  assert_true(output.contains("catch (missing)"))
  assert_true(output.contains("finally"))
  assert_true(output.contains("zenuml:"))
  let snapshot = @test.Test("annotated interaction")
  snapshot.write(output)
  snapshot.snapshot(filename="interaction.svg")
  let sequence = @zenuml.convert(@syntax.read(source).ast.unwrap()).sequence.unwrap()
  let layout = @layout.layout(sequence)
  assert_true(layout.participants[0].icon_box is Some(_))
  for palette in [@theme.Theme::classic().dark, @theme.Theme::classic().light] {
    assert_eq(@layout.check(layout, palette), [])
  }
  for mode in [@svg.Mode::Fixed(Dark), Fixed(Light)] {
    let fixed = @svg.render_sequence(sequence, mode~)
    assert_false(fixed.contains("var("))
    assert_false(fixed.contains("<style"))
  }
}

///|
test "symbols survive render properties isolated definitions playback and export" {
  let icon = @icons.Reference::new("zenuml", "postgresql")
  let participant = @model.Participant::new("db", kind=Service, icon~)
  let resolved = participant.with_properties(
    @model.ParticipantProperties::new(kind=Database, sublabel="Long model type"),
  )
  assert_eq(resolved.icon, Some(icon))
  assert_eq(resolved.kind, Service)
  assert_eq(resolved.render_kind(), Database)
  let sequence = @model.Sequence::new(
    [resolved, @model.Participant::new("other", icon~)],
    [@model.Event::Message(@model.Message::new("db", "other", "query"))],
  )
  let svg = @svg.render_sequence(sequence, id_prefix="one")
  assert_eq(svg.split("<symbol ").count() - 1, 1)
  let second = @svg.render_sequence(sequence, id_prefix="two")
  assert_true(svg != second)
  let scene = @svg.SvgRenderer::new().scene(@render.Diagram::Sequence(sequence)).scene.unwrap()
  assert_true(scene.canonical_svg.contains("zenuml:"))
  assert_true(scene.display_svg.contains("zenuml:"))
  let html = @render.Renderer::render(
    @animated.AnimatedRenderer::new(),
    @render.Diagram::Sequence(sequence),
  ).output.unwrap()
  assert_true(html.contains("zenuml:"))
  let snapshot = @test.Test("annotated player")
  snapshot.write(html)
  snapshot.snapshot(filename="annotated.html")
}

///|
test "exception playback requires ordered explicit sections without inferred finally" {
  let sequence = @zenuml.convert(
    @syntax.read(
      "zenuml\ntry {\nA->B: success\n} catch(problem) {\nB->A: failed\n} finally {\nA->B: cleanup\n}",
    ).ast.unwrap(),
  ).sequence.unwrap()
  let catalog = @animation.Catalog::sequence(sequence).catalog.unwrap()
  assert_eq(catalog.frames[0].sections[0].role, @model.SectionRole::Try)
  assert_eq(catalog.frames[0].sections[1].role, @model.SectionRole::Catch)
  assert_eq(catalog.frames[0].sections[2].role, @model.SectionRole::Finally)
  assert_eq(@animation.PlaybackPlan::sequence(catalog).plan, None)
  let key = catalog.frames[0].key
  let selected = @animation.PlaybackPlan::sequence(catalog, selections=[
    @animation.Selection::new(key, ExceptionSections([1])),
  ])
  assert_true(selected.plan is Some(_))
  assert_eq(
    @animation.PlaybackPlan::sequence(catalog, selections=[
      @animation.Selection::new(key, ExceptionSections([2, 1])),
    ]).plan,
    None,
  )
  let explicit = @animation.PlaybackPlan::sequence(catalog, selections=[
    @animation.Selection::new(key, ExceptionSections([0, 2])),
  ])
  assert_true(explicit.plan is Some(_))
}

///|
test "unknown symbols identify their names visibly and creation symbols fit measured headers" {
  let result = @mermaid.render_svg(
    "zenuml\n@MissingSymbol A as Long visible alias\nA->B: hello",
  )
  assert_true(result.output is Some(_))
  assert_true(
    result.diagnostics.iter().any(d => d.code == "zenuml/unknown-annotator"),
  )
  assert_true(result.diagnostics.iter().any(d => d.code == "svg/unknown-icon"))
  assert_true(result.output.unwrap().contains("[zenuml:missingsymbol]"))
  let sequence = @zenuml.convert(@syntax.read(source()).ast.unwrap()).sequence.unwrap()
  let geometry = @layout.layout(sequence)
  let worker = geometry.participants
    .iter()
    .find_first(p => p.id == "Worker")
    .unwrap()
  assert_true(worker.icon_box is Some(_))
  assert_true(worker.box.y > geometry.participants[0].box.y)
  assert_eq(worker.lifeline_top, worker.box.y + worker.box.height)
  assert_true(@mermaid.render_svg("zenuml\nreturn missing").output is None)
}

///|
test "unknown hostile long keys remain visible safe measured text" {
  let key = "missing<svg>&".repeat(20)
  let sequence = @model.Sequence::new(
    [
      @model.Participant::new(
        "A",
        label="Visible participant",
        icon=@icons.Reference::new("zenuml", key),
      ),
    ],
    [],
  )
  let rendered = @render.Renderer::render(
    @svg.SvgRenderer::new(),
    Sequence(sequence),
  )
  assert_true(rendered.output is Some(_))
  assert_eq(rendered.diagnostics.length(), 1)
  let output = rendered.output.unwrap()
  assert_true(output.contains("missing&lt;svg&gt;&amp;"))
  assert_false(output.contains("missing<svg>"))
  let geometry = @layout.layout(sequence)
  for palette in [@theme.Theme::classic().dark, @theme.Theme::classic().light] {
    assert_eq(@layout.check(geometry, palette), [])
  }
}

///|
test "ID isolation does not rewrite descriptive metadata that resembles a local reference" {
  let participant = @model.Participant::new(
    "A",
    properties=@model.ParticipantProperties::new(
      description="url(#authored-text)",
    ),
  )
  let output = @svg.render_sequence(
    @model.Sequence::new([participant], []),
    id_prefix="isolated",
  )
  assert_true(output.contains("url(#authored-text)"))
}
