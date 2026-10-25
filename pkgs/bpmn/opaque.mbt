///|
/// Preserved XML content has string-valued attributes and its own namespace
/// scope. A known BPMN name inside this payload remains XML payload data.
pub(all) enum XmlContent {
  Text(String)
  Element(XmlElement)
  Comment(String)
  ProcessingInstruction(target~ : String, data~ : String)
} derive(Eq, Debug)

///|
pub extend XmlContent with Eq::{equal, not_equal}

///|
pub extend XmlContent with @debug.Debug::{to_repr}

///|
pub struct XmlElement { element : Element } derive(Eq, Debug)

///|
pub extend XmlElement with Eq::{equal, not_equal}

///|
pub extend XmlElement with @debug.Debug::{to_repr}

///|
pub fn XmlElement::new(name : ExpandedName, attributes? : ArrayView[(ExpandedName,String)] = [], contents? : ArrayView[XmlContent] = [], bindings? : ArrayView[(String,String)] = []) -> XmlElement {
  let values=attributes.map(pair => Attribute::new(pair.0,Text(pair.1)))
  let contents=contents.map(part => match part {
    Text(s) => Content::Text(s)
    Element(e) => Content::Element(e.element)
    Comment(s) => Content::Comment(s)
    ProcessingInstruction(target~,data~) => Content::ProcessingInstruction(target~,data~)
  })
  { element: make_element(Kind::Foreign(name),values,contents,bindings,None,None,None) }
}

///|
pub fn XmlElement::from_element(element : Element) -> XmlElement? {
  if opaque_kind(element.kind) { Some({ element, }) } else { None }
}

///|
pub fn XmlElement::name(self : XmlElement) -> ExpandedName { self.element.kind.name() }

///|
pub fn XmlElement::contents(self : XmlElement) -> ReadOnlyArray[Content] { self.element.contents }

///|
pub fn XmlElement::attributes(self : XmlElement) -> ReadOnlyArray[Attribute] { self.element.values }

///|
pub fn XmlElement::bindings(self : XmlElement) -> ReadOnlyArray[(String,String)] { self.element.bindings }

///|
pub fn Element::xml(self : Element) -> XmlElement? { XmlElement::from_element(self) }

///|
fn opaque_kind(kind : Kind) -> Bool { match kind { Foreign(_) | Unknown(_) => true; _ => false } }

///|
fn namespace_context(element : Element, inherited : @namespaces.HashMap[String,String]) -> @namespaces.HashMap[String,String] {
  if element.captured_context { element.context } else {
    let mut result=inherited
    for (prefix,uri) in element.bindings { if result.get(prefix) != Some(uri) { result=result.add(prefix,uri) } }
    result
  }
}

///|
fn namespace_uri(scope : @namespaces.HashMap[String,String], prefix : String) -> String? {
  if prefix == "xml" { Some("http://www.w3.org/XML/1998/namespace") }
  else if prefix == "" { Some(scope.get("").unwrap_or("")) }
  else { scope.get(prefix) }
}

///|
fn opaque_attribute(element : Element, name : ExpandedName) -> Bool {
  if opaque_kind(element.kind) { return true }
  if name.namespace_uri == "http://www.w3.org/XML/1998/namespace" && ["space","lang","base","id"].contains(name.local_name) { return false }
  if name.namespace_uri == "http://www.w3.org/2001/XMLSchema-instance" && name.local_name == "type" { return false }
  if element.value_type is Some(t) && schema_type(t) is Some(t) {
    return !t.fields().iter().any(f => f.kind == Attribute && f.name == Some(name))
  }
  true
}

///|
pub fn Element::opaque_attributes(self : Element) -> ReadOnlyArray[Attribute] {
  ReadOnlyArray::from_array(self.values.iter().filter(a => a.name.map(n => opaque_attribute(self,n)).unwrap_or(true)).to_array())
}

///|
fn namespace_sensitive(element : Element) -> Bool {
  opaque_kind(element.kind) || element.values.iter().any(a => a.name.map(n => opaque_attribute(element,n)).unwrap_or(false))
}

///|
/// Conservative QName-looking tokens. This never interprets or executes vendor
/// text; it only keeps namespace identities stable when comparing/writing it.
fn text_prefixes(text : String) -> Array[String] {
  let prefixes : Array[String] = []
  let mut i=0
  while i < text.length() {
    let (c,width)=codepoint(text,i)
    if !name_start(c) { i+=width; continue }
    let start=i; i+=width
    while i < text.length() {
      let (c,width)=codepoint(text,i)
      if !name_char(c) && c != 58 { break }
      i+=width
    }
    if qname(text[start:i].to_owned()) is Some((prefix,_)) && prefix != "" { prefixes.push(prefix) }
  }
  prefixes
}

///|
fn opaque_strings(element : Element) -> Array[String] {
  let values : Array[String] = []
  for a in element.values { if a.name.map(n => opaque_attribute(element,n)).unwrap_or(false) { values.push(a.value.token()) } }
  if opaque_kind(element.kind) {
    for content in element.contents { match content {
      Text(s) | Comment(s) => values.push(s)
      ProcessingInstruction(target~,data~) => { values.push(target); values.push(data) }
      _ => ()
    } }
  }
  values
}

///|
fn opaque_namespace_equal(element : Element, a : @namespaces.HashMap[String,String], b : @namespaces.HashMap[String,String]) -> Bool {
  if namespace_sensitive(element) && namespace_uri(a,"") != namespace_uri(b,"") { return false }
  for text in opaque_strings(element) {
    for prefix in text_prefixes(text) { if namespace_uri(a,prefix) != namespace_uri(b,prefix) { return false } }
  }
  true
}

///|
pub fn XmlElement::namespace_binding(self : XmlElement, prefix : String) -> String? { self.element.namespace_binding(prefix) }

///|
pub fn Element::namespace_binding(self : Element, prefix : String) -> String? { namespace_uri(self.context,prefix) }
