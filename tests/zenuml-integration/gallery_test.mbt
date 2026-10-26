///|
let annotated : String =
  #|zenuml
  #|title Checkout interaction
  #|@Actor Customer
  #|@EC2 API as "Orders API"
  #|@Lambda Worker
  #|@AzureFunction Functions
  #|@BigQuery Analytics
  #|@PostgreSQL Store
  #|@Kubernetes Cluster
  #|Customer->API.checkout() {
  #|    Worker.process() {
  #|        Store->Analytics: record
  #|    }
  #|    Functions->Cluster: deploy request
  #|}

///|
let architecture_example : String =
  #|architecture-beta
  #|title Offline architecture
  #|accTitle: Order processing
  #|accDescr: Authored connections, not deployment execution
  #|group cloud(cloud)[Cloud]
  #|group backend(server)[Backend] in cloud
  #|service api(server)[API] in backend
  #|service db(database)[Database] in cloud
  #|service disk(disk)[Disk]
  #|service net(internet)[Internet]
  #|junction hub in cloud
  #|api:R <--> L:db
  #|db:B --> T:hub
  #|hub:R -- L:disk
  #|disk:R --> L:net

///|
fn diagram(source : String) -> @render.Diagram raise {
  let read = @mermaid.read_diagram(source)
  assert_false(read.diagnostics.iter().any(d => d.severity == Error))
  match read.ast.unwrap() {
    Zenuml(ast) =>
      @render.Diagram::Sequence(
        @mermaid.to_zenuml_sequence(ast).sequence.unwrap(),
      )
    Architecture(ast) =>
      @render.Diagram::Architecture(
        @mermaid.to_architecture(ast).architecture.unwrap(),
      )
    _ => abort("Expected new Mermaid kind")
  }
}

///|
test "ZenUML and architecture review gallery with offline players" (
  t : @test.Test,
) {
  let rows : Array[Json] = []
  for
    (name, source) in [
      ("zenuml-symbols", annotated),
      (
        "zenuml-exceptions",
        annotated +
        "\ntry {\n API->Store: query\n} catch(missing) {\n Store->API: absent\n} catch(busy) {\n Store->API: retry\n} finally {\n API->Store: close\n}\n",
      ),
      ("architecture-cloud", architecture_example),
      ("architecture-grid", architecture_grid),
      ("architecture-group-boundary", architecture_group_boundary),
    ] {
    rows.push(
      Json::array([Json(name + ".mmd"), Json("text/plain"), Json(source)]),
    )
    let model = diagram(source)
    for
      (variant, mode) in [
        ("dark", @svg.Mode::Fixed(Dark)),
        ("light", @svg.Mode::Fixed(Light)),
        ("adaptive", @svg.Mode::Adaptive),
      ] {
      let renderer = @svg.SvgRenderer::new(
        mode~,
        id_prefix=name + "-" + variant,
      )
      let rendered = @render.Renderer::render(renderer, model)
      assert_false(rendered.diagnostics.iter().any(d => d.severity == Error))
      rows.push(
        Json::array([
          Json(name + "-" + variant + ".svg"),
          Json("image/svg+xml"),
          Json(rendered.output.unwrap()),
        ]),
      )
      let playback = match model {
        Sequence(sequence) => {
          let catalog = @animation.Catalog::sequence(sequence).catalog.unwrap()
          let selections = catalog.frames
            .iter()
            .filter(f => f.kind == Try)
            .map(f => {
              @animation.Selection::new(f.key, ExceptionSections([0, 1, 3]))
            })
            .to_array()
          if selections.is_empty() {
            None
          } else {
            @animation.PlaybackPlan::sequence(catalog, selections~).plan
          }
        }
        _ => None
      }
      let html = @render.Renderer::render(
        @animated.AnimatedRenderer::new(svg=renderer, playback?),
        model,
      )
      assert_false(html.diagnostics.iter().any(d => d.severity == Error))
      rows.push(
        Json::array([
          Json(name + "-" + variant + ".html"),
          Json("text/html"),
          Json(html.output.unwrap()),
        ]),
      )
    }
  }
  t.write(Json(rows).stringify(indent=1))
  t.snapshot(filename="new-gallery.json")
}

///|
let architecture_grid : String = "architecture-beta\n    group sources(cloud)[Sources]\n        service src_a(server)[Source A] in sources\n        service src_b(server)[Source B] in sources\n        service src_c(server)[Source C] in sources\n\n    group storage(database)[Storage]\n        service db_one(database)[DB One] in storage\n        service db_two(database)[DB Two] in storage\n        service db_three(database)[DB Three] in storage\n\n    group output(disk)[Output]\n        service brief(disk)[Brief] in output\n        service analyst(server)[Analyst] in output\n        service delivery(cloud)[Delivery] in output\n\n    src_a:B --> T:db_one\n    src_b:B --> T:db_two\n    src_c:B --> T:db_three\n    db_two:B --> T:brief\n    brief:R --> L:analyst\n    analyst:R --> L:delivery\n\n    align row src_a src_b src_c\n    align row db_one db_two db_three\n    align row brief analyst delivery\n\n    align column src_a db_one\n    align column src_b db_two brief\n    align column src_c db_three\n"

///|
let architecture_group_boundary : String = "architecture-beta\ngroup left(cloud)[Left]\ngroup right(server)[Right]\nservice a(server)[A] in left\nservice b(database)[B] in right\na{group}:R --> L:b{group}\na{group}:R <-- L:b{group}\n"
