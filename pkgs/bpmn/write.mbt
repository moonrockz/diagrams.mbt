///|
pub(all) enum WriteFormat { Compact; Pretty } derive(Eq, Debug)

///|
pub extend WriteFormat with Eq::{equal, not_equal}

///|
pub extend WriteFormat with @debug.Debug::{to_repr}

///|
pub struct WriteResult { output : String?; diagnostics : ReadOnlyArray[Diagnostic] } derive(Eq, Debug)

///|
pub extend WriteResult with Eq::{equal, not_equal}

///|
pub extend WriteResult with @debug.Debug::{to_repr}

///|
pub(all) suberror WriteError { Failed(ReadOnlyArray[Diagnostic]) } derive(Eq, Debug)

///|
pub extend WriteError with Eq::{equal, not_equal}

///|
pub extend WriteError with @debug.Debug::{to_repr}

///|
priv struct XmlOutput {
  buffer : StringBuilder
  limits : Limits
  diagnostics : Array[Diagnostic]
  uris : Map[String, String]
  mut size : Int
  mut input_records : Int
  mut output_records : Int
  mut stopped : Bool
}

///|
fn XmlOutput::fail(self : XmlOutput, code : String, message : String, span : Span?) -> Unit {
  if !self.stopped { self.diagnostics.push(finding(code,message,span?)) }
  self.stopped = true
}

///|
fn XmlOutput::chunk(self : XmlOutput, text : String) -> Unit {
  if self.stopped { return }
  if text.length() > self.limits.output_units - self.size { self.fail("bpmn/output-limit","XML output exceeds its UTF-16 limit",None); return }
  self.buffer.write_string(text); self.size += text.length()
}

///|
fn XmlOutput::records(self : XmlOutput, count : Int, output : Bool, span : Span?) -> Unit {
  if self.stopped { return }
  let previous = if output { self.output_records } else { self.input_records }
  if count > self.limits.nodes - previous { self.fail("bpmn/write-node-limit","Writer node/attribute limit exceeded",span); return }
  if output { self.output_records += count } else { self.input_records += count }
}

///|
fn XmlOutput::text_valid(self : XmlOutput, text : String, span : Span?) -> Bool {
  if text.length() > self.limits.token_units { self.fail("bpmn/write-token-limit","Writer token limit exceeded",span); return false }
  let mut i=0
  while i < text.length() {
    let (c,width)=codepoint(text,i)
    if !xml_char(c) { self.fail("bpmn/forbidden-text","Constructed text contains a forbidden XML character",span); return false }
    i+=width
  }
  true
}

///|
fn XmlOutput::name_valid(self : XmlOutput, name : ExpandedName, span : Span?) -> Bool {
  if !self.text_valid(name.local_name,span) || !self.text_valid(name.namespace_uri,span) { return false }
  if !ncname(name.local_name) { self.fail("bpmn/invalid-name","Constructed name is not an XML local name",span); return false }
  if name.namespace_uri == "http://www.w3.org/2000/xmlns/" { self.fail("bpmn/namespace-conflict","The namespace declaration namespace cannot name a model value",span); return false }
  if name.namespace_uri != "" && name.namespace_uri != "http://www.w3.org/XML/1998/namespace" { self.uris[name.namespace_uri] = "" }
  true
}

///|
fn XmlOutput::scalar_valid(self : XmlOutput, value : Scalar, expected : ExpandedName?, span : Span?) -> Bool {
  if !self.text_valid(value.token(),span) { return false }
  match value {
    Invalid(..) => { self.fail("bpmn/invalid-scalar","Cannot write an invalid scalar value",span); return false }
    Reference(r) => {
      guard r.name is Some(name) else { self.fail("bpmn/unbound-qname","Cannot write a QName with an unbound prefix or invalid local name",span); return false }
      if !self.name_valid(name,span) { return false }
      if r.kind == Id && name.namespace_uri != "" { self.fail("bpmn/invalid-scalar","An ID reference cannot have a namespace",span); return false }
    }
    Identifier(id) => if !ncname(id) { self.fail("bpmn/invalid-scalar","Identifier is not an XML NCName",span); return false }
    _ => ()
  }
  if expected is Some(t) {
    let parsed = parse_scalar(t,value.token(),[])
    let matches = match (value,parsed) {
      (Reference(a),Reference(b)) => a.kind == b.kind
      _ => value == parsed
    }
    if !matches { self.fail("bpmn/scalar-type-mismatch","Scalar alternative does not match its schema field",span); return false }
  }
  true
}

///|
fn XmlOutput::binding_valid(self : XmlOutput, bindings : ReadOnlyArray[(String,String)], span : Span?) -> Unit {
  let seen : Map[String,Bool] = Map([])
  for (prefix,uri) in bindings {
    if self.stopped { break }
    if !self.text_valid(prefix,span) || !self.text_valid(uri,span) { break }
    if seen.contains(prefix) || (prefix != "" && !ncname(prefix)) || prefix == "xmlns" ||
      uri == "http://www.w3.org/2000/xmlns/" || (prefix != "" && uri == "") ||
      (prefix == "xml" && uri != "http://www.w3.org/XML/1998/namespace") ||
      (prefix != "xml" && uri == "http://www.w3.org/XML/1998/namespace") {
      self.fail("bpmn/namespace-conflict","Conflicting or reserved namespace binding",span); break
    }
    seen[prefix] = true
  }
}

///|
fn XmlOutput::content_valid(self : XmlOutput, content : Content, outside : Bool, span : Span?) -> Unit {
  if self.stopped { return }
  self.records(1,false,span)
  match content {
    Text(text) => {
      self.text_valid(text,span) |> ignore
      if outside && !text.iter().all(c => space(c.to_int())) { self.fail("bpmn/outside-root","Only literal whitespace is allowed outside the document element",span) }
    }
    Comment(text) => {
      if text.length() > self.limits.token_units-7 { self.fail("bpmn/write-token-limit","Comment token exceeds its limit",span); return }
      self.text_valid(text,span) |> ignore
      if text.contains("--") || text.has_suffix("-") || text.contains("\r") { self.fail("bpmn/invalid-comment","Comment cannot contain '--', a final '-', or a non-normalized CR",span) }
    }
    ProcessingInstruction(target~,data~) => {
      let extra = if data.is_empty() { 4 } else { 5 }
      if target.length() > self.limits.token_units-extra || data.length() > self.limits.token_units-extra-target.length() { self.fail("bpmn/write-token-limit","Processing instruction token exceeds its limit",span); return }
      self.text_valid(target,span) |> ignore; self.text_valid(data,span) |> ignore
      if !ncname(target) || ascii_lower(target) == "xml" || data.contains("?>") || data.contains("\r") || (!data.is_empty() && space(unit(data,0))) {
        self.fail("bpmn/invalid-pi","Processing instruction target or data is not representable without changing its meaning",span)
      }
    }
    Element(_) => if outside { self.fail("bpmn/definitions-required","A document has only one definitions root",span) }
  }
}

///|
priv struct WalkFrame { node : Element; depth : Int; mut entered : Bool; mut next : Int; preserve : Bool; expected_type : ExpandedName? }

///|
fn XmlOutput::inspect(self : XmlOutput, document : Document) -> Unit {
  if document.root.kind != Kind::Definitions { self.fail("bpmn/definitions-required","A BPMN document needs a definitions root",document.root.span); return }
  self.records(1,false,None)
  for c in document.prolog { self.content_valid(c,true,None) }
  for c in document.epilog { self.content_valid(c,true,None) }
  let stack = [WalkFrame::{ node: document.root, depth: 0, entered: false, next: 0, preserve: false, expected_type: Kind::Definitions.declared_type() }]
  while !stack.is_empty() && !self.stopped {
    let f = stack[stack.length()-1]
    let node=f.node
    if !f.entered {
      f.entered = true
      self.records(1,false,node.span)
      self.records(node.values.length(),false,node.span)
      self.records(node.bindings.length(),false,node.span)
      if self.stopped { break }
      if f.depth >= self.limits.depth { self.fail("bpmn/write-depth-limit","Writer element depth limit exceeded",node.span); break }
      match node.kind { Foreign(_) | Unknown(_) => { self.fail("bpmn/unsupported-element","Opaque/unknown element writing follows in the extension story",node.span); break }; _ => () }
      if node.value_type is Some(t) && t.namespace_uri != "http://www.w3.org/2001/XMLSchema" && schema_type(t) == None {
        self.fail("bpmn/unsupported-type","Constructed type is outside the pinned schema",node.span); break
      }
      let type_name=ExpandedName::new("http://www.w3.org/2001/XMLSchema-instance","type")
      if node.value_type != f.expected_type && !node.values.iter().any(a => a.name == Some(type_name)) {
        self.fail("bpmn/type-conflict","Constructed type differs from its containment type without an explicit xsi:type",node.span); break
      }
      self.name_valid(node.kind.name(),node.span) |> ignore
      self.binding_valid(node.bindings,node.span)
      let seen : Map[(String,String),Bool] = Map([])
      for attr in node.values {
        if self.stopped { break }
        guard attr.name is Some(name) else { self.fail("bpmn/invalid-name","Attribute has an unbound prefix or invalid name",attr.span); break }
        if name.namespace_uri != "" && name.namespace_uri != "http://www.w3.org/XML/1998/namespace" && name.namespace_uri != "http://www.w3.org/2001/XMLSchema-instance" {
          self.fail("bpmn/unsupported-attribute","Foreign attribute writing follows in the extension story",attr.span); break
        }
        if name.namespace_uri == "" && name.local_name == "xmlns" { self.fail("bpmn/namespace-conflict","Namespace declarations belong in bindings, not model attributes",attr.span); break }
        self.name_valid(name,attr.span) |> ignore
        if seen.contains((name.namespace_uri,name.local_name)) { self.fail("bpmn/duplicate-attribute","Duplicate expanded attribute name",attr.span); break }
        seen[(name.namespace_uri,name.local_name)] = true
        self.scalar_valid(attr.value,Some(field_type(node.value_type,name)),attr.span) |> ignore
        if name.namespace_uri == "http://www.w3.org/2001/XMLSchema-instance" && name.local_name == "type" {
          match attr.value { Reference(r) if r.name != node.value_type => self.fail("bpmn/type-conflict","xsi:type does not match the model's type identity",attr.span); _ => () }
        }
      }
      if node.text_value is Some(value) {
        if !simple_type(node.value_type) { self.fail("bpmn/invalid-content","Typed scalar content needs a simple schema type",node.span); break }
        self.scalar_valid(value,node.value_type,node.span) |> ignore
        if !node.children.is_empty() { self.fail("bpmn/invalid-content","A scalar element cannot contain element children",node.span) }
      }
    }
    if f.next >= node.contents.length() { stack.pop() |> ignore; continue }
    let part=node.contents[f.next]; f.next += 1
    match part {
      Element(child) => {
        if self.input_records >= self.limits.nodes { self.fail("bpmn/write-node-limit","Writer node limit exceeded",child.span); break }
        if f.depth >= self.limits.depth-1 { self.fail("bpmn/write-depth-limit","Writer element depth limit exceeded",child.span); break }
        stack.push({ node: child, depth: f.depth+1, entered: false, next: 0, preserve: space_policy(node,f.preserve), expected_type: child_type(node.value_type,child.kind) })
      }
      _ => self.content_valid(part,false,node.span)
    }
  }
  if self.stopped { return }
  let uris = self.uris.keys().to_array(); uris.sort()
  let mut next = 1
  for uri in uris {
    let fixed = namespace_prefix(uri)
    self.uris[uri] = if fixed == "" { let p="ns\{next}"; next += 1; p } else { fixed }
  }
}

///|
fn XmlOutput::escaped(self : XmlOutput, text : String, attribute : Bool) -> Unit {
  let mut units = 0
  for c in text {
    if self.stopped { break }
    let escaped = match c {
      '<' => "&lt;"; '>' => "&gt;"; '&' => "&amp;"; '"' if attribute => "&quot;"
      '\r' => "&#xd;"; '\n' if attribute => "&#xa;"; '\t' if attribute => "&#x9;"
      _ => c.to_string()
    }
    if escaped.length() > self.limits.token_units-units { self.fail("bpmn/write-token-limit","Escaped XML token exceeds its limit",None); break }
    units += escaped.length(); self.chunk(escaped)
  }
}

///|
fn XmlOutput::prefix(self : XmlOutput, uri : String) -> String {
  if uri == "" { "" } else if uri == "http://www.w3.org/XML/1998/namespace" { "xml" } else { self.uris.get(uri).unwrap() }
}

///|
fn XmlOutput::qualified(self : XmlOutput, name : ExpandedName) -> Unit {
  let prefix=self.prefix(name.namespace_uri)
  let extra = if prefix == "" { 0 } else { prefix.length()+1 }
  if extra > self.limits.token_units || name.local_name.length() > self.limits.token_units-extra { self.fail("bpmn/write-token-limit","Qualified name exceeds its token limit",None); return }
  if prefix != "" { self.chunk(prefix); self.chunk(":") }
  self.chunk(name.local_name)
}

///|
fn XmlOutput::scalar(self : XmlOutput, value : Scalar, attribute : Bool) -> Unit {
  match value {
    Reference(r) => self.qualified(r.name.unwrap())
    _ => self.escaped(value.token(),attribute)
  }
}

///|
fn XmlOutput::line(self : XmlOutput, depth : Int) -> Unit {
  if depth > (self.limits.token_units-1)/2 { self.fail("bpmn/write-token-limit","Pretty indentation exceeds its token limit",None); return }
  self.chunk("\n")
  for _ in 0..<depth { if self.stopped { break }; self.chunk("  ") }
}

///|
fn XmlOutput::inert_content(self : XmlOutput, content : Content) -> Unit {
  self.records(1,true,None)
  match content {
    Text(text) => self.escaped(text,false)
    Comment(text) => { self.chunk("<!--"); self.chunk(text); self.chunk("-->") }
    ProcessingInstruction(target~,data~) => { self.chunk("<?"); self.chunk(target); if !data.is_empty() { self.chunk(" "); self.chunk(data) }; self.chunk("?>") }
    Element(_) => self.fail("bpmn/invalid-content","Unexpected element in inert content",None)
  }
}

///|
priv struct EmitFrame { node : Element; depth : Int; preserve : Bool; mut entered : Bool; mut next : Int; mut block : Bool; mut any : Bool }

///|
fn XmlOutput::emit_document(self : XmlOutput, document : Document, format : WriteFormat) -> Unit {
  self.records(1,true,None)
  for part in document.prolog { self.inert_content(part); if format == Pretty { self.line(0) } }
  let stack = [EmitFrame::{ node: document.root, depth: 0, preserve: false, entered: false, next: 0, block: false, any: false }]
  while !stack.is_empty() && !self.stopped {
    let f=stack[stack.length()-1]; let node=f.node
    let preserve=space_policy(node,f.preserve)
    let mixed=match node.value_type { Some(t) => schema_type(t).map(t => t.has_mixed_content()).unwrap_or(false); None => false }
    if !f.entered {
      f.entered=true; self.records(1,true,node.span)
      self.chunk("<"); self.qualified(node.kind.name())
      if f.depth == 0 {
        let uris=self.uris.keys().to_array(); uris.sort_by((a,b) => self.prefix(a).compare(self.prefix(b)))
        for uri in uris {
          self.records(1,true,None); self.chunk(" xmlns:"); self.chunk(self.prefix(uri)); self.chunk("=\""); self.escaped(uri,true); self.chunk("\"")
        }
      }
      let values=node.values.iter().to_array()
      values.sort_by((a,b) => { let a=a.name.unwrap(); let b=b.name.unwrap(); let order=a.namespace_uri.compare(b.namespace_uri); if order == 0 { a.local_name.compare(b.local_name) } else { order } })
      for attr in values {
        self.records(1,true,attr.span); self.chunk(" "); self.qualified(attr.name.unwrap()); self.chunk("=\""); self.scalar(attr.value,true); self.chunk("\"")
      }
      let has_non_text=node.contents.iter().any(c => match c { Text(s) => node.text_value == None && (mixed || preserve || !s.iter().all(c => space(c.to_int()))); _ => true })
      let has_scalar=node.text_value.map(v => !v.token().is_empty()).unwrap_or(false)
      if !has_non_text && !has_scalar { self.chunk("/>"); stack.pop() |> ignore; continue }
      self.chunk(">")
      f.block = format == Pretty && !mixed && !preserve && node.text_value == None && !node.contents.iter().any(c => match c { Text(s) => !s.iter().all(c => space(c.to_int())); _ => false })
      if node.text_value is Some(value) { self.records(1,true,node.span); self.scalar(value,false) }
    }
    if f.next >= node.contents.length() {
      if f.block && f.any { self.line(f.depth) }
      self.chunk("</"); self.qualified(node.kind.name()); self.chunk(">")
      stack.pop() |> ignore; continue
    }
    let part=node.contents[f.next]; f.next += 1
    if part is Text(text) {
      if node.text_value != None || (!mixed && !preserve && text.iter().all(c => space(c.to_int()))) { continue }
    }
    if f.block { self.line(f.depth+1) }
    f.any=true
    match part {
      Element(child) => stack.push({ node: child, depth: f.depth+1, preserve, entered: false, next: 0, block: false, any: false })
      _ => self.inert_content(part)
    }
  }
  for part in document.epilog { if format == Pretty { self.line(0) }; self.inert_content(part) }
  if format == Pretty { self.chunk("\n") }
}

///|
/// Canonical XML with deterministic namespaces and expanded-name attribute order.
/// A failed result never exposes the partially assembled buffer as output.
pub fn try_write(document : Document, format? : WriteFormat = Compact, limits? : Limits = Limits::new()) -> WriteResult {
  let output = XmlOutput::{ buffer: StringBuilder(),limits,diagnostics:[],uris:Map([]),size:0,input_records:0,output_records:0,stopped:false }
  if limits.source_units <= 0 || limits.output_units <= 0 || limits.nodes <= 0 || limits.depth <= 0 || limits.token_units <= 0 || limits.diagnostics <= 0 { output.fail("bpmn/write-invalid-limits","All processing limits must be positive",None) }
  if !output.stopped { output.inspect(document) }
  if !output.stopped { output.emit_document(document,format) }
  { output: if output.stopped { None } else { Some(output.buffer.to_string()) }, diagnostics: ReadOnlyArray::from_array(output.diagnostics) }
}

///|
/// Convenience writer. Handle WriteError for invalid constructed values or use
/// try_write when an explicit result is more convenient.
pub fn write(document : Document, format? : WriteFormat = Compact, limits? : Limits = Limits::new()) -> String raise WriteError {
  let result=try_write(document,format~,limits~)
  match result.output { Some(output) => output; None => raise WriteError::Failed(result.diagnostics) }
}
