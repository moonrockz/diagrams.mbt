///|
test "automatic corpus geometry is complete deterministic and legible in both palettes" {
  let snapshots : Array[Json]=[]
  for name in ["activities","events","collaboration","di-views"] {
    let document=model_document(name)
    let conversion=@adapter.to_diagram(document,selector=if name == "di-views" { Plane("D1") } else { Automatic },geometry_policy=Automatic)
    guard conversion.diagram is Some(Bpmn(view)) else { fail(@debug.to_string(conversion.diagnostics)) }
    let result=@bpmn_layout.layout(view,policy=Automatic)
    assert_true(result.geometry != None,msg="\{name}: \{@debug.to_string(result.diagnostics)}")
    let geometry=result.geometry.unwrap()
    assert_eq(result,@bpmn_layout.layout(view,policy=Automatic))
    for palette in [@theme.Theme::classic().dark,@theme.Theme::classic().light] {
      let findings=@bpmn_layout.check(geometry,@bpmn_layout.bpmn_palette(palette))
      assert_eq(findings,[],msg="\{name}: \{@debug.to_string(findings)}")
    }
    for (mode,variant) in [(@svg.Mode::Adaptive,"adaptive"),(Fixed(Dark),"dark"),(Fixed(Light),"light")] {
      let rendered=@svg.SvgRenderer::new(mode~,bpmn_policy=Automatic).render(Bpmn(view))
      assert_eq(rendered.diagnostics,[],msg="\{name}: \{@debug.to_string(rendered.diagnostics)}")
      check_bpmn_svg(rendered.output.unwrap()); snapshots.push(Json([name,variant,rendered.output.unwrap()]))
    }
  }
  for input in @corpus.render_inputs {
    let document=@bpmn.read(input.source).document.unwrap()
    for (policy,variant) in [(@model.GeometryPolicy::PreferDi,"expanded"),(Automatic,"semantic")] {
      let conversion=@adapter.to_diagram(document,geometry_policy=policy)
      guard conversion.diagram is Some(Bpmn(view)) else { fail(@debug.to_string(conversion.diagnostics)) }
      let result=@bpmn_layout.layout(view,policy=Automatic)
      assert_true(result.geometry != None,msg="\{input.name}/\{variant}: \{@debug.to_string(result.diagnostics)}")
      let geometry=result.geometry.unwrap()
      let findings=@bpmn_layout.check(geometry,@bpmn_layout.bpmn_palette(@theme.Theme::classic().dark))
      assert_eq(findings,[],msg="\{input.name}/\{variant}: \{@debug.to_string(findings)}")
      for (mode,theme_name) in [(@svg.Mode::Adaptive,"adaptive"),(Fixed(Dark),"dark"),(Fixed(Light),"light")] {
        let rendered=@svg.SvgRenderer::new(mode~,bpmn_policy=Automatic).render(Bpmn(view))
        assert_eq(rendered.diagnostics,[],msg="\{input.name}/\{variant}: \{@debug.to_string(rendered.diagnostics)}")
        snapshots.push(Json([input.name+"/"+variant,theme_name,rendered.output.unwrap()]))
      }
    }
  }
  let t=@test.Test("automatic BPMN corpus"); t.write(Json(snapshots).stringify()); t.snapshot(filename="automatic.json")
}
