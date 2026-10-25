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
  payload_mode : Bool
  context : @namespaces.HashMap[String,String]
  context_parent : @namespaces.HashMap[String,String]?
}

///|
fn lower_minimal(tree : Cst, map : SourceMap, diagnostics : Array[Diagnostic], maximum : Int, source : String) -> Document? {
  let origin=SourceOrigin::{ source, map }
  let prepared : Array[PreparedElement?] = Array::make(tree.nodes.length(),None)
  let lowered : Array[Element?] = Array::make(tree.nodes.length(),None)
  let mut exhausted = false
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
    let node=tree.nodes[i]
    if node.kind != Element { continue }
    let parent=match node.parent { Some(p) => prepared[p]; None => None }
    let mut context=parent.map(p => p.context).unwrap_or_else(() => @namespaces.HashMap::new().add("xml","http://www.w3.org/XML/1998/namespace").add("",""))
    for (prefix,uri) in node.bindings { if context.get(prefix) != Some(uri) { context=context.add(prefix,uri) } }
    let name=node.name.unwrap()
    let mut payload_mode=parent.map(p => p.payload_mode).unwrap_or(false)
    let mut kind=if payload_mode { Kind::Foreign(name) } else {
      match kind_from_name(name) {
        Some(kind) => kind
        None => {
          payload_mode=true
          if known_namespace(name.namespace_uri) {
            report("bpmn/unsupported-element","Unknown standard element is retained as payload_mode XML",node.span)
            Kind::Unknown(name)
          } else { Kind::Foreign(name) }
        }
      }
    }
    let mut value_type : ExpandedName?=if payload_mode { None } else { child_type(parent.map(p => p.value_type).unwrap_or(None),kind) }
    if !payload_mode {
      for attr in node.attributes {
        if attr.name.namespace_uri == "http://www.w3.org/2001/XMLSchema-instance" && attr.name.local_name == "type" {
          let value=reference_lookup(attr.value,QName,prefix => context.get(prefix))
          inspect_scalar(Reference(value),attr.value_span)
          if value.name is Some(t) { value_type=Some(t) }
        }
      }
      if value_type is Some(t) && t.namespace_uri != "http://www.w3.org/2001/XMLSchema" && schema_type(t) == None {
        report("bpmn/unsupported-type","Unknown type is retained with its complete payload_mode XML",node.span)
        payload_mode=true; kind=Kind::Unknown(name); value_type=None
      }
    }
    let values : Array[Attribute] = []
    let mut preserve_space=parent.map(p => p.preserve_space).unwrap_or(false)
    for attr in node.attributes {
      if exhausted { break }
      if attr.namespace_declaration { continue }
      let named_type=field_type(value_type,attr.name)
      let value=if payload_mode { Scalar::Text(attr.value) } else { parse_scalar_lookup(named_type,attr.value,prefix => context.get(prefix)) }
      if !payload_mode {
        inspect_scalar(value,attr.value_span)
        if (attr.name.namespace_uri == "" || known_namespace(attr.name.namespace_uri)) &&
          !value_type.map(t => schema_type(t).map(t => t.fields().iter().any(f => f.kind == Attribute && f.name == Some(attr.name))).unwrap_or(false)).unwrap_or(false) {
          report("bpmn/unsupported-attribute","Unknown standard attribute is retained",attr.span)
        }
      }
      values.push({ name:Some(attr.name),raw_name:attr.raw_name,value,span:Some(attr.span),origin:Some(origin) })
      if attr.name.namespace_uri == "http://www.w3.org/XML/1998/namespace" && attr.name.local_name == "space" {
        if attr.value == "preserve" { preserve_space=true } else if attr.value == "default" { preserve_space=false }
      }
    }
    let mut text_value : Scalar? = None
    if !payload_mode && simple_type(value_type) {
      let text=StringBuilder()
      for child in node.children { let child=tree.nodes[child]; if child.kind == Text || child.kind == CData { text.write_string(child.value) } }
      let value=parse_scalar_lookup(value_type.unwrap(),text.to_string(),prefix => context.get(prefix))
      inspect_scalar(value,node.span); text_value=Some(value)
    }
    let mixed=payload_mode || (match value_type { Some(t) => schema_type(t).map(t => t.has_mixed_content()).unwrap_or(false); None => false })
    prepared[i]=Some({kind,values,value_type,text_value,preserve_space,mixed,payload_mode,context,context_parent:parent.map(p => p.context)})
  }
  if exhausted { return None }
  for i=tree.nodes.length()-1; i>0; i=i-1 {
    guard prepared[i] is Some(p) else { continue }
    let node=tree.nodes[i]
    let contents : Array[Content] = []
    let spans : Array[Span?] = []
    let mut text_span : Span? = None
    let mut text=StringBuilder()
    fn flush() -> Unit {
      let value=text.to_string()
      if !value.is_empty() && (p.text_value != None || p.mixed || p.preserve_space || !value.iter().all(c => space(c.to_int()))) { contents.push(Text(value)); spans.push(text_span) }
      text=StringBuilder(); text_span=None
    }
    for child in node.children {
      let c=tree.nodes[child]
      if lowered[child] is Some(element) { flush(); contents.push(Element(element)); spans.push(element.span) }
      else { match c.kind {
        Text | CData => { text.write_string(c.value); text_span=Some({start:text_span.map(s => s.start).unwrap_or(c.span.start),end:c.span.end}) }
        Comment => { flush(); contents.push(Comment(c.value)); spans.push(Some(c.span)) }
        ProcessingInstruction => { flush(); contents.push(ProcessingInstruction(target=c.raw_name,data=c.value)); spans.push(Some(c.span)) }
        _ => ()
      } }
    }
    flush()
    lowered[i]=Some(make_element(p.kind,p.values,contents,node.bindings,p.value_type,p.text_value,Some(node.span),context=p.context,captured_context=true,parent_context?=p.context_parent,raw_name=node.raw_name,origin~,content_spans=spans))
  }
  let roots=tree.nodes[0].children.filter(i => tree.nodes[i].kind == Element).iter().to_array()
  guard roots.length() == 1 && lowered[roots[0]] is Some(root) && root.kind.name() == Kind::Definitions.name() else {
    report("bpmn/definitions-required","One BPMN definitions root is required",tree.nodes[0].span); return None
  }
  let prolog : Array[Content] = []; let epilog : Array[Content] = []
  let prolog_spans : Array[Span?] = []; let epilog_spans : Array[Span?] = []
  for child in tree.nodes[0].children {
    let node=tree.nodes[child]
    let target=if child < roots[0] { prolog } else { epilog }
    let spans=if child < roots[0] { prolog_spans } else { epilog_spans }
    match node.kind { Comment => { target.push(Comment(node.value)); spans.push(Some(node.span)) }; ProcessingInstruction => { target.push(ProcessingInstruction(target=node.raw_name,data=node.value)); spans.push(Some(node.span)) }; _ => () }
  }
  Some(Document::{root,prolog:ReadOnlyArray::from_array(prolog),epilog:ReadOnlyArray::from_array(epilog),origin:Some(origin),prolog_spans:ReadOnlyArray::from_array(prolog_spans),epilog_spans:ReadOnlyArray::from_array(epilog_spans)})
}
