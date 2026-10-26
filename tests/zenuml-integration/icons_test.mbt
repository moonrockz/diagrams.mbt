///|
test "every pinned annotator renders through public Mermaid convenience" {
  assert_eq(@icons.registry_keys().length(), 523)
  for key in @icons.registry_keys() {
    let result = @mermaid.render_svg("zenuml\n@" + key + " A\nA->B: notify\n")
    assert_false(
      result.diagnostics.iter().any(d => d.severity == Error),
      msg=key,
    )
    assert_false(
      result.diagnostics.iter().any(d => d.code.contains("unknown-icon")),
      msg=key,
    )
    assert_true(result.output.unwrap().contains("zenuml:" + key), msg=key)
    assert_true(result.output.unwrap().contains("<symbol"), msg=key)
  }
}

///|
test "complete provider symbol contact sheet" (t : @test.Test) {
  let nodes = []
  let defs = []
  let seen : Map[String, Bool] = Map([])
  for index, key in @icons.registry_keys() {
    let icon = @icon_ref.Reference::new("zenuml", key)
    let x = (index % 5 * 400).to_double()
    let y = (index / 5 * 90).to_double()
    let id = @icons.asset_id(icon, "sheet")
    if !seen.contains(id) {
      seen[id] = true
      defs.push(@icons.definition_node(icon, "sheet"))
    }
    nodes.push(@icons.paint_node(icon, "sheet", x + 8.0, y + 8.0, 40.0))
    nodes.push(
      @writer.element(
        "text",
        attrs=[
          ("x", (x + 8.0).to_string()),
          ("y", (y + 64.0).to_string()),
          ("font-size", "11"),
          ("fill", "#111111"),
        ],
        children=[@writer.text(key)],
      ),
    )
  }
  nodes.insert(0, @writer.element("defs", children=defs))
  let svg = @writer.to_string(
    @writer.element(
      "svg",
      attrs=[
        ("xmlns", "http://www.w3.org/2000/svg"),
        ("width", "2000"),
        ("height", "9450"),
        ("viewBox", "0 0 2000 9450"),
      ],
      children=nodes,
    ),
  )
  t.write(svg)
  t.snapshot(filename="icon-contact-sheet.svg")
}

///|
test "one symbol output stays bounded independently of full registry size" {
  let result = @mermaid.render_svg("zenuml\n@Actor A\nA->B: notify\n").output.unwrap()
  assert_eq(result.split("<symbol ").count() - 1, 1)
  assert_true(result.length() < 50000)
  assert_false(result.contains("Arch_AWS-Lambda"))
  assert_true(result.contains("MIT License"))
}
