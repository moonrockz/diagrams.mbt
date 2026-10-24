///|
priv struct XmlBuildNode {
  mut kind : XmlNodeKind
  mut raw_name : String
  mut name : ExpandedName?
  attributes : Array[XmlAttribute]
  bindings : Array[(String, String)]
  children : Array[Int]
  parent : Int?
  start : Int
  mut end : Int
  mut value : String
  mut complete : Bool
}

///|
priv struct XmlFrame { index : Int; raw_name : String; undo : Array[(String, String?)] }

///|
priv struct XmlParser {
  source : String
  map : SourceMap
  limits : Limits
  ascii_only : Bool
  tokens : Array[Token]
  nodes : Array[XmlBuildNode]
  stack : Array[XmlFrame]
  namespaces : Map[String, String]
  diagnostics : Array[Diagnostic]
  mut pos : Int
  mut emitted : Int
  mut units : Int
  mut roots : Int
  mut failed : Bool
  mut halted : Bool
}

///|
fn XmlParser::error(self : XmlParser, code : String, message : String, start : Int, end : Int) -> Unit {
  self.failed = true
  let diagnostic = finding(code, message, span={ start, end }, map=self.map)
  if self.diagnostics.length() < self.limits.diagnostics { self.diagnostics.push(diagnostic) }
  else {
    self.diagnostics[self.diagnostics.length()-1] = finding("xml/diagnostic-limit", "Diagnostic limit exceeded", span={ start, end }, map=self.map)
    self.halted = true
  }
}

///|
fn XmlParser::budget(self : XmlParser) -> Bool {
  if self.halted { return false }
  if self.units >= self.limits.nodes {
    self.error("xml/node-limit", "CST node/attribute limit exceeded", self.pos, self.pos)
    self.halted = true
    return false
  }
  self.units += 1
  true
}

///|
fn XmlParser::emit(self : XmlParser, kind : TokenKind, end : Int) -> Unit {
  if self.halted || end <= self.emitted { return }
  let start = self.emitted
  if end - start > self.limits.token_units {
    self.error("xml/token-limit", "Lexical token limit exceeded", start, end)
    self.halted = true
    return
  }
  self.tokens.push({ kind, text: self.source[start:end].to_owned(), span: { start, end } })
  self.emitted = end
}

///|
fn XmlParser::at(self : XmlParser, text : String) -> Bool {
  if text.length() > self.source.length() - self.pos { return false }
  for i in 0..<text.length() { if unit(self.source, self.pos+i) != unit(text, i) { return false } }
  true
}

///|
fn XmlParser::new_node(self : XmlParser, kind : XmlNodeKind, start : Int) -> Int? {
  guard self.budget() else { return None }
  let parent = if self.stack.is_empty() { 0 } else { self.stack[self.stack.length()-1].index }
  let index = self.nodes.length()
  self.nodes.push({ kind, raw_name: "", name: None, attributes: [], bindings: [], children: [], parent: Some(parent), start, end: start, value: "", complete: false })
  self.nodes[parent].children.push(index)
  Some(index)
}

///|
fn XmlParser::whitespace(self : XmlParser) -> Bool {
  if self.halted { return false }
  let start = self.pos
  while space(unit(self.source, self.pos)) {
    self.pos += 1
    if self.pos - start > self.limits.token_units { self.error("xml/token-limit", "Whitespace token limit exceeded", start, self.pos); self.halted = true; break }
  }
  self.emit(Whitespace, self.pos)
  self.pos != start
}

///|
fn XmlParser::take_name(self : XmlParser) -> (String, Span) {
  let start = self.pos
  while self.pos < self.source.length() {
    let c = unit(self.source, self.pos)
    if space(c) || c == 47 || c == 62 || c == 61 || c == 63 || c == 60 { break }
    self.pos += 1
    if self.pos - start > self.limits.token_units { self.error("xml/token-limit", "Name token limit exceeded", start, self.pos); self.halted = true; break }
  }
  if self.halted { return ("", { start, end: self.pos }) }
  self.emit(Name, self.pos)
  let text = self.source[start:self.pos].to_owned()
  if qname(text) == None { self.error("xml/invalid-name", "Invalid XML qualified name", start, self.pos) }
  (text, { start, end: self.pos })
}

///|
/// Decode values separately from lossless source tokens. Literal line endings
/// normalize before attribute whitespace; character references bypass that rule.
fn XmlParser::decode(self : XmlParser, start : Int, end : Int, attribute : Bool, references : Bool, token_kind : TokenKind) -> String {
  let out = StringBuilder()
  let mut i = start
  let mut run = start
  while i < end && !self.halted {
    let (c, width) = codepoint(self.source, i)
    if references && c == 38 {
      self.emit(token_kind, i)
      let begin = i
      i += 1
      while i < end && unit(self.source, i) != 59 && unit(self.source, i) != 38 && !space(unit(self.source, i)) { i += 1 }
      if i < end && unit(self.source, i) == 59 {
        let spelling = self.source[begin+1:i].to_owned()
        i += 1
        if reference(spelling) is Some(value) { out.write_char(value.unsafe_to_char()) }
        else { self.error("xml/character-reference", "Invalid or undeclared XML reference", begin, i) }
      } else { self.error("xml/character-reference", "A reference must end with a semicolon", begin, i) }
      self.emit(CharacterReference, i)
      run = i
      continue
    }
    if !xml_char(c) { self.error("xml/invalid-character", "Forbidden XML character", i, i+width) }
    if attribute && c == 60 { self.error("xml/invalid-tag", "A literal '<' is forbidden in an attribute", i, i+1) }
    if references && !attribute && c == 93 && i+2 < end && self.source[i:i+3] == "]]>" {
      self.error("xml/cdata-close", "CDATA close delimiter outside a CDATA section", i, i+3)
    }
    if c == 13 {
      i += 1
      if i < end && unit(self.source, i) == 10 { i += 1 }
      out.write_char(if attribute { ' ' } else { '\n' })
    } else {
      if attribute && (c == 9 || c == 10) { out.write_char(' ') }
      else if xml_char(c) { out.write_string(self.source[i:i+width].to_owned()) }
      i += width
    }
  }
  if run < end { self.emit(token_kind, end) }
  out.to_string()
}

///|
fn XmlParser::restore(self : XmlParser, frame : XmlFrame) -> Unit {
  for i = frame.undo.length()-1; i >= 0; i = i-1 {
    let (prefix, previous) = frame.undo[i]
    match previous { Some(uri) => self.namespaces[prefix] = uri; None => self.namespaces.remove(prefix) }
  }
}

///|
fn XmlParser::expanded(self : XmlParser, raw : String, span : Span, attribute : Bool) -> ExpandedName? {
  guard qname(raw) is Some((prefix, local_name)) else { return None }
  let namespace_uri = if prefix == "" {
    if attribute { "" } else { self.namespaces.get("").unwrap_or("") }
  } else {
    guard self.namespaces.get(prefix) is Some(uri) else {
      self.error("xml/undeclared-prefix", "Undeclared prefix: \{prefix}", span.start, span.end)
      return None
    }
    uri
  }
  Some({ namespace_uri, local_name })
}

///|
priv struct RawAttribute { name : String; value : String; span : Span; value_span : Span }

///|
fn XmlParser::attributes(self : XmlParser) -> Array[RawAttribute] {
  let attrs = []
  while self.pos < self.source.length() && !self.halted {
    let spaced = self.whitespace()
    if self.halted { break }
    if self.at(">") || self.at("/>") { break }
    if !spaced { self.error("xml/invalid-tag", "Attributes must be separated by whitespace", self.pos, self.pos); break }
    guard self.budget() else { break }
    let start = self.pos
    let (name, _) = self.take_name()
    if self.halted { break }
    self.whitespace() |> ignore
    if !self.at("=") { self.error("xml/invalid-tag", "Expected '=' after the attribute name", start, self.pos); break }
    self.pos += 1; self.emit(Equals, self.pos)
    self.whitespace() |> ignore
    let quote = unit(self.source, self.pos)
    if quote != 34 && quote != 39 { self.error("xml/invalid-tag", "Expected a quoted attribute value", self.pos, self.pos); break }
    self.pos += 1; self.emit(Quote, self.pos)
    let value_start = self.pos
    while self.pos < self.source.length() && unit(self.source, self.pos) != quote && unit(self.source, self.pos) != 60 {
      self.pos += 1
      if self.pos - value_start > self.limits.token_units { self.error("xml/token-limit", "Attribute value limit exceeded", value_start, self.pos); self.halted = true; break }
    }
    let end = self.pos
    let value = self.decode(value_start, end, true, true, AttributeValue)
    if unit(self.source, self.pos) != quote { self.error("xml/invalid-tag", "Unclosed attribute value", value_start, self.pos); break }
    self.pos += 1; self.emit(Quote, self.pos)
    attrs.push({ name, value, span: { start, end: self.pos }, value_span: { start: value_start, end } })
  }
  attrs
}

///|
fn XmlParser::bad_tag(self : XmlParser, index : Int, start : Int) -> Unit {
  while self.pos < self.source.length() && !self.at("<") && !self.at(">") { self.pos += 1 }
  if self.at(">") { self.pos += 1 }
  self.emit(Error, self.pos)
  self.nodes[index].kind = Error
  self.nodes[index].end = self.pos
  self.error("xml/invalid-tag", "Malformed tag; resumed at a tag boundary", start, self.pos)
}

///|
fn XmlParser::start_tag(self : XmlParser) -> Unit {
  let start = self.pos
  let before = self.diagnostics.length()
  guard self.new_node(Element, start) is Some(index) else { return }
  self.pos += 1; self.emit(Open, self.pos)
  let (raw_name, name_span) = self.take_name()
  self.nodes[index].raw_name = raw_name
  let attrs = self.attributes()
  if self.halted { self.nodes[index].kind = Error; self.nodes[index].end = self.pos; return }
  let closed = self.at("/>")
  if !closed && !self.at(">") { self.bad_tag(index, start); return }
  self.pos += if closed { 2 } else { 1 }
  self.emit(if closed { EmptyClose } else { Close }, self.pos)
  if self.halted { return }
  if self.stack.length() >= self.limits.depth { self.error("xml/depth-limit", "Open element depth limit exceeded", start, self.pos); self.halted = true; return }
  let undo : Array[(String, String?)] = []
  let declarations : Map[String, Bool] = Map([])
  for attr in attrs {
    if attr.name == "xmlns" || attr.name.has_prefix("xmlns:") {
      let prefix = if attr.name == "xmlns" { "" } else { attr.name[6:].to_owned() }
      if declarations.contains(prefix) { self.error("xml/duplicate-attribute", "Duplicate namespace declaration", attr.span.start, attr.span.end); continue }
      declarations[prefix] = true
      let uri = attr.value
      if (prefix != "" && !ncname(prefix)) || prefix == "xmlns" || uri == "http://www.w3.org/2000/xmlns/" ||
        (prefix == "xml" && uri != "http://www.w3.org/XML/1998/namespace") ||
        (prefix != "xml" && uri == "http://www.w3.org/XML/1998/namespace") || (prefix != "" && uri == "") {
        self.error("xml/invalid-namespace", "Invalid reserved namespace binding or prefix undeclaration", attr.span.start, attr.span.end)
        continue
      }
      undo.push((prefix, self.namespaces.get(prefix)))
      self.namespaces[prefix] = uri
      self.nodes[index].bindings.push((prefix, uri))
    }
  }
  let frame = XmlFrame::{ index, raw_name, undo }
  self.nodes[index].name = self.expanded(raw_name, name_span, false)
  let names : Map[(String, String), Bool] = Map([])
  for attr in attrs {
    let declaration = attr.name == "xmlns" || attr.name.has_prefix("xmlns:")
    let name = if declaration {
      Some(ExpandedName::{ namespace_uri: "http://www.w3.org/2000/xmlns/", local_name: if attr.name == "xmlns" { "xmlns" } else { attr.name[6:].to_owned() } })
    } else { self.expanded(attr.name, attr.span, true) }
    if name is Some(name) {
      let identity = (name.namespace_uri, name.local_name)
      if names.contains(identity) && !declaration { self.error("xml/duplicate-attribute", "Duplicate expanded attribute name", attr.span.start, attr.span.end) }
      names[identity] = true
      self.nodes[index].attributes.push({ raw_name: attr.name, name, value: attr.value, span: attr.span, value_span: attr.value_span, namespace_declaration: declaration })
    }
  }
  if self.stack.is_empty() {
    self.roots += 1
    if self.roots > 1 { self.error("xml/root-required", "XML must have exactly one document element", start, self.pos) }
  }
  self.nodes[index].end = self.pos
  if before != self.diagnostics.length() || self.halted { self.nodes[index].kind = Error }
  if closed { self.nodes[index].complete = self.nodes[index].kind != Error; self.restore(frame) }
  else { self.stack.push(frame) }
}

///|
fn XmlParser::end_tag(self : XmlParser) -> Unit {
  let start = self.pos
  self.pos += 2; self.emit(EndOpen, self.pos)
  let (name, _) = self.take_name()
  if self.halted { return }
  self.whitespace() |> ignore
  if !self.at(">") {
    guard self.new_node(Error, start) is Some(index) else { return }
    self.bad_tag(index, start); return
  }
  self.pos += 1; self.emit(Close, self.pos)
  let mut found = -1
  for i = self.stack.length()-1; i >= 0; i = i-1 { if self.stack[i].raw_name == name { found = i; break } }
  if found == -1 {
    self.error("xml/mismatched-tag", "Unexpected closing tag: \{name}", start, self.pos)
    if self.new_node(Error, start) is Some(index) { self.nodes[index].end = self.pos }
    return
  }
  if found != self.stack.length()-1 { self.error("xml/mismatched-tag", "Closing tag skips unclosed elements", start, self.pos) }
  while self.stack.length()-1 > found {
    let frame = self.stack.pop().unwrap()
    self.nodes[frame.index].kind = Error
    self.nodes[frame.index].end = start
    self.restore(frame)
  }
  let frame = self.stack.pop().unwrap()
  self.nodes[frame.index].end = self.pos
  self.nodes[frame.index].complete = self.nodes[frame.index].kind != Error
  self.restore(frame)
}
