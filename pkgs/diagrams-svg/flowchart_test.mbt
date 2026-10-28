///|
test "every vector shape has portable themed SVG and attached paths" {
  let frames : Array[Json] = []
  for shape in @flowchart.built_in_shapes {
    let model = @flowchart.Flowchart::new(
      shape,
      [
        @flowchart.Node::new("A", label=shape, shape~, lane="L"),
        @flowchart.Node::new("B", label="Next", lane="L"),
      ],
      [
        @flowchart.Connection::new(
          "AB",
          "A",
          "B",
          label="next",
          source_marker=Circle,
        ),
      ],
      lanes=[@flowchart.Lane::new("L", label="Responsibility")],
      direction=LR,
    )
    for
      (mode, name) in [
        (@svg.Mode::Adaptive, "adaptive"),
        (Fixed(Dark), "dark"),
        (Fixed(Light), "light"),
      ] {
      let result = @svg.render_flowchart(model, mode~)
      assert_true(
        result.output != None,
        msg=shape + @debug.to_string(result.diagnostics),
      )
      assert_eq(
        result.diagnostics,
        [],
        msg=shape + @debug.to_string(result.diagnostics),
      )
      let svg = result.output.unwrap()
      assert_true(svg.contains("data-shape=\"" + shape + "\""))
      assert_false(svg.contains("<script"))
      assert_false(svg.contains("href="))
      assert_true(svg.contains("data-flowchart-id=\"AB\""))
      frames.push(Json([shape, name, svg]))
    }
  }
  let t = @test.Test("flowchart vector catalog")
  t.write(Json(frames).stringify())
  t.snapshot(filename="flowchart-shapes.json")
}

///|
test "spanning partition retains group and explicit lane geometry" {
  let view=@flowchart.Flowchart::new("spanning",[
    @flowchart.Node::new("A",label="Request",groups=["partition"],lane="customer",role=Action),
    @flowchart.Node::new("B",label="Review",groups=["partition"],lane="support",role=Action),
  ],[@flowchart.Connection::new("AB","A","B")],groups=[@flowchart.Group::new("partition",label="Shared partition")],lanes=[@flowchart.Lane::new("customer"),@flowchart.Lane::new("support")])
  assert_eq(@flowchart.validate(view),[])
  let result=@flowchart_layout.layout(view)
  guard result.geometry is Some(geometry) else { fail(@debug.to_string(result.diagnostics)) }
  let shapes=Map(geometry.shapes.map(s => (s.id,s)))
  assert_true(shapes["customer"].box.contains(shapes["A"].box))
  assert_true(shapes["support"].box.contains(shapes["B"].box))
  assert_true(shapes["partition"].box.contains(shapes["A"].box))
  assert_true(shapes["partition"].box.contains(shapes["B"].box))
  assert_eq(@flowchart_layout.check(geometry,@theme.Theme::classic().light),[])
  let rendered=@svg.SvgRenderer::new().render(Flowchart(view))
  assert_eq(rendered.diagnostics,[])
  assert_true(rendered.output.unwrap().contains("data-flowchart-id=\"partition\""))
}

///|
test "flowchart notes are bound without creating route edges" {
  let view=@flowchart.Flowchart::new("notes",[@flowchart.Node::new("A",label="Read",role=Action),@flowchart.Node::new("B",label="Read",role=Action)],[@flowchart.Connection::new("AB","A","B")],notes=[@flowchart.Note::new("note","Plain note",targets=["A"])])
  let renderer=@svg.SvgRenderer::new()
  let rendered=renderer.render(Flowchart(view))
  assert_true(rendered.output is Some(_),msg=@debug.to_string(rendered.diagnostics))
  let scene=renderer.scene(Flowchart(view)).scene.unwrap()
  assert_eq(scene.canonical_svg,rendered.output.unwrap())
  assert_eq(scene.paths.length(),1)
  assert_eq(scene.catalog.graph.edges.length(),1)
  assert_true(scene.catalog.graph.nodes.any(n => n.id == "note"))
  assert_true(scene.catalog.occurrences.any(o => o.is_visit()))
  assert_true(scene.display_svg.contains("data-flowchart-id=\"note\""))
}

///|
test "flowchart limits unsupported shapes and text are explicit" {
  let bad=@flowchart.Flowchart::new("bad",[@flowchart.Node::new("image",shape="image")],[])
  assert_eq(@svg.render_flowchart(bad).output,None)
  assert_true(@svg.render_flowchart(bad).diagnostics.any(d => d.code == "flowchart/unsupported-shape"))
  let model=@flowchart.Flowchart::new("safe",[@flowchart.Node::new("A",label="</script><svg onload='x'>")],[])
  let rendered=@svg.render_flowchart(model,id_prefix="copy")
  assert_true(rendered.output.unwrap().contains("&lt;/script&gt;"))
  assert_false(rendered.output.unwrap().contains("<svg onload"))
  assert_eq(@svg.render_flowchart(model,limits=@flowchart_layout.Limits::new(width=1)).output,None)
  assert_eq(@svg.render_flowchart(model,limits=@flowchart_layout.Limits::new(work=1)).output,None)
}
///|
test "notes honor authored sides and connection targets bind actual drawn paths" {
  let model=@flowchart.Flowchart::new("notes",[@flowchart.Node::new("a",label="Read"),@flowchart.Node::new("b",label="Write")],[@flowchart.Connection::new("edge","a","b")],notes=[@flowchart.Note::new("left","left note",targets=["a"],placement="left"),@flowchart.Note::new("top","top note",targets=["a"],placement="top"),@flowchart.Note::new("on-edge","edge note",connection_targets=["edge"])])
  let result=@flowchart_layout.layout(model)
  guard result.geometry is Some(geometry) else { fail(@debug.to_string(result.diagnostics)) }
  let shapes=Map(geometry.shapes.map(s => (s.id,s)))
  assert_true(shapes["left"].box.x+shapes["left"].box.width < shapes["a"].box.x)
  assert_true(shapes["top"].box.y+shapes["top"].box.height < shapes["a"].box.y)
  let association=geometry.connections.iter().find_first(c => c.connection.target == "on-edge").unwrap()
  assert_eq(association.connection.source,"edge")
  assert_eq(association.connection.role,NoteAttachment)
  let drawn=geometry.connections.iter().find_first(c => c.connection.id == "edge").unwrap()
  let point=association.line[0]
  let mut on_path=false
  for i in 1..<drawn.line.length() {
    let a=drawn.line[i-1];let b=drawn.line[i]
    if a.x == b.x && point.x == a.x && point.y >= Double::min(a.y,b.y) && point.y <= Double::max(a.y,b.y) { on_path=true }
    if a.y == b.y && point.y == a.y && point.x >= Double::min(a.x,b.x) && point.x <= Double::max(a.x,b.x) { on_path=true }
  }
  assert_true(on_path)
  assert_eq(@flowchart_layout.check(geometry,@theme.Theme::classic().light),[])
  let renderer=@svg.SvgRenderer::new()
  let svg=renderer.render(Flowchart(model)).output.unwrap()
  for id in geometry.hidden_containers() { assert_false(svg.contains("data-flowchart-id=\""+id+"\"")) }
  assert_eq(renderer.scene(Flowchart(model)).scene.unwrap().catalog.graph.edges.length(),1)
}
///|
test "local arrow hints preserve endpoint identities and control geometry" {
  let model=@flowchart.Flowchart::new("hints",[@flowchart.Node::new("a"),@flowchart.Node::new("b"),@flowchart.Node::new("c")],[@flowchart.Connection::new("right","a","b",direction_hint=LR),@flowchart.Connection::new("up","b","c",direction_hint=BT)])
  let geometry=@flowchart_layout.layout(model).geometry.unwrap()
  let shapes=Map(geometry.shapes.map(s => (s.id,s)))
  assert_true(shapes["b"].box.x > shapes["a"].box.x)
  assert_true(shapes["c"].box.y < shapes["b"].box.y)
  assert_eq(geometry.connections[0].connection.source,"a")
  assert_eq(geometry.connections[0].connection.target,"b")
  assert_eq(@flowchart_layout.check(geometry,@theme.Theme::classic().light),[])
}
///|
test "control region scene binding names its real entry shape" {
  let model=@flowchart.Flowchart::new("region",[@flowchart.Node::new("entry",role=Decision,regions=["r"])],[],regions=[@flowchart.Region::new("r",Conditional,entry="entry",members=["entry"])])
  let scene=@svg.SvgRenderer::new().scene(Flowchart(model)).scene.unwrap()
  assert_true(scene.nodes.any(binding => binding.endpoint == "r" && binding.kind == Flowchart("entry")))
  assert_eq(scene.paths.length(),0)
}

///|
test "layout warnings survive crossing containers and connection notes" {
  for crossing in [false,true] {
    let model=@flowchart.Flowchart::new("warnings",[
      @flowchart.Node::new("a",label="<b>Read</b>",label_kind=Html,groups=if crossing { ["partition"] } else { [] },lane?=if crossing { Some("customer") } else { None }),
      @flowchart.Node::new("b",label="Write",groups=if crossing { ["partition"] } else { [] },lane?=if crossing { Some("support") } else { None }),
    ],[@flowchart.Connection::new("ab","a","b")],
      groups=if crossing { [@flowchart.Group::new("partition")] } else { [] },
      lanes=if crossing { [@flowchart.Lane::new("customer"),@flowchart.Lane::new("support")] } else { [] },
      notes=[@flowchart.Note::new("note","Explain",connection_targets=["ab"])],
    )
    let layout=@flowchart_layout.layout(model)
    assert_true(layout.geometry is Some(_),msg=@debug.to_string(layout.diagnostics))
    assert_eq(layout.diagnostics.iter().filter(d => d.code == "flowchart/plain-text-label").count(),1)
    let rendered=@svg.render_flowchart(model)
    assert_true(rendered.output is Some(_),msg=@debug.to_string(rendered.diagnostics))
    assert_eq(rendered.diagnostics.iter().filter(d => d.code == "flowchart/plain-text-label").count(),1)
  }
}
