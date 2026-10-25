///|
let model_uri = "http://www.omg.org/spec/BPMN/20100524/MODEL"

///|
fn foundation_doc(body : String) -> @bpmn.Document raise {
  let source="<b:definitions xmlns:b='\{model_uri}' xmlns:d='http://www.omg.org/spec/DD/20100524/DC' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:q='urn:q' targetNamespace='urn:t'>\{body}</b:definitions>"
  let result=@bpmn.read(source)
  assert_eq(result.diagnostics.iter().map(d => d.code).to_array(),[])
  result.document.unwrap()
}

///|
fn roundtrip(doc : @bpmn.Document) -> Unit raise {
  for format in [@bpmn.WriteFormat::Compact,Pretty] {
    let text=@bpmn.write(doc,format~)
    let result=@bpmn.read(text)
    assert_eq(result.diagnostics.iter().map(d => d.code).to_array(),[])
    assert_eq(result.document,Some(doc))
    assert_eq(@bpmn.write(result.document.unwrap(),format~),text)
  }
}

///|
test "pinned XSD declarations independently cover generated metadata" {
  let mut elements=0; let mut attributes=0; let mut types=0; let mut globals=0
  for input in @corpus.inputs[:5] {
    let tree=@bpmn.read(input.source).tree
    assert_true(tree.complete)
    for node in tree.nodes {
      if node.kind != Element { continue }
      let name=node.name.unwrap()
      if name.namespace_uri != "http://www.w3.org/2001/XMLSchema" { continue }
      match name.local_name {
        "element" => { elements+=1; if node.parent is Some(p) && tree.nodes[p].name.map(n => n.local_name) == Some("schema") { globals+=1 } }
        "attribute" => attributes+=1
        "complexType" | "simpleType" => types+=1
        _ => ()
      }
    }
  }
  assert_eq((elements,attributes,types,globals),(313,195,170,154))
  assert_eq(@bpmn.schema_types.length(),types)
  assert_eq(@bpmn.schema_elements.length(),globals)
  assert_eq(@bpmn.schema_fields.iter().filter(f => f.kind == Attribute).count(),attributes)
  assert_eq(@bpmn.schema_fields.iter().filter(f => f.kind == Child).count(),elements-globals)
  let names : Map[(String,String),Bool] = Map([])
  for kind in @bpmn.standard_kinds { let n=kind.name(); assert_false(names.contains((n.namespace_uri,n.local_name))); names[(n.namespace_uri,n.local_name)]=true }
  for e in @bpmn.schema_elements { assert_true(names.contains((e.name.namespace_uri,e.name.local_name))) }
}

///|
test "foundation constructors own ordered values and preserve absent defaults" {
  let imported=@bpmn.Import::new("urn:other","https://invalid.example/never-fetched","urn:bpmn")
  let content : Array[@bpmn.Content] = [Text("before"),Element(@bpmn.Element::new(Task)),Text("after")]
  let documentation=@bpmn.Documentation::new(content)
  content.clear()
  assert_eq(documentation.element.contents.length(),3)
  assert_eq(documentation.text_format(),Absent)
  let attrs=[@bpmn.Attribute::new(@bpmn.ExpandedName::new("","id"),Identifier("P"))]
  let process=@bpmn.Element::from_values(Process,values=attrs,contents=[Element(documentation.element)])
  attrs.clear()
  let children=[imported.element,process]
  let definitions=@bpmn.Definitions::new("urn:t",id="D",children~)
  children.clear()
  assert_eq(definitions.target_namespace(),Present("urn:t"))
  assert_eq(definitions.imports()[0].location(),Present("https://invalid.example/never-fetched"))
  assert_eq(definitions.roots()[0].base().id(),Present("P"))
  assert_eq(definitions.roots()[0].base().documentation()[0],documentation)
  assert_eq(process.boolean("isExecutable"),Absent)
  let doc=definitions.document()
  let written=@bpmn.write(doc)
  assert_false(written.contains("isExecutable"))
  assert_false(written.contains("textFormat"))
  assert_false(written.contains("expressionLanguage"))
  roundtrip(doc)
}

///|
test "typed booleans enums references integers and exact DI numbers" {
  let doc=foundation_doc("<b:process id='P' isExecutable='0' processType='Public'><b:userTask id='T' implementation='##unspecified'/><b:messageFlow id='F' sourceRef='q:T' targetRef='q:U'/></b:process><d:Bounds x='-0.000000000000000000000000001' y='1.2345678901234567890123456789E+250' width='INF' height='NaN'/>")
  let process=doc.root.children[0]
  assert_eq(process.boolean("isExecutable"),Present(false))
  assert_eq(process.enumeration("processType"),Present(@bpmn.BpmnEnum::ProcessType(Public)))
  assert_eq(process.children[1].reference("sourceRef").value().unwrap().name,Some(@bpmn.ExpandedName::new("urn:q","T")))
  let bounds=doc.root.children[1]
  assert_eq(bounds.number("x").value().unwrap().token,"-0.000000000000000000000000001")
  assert_eq(bounds.number("y").value().unwrap().token,"1.2345678901234567890123456789E+250")
  assert_false(bounds.number("width").value().unwrap().is_finite())
  roundtrip(doc)
  for token in ["+2147483647","-2147483648","000000000000000000000000001"] {
    roundtrip(foundation_doc("<b:participantMultiplicity maximum='\{token}'/>"))
  }
  for token in ["2147483648","-2147483649","1.5"] {
    let source="<definitions xmlns='\{model_uri}'><participantMultiplicity maximum='\{token}'/></definitions>"
    let result=@bpmn.read(source)
    assert_true(result.diagnostics.iter().any(d => d.code == "bpmn/invalid-scalar"))
    assert_eq(@bpmn.try_write(result.document.unwrap()).output,None)
  }
  assert_eq(@bpmn.ExactInteger::parse("999999999999999999999999999999999999").unwrap().token,"999999999999999999999999999999999999")
  for token in ["","+","1e","1e+","+INF","1.2.3"," 1"] { assert_eq(@bpmn.ExactNumber::parse(token),None) }
}

///|
test "expanded identities ignore aliases while canonical bytes stay stable" {
  let a=@bpmn.read("<a:definitions xmlns:a='\{model_uri}' xmlns:v='urn:q' targetNamespace='urn:t'><a:process id='P'><a:messageFlow sourceRef='v:T' targetRef='v:U' id='F'/></a:process></a:definitions>").document.unwrap()
  let b=@bpmn.read("<definitions xmlns='\{model_uri}' xmlns:other='urn:q' targetNamespace='urn:t'><process id='P'><messageFlow id='F' targetRef='other:U' sourceRef='other:T'/></process></definitions>").document.unwrap()
  assert_eq(a,b)
  assert_eq(@bpmn.write(a),@bpmn.write(b))
  roundtrip(a)
}

///|
test "mixed content comments PI scalar CDATA and xml space survive both formats" {
  let doc=foundation_doc("<b:process id='P' xml:space='preserve'> \n<b:documentation>before&lt;<![CDATA[&raw]]><!--note--><?hint inert?><b:task id='T'/>tail\r&#xd;</b:documentation> \n<b:task id='U'><b:incoming>q:<!--middle-->F</b:incoming></b:task></b:process>")
  roundtrip(doc)
  let text=@bpmn.write(doc,format=Pretty)
  assert_true(text.contains("before&lt;&amp;raw<!--note--><?hint inert?><bpmn:task id=\"T\"/>tail\n&#xd;"))
  let root=doc.root.with_contents([Text("prefix"),Element(doc.root.children[0]),Text("tail")])
  roundtrip(@bpmn.Document::new(root,prolog=[Comment("start"),ProcessingInstruction(target="data",data="inert")],epilog=[Comment("end")]))
}

///|
test "explicit constructed xsi type retains its identity and absence of defaults" {
  let expression=@bpmn.Element::from_values(ConditionExpression,contents=[Text("a < b")],value_type=@bpmn.ExpandedName::new(model_uri,"tFormalExpression"))
  let doc=@bpmn.Definitions::new("urn:t",children=[expression]).document()
  assert_true(@bpmn.write(doc).contains("xsi:type=\"bpmn:tFormalExpression\""))
  roundtrip(doc)
}

///|
test "writer rejects invalid constructed names bindings scalars and text without partial output" {
  let root=@bpmn.Definitions::new("urn:t").element
  let invalid : Array[(@bpmn.Element,String)] = [
    (root.with_attribute(@bpmn.Attribute::new(@bpmn.ExpandedName::new("","bad:name"),Text("x"))),"bpmn/invalid-name"),
    (root.with_contents([Comment("--")]),"bpmn/invalid-comment"),
    (root.with_contents([ProcessingInstruction(target="XML",data="x")]),"bpmn/invalid-pi"),
    (root.with_contents([ProcessingInstruction(target="p",data=" x")]),"bpmn/invalid-pi"),
    (root.with_contents([Text("\u{0}")]),"bpmn/forbidden-text"),
    (root.with_contents([Element(@bpmn.Element::new(Task,attributes=[("id","bad id")]))]),"bpmn/invalid-scalar"),
    (root.with_contents([Element(@bpmn.Element::new(SequenceFlow,attributes=[("sourceRef","missing:T")]))]),"bpmn/unbound-qname"),
    (@bpmn.Element::new(Definitions,bindings=[("xml","urn:wrong")]),"bpmn/namespace-conflict"),
    (@bpmn.Element::new(Definitions,bindings=[("p","urn:a"),("p","urn:b")]),"bpmn/namespace-conflict"),
    (@bpmn.Element::new(Definitions,attributes=[("id","A"),("id","B")]),"bpmn/duplicate-attribute"),
  ]
  for (root,code) in invalid {
    let result=@bpmn.try_write(@bpmn.Document::new(root))
    assert_eq(result.output,None)
    assert_eq(result.diagnostics.length(),1)
    assert_eq(result.diagnostics[0].code,code)
  }
}

///|
test "writer limits are inclusive and deep construction uses explicit stacks" {
  let doc=@bpmn.Definitions::new("urn:t").document()
  let text=@bpmn.write(doc)
  assert_eq(@bpmn.try_write(doc,limits=@bpmn.Limits::new(output_units=text.length())).output,Some(text))
  assert_eq(@bpmn.try_write(doc,limits=@bpmn.Limits::new(output_units=text.length()-1)).diagnostics[0].code,"bpmn/output-limit")
  assert_eq(@bpmn.try_write(doc,limits=@bpmn.Limits::new(depth=1,nodes=4)).output,Some(text))
  assert_eq(@bpmn.try_write(doc,limits=@bpmn.Limits::new(nodes=3)).diagnostics[0].code,"bpmn/write-node-limit")
  assert_eq(@bpmn.try_write(doc,limits=@bpmn.Limits::new(output_units=0)).diagnostics[0].code,"bpmn/write-invalid-limits")
  let mut e=@bpmn.Element::new(Task)
  for _ in 0..<9999 { e=@bpmn.Element::new(SubProcess,children=[e]) }
  let deep=@bpmn.Definitions::new("urn:t",children=[e]).document()
  let result=@bpmn.try_write(deep,limits=@bpmn.Limits::new(depth=10001))
  assert_true(result.output is Some(_))
  assert_eq(@bpmn.try_write(deep,limits=@bpmn.Limits::new(depth=10000)).diagnostics[0].code,"bpmn/write-depth-limit")
  let escaped=@bpmn.Definitions::new("urn:t",name="&&&&&&&&&&").document()
  assert_eq(@bpmn.try_write(escaped,limits=@bpmn.Limits::new(token_units=48)).diagnostics[0].code,"bpmn/write-token-limit")
}

///|
test "string enums retain their whitespace facet and typed scalar text constructs without aliases" {
  let result=@bpmn.read("<definitions xmlns='\{model_uri}'><process processType=' Public '/></definitions>")
  assert_eq(result.diagnostics[0].code,"bpmn/invalid-scalar")
  let incoming=@bpmn.Element::from_values(Incoming,text_value=Reference(@bpmn.Reference::new(@bpmn.ExpandedName::new("urn:q","F"))))
  assert_eq(incoming.with_contents(incoming.contents),incoming)
  roundtrip(@bpmn.Definitions::new("urn:t",children=[@bpmn.Element::new(Task,children=[incoming])]).document())
  let renamed=@bpmn.Element::new(Task).with_kind(UserTask)
  roundtrip(@bpmn.Definitions::new("urn:t",children=[renamed]).document())
}

///|
test "writer rejects isolated UTF16 surrogates before lossy character iteration" {
  for value in [String::make(1,Int::unsafe_to_char(0xd800)),String::make(1,Int::unsafe_to_char(0xdc00))] {
    let root=@bpmn.Definitions::new("urn:t").element.with_contents([Text(value)])
    let result=@bpmn.try_write(@bpmn.Document::new(root))
    assert_eq(result.output,None)
    assert_eq(result.diagnostics[0].code,"bpmn/forbidden-text")
  }
}

///|
test "namespace declarations cannot masquerade as ordinary model attributes" {
  let root=@bpmn.Definitions::new("urn:t").element.with_attribute(@bpmn.Attribute::new(@bpmn.ExpandedName::new("","xmlns"),Text("urn:changed")))
  let result=@bpmn.try_write(@bpmn.Document::new(root))
  assert_eq(result.output,None)
  assert_eq(result.diagnostics[0].code,"bpmn/namespace-conflict")
}

///|
test "adjacent text construction coalesces without losing spaces or bypassing token bounds" {
  let root=@bpmn.Definitions::new("urn:t").element.with_contents([Text("before"),Text(" "),Text("after")])
  assert_true(@bpmn.write(@bpmn.Document::new(root)).contains(">before after</"))
  roundtrip(@bpmn.Document::new(root))
  let d=@bpmn.Documentation::new([Text(String::make(60,'x')),Text(String::make(60,'y'))])
  let doc=@bpmn.Definitions::new("urn:t",children=[d.element]).document()
  assert_eq(@bpmn.try_write(doc,limits=@bpmn.Limits::new(token_units=100)).output,None)
  roundtrip(foundation_doc("<b:process>before<![CDATA[ ]]>after</b:process>"))
  assert_eq(foundation_doc("<b:process>before<![CDATA[ ]]>after</b:process>").root.children[0].content,"before after")
}

///|
test "writer rejects a constructed scoped field with a missing type identity" {
  let condition=@bpmn.Element::new(Condition,content="a < b")
  let behavior=@bpmn.Element::new(ComplexBehaviorDefinition,children=[condition])
  let doc=@bpmn.Definitions::new("urn:t",children=[behavior]).document()
  let result=@bpmn.try_write(doc)
  assert_eq(result.output,None)
  assert_eq(result.diagnostics[0].code,"bpmn/type-conflict")
  let typed=@bpmn.Element::from_values(Condition,contents=[Text("a < b")],value_type=@bpmn.ExpandedName::new(model_uri,"tFormalExpression"))
  roundtrip(@bpmn.Definitions::new("urn:t",children=[@bpmn.Element::new(ComplexBehaviorDefinition,children=[typed])]).document())
}

///|
test "content updates preserve effective inherited and shadowed QName bindings" {
  let doc=foundation_doc("<b:process xmlns:r='urn:r'><b:task xmlns:q='urn:shadow'><b:incoming>q:F</b:incoming></b:task></b:process>")
  let process=doc.root.children[0]; let task=process.children[0]; let incoming=task.children[0]
  let unchanged=incoming.with_contents(incoming.contents)
  assert_eq(unchanged,incoming)
  let changed=incoming.with_contents([Text("r:G")])
  assert_eq(changed.text_value,Some(@bpmn.Scalar::Reference(@bpmn.Reference::new(@bpmn.ExpandedName::new("urn:r","G")))))
  for updated in [unchanged,changed] {
    let revised_task=task.with_contents([Element(updated)])
    let revised_process=process.with_contents([Element(revised_task)])
    roundtrip(@bpmn.Document::new(doc.root.with_contents([Element(revised_process)])))
  }
}
