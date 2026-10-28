///|
test "native state labels stay inert through source readers SVG and HTML" (
  t : @test.Test,
) {
  let hostile = "</script><script>globalThis.stateAttack=true</script>"
  let rows : Array[Json] = []
  for
    (name, source) in [
      (
        "state-mermaid-hostile",
        "stateDiagram-v2\nstate \"" +
        hostile +
        "\" as A\nstate B\n[*] --> A\nA --> B : event [guard] / action\n",
      ),
      (
        "state-plantuml-hostile",
        "@startuml\nstate \"" +
        hostile +
        "\" as A\nstate B\n[*] --> A\nA --> B : event [guard] / action\n@enduml\n",
      ),
    ] {
    let view = model(name, source)
    assert_true(view.states.any(s => s.label == hostile))
    let renderer = @svg.SvgRenderer::new(id_prefix=name)
    let svg = @render.Renderer::render(renderer, State(view)).output.unwrap()
    let html = @render.Renderer::render(
      @animated.AnimatedRenderer::new(svg=renderer),
      State(view),
    ).output.unwrap()
    assert_false(svg.contains(hostile))
    assert_false(html.contains(hostile))
    assert_true(svg.contains("&lt;/script&gt;"))
    assert_true(html.contains("\\u003c/script\\u003e"))
    rows.push(Json([name + ".svg", "image/svg+xml", svg]))
    rows.push(Json([name + ".html", "text/html", html]))
  }
  t.write(Json(rows).stringify(indent=1))
  t.snapshot(filename="hostile-state.json")
}
