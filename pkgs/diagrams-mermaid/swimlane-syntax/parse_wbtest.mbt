///|
test "native grammar retains labels and recovers errors" {
 let source="swimlane-beta LR\r\nsubgraph Sales [Sales team]\r\n A[\"end --> subgraph 😀\"]\r\n B{Ready?}\r\nend\r\nA -->|Yes| B\r\nC[broken\r\nD[Good]\r\n! @@@\r\nD --> A"
 let read=read(source)
 assert_eq(read.tree.text(),source)
 assert_eq(read.diagnostics.length(),2)
 assert_eq(read.diagnostics[0].span.unwrap().start.line,7)
 assert_eq(read.ast.unwrap().statements.length(),7)
}
///|
test "native edge forms and grouped chained endpoints" {
 for arrow in ["-->","---","-.->","==>","<-->","o--o","x--x","~~~","---->"] {
  let result=read("swimlane-beta\nA "+arrow+" B")
  assert_eq(result.diagnostics.length(),0)
  guard result.ast.unwrap().statements[0].kind is Edges(chain) else { fail("expected edges") }
  assert_eq(chain.links.length(),1)
 }
 let result=read("swimlane-beta\n A & B --> C & D --> E")
 assert_eq(result.diagnostics.length(),0)
 guard result.ast.unwrap().statements[0].kind is Edges(chain) else { fail("expected edges") }
 assert_eq(chain.endpoints[0].length(),2)
 assert_eq(chain.links.length(),2)
}
///|
test "modern shapes metadata and local directions" {
 let result=read("---\nconfig:\n  theme: forest\n---\n%%{init: {}}%%\nswimlane-beta TB\nsubgraph Owner\ndirection RL\nA@{ shape: doc, label: \"Hello, world\", custom: true }\nend\nclassDef test fill:red\nclass A test\nclick A callback\naccTitle: Accessible")
 assert_eq(result.diagnostics.length(),0)
 assert_true(result.ast.unwrap().front_matter != None)
 guard result.ast.unwrap().statements[2].kind is Nodes(nodes) else { fail("expected node") }
 assert_eq(nodes[0].shape,Some("doc"))
 assert_eq(nodes[0].label,Some("Hello, world"))
}
///|
test "missing group ends and source depth work limits are explicit" {
 let result=read("swimlane-beta\nsubgraph A\nsubgraph B\nX")
 assert_eq(result.diagnostics.length(),2)
 let result=read("swimlane-beta\nA",limits=Limits::new(source=3))
 assert_eq(result.ast,None)
 assert_eq(result.diagnostics[0].code,"swimlane/source-limit")
 let result=read("swimlane-beta\nsubgraph A\nsubgraph B",limits=Limits::new(depth=1))
 assert_eq(result.diagnostics[0].code,"swimlane/depth-limit")
}
///|
test "metadata failures recover and limits never give an apparently complete AST" {
 let source="swimlane-beta\r\nA{broken\r\nB[Good 😀]\r\nclass A\r\nstyle B\r\nC --> B"
 let result=read(source)
 assert_eq(result.tree.text(),source)
 if result.diagnostics.length() != 3 { fail(result.diagnostics.iter().map(d => d.message+" "+d.span.map(span => source[span.start.offset:span.end.offset].to_owned()).unwrap_or("")).to_array().join("; ")) }
 assert_eq(result.diagnostics[0].span.unwrap().start.line,2)
 assert_eq(result.diagnostics[2].span.unwrap().start.line,5)
 assert_eq(result.ast.unwrap().statements.length(),2)
 let duplicate=read("swimlane-beta\nA@{ label: 'one', label: 'two' }\nB")
 assert_eq(duplicate.diagnostics.length(),1)
 assert_eq(duplicate.ast.unwrap().statements.length(),1)
 let bad_alias=read("swimlane-beta\nA@{ label: *missing }\nB")
 assert_eq(bad_alias.diagnostics.length(),1)
 let nested=read("swimlane-beta\nA@{ custom: [[[[[1]]]]] }",limits=Limits::new(metadata_depth=2))
 assert_eq(nested.ast,None)
 assert_eq(nested.diagnostics[0].code,"swimlane/depth-limit")
 let grammar_only=read("swimlane-beta\nsubgraph\nA\nend")
 assert_eq(grammar_only.diagnostics.length(),0)
 assert_true(grammar_only.ast != None)
 let unknown_direction=read("swimlane-beta BR\nA --> B")
 assert_eq(unknown_direction.diagnostics.length(),0)
 assert_eq(unknown_direction.ast.unwrap().direction,Some("BR"))
 let excessive=read("swimlane-beta\nA\nB\nC",limits=Limits::new(work=17))
 assert_eq(excessive.ast,None)
 assert_eq(excessive.diagnostics[0].code,"swimlane/work-limit")
}
///|
test "unquoted Unicode node recovery primitive" {
 let context={limits:Limits::new(),failure:None,work:0}
 let (node,end)=parse_node("B[Good 😀]",0,context)
 assert_eq(end,10)
 assert_true(node != None)
 let result=read("swimlane-beta\r\nB[Good 😀]\r\nC --> B")
 assert_eq(result.diagnostics.length(),0)
}
///|
test "UTF16 spans after an unquoted non-BMP label retain exact CRLF columns" {
 let source="swimlane-beta\r\nA[😀]; ! @@@\r\nB"
 let result=read(source)
 assert_eq(result.tree.text(),source)
 assert_eq(result.diagnostics.length(),1)
 let span=result.diagnostics[0].span.unwrap()
 assert_eq(span.start.line,2)
 assert_eq(span.start.column,8)
 assert_eq(span.start.offset,22)
 assert_eq(source[span.start.offset:span.end.offset].to_owned(),"! @@@")
}
///|
test "alias expansion is bounded before exposing complete metadata" {
 let source=StringBuilder()
 source.write_string("swimlane-beta\nA@{\na0: &a0 [one]\n")
 for i=1; i<1000; i=i+1 { source.write_string("a"+i.to_string()+": &a"+i.to_string()+" [*a"+(i-1).to_string()+"]\n") }
 source.write_string("label: End\n}")
 let result=read(source.to_string())
 assert_eq(result.ast,None)
 assert_true(result.diagnostics.iter().any(d => d.code == "swimlane/work-limit" || d.code == "swimlane/depth-limit"))
}

///|
test "metadata safety profile has explicit independent depth and work bounds" {
 for depth in [0,257] {
  let result=read("swimlane-beta\nA",limits=Limits::new(metadata_depth=depth))
  assert_eq(result.ast,None)
  assert_eq(result.diagnostics[0].code,"swimlane/depth-limit")
 }
 let result=read("swimlane-beta\nA",limits=Limits::new(metadata_work=0))
 assert_eq(result.ast,None)
 assert_eq(result.diagnostics[0].code,"swimlane/work-limit")
 let flat=StringBuilder(); flat.write_string("swimlane-beta\nA@{\n")
 for i=0; i<1000; i=i+1 { flat.write_string("a"+i.to_string()+": &a"+i.to_string()+" one\n") }
 flat.write_string("label: End\n}")
 let result=read(flat.to_string(),limits=Limits::new(metadata_depth=1))
 assert_eq(result.diagnostics.length(),0)
 assert_true(result.ast != None)
 let chain=StringBuilder(); chain.write_string("swimlane-beta\nA@{\na0: &a0 [one]\n")
 for i=1; i<300; i=i+1 { chain.write_string("a"+i.to_string()+": &a"+i.to_string()+" [*a"+(i-1).to_string()+"]\n") }
 chain.write_string("label: End\n}")
 let result=read(chain.to_string(),limits=Limits::new(metadata_work=100000000,work=100000000))
 assert_eq(result.ast,None)
 assert_true(result.diagnostics.iter().any(d => d.code == "swimlane/depth-limit"))
}
///|
test "JSON schema scalars preserve nonfinite values and safely normalize overflowing exponents" {
 let result=read("swimlane-beta\nA@{\nlabel: .nan\na: .nan\nb: .inf\nc: -.inf\nd: 1e99999999999999999999999999999\ne: 0b101\nf: -.5\ng: +.5\n}")
 assert_eq(result.diagnostics.length(),0)
 guard result.ast.unwrap().statements[0].kind is Nodes(nodes) else { fail("expected node") }
 let fields : Map[String,Json]=Map([])
 for (key,value) in nodes[0].metadata { fields[key]=value }
 assert_true(fields.get("a").unwrap() is Number(value,..) && value.is_nan())
 assert_true(fields.get("b").unwrap() is Number(value,..) && value.is_pos_inf())
 assert_true(fields.get("c").unwrap() is Number(value,..) && value.is_neg_inf())
 assert_eq(fields.get("d"),Some(Json("1e99999999999999999999999999999")))
 assert_eq(fields.get("e"),Some(Json(5)))
 assert_eq(fields.get("f"),Some(Json("-.5")))
 assert_eq(fields.get("g"),Some(Json("+.5")))
 assert_eq(nodes[0].label,None)
}
