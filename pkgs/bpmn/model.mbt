///|
/// Ordered semantic content. Text and element order are independent of source
/// token spelling. Comments and processing instructions are inert document data.
pub(all) enum Content {
  Text(String)
  Element(Element)
  Comment(String)
  ProcessingInstruction(target~ : String, data~ : String)
} derive(Eq, Debug)

///|
pub extend Content with Eq::{equal, not_equal}

///|
pub extend Content with @debug.Debug::{to_repr}

///|
/// Immutable document element with schema-typed attribute and scalar values.
/// The legacy string attributes expose model tokens; lexical source is in CST.
pub struct Element {
  kind : Kind
  attributes : ReadOnlyArray[(String, String)]
  values : ReadOnlyArray[Attribute]
  children : ReadOnlyArray[Element]
  contents : ReadOnlyArray[Content]
  content : String
  bindings : ReadOnlyArray[(String, String)]
  value_type : ExpandedName?
  text_value : Scalar?
  span : Span?
  priv context : @namespaces.HashMap[String,String]
  priv captured_context : Bool
  priv context_parent : @namespaces.HashMap[String,String]?
  priv raw_name : String?
  priv origin : SourceOrigin?
  priv content_spans : ReadOnlyArray[Span?]
} derive(Debug)

///|
pub extend Element with @debug.Debug::{to_repr}

///|
fn bound_name(raw : String, bindings : ArrayView[(String,String)], attribute : Bool) -> ExpandedName? {
  guard qname(raw) is Some((prefix,local_name)) else { return None }
  let mut uri : String? = if prefix == "" { Some("") } else if prefix == "xml" { Some("http://www.w3.org/XML/1998/namespace") } else { None }
  for (p,value) in bindings { if p == prefix && (!attribute || prefix != "") { uri = Some(value) } }
  uri.map(namespace_uri => ExpandedName::{ namespace_uri, local_name })
}

///|
fn field_type(value_type : ExpandedName?, name : ExpandedName) -> ExpandedName {
  if name.namespace_uri == "http://www.w3.org/2001/XMLSchema-instance" && name.local_name == "type" { return ExpandedName::new("http://www.w3.org/2001/XMLSchema","QName") }
  if value_type is Some(t) && schema_type(t) is Some(t) {
    for field in t.fields() { if field.kind == Attribute && field.name == Some(name) && field.value_type is Some(value_type) { return value_type } }
  }
  ExpandedName::new("http://www.w3.org/2001/XMLSchema","string")
}

///|
fn simple_type(name : ExpandedName?) -> Bool {
  match name { Some(n) => n.namespace_uri == "http://www.w3.org/2001/XMLSchema" || schema_type(n).map(t => t.simple).unwrap_or(false); None => false }
}

///|
fn ordered_contents(contents : ArrayView[Content]) -> Array[Content] {
  let result : Array[Content] = []
  let mut text=StringBuilder()
  fn flush() -> Unit { let value=text.to_string(); if !value.is_empty() { result.push(Text(value)) }; text=StringBuilder() }
  for part in contents { match part { Text(value) => text.write_string(value); _ => { flush(); result.push(part) } } }
  flush(); result
}

///|
fn make_element(kind : Kind, values : ArrayView[Attribute], contents : ArrayView[Content], bindings : ArrayView[(String,String)], value_type : ExpandedName?, text_value : Scalar?, span : Span?, context? : @namespaces.HashMap[String,String], captured_context? : Bool = false, parent_context? : @namespaces.HashMap[String,String], raw_name? : String, origin? : SourceOrigin, content_spans? : ArrayView[Span?] = []) -> Element {
  let context = context.unwrap_or_else(() => @namespaces.HashMap::from_iter(bindings.iter()))
  let contents = ordered_contents(contents)
  let children : Array[Element] = []
  let text = StringBuilder()
  for part in contents { match part { Element(e) => children.push(e); Text(t) => text.write_string(t); _ => () } }
  let content = text.to_string()
  let value_type = match value_type { Some(_) => value_type; None => kind.declared_type() }
  let text_value = match text_value { Some(_) => text_value; None => if simple_type(value_type) { Some(parse_scalar_lookup(value_type.unwrap(),content,prefix => context.get(prefix))) } else { None } }
  {
    kind, attributes: ReadOnlyArray::from_array(values.map(a => (a.raw_name,a.value.token()))),
    values: ReadOnlyArray::from_array(values), children: ReadOnlyArray::from_array(children),
    contents: ReadOnlyArray::from_array(contents), content, bindings: ReadOnlyArray::from_array(bindings), value_type, text_value, span, context, captured_context, context_parent: parent_context, raw_name, origin, content_spans: if content_spans.length() == contents.length() { ReadOnlyArray::from_array(content_spans) } else { [] },
  }
}

///|
/// A compatibility constructor for string attributes and text followed by children.
/// QName spellings use the explicit bindings of this value. Typed references can
/// instead be constructed directly from expanded identity with from_values.
pub fn Element::new(kind : Kind, attributes? : ArrayView[(String, String)] = [], children? : ArrayView[Element] = [], content? : String = "", bindings? : ArrayView[(String,String)] = [], value_type? : ExpandedName) -> Element {
  let contents : Array[Content] = []
  if !content.is_empty() { contents.push(Text(content)) }
  for child in children { contents.push(Element(child)) }
  let value_type = match value_type { Some(_) => value_type; None => kind.declared_type() }
  let values = attributes.map(pair => {
    let name = bound_name(pair.0,bindings,true)
    let value = match name { Some(n) => parse_scalar(field_type(value_type,n),pair.1,bindings); None => Scalar::Text(pair.1) }
    Attribute::{ name, raw_name: pair.0, value, span: None, origin: None }
  })
  make_element(kind,annotated_values(kind,values,value_type),contents,bindings,value_type,None,None)
}

///|
pub fn Element::from_values(kind : Kind, values? : ArrayView[Attribute] = [], contents? : ArrayView[Content] = [], bindings? : ArrayView[(String,String)] = [], value_type? : ExpandedName, text_value? : Scalar) -> Element {
  make_element(kind,annotated_values(kind,values,value_type),contents,bindings,value_type,text_value,None)
}

///|
fn annotated_values(kind : Kind, values : ArrayView[Attribute], value_type : ExpandedName?) -> Array[Attribute] {
  let result=values.to_owned()
  let name=ExpandedName::new("http://www.w3.org/2001/XMLSchema-instance","type")
  if value_type is Some(t) && Some(t) != kind.declared_type() && !values.iter().any(a => a.name == Some(name)) {
    result.push(Attribute::new(name,Reference(Reference::new(t))))
  }
  result
}

///|
pub fn Element::attribute(self : Element, name : String) -> String? {
  for value in self.values { if value.raw_name == name || (value.name is Some(n) && n.namespace_uri == "" && n.local_name == name) { return Some(value.value.token()) } }
  None
}

///|
pub fn Element::scalar(self : Element, name : ExpandedName) -> Scalar? { self.values.iter().find_first(a => a.name == Some(name)).map(a => a.value) }

///|
pub fn Element::with_attribute(self : Element, attribute : Attribute) -> Element {
  let values = self.values.iter().filter(a => if attribute.name is Some(n) { a.name != Some(n) } else { a.raw_name != attribute.raw_name }).to_array()
  values.push(attribute)
  make_element(self.kind,values,self.contents,self.bindings,self.value_type,self.text_value,None,context=self.context,captured_context=self.captured_context,parent_context?=self.context_parent,raw_name?=self.raw_name,origin?=self.origin,content_spans=self.content_spans)
}

///|
pub fn Element::with_contents(self : Element, contents : ArrayView[Content]) -> Element {
  let text=StringBuilder()
  for part in contents { if part is Text(s) { text.write_string(s) } }
  let retained = if text.to_string() == self.content { self.text_value } else { None }
  make_element(self.kind,self.values,contents,self.bindings,self.value_type,retained,None,context=self.context,captured_context=self.captured_context,parent_context?=self.context_parent,raw_name?=self.raw_name,origin?=self.origin)
}

///|
pub fn Element::with_kind(self : Element, kind : Kind) -> Element {
  make_element(kind,annotated_values(kind,self.values,self.value_type),self.contents,self.bindings,self.value_type,self.text_value,None,context=self.context,captured_context=self.captured_context,parent_context?=self.context_parent,raw_name?=self.raw_name,origin?=self.origin,content_spans=self.content_spans)
}

///|
pub fn Element::boolean(self : Element, name : String) -> Field[Bool] {
  match self.scalar(ExpandedName::new("",name)) { None => Absent; Some(Boolean(b)) => Present(b); Some(other) => InvalidValue(other) }
}

///|
pub fn Element::number(self : Element, name : String) -> Field[ExactNumber] {
  match self.scalar(ExpandedName::new("",name)) { None => Absent; Some(Number(n)) => Present(n); Some(other) => InvalidValue(other) }
}

///|
pub fn Element::reference(self : Element, name : String) -> Field[Reference] {
  match self.scalar(ExpandedName::new("",name)) { None => Absent; Some(Reference(r)) => Present(r); Some(other) => InvalidValue(other) }
}

///|
pub fn Element::enumeration(self : Element, name : String) -> Field[BpmnEnum] {
  match self.scalar(ExpandedName::new("",name)) { None => Absent; Some(Enumeration(e)) => Present(e); Some(other) => InvalidValue(other) }
}

///|
fn space_policy(e : Element, inherited : Bool) -> Bool {
  match e.scalar(ExpandedName::new("http://www.w3.org/XML/1998/namespace","space")) {
    Some(Text("preserve")) => true; Some(Text("default")) => false; _ => inherited
  }
}

///|
fn semantic_contents(e : Element, preserve : Bool) -> Array[Content] {
  let simple = simple_type(e.value_type)
  let mixed = opaque_kind(e.kind) || (match e.value_type { Some(name) => schema_type(name).map(t => t.has_mixed_content()).unwrap_or(false); None => false })
  let out : Array[Content] = []
  let mut text = StringBuilder()
  fn flush() -> Unit { let s=text.to_string(); if !s.is_empty() { out.push(Text(s)) }; text = StringBuilder() }
  for content in e.contents {
    match content {
      Text(s) => {
        if simple { continue }
        if mixed || preserve || !s.iter().all(c => space(c.to_int())) { text.write_string(s) }
      }
      other => { flush(); out.push(other) }
    }
  }
  flush(); out
}

///|
pub impl Eq for Element with equal(a,b) {
  let stack = [(a,b,false,false,@namespaces.HashMap::new(),@namespaces.HashMap::new())]
  while !stack.is_empty() {
    let (a,b,pa,pb,sa,sb) = stack.pop().unwrap()
    let sa=namespace_context(a,sa); let sb=namespace_context(b,sb)
    if !opaque_namespace_equal(a,sa,sb) { return false }
    if (if opaque_kind(a.kind) && opaque_kind(b.kind) { a.kind.name() != b.kind.name() } else { a.kind != b.kind }) || a.value_type != b.value_type || a.text_value != b.text_value || a.values.length() != b.values.length() { return false }
    let attrs : Map[(String,String),Scalar] = Map([])
    for attr in a.values {
      let key = match attr.name { Some(n) => (n.namespace_uri,n.local_name); None => ("",attr.raw_name) }
      if attrs.contains(key) { return false }; attrs[key] = attr.value
    }
    for attr in b.values {
      let key = match attr.name { Some(n) => (n.namespace_uri,n.local_name); None => ("",attr.raw_name) }
      if attrs.get(key) != Some(attr.value) { return false }; attrs.remove(key)
    }
    let pa = space_policy(a,pa); let pb = space_policy(b,pb)
    let ca=semantic_contents(a,pa); let cb=semantic_contents(b,pb)
    if ca.length() != cb.length() { return false }
    for i in 0..<ca.length() {
      match (ca[i],cb[i]) {
        (Element(x),Element(y)) => stack.push((x,y,pa,pb,sa,sb))
        (Text(x),Text(y)) | (Comment(x),Comment(y)) => if x != y { return false }
        (ProcessingInstruction(target=x,data=xd),ProcessingInstruction(target=y,data=yd)) => if x != y || xd != yd { return false }
        _ => return false
      }
    }
  }
  true
}

///|
pub extend Element with Eq::{equal, not_equal}

///|
/// The typed document owns its root and ordered prolog/epilog data. Source maps
/// remain separate from semantic equality and are absent on constructed values.
pub struct Document { root : Element; prolog : ReadOnlyArray[Content]; epilog : ReadOnlyArray[Content]; priv origin : SourceOrigin?; priv prolog_spans : ReadOnlyArray[Span?]; priv epilog_spans : ReadOnlyArray[Span?] } derive(Debug)

///|
pub impl Eq for Document with equal(a,b) { a.root == b.root && a.prolog == b.prolog && a.epilog == b.epilog }

///|
pub extend Document with Eq::{equal, not_equal}

///|
pub extend Document with @debug.Debug::{to_repr}

///|
pub fn Document::new(root : Element, prolog? : ArrayView[Content] = [], epilog? : ArrayView[Content] = []) -> Document {
  { root, origin:None, prolog_spans:[],epilog_spans:[], prolog: ReadOnlyArray::from_array(prolog.filter(c => match c { Text(s) => !s.iter().all(c => space(c.to_int())); _ => true })), epilog: ReadOnlyArray::from_array(epilog.filter(c => match c { Text(s) => !s.iter().all(c => space(c.to_int())); _ => true })) }
}

///|
pub fn Document::walk(self : Document, visit : (Element) -> Unit) -> Unit {
  let stack = [self.root]
  while !stack.is_empty() {
    let node = stack.pop().unwrap(); visit(node)
    for i = node.children.length()-1; i >= 0; i = i-1 { stack.push(node.children[i]) }
  }
}
