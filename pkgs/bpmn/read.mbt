///|
priv struct Frame {
  name : String
  kind : Kind
  attributes : Array[(String, String)]
  children : Array[Element]
  bindings : Array[(String, String)]
  mut content : String
}

///|
fn unit(s : String, i : Int) -> Int { s.code_unit_at(i).to_int() }

///|
fn space(c : Int) -> Bool { c == 32 || c == 9 || c == 10 || c == 13 }

///|
fn decode(s : String) -> String? {
  let b = StringBuilder()
  let mut i = 0
  while i < s.length() {
    if unit(s, i) != 38 { b.write_string(s[i:i+1].to_owned()); i += 1; continue }
    guard s[i:].find(";") is Some(n) else { return None }
    let value = match s[i:i+n+1].to_owned() {
      "&amp;" => "&"; "&lt;" => "<"; "&gt;" => ">"; "&quot;" => "\""; "&apos;" => "'"
      _ => return None
    }
    b.write_string(value); i += n + 1
  }
  Some(b.to_string())
}

///|
fn tag(s : String) -> (String, Array[(String, String)])? {
  let mut i = 0
  while i < s.length() && !space(unit(s, i)) { i += 1 }
  let name = s[:i].to_owned()
  if name.is_empty() { return None }
  let attrs : Array[(String, String)] = []
  while i < s.length() {
    while i < s.length() && space(unit(s, i)) { i += 1 }
    if i == s.length() { break }
    let start = i
    while i < s.length() && !space(unit(s, i)) && unit(s, i) != 61 { i += 1 }
    let key = s[start:i].to_owned()
    while i < s.length() && space(unit(s, i)) { i += 1 }
    if key.is_empty() || i >= s.length() || unit(s, i) != 61 { return None }
    i += 1
    while i < s.length() && space(unit(s, i)) { i += 1 }
    if i >= s.length() || (unit(s, i) != 34 && unit(s, i) != 39) { return None }
    let quote = unit(s, i); i += 1
    let start = i
    while i < s.length() && unit(s, i) != quote { i += 1 }
    if i == s.length() { return None }
    guard decode(s[start:i].to_owned()) is Some(value) else { return None }
    if attrs.iter().any(a => a.0 == key) { return None }
    attrs.push((key, value)); i += 1
  }
  Some((name, attrs))
}

///|
fn kind_of(name : String, bindings : Array[(String, String)]) -> Kind? {
  let parts = name.split(":").to_array()
  if parts.length() > 2 { return None }
  let prefix = if parts.length() == 1 { "" } else { parts[0].to_owned() }
  let local_name = parts[parts.length()-1].to_owned()
  let mut uri = ""
  for (p, u) in bindings { if p == prefix { uri = u } }
  for k in [Definitions, Process, StartEvent, Task, EndEvent, SequenceFlow, Incoming, Outgoing, Diagram, Plane, Shape, Edge, Bounds, Waypoint] {
    if k.local_name() == local_name && k.namespace_uri() == uri { return Some(k) }
  }
  None
}

///|
/// Read the first-slice vocabulary with an explicit stack. The CST owns every
/// source code unit even when lowering fails. No URI causes resource access.
pub fn read(source : String) -> ReadResult {
  let tokens = []
  let diagnostics = []
  let stack : Array[Frame] = []
  let roots : Array[Element] = []
  let mut i = 0
  fn error(code : String, message : String, start : Int, end : Int) -> Unit {
    diagnostics.push(finding(code, message, start~, end~))
  }
  fn attach(e : Element) -> Unit {
    if stack.is_empty() { roots.push(e) } else { stack[stack.length()-1].children.push(e) }
  }
  while i < source.length() {
    let start = i
    let markup = unit(source, i) == 60
    if markup {
      let mut quote = 0
      i += 1
      while i < source.length() {
        let c = unit(source, i)
        if quote != 0 { if c == quote { quote = 0 } }
        else if c == 34 || c == 39 { quote = c }
        else if c == 62 { i += 1; break }
        i += 1
      }
    } else { while i < source.length() && unit(source, i) != 60 { i += 1 } }
    let raw = source[start:i].to_owned()
    tokens.push(Token::{ text: raw, span: { start, end: i } })
    if !markup {
      if stack.is_empty() {
        if !raw.trim().is_empty() { error("xml/outside-root", "Text outside the root element", start, i) }
      } else if decode(raw) is Some(text) {
        let f = stack[stack.length()-1]
        if f.kind == Incoming || f.kind == Outgoing { f.content += text }
        else if !text.trim().is_empty() { error("bpmn/unsupported-content", "Mixed text is not supported in this slice", start, i) }
      } else { error("xml/character-reference", "Unsupported or invalid character reference", start, i) }
      continue
    }
    if raw.has_prefix("<?xml ") && raw.has_suffix("?>") && start == 0 { continue }
    if raw.has_prefix("<!") { error("xml/prohibited-declaration", "Declarations are not supported; DTD and entities are prohibited", start, i); continue }
    if !raw.has_suffix(">") { error("xml/unclosed-tag", "Unclosed tag", start, i); continue }
    if raw.has_prefix("</") {
      let name = raw[2:raw.length()-1].trim().to_owned()
      if stack.is_empty() { error("xml/mismatched-tag", "Unexpected closing tag", start, i) }
      else {
        let f = stack.pop().unwrap()
        if f.name != name { error("xml/mismatched-tag", "Closing tag does not match \{f.name}", start, i) }
        attach(Element::new(f.kind, attributes=f.attributes, children=f.children, content=f.content))
      }
      continue
    }
    let closed = raw.has_suffix("/>")
    let end = raw.length() - (if closed { 2 } else { 1 })
    guard tag(raw[1:end].to_owned()) is Some((name, attrs)) else {
      error("xml/invalid-tag", "Invalid name or attribute syntax", start, i); continue
    }
    let bindings = if stack.is_empty() { [] } else { stack[stack.length()-1].bindings.copy() }
    let ordinary = []
    for (key, value) in attrs {
      if key == "xmlns" { bindings.push(("", value)) }
      else if key.has_prefix("xmlns:") { bindings.push((key[6:].to_owned(), value)) }
      else if key.contains(":") { error("bpmn/unsupported-attribute", "Namespaced attributes need the complete XML reader", start, i) }
      else { ordinary.push((key, value)) }
    }
    guard kind_of(name, bindings) is Some(kind) else {
      error("bpmn/unsupported-element", "Unsupported element or namespace: \{name}", start, i); continue
    }
    if closed { attach(Element::new(kind, attributes=ordinary)) }
    else { stack.push({ name, kind, attributes: ordinary, children: [], bindings, content: "" }) }
  }
  if !stack.is_empty() { error("xml/unclosed-tag", "An element remains open", source.length(), source.length()) }
  if roots.length() != 1 || (roots.length() == 1 && roots[0].kind != Definitions) {
    error("bpmn/definitions-required", "One BPMN definitions root is required", 0, source.length())
  }
  let document = if diagnostics.is_empty() { Some(Document::new(roots[0])) } else { None }
  { tree: { tokens: ReadOnlyArray::from_array(tokens) }, document, diagnostics: ReadOnlyArray::from_array(diagnostics) }
}
