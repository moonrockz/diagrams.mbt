///|
fn ascii_lower(s : String) -> String {
  let b = StringBuilder()
  for c in s { let n = c.to_int(); b.write_char(if n >= 65 && n <= 90 { (n+32).unsafe_to_char() } else { c }) }
  b.to_string()
}

///|
fn pseudo_attributes(s : String) -> Array[(String, String)]? {
  let out : Array[(String, String)] = []
  let mut i = 0
  while i < s.length() {
    let before = i
    while space(unit(s, i)) { i += 1 }
    if i == s.length() { break }
    if i == before { return None }
    let start = i
    while name_char(unit(s, i)) { i += 1 }
    let name = s[start:i].to_owned()
    if !ncname(name) { return None }
    while space(unit(s, i)) { i += 1 }
    if unit(s, i) != 61 { return None }
    i += 1
    while space(unit(s, i)) { i += 1 }
    let quote = unit(s, i)
    if quote != 34 && quote != 39 { return None }
    i += 1
    let start = i
    while i < s.length() && unit(s, i) != quote { i += 1 }
    if i == s.length() { return None }
    out.push((name, s[start:i].to_owned())); i += 1
  }
  Some(out)
}

///|
fn XmlParser::declaration(self : XmlParser, body : String, start : Int, end : Int) -> Unit {
  let first = if unit(self.source, 0) == 0xfeff { 1 } else { 0 }
  if start != first { self.error("xml/invalid-declaration", "XML declaration must be first", start, end) }
  guard pseudo_attributes(body) is Some(attrs) && !attrs.is_empty() && attrs[0] == ("version", "1.0") else {
    self.error("xml/invalid-declaration", "Expected an XML 1.0 declaration", start, end); return
  }
  let mut previous = 0
  for i in 1..<attrs.length() {
    let (key, value) = attrs[i]
    let order = match key { "encoding" => 1; "standalone" => 2; _ => -1 }
    if order <= previous || order < 0 { self.error("xml/invalid-declaration", "Invalid declaration attribute order or duplicate", start, end) }
    previous = order
    if key == "standalone" && value != "yes" && value != "no" { self.error("xml/invalid-declaration", "Standalone must be yes or no", start, end) }
    if key == "encoding" {
      let encoding = ascii_lower(value)
      if encoding != "utf-8" && encoding != "us-ascii" { self.error("xml/encoding", "Decoded text accepts UTF-8 or US-ASCII declarations", start, end) }
      else if encoding == "us-ascii" && !self.ascii_only { self.error("xml/encoding", "US-ASCII declaration conflicts with non-ASCII text", start, end) }
    }
  }
}

///|
fn XmlParser::block(self : XmlParser, kind : XmlNodeKind, opener : String, closer : String, unclosed : String) -> Unit {
  let start = self.pos
  guard self.new_node(kind, start) is Some(index) else { return }
  let before = self.diagnostics.length()
  self.pos += opener.length()
  let begin = self.pos
  guard self.source[self.pos:].find(closer) is Some(length) else {
    self.pos = self.source.length()
    self.error(unclosed, "Unclosed XML content block", start, self.pos)
    self.emit(Error, self.pos)
    self.nodes[index].kind = Error; self.nodes[index].end = self.pos
    return
  }
  let end = self.pos + length
  self.pos = end + closer.length()
  if self.pos - start > self.limits.token_units { self.error("xml/token-limit", "Content token limit exceeded", start, self.pos); self.halted = true; self.nodes[index].kind = Error; self.nodes[index].end = self.pos; return }
  let raw = self.source[begin:end].to_owned()
  let token_kind = match kind { Comment => TokenKind::Comment; CData => CData; _ => ProcessingInstruction }
  // Emit the complete raw lexical block once; decode never emits overlapping tokens.
  self.emit(token_kind, self.pos)
  let value = self.decode(begin, end, false, false, token_kind)
  self.nodes[index].value = value
  if kind == Comment && (raw.contains("--") || raw.has_suffix("-")) { self.error("xml/invalid-comment", "A comment cannot contain '--' or end with '-'", begin, end) }
  if kind == CData && self.stack.is_empty() { self.error("xml/outside-root", "CDATA is only allowed inside the document element", start, self.pos) }
  if kind == ProcessingInstruction {
    let mut split = 0
    while split < raw.length() && !space(unit(raw, split)) { split += 1 }
    let target = raw[:split].to_owned()
    self.nodes[index].raw_name = target
    let mut data_start = split
    while space(unit(raw, data_start)) { data_start += 1 }
    self.nodes[index].value = self.decode(begin+data_start, end, false, false, token_kind)
    if target == "xml" {
      self.nodes[index].kind = Declaration
      let token = self.tokens[self.tokens.length()-1]
      self.tokens[self.tokens.length()-1] = { kind: Declaration, text: token.text, span: token.span }
      self.declaration(raw[split:].to_owned(), start, self.pos)
    } else if !ncname(target) || ascii_lower(target) == "xml" { self.error("xml/invalid-pi", "Invalid or reserved processing-instruction target", begin, begin+split) }
  }
  self.nodes[index].end = self.pos
  self.nodes[index].complete = before == self.diagnostics.length() && !self.halted
  if !self.nodes[index].complete { self.nodes[index].kind = Error }
}

///|
fn XmlParser::prohibited(self : XmlParser) -> Unit {
  let start = self.pos
  guard self.new_node(Declaration, start) is Some(index) else { return }
  let mut quote = 0
  let mut brackets = 0
  self.pos += 2
  while self.pos < self.source.length() {
    let c = unit(self.source, self.pos)
    self.pos += 1
    if quote != 0 { if c == quote { quote = 0 } }
    else if c == 34 || c == 39 { quote = c }
    else if c == 91 { brackets += 1 }
    else if c == 93 && brackets > 0 { brackets -= 1 }
    else if c == 62 && brackets == 0 { break }
    if self.pos - start > self.limits.token_units { self.error("xml/token-limit", "Declaration token limit exceeded", start, self.pos); self.halted = true; break }
  }
  self.error("xml/prohibited-declaration", "DTD, entity and other markup declarations are prohibited", start, self.pos)
  self.emit(Declaration, self.pos)
  self.nodes[index].kind = Error; self.nodes[index].end = self.pos
}

///|
fn XmlParser::text(self : XmlParser) -> Unit {
  let start = self.pos
  guard self.new_node(Text, start) is Some(index) else { return }
  while self.pos < self.source.length() && !self.at("<") {
    self.pos += 1
    if self.pos - start > self.limits.token_units { self.error("xml/token-limit", "Text token limit exceeded", start, self.pos); self.halted = true; self.nodes[index].kind = Error; self.nodes[index].end = self.pos; return }
  }
  let before = self.diagnostics.length()
  let value = self.decode(start, self.pos, false, true, Text)
  if self.stack.is_empty() && !value.iter().all(c => space(c.to_int())) { self.error("xml/outside-root", "Non-whitespace text outside the document element", start, self.pos) }
  self.nodes[index].value = value
  self.nodes[index].end = self.pos
  self.nodes[index].complete = before == self.diagnostics.length() && !self.halted
  if !self.nodes[index].complete { self.nodes[index].kind = Error }
}

///|
fn parse_xml(source : String, map : SourceMap, limits : Limits) -> (Cst, Array[Diagnostic]) {
  let root = XmlBuildNode::{ kind: Document, raw_name: "", name: None, attributes: [], bindings: [], children: [], parent: None, start: 0, end: source.length(), value: "", complete: false }
  let parser = XmlParser::{ source, map, limits, ascii_only: source.iter().all(c => c.is_ascii()), tokens: [], nodes: [root], stack: [], namespaces: { "xml": "http://www.w3.org/XML/1998/namespace" }, diagnostics: [], pos: 0, emitted: 0, units: 1, roots: 0, failed: false, halted: false }
  if unit(source, 0) == 0xfeff { parser.pos = 1; parser.emit(Whitespace, 1) }
  while parser.pos < source.length() && !parser.halted {
    if parser.at("<!--") { parser.block(Comment, "<!--", "-->", "xml/unclosed-comment") }
    else if parser.at("<![CDATA[") { parser.block(CData, "<![CDATA[", "]]>", "xml/unclosed-cdata") }
    else if parser.at("<?") { parser.block(ProcessingInstruction, "<?", "?>", "xml/unclosed-pi") }
    else if parser.at("<!") { parser.prohibited() }
    else if parser.at("</") { parser.end_tag() }
    else if parser.at("<") { parser.start_tag() }
    else { parser.text() }
  }
  if !parser.halted {
    if parser.roots != 1 { parser.error("xml/root-required", "XML must have exactly one document element", 0, source.length()) }
    while !parser.stack.is_empty() && !parser.halted {
      let frame = parser.stack.pop().unwrap()
      parser.nodes[frame.index].kind = Error
      parser.nodes[frame.index].end = source.length()
      parser.error("xml/unclosed-tag", "Unclosed element: \{frame.raw_name}", parser.nodes[frame.index].start, source.length())
    }
  }
  // A bounded parser retains the unparsed source tail as one error token, without
  // decoding or expanding it. This preservation record is exempt from token size.
  if parser.emitted < source.length() {
    let start = parser.emitted
    parser.tokens.push({ kind: Error, text: source[start:].to_owned(), span: { start, end: source.length() } })
  }
  for frame in parser.stack { parser.nodes[frame.index].kind = Error; parser.nodes[frame.index].end = parser.pos }
  root.complete = !parser.failed
  let nodes = parser.nodes.map(n => XmlNode::{ kind: n.kind, raw_name: n.raw_name, name: n.name, attributes: ReadOnlyArray::from_array(n.attributes), bindings: ReadOnlyArray::from_array(n.bindings), children: ReadOnlyArray::from_array(n.children), parent: n.parent, span: { start: n.start, end: n.end }, value: n.value, complete: n.complete })
  ({ tokens: ReadOnlyArray::from_array(parser.tokens), nodes: ReadOnlyArray::from_array(nodes), complete: !parser.failed }, parser.diagnostics)
}
