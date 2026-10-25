///|
test "diagram renders" {
  let pass = @content.render_mermaid_blocks(
    "a.md", "<p>x</p><pre><code class=\"language-mermaid\">graph LR\nA --&gt; B\n</code></pre><p>y</p>",
  )
  assert_true(pass.html.has_prefix("<p>x</p><figure class=\"diagram\"><svg"))
  assert_true(pass.html.has_suffix("</svg></figure><p>y</p>"))
  assert_false(pass.html.contains("<pre"))
  assert_eq(pass.problems, [])
}

///|
test "diagram does not render" {
  let pass = @content.render_mermaid_blocks(
    "docs/a.md", "<pre><code class=\"language-mermaid\">graph LR\nA --&gt; B\n</code></pre><pre><code class=\"language-mermaid\">gantt\ntitle x\n</code></pre>",
  )
  assert_eq(pass.problems.length(), 1)
  assert_true(
    pass.problems[0]
    .render()
    .has_prefix("docs/a.md: Mermaid diagram 2 does not render"),
  )
  assert_false(pass.html.contains("class=\"mermaid\""))
}

///|
test "native swimlane fences use library SVG with isolated IDs and explicit failures" {
  let fence = "<pre><code class=\"language-mermaid\">swimlane-beta LR\nsubgraph Owner\nA[Start]\nend\nA --&gt; B\n</code></pre>"
  let pass = @content.render_mermaid_blocks("guide.md", fence + fence)
  assert_eq(pass.problems, [])
  assert_true(pass.html.contains("data-swimlane-id"))
  let ids = pass.html.split(" id=\"").collect()
  let seen : Map[String, Bool] = Map([])
  assert_true(ids.length() > 2)
  for i in 1..<ids.length() {
    let id = ids[i].split("\"").next().unwrap().to_owned()
    assert_false(seen.contains(id))
    seen[id] = true
  }
  let failed = @content.render_mermaid_blocks(
    "bad.md", "<pre><code class=\"language-mermaid\">swimlane-beta\nA@{ shape: image, img: 'https://example.com/x' }\n</code></pre>",
  )
  assert_eq(failed.problems.length(), 1)
  assert_true(
    failed.problems[0].render().contains("Mermaid diagram 1 does not render"),
  )
}
