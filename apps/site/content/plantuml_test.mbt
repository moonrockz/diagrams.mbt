///|
fn fence(language : String, source : String) -> String {
  "<pre><code class=\"language-\{language}\">" +
  source
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;") +
  "</code></pre>"
}

///|
test "plantuml and puml fences render the four native kinds inline" {
  let html = [
    fence("plantuml", "@startregex\na(b|c)*\n@endregex"),
    fence("puml", "@startebnf\nr = \"a\", { r };\n@endebnf"),
    fence("plantuml", "@startjson\n{\"a\": [1, \"<b>\"]}\n@endjson"),
    fence("puml", "@startyaml\na: b\n@endyaml"),
  ].join("\n")
  let pass = @content.render_plantuml_blocks("docs/a.md", html)
  assert_eq(pass.problems.length(), 0)
  assert_eq(pass.html.split("<figure class=\"diagram\">").count() - 1, 4)
  for kind in ["regex", "ebnf", "data-tree"] {
    assert_true(pass.html.contains("data-diagram=\"\{kind}\""), msg=kind)
  }
  assert_false(pass.html.contains("language-plantuml"))
}

///|
test "adjacent copies have scoped identifiers" {
  let source = fence("plantuml", "@startregex\na+\n@endregex")
  let pass = @content.render_plantuml_blocks("docs/a.md", source + source)
  let ids = pass.html
    .split("id=\"")
    .drop(1)
    .map(part => part.split("\"").next().unwrap().to_owned())
    .collect()
  assert_true(ids.length() >= 4)
  let unique : Map[String, Bool] = Map([])
  for id in ids {
    assert_false(unique.contains(id), msg=id)
    unique[id] = true
  }
}

///|
test "a failing PlantUML diagram reports the file and the diagram number" {
  let html = fence("plantuml", "@startregex\na\n@endregex") +
    fence("puml", "@startregex\n(ab\n@endregex")
  let pass = @content.render_plantuml_blocks("docs/b.md", html)
  assert_eq(pass.problems.length(), 1)
  let text = @debug.to_string(pass.problems[0])
  assert_true(text.contains("docs/b.md"))
  assert_true(text.contains("PlantUML diagram 2"))
}

///|
test "ordinary json, yaml, regex and ebnf code blocks stay code" {
  let html = [
    fence("json", "{\"a\": 1}"),
    fence("yaml", "a: b"),
    fence("regex", "a+"),
    fence("ebnf", "r = \"a\";"),
  ].join("\n")
  let pass = @content.render_plantuml_blocks("docs/c.md", html)
  assert_eq(pass.html, html)
  assert_eq(pass.problems.length(), 0)
}
