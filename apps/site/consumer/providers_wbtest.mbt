///|
fn input(
  language : String,
  body : String,
  ordinal : Int32,
) -> @extensions.RenderInput {
  {
    source: "fixture.md",
    route: "/docs/fixture/",
    base_path: "/diagrams.mbt/next/",
    body,
    language,
    ordinal,
  }
}

///|
async test "compiled native providers retain figure markup and legacy SVG prefixes" {
  for
    (file, language) in [
      ("swimlane-review.mmd", "mermaid"),
      ("zenuml-symbols.mmd", "mermaid"),
      ("architecture-cloud.mmd", "mermaid"),
      ("regex-date.puml", "plantuml"),
      ("ebnf-arithmetic.puml", "puml"),
    ] {
    let body = @fs.read_file("assets/examples/" + file).text()
    let rendered = @extensions.render_fence(
      providers(),
      input(language, body, 2),
    )
    guard rendered is Ok(output) else { fail("provider rejected " + file) }
    assert_true(output.body_html.has_prefix("<figure class=\"diagram\"><svg"))
    let next = @extensions.render_fence(providers(), input(language, body, 3))
    guard next is Ok(next) else {
      fail("second provider occurrence rejected " + file)
    }
    assert_true(output.body_html != next.body_html)
    assert_eq(output.text, body)
  }
}

///|
test "aliases share a provider and failed diagrams return diagnostics" {
  let registry = providers()
  assert_eq(@extensions.validate_registry(registry), [])
  assert_eq(registry.fences[1].labels, ["plantuml", "puml"])
  let failed = @extensions.render_fence(
    registry,
    input("mermaid", "gantt\ntitle unsupported", 3),
  )
  guard failed is Err(problems) else { fail("invalid diagram succeeded") }
  assert_true(problems[0].message.contains("Mermaid diagram 3"))
}
