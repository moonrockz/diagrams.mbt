///|
/// A nested sample: an object with repeated scalars, a nested array with a
/// nested object, empty containers, every scalar kind and a long text.
fn data_sample(
  highlights~ : Array[@data_tree.Highlight] = [],
) -> @data_tree.DataTree {
  let m = (id : String, name : String, value : String) => {
    @data_tree.Member::named(id, name, value)
  }
  let i = (id : String, index : Int32, value : String) => {
    @data_tree.Member::index(id, index, value)
  }
  @data_tree.DataTree::new(
    "sample",
    "v",
    [
      @data_tree.Node::object("v", [
        m("m/0", "name", "v/0"),
        m("m/1", "item", "v/1"),
        m("m/2", "item", "v/2"),
        m("m/3", "list", "v/3"),
        m("m/4", "empty", "v/4"),
        m("m/5", "none", "v/5"),
        m("m/6", "note", "v/6"),
      ]),
      @data_tree.Node::new("v/0", Text("<script>alert(\"x\") & 'y'</script>")),
      @data_tree.Node::new("v/1", Number("12345678901234567890123")),
      @data_tree.Node::new("v/2", Number("12345678901234567890123")),
      @data_tree.Node::array("v/3", [
        i("m/3/0", 0, "v/3/0"),
        i("m/3/1", 1, "v/3/1"),
        i("m/3/2", 2, "v/3/2"),
      ]),
      @data_tree.Node::new("v/3/0", Boolean(true)),
      @data_tree.Node::new("v/3/1", Text("true")),
      @data_tree.Node::object("v/3/2", [m("m/3/2/0", "deep", "v/3/2/0")]),
      @data_tree.Node::new("v/3/2/0", Number("-0.0")),
      @data_tree.Node::object("v/4", []),
      @data_tree.Node::new("v/5", Null),
      @data_tree.Node::new(
        "v/6",
        Text(
          "A long note that wraps over several lines without losing any of its words or spaces.\nA second paragraph.",
        ),
      ),
    ],
    highlights~,
    title="Sample data",
  )
}

///|
fn data_svg(
  tree : @data_tree.DataTree,
  mode~ : @svg.Mode = Adaptive,
) -> String raise {
  let rendered = @svg.render_data_tree(tree, mode~)
  guard rendered.output is Some(svg) else {
    fail(rendered.diagnostics.iter().map(d => d.message).collect().join("; "))
  }
  svg
}

///|
fn count(text : String, part : String) -> Int32 {
  text.split(part).count() - 1
}

///|
test "data SVG is standalone, script-free and follows the element contract" {
  let svg = data_svg(data_sample())
  assert_true(svg.has_prefix("<svg xmlns=\"http://www.w3.org/2000/svg\""))
  assert_true(svg.contains("data-diagram=\"data-tree\""))
  assert_true(svg.contains("<title>Sample data</title>"))
  assert_true(svg.contains("<desc>Structured data diagram with 12 values"))
  assert_eq(svg.find("<script"), None)
  assert_eq(svg.find("href"), None)
  for part in svg.split("url(").drop(1) {
    assert_true(part.has_prefix("#"))
  }
  assert_true(
    svg.contains("&lt;script&gt;alert(&quot;x&quot;) &amp; 'y'&lt;/script&gt;") ||
    svg.contains("&lt;script&gt;alert(\"x\") &amp; 'y'&lt;/script&gt;"),
  )
  // Four boxes: the root, the array, the nested object and the empty object.
  assert_eq(count(svg, "class=\"data-box\""), 4)
  assert_eq(count(svg, "class=\"data-row\""), 11)
  assert_eq(count(svg, "class=\"data-connector\""), 3)
  assert_true(
    svg.contains(
      "<g class=\"data-box\" data-node=\"v/4\" data-type=\"object\" data-empty=\"true\">",
    ),
  )
  assert_true(
    svg.contains(
      "<g class=\"data-row\" data-member=\"m/1\" data-node=\"v/1\" data-type=\"number\">",
    ),
  )
  assert_true(
    svg.contains(
      "<g class=\"data-row\" data-member=\"m/3/0\" data-node=\"v/3/0\" data-type=\"boolean\">",
    ),
  )
  assert_true(
    svg.contains(
      "<g class=\"data-row\" data-member=\"m/3/1\" data-node=\"v/3/1\" data-type=\"string\">",
    ),
  )
  assert_true(
    svg.contains(
      "<g class=\"data-row\" data-member=\"m/5\" data-node=\"v/5\" data-type=\"null\">",
    ),
  )
  assert_true(svg.contains("☑ true"))
  assert_true(svg.contains("␀ null"))
  assert_true(svg.contains(">12345678901234567890123<"))
  assert_true(svg.contains(">-0.0<"))
  assert_true(
    svg.contains("<path class=\"data-connector\" data-member=\"m/3\""),
  )
  assert_true(svg.contains("xml:space=\"preserve\""))
}

///|
test "long text wraps without losing code units" {
  let tree = data_sample()
  let geometry = @data_tree_layout.layout(tree).geometry.unwrap()
  let root = geometry.boxes[0]
  let note = root.rows[6].value.unwrap()
  assert_true(note.lines.length() > 2)
  let joined = note.lines.iter().collect().join("")
  assert_eq(
    joined, "A long note that wraps over several lines without losing any of its words or spaces.A second paragraph.",
  )
  for line in note.lines {
    assert_true(@data_tree_layout.text_width(line) <= 360.0)
  }
}

///|
test "nested containers have connectors and inline scalars do not" {
  let geometry = @data_tree_layout.layout(data_sample()).geometry.unwrap()
  assert_eq(geometry.connectors.map(c => c.entry).iter().collect(), [
    "m/3", "m/4", "m/3/2",
  ])
  for box in geometry.boxes {
    for row in box.rows {
      assert_eq(
        row.port is Some(_),
        row.kind is (Object | Array),
        msg=row.entry,
      )
    }
  }
  for connector in geometry.connectors {
    let points = connector.points
    let start = points[0]
    let end = points[points.length() - 1]
    assert_true(
      end.x - start.x > 10.0,
      msg="connector \{connector.entry} has length",
    )
  }
}

///|
test "the measured geometry passes its legibility checks" {
  let geometry = @data_tree_layout.layout(data_sample()).geometry.unwrap()
  let theme = @theme.Theme::classic()
  for palette in [theme.dark, theme.light] {
    let findings = @data_tree_layout.check(
      geometry,
      @data_tree_layout.palette(palette),
    )
    assert_eq(findings.map(f => f.message).iter().collect(), [])
  }
}

///|
test "highlights style only the selected occurrence and keep the stereotype inert" {
  let tree = data_sample(highlights=[
    @data_tree.Highlight::new(
      ["m/2"],
      style="color: red; } svg { display: none",
    ),
  ])
  let svg = data_svg(tree)
  assert_eq(count(svg, "data-highlight=\"true\""), 1)
  assert_true(
    svg.contains(
      "<g class=\"data-row\" data-member=\"m/2\" data-node=\"v/2\" data-type=\"number\" data-highlight=\"true\">",
    ),
  )
  assert_eq(svg.find("display: none"), None)
  assert_eq(svg.find("color: red"), None)
  // Both repeated values stay intact.
  assert_eq(count(svg, ">12345678901234567890123<"), 2)
  let plain = @data_tree_layout.layout(data_sample()).geometry.unwrap()
  let marked = @data_tree_layout.layout(tree).geometry.unwrap()
  assert_eq(
    plain.boxes.map(b => b.box).iter().collect(),
    marked.boxes.map(b => b.box).iter().collect(),
  )
}

///|
test "scalar roots and empty roots are visible boxes" {
  for
    value in [
      @data_tree.Value::Text("hello"),
      Number("42"),
      Boolean(false),
      Null,
      Object([]),
      Array([]),
    ] {
    let tree = @data_tree.DataTree::new("s", "v", [
      @data_tree.Node::new("v", value),
    ])
    let svg = data_svg(tree)
    assert_eq(count(svg, "class=\"data-box\""), 1)
    assert_eq(count(svg, "class=\"data-row\""), 0)
    assert_eq(count(svg, "class=\"data-connector\""), 0)
  }
}

///|
test "invalid XML characters and limits fail without partial output" {
  let bad = @data_tree.DataTree::new("s", "v", [
    @data_tree.Node::new("v", Text("nul\u{0}here")),
  ])
  let rendered = @svg.render_data_tree(bad)
  assert_true(rendered.output is None)
  assert_eq(rendered.diagnostics.map(d => d.code).iter().collect(), [
    "data-tree/invalid-xml-character",
  ])
  let small = @svg.render_data_tree(
    data_sample(),
    limits=@data_tree_layout.Limits::new(output_units=2000),
  )
  assert_true(small.output is None)
  assert_true(
    small.diagnostics.iter().any(d => d.code == "data-tree/render-limit"),
  )
  let work = @svg.render_data_tree(
    data_sample(),
    limits=@data_tree_layout.Limits::new(work=50),
  )
  assert_true(work.output is None)
  let shallow = @svg.render_data_tree(
    data_sample(),
    limits=@data_tree_layout.Limits::new(depth=1),
  )
  assert_true(shallow.output is None)
  assert_true(
    shallow.diagnostics.iter().any(d => d.code == "data-tree/model-limit"),
  )
}

///|
test "deep data renders without recursion" {
  let nodes = []
  let depth = 200
  for k in 0..<depth {
    nodes.push(
      @data_tree.Node::object("n\{k}", [
        @data_tree.Member::named("e\{k}", "k", "n\{k + 1}"),
      ]),
    )
  }
  nodes.push(@data_tree.Node::new("n\{depth}", Text("leaf")))
  let tree = @data_tree.DataTree::new("deep", "n0", nodes)
  let rendered = @svg.render_data_tree(tree)
  assert_true(rendered.output is Some(_))
  let shallow = @svg.render_data_tree(
    tree,
    limits=@data_tree_layout.Limits::new(depth=50),
  )
  assert_true(shallow.output is None)
}

///|
test "prefixes scope identifiers so two copies are independent" {
  let a = @svg.render_data_tree(data_sample(), id_prefix="a").output.unwrap()
  let b = @svg.render_data_tree(data_sample(), id_prefix="b").output.unwrap()
  assert_true(a.contains("id=\"dt-u-61-dt-arrow\""))
  assert_true(b.contains("id=\"dt-u-62-dt-arrow\""))
  assert_true(a.contains("url(#dt-u-61-dt-arrow)"))
  assert_true(a.contains("svg#dt-u-61-diagram"))
  assert_eq(a.find("dt-u-62"), None)
  assert_eq(data_svg(data_sample()), data_svg(data_sample()))
}

///|
test "fixed modes write literal colours" {
  let dark = data_svg(data_sample(), mode=Fixed(Dark))
  let light = data_svg(data_sample(), mode=Fixed(Light))
  assert_eq(dark.find("var(--"), None)
  assert_eq(light.find("var(--"), None)
  assert_eq(dark.find("<style"), None)
  assert_true(dark != light)
}

///|
test "scene bindings follow drawn rows, boxes and connectors" {
  let tree = data_sample()
  let result = @svg.SvgRenderer::new().scene(DataTree(tree))
  guard result.scene is Some(scene) else {
    fail(result.diagnostics.iter().map(d => d.message).collect().join("; "))
  }
  assert_eq(scene.canonical_svg, data_svg(tree))
  assert_eq(scene.paths.length(), 3)
  let geometry = @data_tree_layout.layout(tree).geometry.unwrap()
  for binding in scene.paths {
    let entry = binding.occurrence.data_member.unwrap().id
    let connector = geometry.connectors
      .iter()
      .find_first(c => c.entry == entry)
      .unwrap()
    assert_eq(binding.path, connector.path())
    assert_true(scene.canonical_svg.contains("d=\"" + binding.path + "\""))
  }
  let rows = scene.nodes.iter().filter(n => n.kind is DataRow(_)).count()
  let boxes = scene.nodes.iter().filter(n => n.kind is DataBox(_)).count()
  assert_eq(rows, 11)
  assert_eq(boxes, 4)
  // An inline scalar row is a visit target and has no path.
  assert_true(scene.nodes.iter().any(n => n.kind == DataRow("m/1")))
  assert_true(
    !scene.paths
    .iter()
    .any(p => p.occurrence.data_member.map(m => m.id) == Some("m/1")),
  )
}

///|
test "data SVG snapshots in adaptive and fixed modes" {
  let tree = data_sample(highlights=[
    @data_tree.Highlight::new(["m/2", "m/3/2/0"]),
  ])
  let adaptive = @test.Test("data adaptive")
  adaptive.write(data_svg(tree))
  adaptive.snapshot(filename="data-adaptive.svg")
}

///|
test "data SVG fixed dark snapshot" {
  let t = @test.Test("data dark")
  let tree = data_sample(highlights=[
    @data_tree.Highlight::new(["m/2", "m/3/2/0"]),
  ])
  t.write(data_svg(tree, mode=Fixed(Dark)))
  t.snapshot(filename="data-dark.svg")
}

///|
test "data SVG fixed light snapshot" {
  let t = @test.Test("data light")
  let tree = data_sample(highlights=[
    @data_tree.Highlight::new(["m/2", "m/3/2/0"]),
  ])
  t.write(data_svg(tree, mode=Fixed(Light)))
  t.snapshot(filename="data-light.svg")
}
