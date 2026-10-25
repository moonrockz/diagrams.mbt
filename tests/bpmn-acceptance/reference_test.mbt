///|
fn reference_type(element : @bpmn.Element) -> String {
  let name=element.value_type.unwrap()
  let prefix=match name.namespace_uri {
    "http://www.omg.org/spec/BPMN/20100524/MODEL" => "bpmn:"
    "http://www.omg.org/spec/BPMN/20100524/DI" => "bpmndi:"
    "http://www.omg.org/spec/DD/20100524/DC" => "dc:"
    "http://www.omg.org/spec/DD/20100524/DI" => "di:"
    _ => "unknown:"
  }
  let local_name=if prefix == "bpmn:" && name.local_name.has_prefix("t") { name.local_name[1:].to_owned() } else { name.local_name }
  prefix+local_name
}

///|
fn reference_scalar(value : @bpmn.Scalar, external : Bool) -> Json raise {
  let pair : (String,Json) = match value {
    Boolean(v) => ("boolean",Json(v))
    Integer(v) => ("number",@json.parse(v.token))
    Number(v) => ("number",@json.parse(v.token))
    Reference(r) if !external => ("reference",Json([r.name.unwrap().local_name]))
    _ => ("string",Json(value.token()))
  }
  { "kind": Json(pair.0), "value": pair.1 }
}

///|
fn normalize_reference(doc : @bpmn.Document) -> Json raise {
  let root_key=doc.root.attribute("id").map(id => "#"+id).unwrap_or("$")
  let stack : Array[(@bpmn.Element,String,String?)] = [(doc.root,root_key,None)]
  let nodes : Array[(String,Json)] = []
  while !stack.is_empty() {
    let (element,key,parent)=stack.pop().unwrap()
    let fields : Map[String,Json] = Map([])
    for attr in element.values {
      let name=attr.name.unwrap()
      if name.namespace_uri == "http://www.w3.org/2001/XMLSchema-instance" && name.local_name == "type" { continue }
      assert_eq(name.namespace_uri,"")
      let external=["calledElement","implementationRef"].contains(name.local_name) || (name.local_name == "structureRef" && element.kind == ItemDefinition)
      fields[name.local_name]=reference_scalar(attr.value,external)
    }
    if !element.content.is_empty() { fields["@body"]={"kind":"string","value":Json(element.content)} }
    let counts : Map[String,Int] = Map([])
    let references : Map[String,Array[String]] = Map([])
    let children : Array[String] = []
    for child in element.children {
      if child.text_value is Some(Reference(r)) {
        let name=child.kind.local_name()
        let values=references.get(name).unwrap_or_else(() => { let a=[]; references[name]=a; a })
        values.push(r.name.unwrap().local_name)
        continue
      }
      if child.kind == Script || child.kind == Text {
        fields[child.kind.local_name()]={"kind":"string","value":Json(child.content)}
        continue
      }
      let typ=reference_type(child)
      let ordinal=counts.get(typ).unwrap_or(0); counts[typ]=ordinal+1
      let child_key=child.attribute("id").map(id => "#"+id).unwrap_or_else(() => key+"/"+typ+"[\{ordinal}]")
      children.push(child_key); stack.push((child,child_key,Some(key)))
    }
    for name,targets in references { fields[name]={"kind":"reference","value":Json(targets)} }
    children.sort_by((a,b) => a.lexical_compare(b))
    let value : Json={"key":Json(key),"parent":(match parent { Some(value) => Json(value); None => Json::null() }),"type":Json(reference_type(element)),"fields":Json(fields),"children":Json(children)}
    nodes.push((key,value))
  }
  nodes.sort_by((a,b) => a.0.lexical_compare(b.0))
  Json(nodes.map(n => n.1))
}

///|
test "pinned bpmn-moddle agrees on identities containment references and minimal DI" {
  for name in ["minimal","activities","events","collaboration","choreography-conversation","di-views"] {
    let source=if name == "minimal" { fixture() } else { model_source(name+".bpmn") }
    let result=@bpmn.read(source)
    assert_eq(result.diagnostics.iter().map(d => (d.code,d.span.map(s => source[s.start:s.end].to_owned()))).to_array(),[])
    let expected=@json.parse(model_source(name+".reference.json"))
    guard expected is Object(fields) else { fail("reference fixture must be an object") }
    assert_eq(fields.get("reference"),Some(Json("bpmn-moddle@10.3.1")))
    let source_digest=if name == "minimal" { @corpus.inputs[5].sha256 } else { @corpus.model_inputs.iter().find_first(i => i.name == name+".bpmn").unwrap().sha256 }
    assert_eq(fields.get("source_sha256"),Some(Json(source_digest)))
    let expected_nodes=fields.get("nodes").unwrap()
    let actual=normalize_reference(result.document.unwrap())
    guard actual is Array(a) && expected_nodes is Array(e) else { fail("node arrays required") }
    assert_eq(a.length(),e.length())
    for i in 0..<a.length() { if a[i] != e[i] { fail(name+" actual "+a[i].stringify()+" expected "+e[i].stringify()) } }
    roundtrip(result.document.unwrap())
  }
}
