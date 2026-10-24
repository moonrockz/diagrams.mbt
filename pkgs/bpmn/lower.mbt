///|
fn known_namespace(uri : String) -> Bool {
  uri == "http://www.omg.org/spec/BPMN/20100524/MODEL" || uri == "http://www.omg.org/spec/BPMN/20100524/DI" || uri == "http://www.omg.org/spec/DD/20100524/DC" || uri == "http://www.omg.org/spec/DD/20100524/DI"
}

///|
pub fn Kind::substitutes(self : Kind, head : ExpandedName) -> Bool {
  let mut name = self.name()
  for _ in 0..<(schema_elements.length()+1) {
    if name == head { return true }
    guard schema_elements.iter().find_first(e => e.name == name) is Some(e) && e.substitution_group is Some(parent) else { return false }
    name = parent
  }
  false
}

///|
fn child_type(parent : ExpandedName?, kind : Kind) -> ExpandedName? {
  if parent is Some(name) && schema_type(name) is Some(t) {
    for field in t.fields() {
      if field.kind != Child { continue }
      if field.reference_element is Some(head) && kind.substitutes(head) {
        return match kind.declared_type() { Some(t) => Some(t); None => field.value_type }
      }
      if field.reference_element == None && field.name == Some(kind.name()) { return field.value_type }
    }
  }
  kind.declared_type()
}

///|
priv struct PreparedElement {
  kind : Kind
  values : Array[Attribute]
  value_type : ExpandedName?
  text_value : Scalar?
  preserve_space : Bool
  mixed : Bool
}

///|
priv struct LowerFrame { index : Int; undo : Array[(String,String?)] }

///|
fn lower_minimal(tree : Cst, map : SourceMap, diagnostics : Array[Diagnostic], maximum : Int) -> Document? {
  let prepared : Array[PreparedElement?] = Array::make(tree.nodes.length(),None)
  let lowered : Array[Element?] = Array::make(tree.nodes.length(),None)
  let scope : Map[String,String] = { "xml": "http://www.w3.org/XML/1998/namespace" }
  let frames : Array[LowerFrame] = []
  let mut exhausted = false
  let mut unsupported = false
  fn report(code : String, message : String, span : Span) -> Unit {
    if diagnostics.length() < maximum { diagnostics.push(finding(code,message,span~,map~)) }
    else if !exhausted { diagnostics[maximum-1] = finding("xml/diagnostic-limit","Diagnostic limit exceeded during typed lowering",span~,map~); exhausted = true }
  }
  fn inspect_scalar(value : Scalar, span : Span) -> Unit {
    match value {
      Invalid(..) => report("bpmn/invalid-scalar","Value does not match its declared schema scalar type",span)
      Reference(r) if r.name == None => report("bpmn/unbound-qname","QName value has an invalid name or an unbound prefix",span)
      _ => ()
    }
  }
  for i in 1..<tree.nodes.length() {
    if exhausted { break }
    let node = tree.nodes[i]
    if node.kind != Element { continue }
    while !frames.is_empty() && Some(frames[frames.length()-1].index) != node.parent {
      let frame = frames.pop().unwrap()
      for j = frame.undo.length()-1; j >= 0; j = j-1 { let (prefix,old)=frame.undo[j]; match old { Some(uri) => scope[prefix]=uri; None => scope.remove(prefix) } }
    }
    let undo : Array[(String,String?)] = []
    for (prefix,uri) in node.bindings { undo.push((prefix,scope.get(prefix))); scope[prefix]=uri }
    frames.push({ index: i, undo })
    let name = node.name.unwrap()
    let kind = match kind_from_name(name) {
      Some(kind) => kind
      None => {
        report("bpmn/unsupported-element","Element is outside the current typed BPMN schema coverage",node.span)
        unsupported = true
        if known_namespace(name.namespace_uri) { Kind::Unknown(name) } else { Kind::Foreign(name) }
      }
    }
    let parent = match node.parent { Some(p) => prepared[p]; None => None }
    let mut value_type = child_type(match parent { Some(p) => p.value_type; None => None },kind)
    for attr in node.attributes {
      if attr.name.namespace_uri == "http://www.w3.org/2001/XMLSchema-instance" && attr.name.local_name == "type" {
        let value = reference_lookup(attr.value,QName,prefix => scope.get(prefix))
        inspect_scalar(Reference(value),attr.value_span)
        if value.name is Some(t) { value_type = Some(t) }
      }
    }
    if value_type is Some(t) && t.namespace_uri != "http://www.w3.org/2001/XMLSchema" && schema_type(t) == None {
      report("bpmn/unsupported-type","The declared type is outside the pinned BPMN schema",node.span); unsupported = true
    }
    let values : Array[Attribute] = []
    let mut preserve_space = parent.map(p => p.preserve_space).unwrap_or(false)
    for attr in node.attributes {
      if exhausted { break }
      if attr.namespace_declaration { continue }
      if attr.name.namespace_uri != "" && attr.name.namespace_uri != "http://www.w3.org/2001/XMLSchema-instance" && attr.name.namespace_uri != "http://www.w3.org/XML/1998/namespace" {
        report("bpmn/unsupported-attribute","Opaque vendor attribute semantics follow in the extension story",attr.span); unsupported = true
      }
      let value = parse_scalar_lookup(field_type(value_type,attr.name),attr.value,prefix => scope.get(prefix))
      inspect_scalar(value,attr.value_span)
      values.push({ name: Some(attr.name), raw_name: attr.raw_name, value, span: Some(attr.span) })
      if attr.name.namespace_uri == "http://www.w3.org/XML/1998/namespace" && attr.name.local_name == "space" {
        if attr.value == "preserve" { preserve_space = true } else if attr.value == "default" { preserve_space = false }
      }
    }
    let mut text_value : Scalar? = None
    if simple_type(value_type) {
      let b = StringBuilder()
      for child in node.children { let child=tree.nodes[child]; if child.kind == Text || child.kind == CData { b.write_string(child.value) } }
      let value = parse_scalar_lookup(value_type.unwrap(),b.to_string(),prefix => scope.get(prefix))
      inspect_scalar(value,node.span); text_value = Some(value)
    }
    let mixed = match value_type { Some(t) => schema_type(t).map(t => t.has_mixed_content()).unwrap_or(false); None => false }
    prepared[i] = Some({ kind,values,value_type,text_value,preserve_space,mixed })
  }
  if exhausted || unsupported { return None }
  for i = tree.nodes.length()-1; i > 0; i = i-1 {
    guard prepared[i] is Some(p) else { continue }
    let node = tree.nodes[i]
    let contents : Array[Content] = []
    let mut text = StringBuilder()
    fn flush() -> Unit { let s=text.to_string(); if !s.is_empty() && (p.text_value != None || p.mixed || p.preserve_space || !s.iter().all(c => space(c.to_int()))) { contents.push(Text(s)) }; text=StringBuilder() }
    for child in node.children {
      let c=tree.nodes[child]
      if lowered[child] is Some(element) { flush(); contents.push(Element(element)) }
      else { match c.kind {
        Text | CData => text.write_string(c.value)
        Comment => { flush(); contents.push(Comment(c.value)) }
        ProcessingInstruction => { flush(); contents.push(ProcessingInstruction(target=c.raw_name,data=c.value)) }
        _ => ()
      } }
    }
    flush()
    lowered[i] = Some(make_element(p.kind,p.values,contents,node.bindings,p.value_type,p.text_value,Some(node.span)))
  }
  let roots = tree.nodes[0].children.filter(i => tree.nodes[i].kind == Element).iter().to_array()
  guard roots.length() == 1 && lowered[roots[0]] is Some(root) && root.kind == Kind::Definitions else {
    report("bpmn/definitions-required","One BPMN definitions root is required",tree.nodes[0].span); return None
  }
  let prolog : Array[Content] = []; let epilog : Array[Content] = []
  for child in tree.nodes[0].children {
    let node=tree.nodes[child]
    let target = if child < roots[0] { prolog } else { epilog }
    match node.kind { Comment => target.push(Comment(node.value)); ProcessingInstruction => target.push(ProcessingInstruction(target=node.raw_name,data=node.value)); _ => () }
  }
  Some(Document::new(root,prolog~,epilog~))
}
