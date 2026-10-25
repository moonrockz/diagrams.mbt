///|
test "canonical sequence scenes preserve every corpus SVG and bind every message occurrence" {
  let snapshots : Array[Json]=[]
  for input in @corpus.mermaid_12_2_0 {
    let sequence=@mermaid.to_sequence(@mermaid.read(input.source).ast.unwrap()).sequence
    for (mode,variant) in [(@svg.Mode::Adaptive,"adaptive"),(Fixed(Dark),"dark"),(Fixed(Light),"light")] {
      let renderer=@svg.SvgRenderer::new(mode~)
      let original=renderer.render(Sequence(sequence))
      let result=renderer.scene(Sequence(sequence))
      guard result.scene is Some(scene) else { fail("\{input.name}: \{result.diagnostics.map(d => d.message).iter().to_array().join("; ")}") }
      assert_eq(scene.canonical_svg,original.output.unwrap())
      assert_eq(scene.paths.length(),@layout.layout(sequence).messages.length())
      assert_eq(scene.catalog.occurrences.length(),scene.paths.length())
      for binding in scene.paths { assert_true(binding.path.has_prefix("M")); assert_true(scene.display_svg.contains(binding.id)) }
      assert_false(scene.display_svg.contains("<script")); assert_false(scene.canonical_svg.contains("data-motion-paths"))
      snapshots.push(Json([input.name,variant,scene.canonical_svg,scene.display_svg]))
    }
  }
  let t=@test.Test("sequence canonical and display scenes"); t.write(Json(snapshots).stringify()); t.snapshot(filename="scenes.json")
}
