///|
fn validation_document(body : String, extra? : String = "") -> @bpmn.Document {
  @bpmn.read("<b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:main' \{extra}>\{body}</b:definitions>",source_id="memory:main").document.unwrap()
}

///|
fn validation_codes(findings : ReadOnlyArray[@bpmn.ValidationFinding]) -> Array[String] { findings.iter().map(f => f.diagnostic.code).to_array() }

///|
test "per-document ID indexes retain ambiguity and exclude opaque IDs" {
  let doc=validation_document("<b:process id='P'><b:task id='T'/><b:task id='T'/><b:extensionElements><v:data xmlns:v='urn:v' id='Vendor'><b:task id='Fake'/></v:data></b:extensionElements></b:process>")
  let result=@bpmn.validate_structure(doc)
  assert_true(result.complete)
  assert_true(validation_codes(result.findings).contains("bpmn/duplicate-id"))
  guard result.index.lookup("T") is Ambiguous(found) else { fail("duplicate was lost") }
  assert_eq(found.length(),2)
  assert_true(result.index.lookup("Vendor") is Missing)
  assert_true(result.index.lookup("Fake") is Missing)
  assert_true(result.index.lookup("P") is Found(_))
  assert_eq(result.index.nodes[0].children,[1])
}

///|
test "required fields cardinalities containment order and choices use schema metadata" {
  for (body,code) in [
    ("<b:process><b:sequenceFlow id='F'/></b:process>","bpmn/required-field"),
    ("<b:process><b:message/></b:process>","bpmn/invalid-containment"),
    ("<b:process><b:documentation/><b:documentation/><b:extensionElements/><b:extensionElements/></b:process>","bpmn/field-cardinality"),
    ("<b:process><b:task/><b:documentation/></b:process>","bpmn/child-order"),
    ("<b:process><b:startEvent><b:timerEventDefinition><b:timeDate/><b:timeCycle/></b:timerEventDefinition></b:startEvent></b:process>","bpmn/choice-conflict"),
    ("<b:process><b:userTask><b:potentialOwner><b:resourceParameterBinding parameterRef='R'/></b:potentialOwner></b:userTask></b:process>","bpmn/required-field"),
  ] {
    let result=@bpmn.validate_structure(validation_document(body))
    assert_true(validation_codes(result.findings).contains(code),msg=body)
  }
  for body in [
    "<b:process><b:startEvent><b:timerEventDefinition/></b:startEvent></b:process>",
    "<b:process><b:userTask><b:potentialOwner><b:resourceAssignmentExpression><b:expression/></b:resourceAssignmentExpression></b:potentialOwner></b:userTask></b:process>",
  ] { assert_eq(@bpmn.validate_structure(validation_document(body)).findings,[]) }
}

///|
test "local references reject dangling endpoints wrong kinds cross-scope flows and boundary attachments" {
  let doc=validation_document("<b:process id='P'><b:task id='T'/><b:boundaryEvent id='B' attachedToRef='P'/><b:subProcess id='Sub'><b:task id='Nested'/></b:subProcess><b:sequenceFlow id='F' sourceRef='T' targetRef='Nested'/><b:sequenceFlow id='Wrong' sourceRef='P' targetRef='Missing'/></b:process>")
  let structure=@bpmn.validate_structure(doc)
  let result=@bpmn.resolve_references(structure.index)
  assert_true(result.complete)
  let codes=validation_codes(result.findings)
  for code in ["bpmn/wrong-reference-kind","bpmn/sequence-flow-scope","bpmn/boundary-attachment","bpmn/unresolved-reference"] { assert_true(codes.contains(code),msg=code) }
  assert_true(result.findings.iter().all(f => f.stage == References))
  let missing=result.findings.iter().find_first(f => f.diagnostic.code == "bpmn/unresolved-reference").unwrap()
  assert_eq(missing.element_id,Some("Wrong")); assert_eq(missing.field.unwrap().local_name,"targetRef")
  assert_eq(missing.diagnostic.location.unwrap().source_id,Some("memory:main"))
  assert_true(missing.diagnostic.message.contains("Missing"))
}

///|
test "QName imports match namespace identity and never arbitrary local IDs" {
  let doc=validation_document("<b:import namespace='urn:a' location='a.bpmn' importType='\{model_uri}'/><b:import namespace='urn:b' location='b.bpmn' importType='\{model_uri}'/><b:collaboration id='C'><b:participant id='A' processRef='a:Shared'/><b:participant id='B' processRef='bref:Shared'/><b:participant id='Bad' processRef='c:Shared'/></b:collaboration>",extra="xmlns:a='urn:a' xmlns:bref='urn:b' xmlns:c='urn:c'")
  let a=@bpmn.Definitions::new("urn:a",children=[@bpmn.Process::new(id="Shared").element]).document()
  let b=@bpmn.Definitions::new("urn:b",children=[@bpmn.Process::new(id="Shared").element]).document()
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a.bpmn",a),@bpmn.DocumentResource::new("b.bpmn",b)])
  let result=@bpmn.resolve_references(@bpmn.validate_structure(doc).index,resources~)
  assert_eq(validation_codes(result.findings),["bpmn/unresolved-reference"])
  assert_true(result.resolve(@bpmn.Reference::new(@bpmn.ExpandedName::new("urn:a","Shared"))) is Found(found) && found.resource_id == Some("a.bpmn"))
  assert_true(result.resolve(@bpmn.Reference::new(@bpmn.ExpandedName::new("urn:b","Shared"))) is Found(found) && found.resource_id == Some("b.bpmn"))
  assert_true(result.resolve(@bpmn.Reference::new(@bpmn.ExpandedName::new("urn:c","Shared"))) is Unresolved)
}

///|
test "unresolved unrelated imports preserve local inspectability and unimported resources stay invisible" {
  let doc=validation_document("<b:import namespace='urn:missing' location='https://invalid.example/model' importType='\{model_uri}'/><b:process id='P'><b:task id='A'/><b:task id='B'/><b:sequenceFlow id='F' sourceRef='A' targetRef='B'/></b:process>")
  let unused=@bpmn.Definitions::new("urn:unused",children=[@bpmn.Process::new(id="Hidden").element]).document()
  let result=@bpmn.resolve_references(@bpmn.validate_structure(doc).index,resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("unused",unused)]))
  assert_eq(validation_codes(result.findings),["bpmn/unresolved-import"])
  assert_true(result.complete)
  assert_true(result.resolve(@bpmn.Reference::new(@bpmn.ExpandedName::new("","A"))) is Found(_))
  assert_true(result.resolve(@bpmn.Reference::new(@bpmn.ExpandedName::new("urn:unused","Hidden"))) is Unresolved)
  let minimal=@bpmn.read(fixture()).document.unwrap()
  let contents : Array[@bpmn.Content] = [Element(@bpmn.Import::new("urn:missing","https://invalid.example/model",model_uri).element)]
  for child in minimal.root.children { contents.push(Element(child)) }
  let selected=@bpmn.Document::new(minimal.root.with_contents(contents))
  let checked=@bpmn.validate(selected)
  assert_eq(validation_codes(checked.findings),["bpmn/unresolved-import"])
  assert_true(@adapter.to_diagram(selected).diagram is Some(_))
}

///|
test "copied source attributes retain their own locations while constructed fields have none" {
  let source=@bpmn.read("<b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:a'>\r\n<!--😀--><b:process><b:sequenceFlow id='F' sourceRef='Missing' targetRef='Missing'/></b:process></b:definitions>",source_id="memory:original").document.unwrap()
  let flow=source.root.children[0].children[0]
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(id="P",contents=[Element(flow)]).element]).document()
  let result=@bpmn.resolve_references(@bpmn.validate_structure(doc).index)
  assert_eq(result.findings[0].diagnostic.location.unwrap().source_id,Some("memory:original"))
  assert_eq(result.findings[0].diagnostic.location.unwrap().start.line,2)
  let constructed=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(@bpmn.SequenceFlow::new(id="F").element)]).element]).document()
  let result=@bpmn.validate_structure(constructed)
  assert_true(result.findings.iter().all(f => f.diagnostic.span == None && f.diagnostic.location == None))
  assert_true(result.findings.iter().any(f => f.element_id == Some("F") && f.field.map(n => n.local_name) == Some("sourceRef")))
}

///|
test "reference target inventory covers every QName and IDREF declaration exactly once" {
  for field in @bpmn.schema_fields {
    if field.value_type.map(t => t.namespace_uri == "http://www.w3.org/2001/XMLSchema" && ["QName","IDREF"].contains(t.local_name)).unwrap_or(false) {
      let matches=@bpmn.reference_rules.iter().filter(r => r.owner == field.owner && r.kind == field.kind && Some(r.field) == field.name).to_array()
      assert_eq(matches.length(),1,msg=field.source_path)
    }
  }
  assert_eq(@bpmn.reference_rules.length(),114)
}

///|
test "every frozen interchange fixture has valid schema structure" {
  assert_eq(@bpmn.validate_structure(@bpmn.read(fixture()).document.unwrap()).findings,[])
  for name in ["activities","events","collaboration","choreography-conversation","di-views"] {
    assert_eq(@bpmn.validate_structure(model_document(name)).findings,[],msg=name)
  }
}

///|
test "transitive imports and cycles use only explicitly supplied location keys" {
  let root=validation_document("<b:import namespace='urn:a' location='a' importType='\{model_uri}'/><b:collaboration><b:participant processRef='c:C'/></b:collaboration>",extra="xmlns:c='urn:c'")
  let a=@bpmn.read("<b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:a'><b:import namespace='urn:c' location='c' importType='\{model_uri}'/><b:process id='A'/></b:definitions>").document.unwrap()
  let c=@bpmn.read("<b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:c'><b:import namespace='urn:main' location='root' importType='\{model_uri}'/><b:process id='C'/></b:definitions>").document.unwrap()
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a",a),@bpmn.DocumentResource::new("c",c)])
  let result=@bpmn.resolve_references(@bpmn.validate_structure(root).index,resources~,resource_id="root")
  assert_eq(result.findings,[]); assert_true(result.complete)
  assert_true(result.resolve(@bpmn.Reference::new(@bpmn.ExpandedName::new("urn:c","C"))) is Found(_))
}

///|
test "duplicate imported identities remain ambiguous while namespace and type mismatches are distinct" {
  let root=validation_document("<b:import namespace='urn:a' location='a1' importType='\{model_uri}'/><b:import namespace='urn:a' location='a2' importType='\{model_uri}'/><b:collaboration><b:participant processRef='a:Shared'/></b:collaboration>",extra="xmlns:a='urn:a'")
  let a=@bpmn.Definitions::new("urn:a",children=[@bpmn.Process::new(id="Shared").element]).document()
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a1",a),@bpmn.DocumentResource::new("a2",a)])
  let result=@bpmn.resolve_references(@bpmn.validate_structure(root).index,resources~)
  assert_eq(validation_codes(result.findings),["bpmn/ambiguous-reference"])
  assert_true(result.references[0].resolution is Ambiguous(found,_) && found.length() == 2)
  for (imports,resources,code) in [
    ("<b:import namespace='urn:a' location='a' importType='\{model_uri}'/>",@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a",a),@bpmn.DocumentResource::new("a",a)]),"bpmn/ambiguous-import"),
    ("<b:import namespace='urn:wrong' location='a' importType='\{model_uri}'/>",@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a",a)]),"bpmn/import-namespace"),
    ("<b:import namespace='urn:a' location='a' importType='urn:wrong'/>",@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a",a)]),"bpmn/import-type"),
  ] { assert_eq(validation_codes(@bpmn.resolve_references(@bpmn.validate_structure(validation_document(imports)).index,resources~).findings),[code]) }
}

///|
test "external language symbols require explicit imported resources" {
  let doc=validation_document("<b:import namespace='urn:types' location='types.xsd' importType='http://www.w3.org/2001/XMLSchema'/><b:itemDefinition id='Item' structureRef='t:Order'/>",extra="xmlns:t='urn:types'")
  let names=["Order"]
  let resource=@bpmn.ExternalResource::new("types.xsd","urn:types","http://www.w3.org/2001/XMLSchema",names)
  let resources=@bpmn.ResourceSet::new(external=[resource]); names.clear()
  let result=@bpmn.resolve_references(@bpmn.validate_structure(doc).index,resources~)
  assert_eq(result.findings,[])
  assert_true(result.references[0].resolution is External(symbol) && symbol.name == @bpmn.ExpandedName::new("urn:types","Order"))
}

///|
test "syntax structure and reference stages remain explicit and preserve the document" {
  let bad=@bpmn.validate_read(@bpmn.read("<b:definitions>"))
  assert_eq(bad.document,None)
  assert_true(bad.findings.iter().all(f => f.stage == Syntax))
  let read=@bpmn.read("<b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:t'><b:process><b:sequenceFlow id='F' sourceRef='Missing'/></b:process></b:definitions>")
  let result=@bpmn.validate_read(read)
  assert_eq(result.document,read.document)
  assert_true(result.findings.iter().any(f => f.stage == Structure && f.diagnostic.code == "bpmn/required-field"))
  assert_true(result.findings.iter().any(f => f.stage == References && f.diagnostic.code == "bpmn/unresolved-reference"))
  assert_true(result.complete)
}

///|
test "validation bounds distinguish incomplete processing from invalid document findings" {
  let doc=validation_document("<b:process><b:task id='T'/></b:process>")
  for (limits,code) in [
    (@bpmn.Limits::new(nodes=1),"bpmn/validation-node-limit"),
    (@bpmn.Limits::new(depth=2),"bpmn/validation-depth-limit"),
    (@bpmn.Limits::new(token_units=1),"bpmn/validation-token-limit"),
    (@bpmn.Limits::new(depth=0),"bpmn/validation-invalid-limits"),
  ] {
    let result=@bpmn.validate_structure(doc,limits~)
    assert_false(result.complete); assert_eq(result.findings[0].diagnostic.code,code)
    assert_true(result.index.lookup("T") is Incomplete)
  }
  let result=@bpmn.validate_structure(validation_document("<b:process><b:sequenceFlow/><b:sequenceFlow/></b:process>"),limits=@bpmn.Limits::new(diagnostics=1))
  assert_false(result.complete); assert_eq(result.findings.length(),1)
  assert_eq(result.findings[0].diagnostic.code,"bpmn/validation-diagnostic-limit")
  let index=@bpmn.validate_structure(doc).index
  assert_false(@bpmn.resolve_references(index,limits=@bpmn.Limits::new(nodes=1)).complete)
  let invalid=@bpmn.validate(doc,limits=@bpmn.Limits::new(diagnostics=0))
  assert_false(invalid.complete)
  let invalid=@bpmn.validate_read(@bpmn.read("<"),limits=@bpmn.Limits::new(diagnostics=0))
  assert_eq(validation_codes(invalid.findings),["bpmn/validation-invalid-limits"])
}

///|
test "malformed constructed scalar alternatives and abstract types are structural findings" {
  let task=@bpmn.Task::new(id="T").element.with_attribute(@bpmn.Attribute::new(@bpmn.ExpandedName::new("","isForCompensation"),Text("false")))
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(task),Element(@bpmn.Element::new(FlowElement))]).element]).document()
  let result=@bpmn.validate_structure(doc)
  assert_true(validation_codes(result.findings).contains("bpmn/invalid-field"))
  assert_true(validation_codes(result.findings).contains("bpmn/abstract-element"))
}

///|
test "default QName namespaces survive writing and never fall back to a same-named local process" {
  let doc=validation_document("<b:import namespace='urn:a' location='a' importType='\{model_uri}'/><b:process id='Shared'/><b:collaboration><b:participant processRef='Shared'/></b:collaboration>",extra="xmlns='urn:a'")
  let a=@bpmn.Definitions::new("urn:a",children=[@bpmn.Process::new(id="Shared").element]).document()
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a",a)])
  for value in [doc,@bpmn.read(@bpmn.write(doc)).document.unwrap()] {
    let result=@bpmn.resolve_references(@bpmn.validate_structure(value).index,resources~)
    assert_eq(result.findings,[])
    assert_true(result.references[0].resolution is Found(found) && found.resource_id == Some("a"))
    assert_true(result.resolve(@bpmn.Reference::new(@bpmn.ExpandedName::new("","Shared"))) is Found(found) && found.resource_id == None)
    assert_true(result.resolve(@bpmn.Reference::new(@bpmn.ExpandedName::new(model_uri,"Shared"))) is Unresolved)
  }
}

///|
test "endpoint consistency wrong DI plane kinds and unbound QName values give reference findings" {
  let doc=validation_document("<b:process id='P'><b:task id='A' default='F'><b:incoming>F</b:incoming></b:task><b:task id='B'/><b:sequenceFlow id='F' sourceRef='B' targetRef='B'/><b:boundaryEvent id='Boundary' attachedToRef='bad:Task'/></b:process>")
  let result=@bpmn.validate(doc)
  assert_true(validation_codes(result.findings).contains("bpmn/reference-endpoint"))
  assert_true(validation_codes(result.findings).contains("bpmn/invalid-reference"))
  let typed=@bpmn.Task::new(id="T").element
  let plane=@bpmn.BpmnPlane::new(bpmn_element=qref("T"))
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(typed)]).element,@bpmn.BpmnDiagram::new(contents=[Element(plane.element)]).element]).document()
  assert_true(validation_codes(@bpmn.validate(doc).findings).contains("bpmn/wrong-reference-kind"))
}

///|
test "an attribute copied from another document carries its own source identity" {
  let original=validation_document("<b:process><b:sequenceFlow sourceRef='Missing' targetRef='Missing'/></b:process>")
  let attribute=original.root.children[0].children[0].values[0]
  let flow=@bpmn.SequenceFlow::new(id="F").element.with_attribute(attribute)
  assert_eq(flow.location(),None)
  assert_eq(attribute.location().unwrap().source_id,Some("memory:main"))
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(flow)]).element]).document()
  let result=@bpmn.resolve_references(@bpmn.validate_structure(doc).index)
  assert_eq(result.findings[0].diagnostic.location,attribute.location())
}

///|
test "invalid actual type identity and invalid supplied external symbols are diagnosed" {
  let wrong=@bpmn.Element::new(Task,value_type=@bpmn.TypeId::Process.name())
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(wrong)]).element]).document()
  assert_true(validation_codes(@bpmn.validate(doc).findings).contains("bpmn/invalid-type"))
  let doc=validation_document("<b:import namespace='urn:x' location='x' importType='urn:external'/>")
  let resources=@bpmn.ResourceSet::new(external=[@bpmn.ExternalResource::new("x","urn:x","urn:external",["not an NCName"])])
  assert_eq(validation_codes(@bpmn.resolve_references(@bpmn.validate_structure(doc).index,resources~).findings),["bpmn/invalid-reference"])
}

///|
test "deep constructed containment is iterative and inclusive node bounds agree with source records" {
  let doc=validation_document("<b:process><b:task id='T'/></b:process>")
  assert_true(@bpmn.validate_structure(doc,limits=@bpmn.Limits::new(nodes=7)).complete)
  assert_false(@bpmn.validate_structure(doc,limits=@bpmn.Limits::new(nodes=6)).complete)
  let mut nested=@bpmn.Task::new().element
  for _ in 0..<10000 { nested=@bpmn.SubProcess::new(contents=[Element(nested)]).element }
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(nested)]).element]).document()
  let result=@bpmn.validate_structure(doc,limits=@bpmn.Limits::new(depth=10003))
  assert_true(result.complete)
  assert_eq(result.findings,[])
  assert_eq(result.index.nodes.length(),10003)
}

///|
test "ambiguous reference fanout consumes a bounded candidate budget" {
  let body=StringBuilder()
  body.write_string("<b:process>")
  for _ in 0..<20 { body.write_string("<b:task id='T'/>") }
  for i in 0..<20 { body.write_string("<b:sequenceFlow id='F\{i}' sourceRef='T' targetRef='T'/>") }
  body.write_string("</b:process>")
  let index=@bpmn.validate_structure(validation_document(body.to_string())).index
  let result=@bpmn.resolve_references(index,limits=@bpmn.Limits::new(nodes=200))
  assert_false(result.complete)
  assert_true(validation_codes(result.findings).contains("bpmn/resource-limit"))
  assert_true(result.references.length() < 40)
}

///|
test "known raw XML and unknown actual types cannot claim complete typed structural coverage" {
  let raw=@bpmn.XmlElement::new(@bpmn.Kind::Task.name(),attributes=[(@bpmn.ExpandedName::new("","id"),"T")])
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(raw.element)]).element]).document()
  let result=@bpmn.validate_structure(doc)
  assert_true(validation_codes(result.findings).contains("bpmn/invalid-type"))
  assert_true(result.index.lookup("T") is Missing)
  let doc=@bpmn.read("<b:definitions xmlns:b='\{model_uri}' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:v='urn:v' xsi:type='v:Definitions' targetNamespace='urn:t'/>").document.unwrap()
  assert_true(validation_codes(@bpmn.validate_structure(doc).findings).contains("bpmn/invalid-type"))
}

///|
test "an import in invalid containment cannot make a supplied resource visible" {
  let doc=validation_document("<b:process><b:import namespace='urn:a' location='a' importType='\{model_uri}'/></b:process><b:collaboration><b:participant processRef='a:Shared'/></b:collaboration>",extra="xmlns:a='urn:a'")
  let imported=@bpmn.Definitions::new("urn:a",children=[@bpmn.Process::new(id="Shared").element]).document()
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a",imported)])
  let structure=@bpmn.validate_structure(doc)
  assert_true(validation_codes(structure.findings).contains("bpmn/invalid-containment"))
  let result=@bpmn.resolve_references(structure.index,resources~)
  assert_eq(validation_codes(result.findings),["bpmn/unresolved-reference"])
}
