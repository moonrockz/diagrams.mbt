///|
fn field(value : Json, key : String) -> Json { guard value is Object(fields) else { abort("Expected object") }; fields.get(key).unwrap() }
///|
fn string(value : Json) -> String { guard value is String(value) else { abort("Expected string") }; value }
///|
fn array(value : Json) -> Array[Json] { guard value is Array(values) else { abort("Expected array") }; values }
///|
fn actual_nodes(model : @model.Swimlane) -> Json { Json(model.nodes.iter().map(node => Json({"id":Json(node.id),"label":Json(node.label),"shape":Json(node.shape)})).to_array()) }
///|
test "all frozen docs and reference semantics agree with native Mermaid 12.2.0" {
 let fixtures=array(field(@json.parse(@corpus.reference),"fixtures"))
 for fixture in fixtures {
  let name=string(field(fixture,"name")); let source=string(field(fixture,"source"))
  let result=@syntax.read(source)
  assert_eq(result.tree.text(),source)
  if !result.diagnostics.is_empty() { fail(name+" "+result.diagnostics.iter().map(d => d.code+" "+d.message+" "+d.span.map(s => source[s.start.offset:s.end.offset].to_owned()).unwrap_or("")).to_array().join("; ")) }
  let ast=result.ast.unwrap()
  let rendered=@printer.print(ast)
  guard rendered.output is Some(printed) else { fail(name+" printer "+rendered.diagnostics.iter().map(d => d.code+" "+d.message).to_array().join("; ")) }
  let again=@syntax.read(printed)
  assert_eq(again.diagnostics.length(),0)
  assert_eq(again.ast.unwrap().statements.length(),ast.statements.length())
  for i,statement in ast.statements {
   if statement != again.ast.unwrap().statements[i] { fail(name+" canonical statement "+i.to_string()+" original "+statement.spelling+" canonical "+again.ast.unwrap().statements[i].spelling) }
  }
  assert_eq(@printer.print(again.ast.unwrap()).output,Some(printed))
  let converted=@conversion.to_swimlane(ast)
  if converted.swimlane == None { fail(name+" conversion "+converted.diagnostics.iter().map(d => d.code+" "+d.message+" "+d.span.map(s => source[s.start.offset:s.end.offset].to_owned()).unwrap_or("")).to_array().join("; ")) }
  let model=converted.swimlane.unwrap(); let expected=field(fixture,"normalized")
  assert_eq(Some(model.direction),@model.direction(string(field(expected,"direction"))))
  let expected_nodes=Json(array(field(expected,"nodes")).map(node => Json({"id":field(node,"id"),"label":field(node,"label"),"shape":Json(@model.canonical_shape(string(field(node,"shape"))))})))
  if actual_nodes(model) != expected_nodes { fail(name+" actual nodes "+actual_nodes(model).stringify()+" expected "+expected_nodes.stringify()) }
  if model.connections.length() != array(field(expected,"edges")).length() { fail(name+" edges "+Json(model.connections.iter().map(e => Json([e.source,e.target,e.label])).to_array()).stringify()+" expected "+field(expected,"edges").stringify()) }
  for i,node in model.nodes {
   let expected_kind=string(field(array(field(expected,"nodes"))[i],"labelKind"))
   assert_eq(node.label_kind,match expected_kind { "markdown" => @model.LabelKind::Markdown; "html" => Html; _ => Text })
  }
  for i,edge in model.connections {
   let expected_edge=array(field(expected,"edges"))[i]
   assert_eq(edge.source,string(field(expected_edge,"source")))
   assert_eq(edge.target,string(field(expected_edge,"target")))
   assert_eq(edge.label,string(field(expected_edge,"label")))
   assert_eq(edge.id,string(field(expected_edge,"id")))
   if Json(edge.min_length) != field(expected_edge,"length") { fail(name+" edge "+edge.id+" length actual="+edge.min_length.to_string()+" expected="+field(expected_edge,"length").stringify()) }
   assert_eq(edge.style,match string(field(expected_edge,"style")) { "dotted" => @model.LineStyle::Dotted; "thick" => Thick; "invisible" => Invisible; _ => Solid })
   match string(field(expected_edge,"type")) {
    "double_arrow_point" => { assert_eq(edge.source_marker,@model.Marker::Arrow); assert_eq(edge.target_marker,@model.Marker::Arrow) }
    "double_arrow_circle" => { assert_eq(edge.source_marker,@model.Marker::Circle); assert_eq(edge.target_marker,@model.Marker::Circle) }
    "double_arrow_cross" => { assert_eq(edge.source_marker,@model.Marker::Cross); assert_eq(edge.target_marker,@model.Marker::Cross) }
    "arrow_point" => { assert_eq(edge.source_marker,@model.Marker::None); assert_eq(edge.target_marker,@model.Marker::Arrow) }
    "arrow_circle" => { assert_eq(edge.source_marker,@model.Marker::None); assert_eq(edge.target_marker,@model.Marker::Circle) }
    "arrow_cross" => { assert_eq(edge.source_marker,@model.Marker::None); assert_eq(edge.target_marker,@model.Marker::Cross) }
    "arrow_open" => assert_eq(edge.target_marker,@model.Marker::None)
    unexpected => fail("Unexpected upstream edge type "+unexpected)
   }
  }
  let reference_groups=array(field(expected,"groups"))
  let parents : Map[String,String]=Map([])
  for group in reference_groups {
   for child in array(field(group,"members")) { parents[string(child)]=string(field(group,"id")) }
  }
  let expected_lanes=reference_groups.filter(group => !parents.contains(string(field(group,"id")))).map(group => string(field(group,"id")))
  assert_eq(model.lanes.iter().map(lane => lane.id).to_array(),expected_lanes)
  assert_eq(model.groups.length()+model.lanes.length(),reference_groups.length())
  for node in model.nodes {
   let mut owner=parents.get(node.id); let path=[]; let mut lane : String?=None
   while owner is Some(id) {
    if parents.get(id) is Some(parent) { path.push(id); owner=Some(parent) }
    else { lane=Some(id); owner=None }
   }
   let ordered=[]; for i=path.length()-1; i>=0; i=i-1 { ordered.push(path[i]) }
   assert_eq(node.lane,lane)
   assert_eq(node.groups.iter().to_array(),ordered)
  }
  for group in reference_groups {
   let id=string(field(group,"id"))
   let label=string(field(group,"label"))
   let actual_label=match model.lanes.iter().find_first(lane => lane.id == id) { Some(lane) => Some(lane.label); None => model.groups.iter().find_first(group => group.id == id).map(group => group.label) }
   assert_eq(actual_label,Some(label))
   let actual_direction=match model.lanes.iter().find_first(lane => lane.id == id) { Some(lane) => lane.direction; None => model.groups.iter().find_first(group => group.id == id).unwrap().direction }
   let expected_direction=match field(group,"direction") { String(value) => @model.direction(value); _ => None }
   assert_eq(actual_direction,expected_direction)
   for child in array(field(group,"members")) {
    let child=string(child)
    if model.nodes.iter().find_first(node => node.id == child) is Some(node) {
     assert_true(node.lane == Some(id) || node.groups.contains(id))
    }
   }
  }
 }
}
///|
test "dispatch supports both kinds and rejects unsupported inputs and renderer failures" {
 for source in ["sequenceDiagram\nA->>B: hello","swimlane-beta LR\nsubgraph Owner\nA\nend\nA --> B"] {
  let read=@mermaid.read_diagram(source)
  assert_eq(read.tree.text(),source)
  assert_true(read.ast != None)
  let printed=@mermaid.print_diagram(read.ast.unwrap())
  assert_eq(@mermaid.read_diagram(printed.output.unwrap()).ast,read.ast)
 }
 assert_eq(@mermaid.read_diagram("flowchart LR\nA-->B").ast,None)
 assert_eq(@mermaid.render_svg("swimlane-beta\nA@{ shape: image, img: 'https://example.com/a.svg' }").output,None)
}
///|
test "conversion has explicit expansion and node limits" {
 let ast=@syntax.read("swimlane-beta\nA & B --> C & D").ast.unwrap()
 let limited=@conversion.to_swimlane(ast,limits=@syntax.Limits::new(edges=3))
 assert_eq(limited.swimlane,None)
 assert_eq(limited.diagnostics[0].code,"swimlane/edge-limit")
 let limited=@conversion.to_swimlane(ast,limits=@syntax.Limits::new(nodes=2))
 assert_eq(limited.swimlane,None)
 assert_eq(limited.diagnostics[0].code,"swimlane/node-limit")
}
///|
test "shape registry manifest covers every upstream alias and vector identity" {
 let entries=array(@json.parse(@corpus.shapes))
 for entry in entries {
  let short=string(field(entry,"shortName")); let aliases=array(field(entry,"aliases"))
  for spelling in aliases { assert_eq(@model.canonical_shape(string(spelling)),@model.canonical_shape(short)) }
  if field(entry,"asset") == Json(false) { assert_true(@model.built_in_shapes.contains(@model.canonical_shape(short))) }
 }
}
///|
test "collapsed groups retain logical endpoints and unowned nodes stay unowned" {
 let source="swimlane-beta\nsubgraph Lane\nsubgraph Inner\nA[Hidden]\nend\nend\nInner@{ view: collapsed }\nA --> B"
 let converted=@conversion.to_swimlane(@syntax.read(source).ast.unwrap())
 assert_eq(converted.diagnostics.length(),0)
 let model=converted.swimlane.unwrap()
 assert_eq(model.nodes.length(),2)
 assert_eq(model.groups[0].expanded,false)
 assert_eq(model.connections[0].source,"A")
 assert_eq(model.nodes[0].groups,["Inner"])
 assert_eq(model.nodes[1].lane,None)
}
///|
test "every frozen vector-only native source has legible static output in both themes" {
 for fixture in array(field(@json.parse(@corpus.reference),"fixtures")) {
  let name=string(field(fixture,"name")); let source=string(field(fixture,"source"))
  let model=@conversion.to_swimlane(@syntax.read(source).ast.unwrap()).swimlane.unwrap()
  if model.nodes.iter().any(node => node.shape == "image" || node.shape == "icon") {
   let output=@render.Renderer::render(@svg.SvgRenderer::new(),Swimlane(model))
   assert_eq(output.output,None)
   assert_true(output.diagnostics.iter().any(d => d.message.contains("image") || d.message.contains("icon")))
   continue
  }
  let geometry=@layout.layout(model)
  if geometry.geometry == None { fail(name+" layout "+geometry.diagnostics.iter().map(d => d.code+" "+d.message).to_array().join("; ")) }
  for palette in [@theme.Theme::classic().dark,@theme.Theme::classic().light] {
   let findings=@layout.check(geometry.geometry.unwrap(),@layout.palette(palette))
   if !findings.is_empty() { fail(name+" legibility "+findings.iter().map(d => d.message).to_array().join("; ")) }
  }
  let output=@render.Renderer::render(@svg.SvgRenderer::new(),Swimlane(model))
  if output.output == None { fail(name+" SVG "+output.diagnostics.iter().map(d => d.code+" "+d.message).to_array().join("; ")) }
 }
}
///|
test "canonical native source bytes are identical across all targets" {
 let output=[]
 for fixture in array(field(@json.parse(@corpus.reference),"fixtures")) {
  let source=string(field(fixture,"source")); let name=string(field(fixture,"name"))
  let printed=@printer.print(@syntax.read(source).ast.unwrap())
  guard printed.output is Some(text) else { fail(name+" canonical print failed") }
  output.push(Json([name,text]))
 }
 let snapshot=@test.Test("canonical native swimlane sources")
 snapshot.write(Json(output).stringify()); snapshot.snapshot(filename="canonical.json")
}

///|
test "typed unknown metadata retains nonfinite scalar identities through canonical printing" {
 let source="swimlane-beta\nA@{ custom: .nan, positive: .inf, negative: -.inf, overflow: 1e9999 }"
 let original=@syntax.read(source).ast.unwrap()
 let text=@printer.print(original).output.unwrap()
 let roundtrip=@syntax.read(text).ast.unwrap()
 assert_eq(original,roundtrip)
 guard roundtrip.statements[0].kind is Nodes(nodes) else { fail("expected nodes") }
 for (key,value) in nodes[0].metadata {
  match key {
   "custom" => assert_true(value is Number(number,..) && number.is_nan())
   "positive" => assert_true(value is Number(number,..) && number.is_pos_inf())
   "negative" => assert_true(value is Number(number,..) && number.is_neg_inf())
   "overflow" => assert_eq(value,Json("1e9999"))
   _ => ()
  }
 }
}
