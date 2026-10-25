///|
priv struct XmlNames {
  scope : @namespaces.HashMap[String,String]
  logical : @namespaces.HashMap[String,String]
  fallbacks : @namespaces.HashMap[String,String]
  declarations : Map[String,String]
  element_prefix : String
  attribute_prefixes : Map[(String,String),String]
  reference_prefixes : Map[(String,String,String),String]
  preserve : Bool
}

///|
fn XmlOutput::global_scope(self : XmlOutput) -> @namespaces.HashMap[String,String] {
  let mut scope=@namespaces.HashMap::new().add("xml","http://www.w3.org/XML/1998/namespace").add("","")
  for uri,prefix in self.uris { scope=scope.add(prefix,uri) }
  scope
}

///|
fn XmlOutput::names_for(self : XmlOutput, node : Element, parent : @namespaces.HashMap[String,String], parent_names : XmlNames?, root : Bool) -> XmlNames {
  let logical=namespace_context(node,parent_names.map(n => n.logical).unwrap_or_else(() => @namespaces.HashMap::new()))
  let preserve=parent_names.map(n => n.preserve).unwrap_or(false) || namespace_sensitive(node)
  let mut scope=if root { self.global_scope() } else { parent }
  let mut fallbacks=parent_names.map(n => n.fallbacks).unwrap_or_else(() => @namespaces.HashMap::from_iter(self.uris.iter()))
  let declarations : Map[String,String] = Map([])
  let remaining=self.limits.nodes-self.output_records
  fn bind(prefix : String, uri : String) -> Unit {
    if self.stopped { return }
    if prefix != "xml" && namespace_uri(parent,prefix) != Some(uri) {
      if !declarations.contains(prefix) && declarations.length() >= remaining { self.fail("bpmn/write-node-limit","Preserved namespace declarations exceed the writer node limit",node.span); return }
      declarations[prefix]=uri
    } else { declarations.remove(prefix) }
    if scope.get(prefix) != Some(uri) { scope=scope.add(prefix,uri) }
  }
  if root {
    for uri,prefix in self.uris { if self.stopped { break }; bind(prefix,uri) }
  }
  if preserve {
    let delta=parent_names.map(p => p.preserve && (!node.captured_context || node.context_parent.map(old => physical_equal(old,p.logical)).unwrap_or(false))).unwrap_or(false)
    if delta {
      for (prefix,uri) in node.bindings { if self.stopped { break }; bind(prefix,uri) }
    } else {
      for prefix,uri in logical { if self.stopped { break }; bind(prefix,uri) }
      bind("",namespace_uri(logical,"").unwrap())
    }
    if self.stopped { return {scope,logical,fallbacks,declarations,element_prefix:"",attribute_prefixes:Map([]),reference_prefixes:Map([]),preserve} }
    for text in opaque_strings(node) {
      for prefix in text_prefixes(text) {
        if namespace_uri(logical,prefix) != namespace_uri(scope,prefix) { self.fail("bpmn/namespace-conflict","An inherited prefix would bind an opaque token that was unbound in its captured scope",node.span) }
      }
    }
  }
  let mut next=1
  fn choose(name : ExpandedName, attribute : Bool, spelling : String?) -> String {
    if self.stopped { return "" }
    if name.namespace_uri == "" {
      if !attribute && namespace_uri(scope,"") != Some("") { self.fail("bpmn/namespace-conflict","An empty namespace identity conflicts with the preserved default namespace",node.span) }
      return ""
    }
    if preserve && spelling is Some(raw) && qname(xml_trim(raw)) is Some((prefix,_)) && (prefix != "" || !attribute) && namespace_uri(scope,prefix) == Some(name.namespace_uri) {
      if prefix != "" { fallbacks=fallbacks.add(name.namespace_uri,prefix) }
      return prefix
    }
    if preserve && !attribute && namespace_uri(scope,"") == Some(name.namespace_uri) { return "" }
    if self.uris.get(name.namespace_uri) is Some(prefix) && namespace_uri(scope,prefix) == Some(name.namespace_uri) { return prefix }
    if fallbacks.get(name.namespace_uri) is Some(prefix) && namespace_uri(scope,prefix) == Some(name.namespace_uri) { return prefix }
    let preferred=namespace_prefix(name.namespace_uri)
    let prefix=if preferred != "" && namespace_uri(scope,preferred) == Some(name.namespace_uri) { preferred }
    else if preferred != "" && !scope.contains(preferred) && !self.reserved.contains(preferred) { preferred }
    else {
      while scope.contains("ns\{next}") || self.reserved.contains("ns\{next}") { next+=1 }
      let prefix="ns\{next}"; next+=1; prefix
    }
    bind(prefix,name.namespace_uri); fallbacks=fallbacks.add(name.namespace_uri,prefix)
    prefix
  }
  let element_prefix=choose(node.kind.name(),false,node.raw_name)
  let attribute_prefixes : Map[(String,String),String] = Map([])
  let reference_prefixes : Map[(String,String,String),String] = Map([])
  fn reference(value : Scalar) -> Unit {
    if value is Reference(r) && r.kind == QName && r.name is Some(name) {
      reference_prefixes[(name.namespace_uri,name.local_name,r.spelling)]=choose(name,false,Some(r.spelling))
    }
  }
  for attr in node.values {
    if attr.name is Some(name) { attribute_prefixes[(name.namespace_uri,name.local_name)]=choose(name,true,Some(attr.raw_name)) }
    reference(attr.value)
  }
  if node.text_value is Some(value) { reference(value) }
  {scope,logical,fallbacks,declarations,element_prefix,attribute_prefixes,reference_prefixes,preserve}
}

///|
fn XmlOutput::name_with_prefix(self : XmlOutput, prefix : String, local_name : String) -> Unit {
  if self.stopped { return }
  let extra=if prefix == "" { 0 } else { prefix.length()+1 }
  if extra > self.limits.token_units || local_name.length() > self.limits.token_units-extra { self.fail("bpmn/write-token-limit","Qualified name exceeds its token limit",None); return }
  if prefix != "" { self.chunk(prefix); self.chunk(":") }
  self.chunk(local_name)
}

///|
fn XmlOutput::qualified_names(self : XmlOutput, names : XmlNames, name : ExpandedName, attribute : Bool) -> Unit {
  let prefix=if attribute { names.attribute_prefixes.get((name.namespace_uri,name.local_name)).unwrap() } else { names.element_prefix }
  self.name_with_prefix(prefix,name.local_name)
}

///|
fn XmlOutput::scalar_names(self : XmlOutput, names : XmlNames, value : Scalar, attribute : Bool) -> Unit {
  match value {
    Reference(r) if r.kind == QName => {
      let name=r.name.unwrap()
      self.name_with_prefix(names.reference_prefixes.get((name.namespace_uri,name.local_name,r.spelling)).unwrap(),name.local_name)
    }
    Reference(r) => self.escaped(r.name.unwrap().local_name,attribute)
    _ => self.escaped(value.token(),attribute)
  }
}

///|
fn XmlOutput::namespace_declarations(self : XmlOutput, names : XmlNames, _parent : @namespaces.HashMap[String,String]) -> Unit {
  let keys=names.declarations.keys().to_array(); keys.sort_by((a,b) => a.lexical_compare(b))
  for prefix in keys {
    if self.stopped { break }
    let uri=names.declarations.get(prefix).unwrap()
    let extra=if prefix == "" { 5 } else { 6 }
    if prefix.length() > self.limits.token_units-extra { self.fail("bpmn/write-token-limit","Namespace declaration name exceeds its token limit",None); break }
    self.records(1,true,None); self.chunk(" xmlns")
    if prefix != "" { self.chunk(":"); self.chunk(prefix) }
    self.chunk("=\""); self.escaped(uri,true); self.chunk("\"")
  }
}

///|
fn opaque_unknown_type(element : Element, scope : @namespaces.HashMap[String,String]) -> Bool {
  let type_name=ExpandedName::new("http://www.w3.org/2001/XMLSchema-instance","type")
  guard element.scalar(type_name) is Some(Text(raw)) else { return false }
  let value=reference_lookup(raw,QName,prefix => scope.get(prefix))
  match value.name { Some(name) => name.namespace_uri != "http://www.w3.org/2001/XMLSchema" && schema_type(name) == None; None => false }
}
