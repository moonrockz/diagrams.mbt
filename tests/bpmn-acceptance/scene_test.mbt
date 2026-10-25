///|
test "BPMN scenes share supplied and automatic geometry while canonical bytes remain ordinary SVG" {
  let snapshots : Array[Json]=[]
  for input in @corpus.render_inputs {
    let document=@bpmn.read(input.source).document.unwrap()
    let diagram=@adapter.to_diagram(document).diagram.unwrap()
    for (policy,policy_name) in [(@model.GeometryPolicy::RequireDi,"supplied"),(Automatic,"automatic")] {
      for (mode,variant) in [(@svg.Mode::Adaptive,"adaptive"),(Fixed(Dark),"dark"),(Fixed(Light),"light")] {
        let renderer=@svg.SvgRenderer::new(mode~,bpmn_policy=policy)
        let result=renderer.scene(diagram)
        guard result.scene is Some(scene) else { fail(@debug.to_string(result.diagnostics)) }
        assert_eq(result.diagnostics,[])
        assert_eq(scene.canonical_svg,renderer.render(diagram).output.unwrap())
        assert_eq(scene.paths.length(),scene.catalog.occurrences.length())
        check_bpmn_svg(scene.display_svg)
        for binding in scene.paths { assert_true(scene.display_svg.contains(binding.id)); assert_true(binding.path.has_prefix("M")) }
        snapshots.push(Json([input.name+"/"+policy_name,variant,scene.canonical_svg,scene.display_svg]))
      }
    }
  }
  let t=@test.Test("BPMN canonical and display scenes"); t.write(Json(snapshots).stringify()); t.snapshot(filename="scenes.json")
}

///|
test "scene ID namespaces and output bounds are explicit" {
  let view=@adapter.to_diagram(@bpmn.read(fixture()).document.unwrap()).diagram.unwrap()
  let a=@svg.SvgRenderer::new(id_prefix="A").scene(view).scene.unwrap()
  let b=@svg.SvgRenderer::new(id_prefix="B").scene(view).scene.unwrap()
  assert_true(a.paths[0].id != b.paths[0].id)
  let limited=@svg.SvgRenderer::new().scene(view,output_units=10)
  assert_true(limited.scene is None); assert_eq(limited.diagnostics[0].code,"animation/scene-limit")
}
