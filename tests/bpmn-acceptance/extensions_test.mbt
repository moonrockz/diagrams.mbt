///|
fn vendor_source() -> String {
  "<definitions xmlns='\{model_uri}' xmlns:v='urn:vendor' xmlns:q='urn:outer' xmlns:unused='urn:retained' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' targetNamespace='urn:t'><process id='P'><task id='T' v:ref='q:Input'><extensionElements><v:payload ref='q:Payload' xsi:type='q:VendorType'>lead <![CDATA[q:raw&]]><v:nested xmlns:q='urn:inner' ref='q:X'><b:task xmlns:b='\{model_uri}' flag='01'> keep </b:task></v:nested>tail<?inert q:PI?><!--q:comment--></v:payload></extensionElements></task></process></definitions>"
}

///|
fn vendor_payload(doc : @bpmn.Document) -> @bpmn.XmlElement { doc.root.children[0].children[0].children[0].children[0].xml().unwrap() }

///|
test "foreign XML retains mixed content all namespace bindings and shadowed QName values" {
  let source=vendor_source(); let result=@bpmn.read(source)
  assert_eq(result.tree.text(),source)
  assert_eq(result.diagnostics.iter().map(d => d.code).to_array(),[])
  let doc=result.document.unwrap()
  let payload=vendor_payload(doc)
  assert_eq(payload.name(),@bpmn.ExpandedName::new("urn:vendor","payload"))
  assert_eq(payload.namespace_binding("unused"),Some("urn:retained"))
  assert_eq(payload.namespace_binding("q"),Some("urn:outer"))
  assert_eq(payload.element.children[0].xml().unwrap().namespace_binding("q"),Some("urn:inner"))
  assert_eq(payload.element.children[0].children[0].kind.name(),@bpmn.Kind::Task.name())
  assert_eq(payload.element.children[0].children[0].value_type,None)
  assert_eq(payload.element.children[0].children[0].content," keep ")
  assert_eq(payload.element.content,"lead q:raw&tail")
  assert_eq(doc.root.children[0].children[0].opaque_attributes().length(),1)
  assert_eq(doc.root.children[0].children[0].namespace_binding("q"),Some("urn:outer"))
  roundtrip(doc)
  for format in [@bpmn.WriteFormat::Compact,Pretty] {
    let text=@bpmn.write(doc,format~)
    let copy=@bpmn.read(text).document.unwrap(); let retained=vendor_payload(copy)
    assert_eq(retained.namespace_binding("unused"),Some("urn:retained"))
    assert_eq(retained.namespace_binding("q"),Some("urn:outer"))
    assert_eq(retained.element.children[0].xml().unwrap().namespace_binding("q"),Some("urn:inner"))
    assert_true(text.contains("lead q:raw&amp;"))
  }
}

///|
test "opaque namespace identity participates in equality and detached values retain their context" {
  let a=@bpmn.read(vendor_source()).document.unwrap()
  let b=@bpmn.read(vendor_source().replace(old="urn:outer",new="urn:other")).document.unwrap()
  assert_false(a == b)
  let payload=vendor_payload(a)
  let extension=@bpmn.ExtensionElements::new(contents=[Element(payload.element)])
  let task=@bpmn.Task::new(id="Copied",contents=[Element(extension.element)])
  let copy=@bpmn.Definitions::new("urn:copy",children=[@bpmn.Process::new(id="P",contents=[Element(task.element)]).element]).document()
  roundtrip(copy)
  assert_eq(vendor_payload(@bpmn.read(@bpmn.write(copy)).document.unwrap()).namespace_binding("q"),Some("urn:outer"))
}

///|
test "canonical namespace prefixes never bind opaque QName-looking tokens that were unbound" {
  let source="<m:definitions xmlns:m='\{model_uri}' xmlns:v='urn:v' targetNamespace='urn:t'><m:process id='P'><m:extensionElements><v:payload ref='bpmn:Unbound ns1:Unbound'>bpmn:Body</v:payload></m:extensionElements></m:process></m:definitions>"
  let doc=@bpmn.read(source).document.unwrap()
  roundtrip(doc)
  let text=@bpmn.write(doc)
  assert_false(text.contains("xmlns:bpmn=")); assert_false(text.contains("xmlns:ns1="))
  let payload=@bpmn.read(text).document.unwrap().root.children[0].children[0].children[0].xml().unwrap()
  assert_eq(payload.namespace_binding("bpmn"),None)
  assert_eq(payload.namespace_binding("ns1"),None)
}

///|
test "source prefixes may shadow canonical standard prefixes without renaming XML identities" {
  let source="<m:definitions xmlns:m='\{model_uri}' xmlns:bpmn='urn:vendor' targetNamespace='urn:t' bpmn:ref='bpmn:Root'><m:process id='P'><m:extensionElements><bpmn:payload ref='bpmn:Child'/></m:extensionElements></m:process></m:definitions>"
  let result=@bpmn.read(source); assert_eq(result.diagnostics.length(),0)
  roundtrip(result.document.unwrap())
  let text=@bpmn.write(result.document.unwrap())
  let copy=@bpmn.read(text)
  assert_eq(copy.document.unwrap().root.kind,Definitions)
  assert_eq(copy.document.unwrap().root.children[0].kind,Process)
  assert_eq(copy.document.unwrap().root.children[0].children[0].children[0].kind.name().namespace_uri,"urn:vendor")
}

///|
test "unknown standard elements and vendor xsi types remain inspectable and writable" {
  for (body,code) in [
    ("<futureTask id='Future' ref='v:X'><task label='opaque'/></futureTask>","bpmn/unsupported-element"),
    ("<task xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:type='v:CustomTask' id='Future'><v:data>v:X</v:data></task>","bpmn/unsupported-type"),
  ] {
    let source="<definitions xmlns='\{model_uri}' xmlns:v='urn:v' targetNamespace='urn:t'><process id='P'>\{body}</process></definitions>"
    let result=@bpmn.read(source)
    assert_eq(result.tree.text(),source)
    assert_true(result.document is Some(_))
    assert_eq(result.diagnostics[0].code,code)
    let doc=result.document.unwrap()
    assert_true(doc.root.children[0].children[0].xml() is Some(_))
    for format in [@bpmn.WriteFormat::Compact,Pretty] {
      let text=@bpmn.write(doc,format~); let copy=@bpmn.read(text)
      assert_eq(copy.document,Some(doc)); assert_eq(copy.diagnostics[0].code,code)
      assert_eq(@bpmn.write(copy.document.unwrap(),format~),text)
    }
    assert_eq(@adapter.to_diagram(doc).diagram,None)
  }
}

///|
test "construct immutable opaque XML with explicit namespace scopes" {
  let attributes=[(@bpmn.ExpandedName::new("","ref"),"q:T")]
  let nested=@bpmn.XmlElement::new(@bpmn.ExpandedName::new(model_uri,"task"),attributes=[(@bpmn.ExpandedName::new("","flag"),"01")],contents=[Text(" mixed ")])
  let contents : Array[@bpmn.XmlContent] = [Text("before "),Element(nested),Text(" after")]
  let payload=@bpmn.XmlElement::new(@bpmn.ExpandedName::new("urn:v","payload"),attributes~,contents~,bindings=[("q","urn:q"),("unused","urn:keep")])
  attributes.clear(); contents.clear()
  assert_eq(payload.attributes().length(),1)
  assert_eq(payload.contents().length(),3)
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(id="P",contents=[Element(@bpmn.ExtensionElements::new(contents=[Element(payload.element)]).element)]).element]).document()
  roundtrip(doc)
  let read=@bpmn.read(@bpmn.write(doc)).document.unwrap().root.children[0].children[0].children[0].xml().unwrap()
  assert_eq(read.namespace_binding("q"),Some("urn:q"))
  assert_eq(read.namespace_binding("unused"),Some("urn:keep"))
}

///|
test "unknown XML and XSI attributes retain opaque QName contexts" {
  let source="<m:definitions xmlns:m='\{model_uri}' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:q='urn:q' targetNamespace='urn:t' xsi:custom='q:Type' xml:custom='q:Other'/>"
  let result=@bpmn.read(source)
  assert_eq(result.diagnostics.length(),0)
  assert_eq(result.document.unwrap().root.opaque_attributes().length(),2)
  roundtrip(result.document.unwrap())
  let copy=@bpmn.read(@bpmn.write(result.document.unwrap()))
  let root=copy.tree.nodes.iter().find_first(n => n.name.map(n => n.local_name) == Some("definitions")).unwrap()
  assert_true(root.bindings.iter().any(pair => pair == ("q","urn:q")))
}

///|
test "unknown definitions type and raw namespace scope survive the whole document" {
  let source="<definitions xmlns='\{model_uri}' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:v='urn:v' xsi:type='v:Definitions' targetNamespace='urn:t'><process id='P'><v:data>v:X</v:data></process></definitions>"
  let result=@bpmn.read(source)
  assert_eq(result.diagnostics[0].code,"bpmn/unsupported-type")
  let doc=result.document.unwrap()
  assert_eq(doc.definitions(),None)
  assert_true(doc.root.xml() is Some(_))
  for format in [@bpmn.WriteFormat::Compact,Pretty] {
    let xml=@bpmn.write(doc,format~)
    let copy=@bpmn.read(xml)
    assert_eq(copy.document,Some(doc))
    assert_eq(copy.diagnostics[0].code,"bpmn/unsupported-type")
    assert_eq(@bpmn.write(copy.document.unwrap(),format~),xml)
  }
}

///|
test "constructed opaque values inherit bindings from a typed parent" {
  let payload=@bpmn.XmlElement::new(@bpmn.ExpandedName::new("urn:v","payload"),attributes=[(@bpmn.ExpandedName::new("","ref"),"q:T")])
  let root=@bpmn.Element::new(Definitions,attributes=[("targetNamespace","urn:t")],bindings=[("q","urn:q")],children=[@bpmn.ExtensionElements::new(contents=[Element(payload.element)]).element])
  let doc=@bpmn.Document::new(root)
  roundtrip(doc)
  let read=@bpmn.read(@bpmn.write(doc)).document.unwrap().root.children[0].children[0].xml().unwrap()
  assert_eq(read.namespace_binding("q"),Some("urn:q"))
}

///|
test "an impossible detached unbound prefix scope returns a namespace conflict" {
  let source="<m:definitions xmlns:m='\{model_uri}' xmlns:v='urn:v' targetNamespace='urn:t'><m:extensionElements><v:payload ref='q:Unbound'/></m:extensionElements></m:definitions>"
  let child=@bpmn.read(source).document.unwrap().root.children[0].children[0].xml().unwrap()
  let parent=@bpmn.XmlElement::new(@bpmn.ExpandedName::new("urn:v","parent"),contents=[Element(child)],bindings=[("q","urn:parent")])
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.ExtensionElements::new(contents=[Element(parent.element)]).element]).document()
  let result=@bpmn.try_write(doc)
  assert_eq(result.output,None)
  assert_eq(result.diagnostics[0].code,"bpmn/namespace-conflict")
}

///|
test "wide namespace scopes and sibling shadowing share captured contexts" {
  let source=StringBuilder()
  source.write_string("<m:definitions xmlns:m='\{model_uri}' xmlns:v='urn:v' xmlns:q='urn:q' targetNamespace='urn:t'")
  for i in 0..<1000 { source.write_string(" xmlns:p\{i}='urn:scope:\{i}'") }
  source.write_string("><m:extensionElements><v:payload>")
  for i in 0..<2000 { source.write_string("<v:child xmlns:q='urn:q:\{i}' ref='q:Target'>q:Value</v:child>") }
  source.write_string("</v:payload></m:extensionElements></m:definitions>")
  let result=@bpmn.read(source.to_string())
  assert_eq(result.diagnostics.length(),0)
  let doc=result.document.unwrap()
  roundtrip(doc)
  let copy=@bpmn.read(@bpmn.write(doc)).document.unwrap()
  let payload=copy.root.children[0].children[0].xml().unwrap()
  assert_eq(payload.namespace_binding("p999"),Some("urn:scope:999"))
  assert_eq(payload.element.children[1999].xml().unwrap().namespace_binding("q"),Some("urn:q:1999"))
}
