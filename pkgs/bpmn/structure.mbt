///|
fn wildcard_accepts(constraint : String, owner : ExpandedName, name : ExpandedName) -> Bool {
  if constraint == "" || constraint == "##any" { return true }
  constraint.split(" ").iter().any(part => match part.to_owned() {
    "##other" => name.namespace_uri != "" && name.namespace_uri != owner.namespace_uri
    "##local" => name.namespace_uri == ""
    "##targetNamespace" => name.namespace_uri == owner.namespace_uri
    uri => name.namespace_uri == uri
  })
}

///|
fn scalar_conforms(value : Scalar, expected : ExpandedName) -> Bool {
  let parsed=parse_scalar(expected,value.token(),[])
  match (value,parsed) {
    (Reference(a),Reference(b)) => a.kind == b.kind
    _ => value == parsed && !(value is Invalid(..))
  }
}

///|
fn value_subtype(actual : ExpandedName, expected : ExpandedName) -> Bool {
  actual == expected || schema_type(actual).map(t => t.is_subtype_of(expected)).unwrap_or(false)
}

///|
fn field_matches(field : SchemaField, child : Element, owner : ExpandedName) -> Bool {
  match field.kind {
    Child => field.name.map(name => typed_child_matches(child,name,field.reference_element != None)).unwrap_or(false)
    AnyChild => wildcard_accepts(field.namespace_constraint,owner,child.kind.name())
    _ => false
  }
}

///|
fn group_has_values(path : String, fields : ReadOnlyArray[SchemaField], counts : Array[Int]) -> Bool {
  for i in 0..<fields.length() { if counts[i] > 0 && (fields[i].group == path || fields[i].group.has_prefix(path+"/")) { return true } }
  false
}

///|
fn choice_branch_active(path : String, fields : ReadOnlyArray[SchemaField], counts : Array[Int]) -> Bool {
  if schema_groups.iter().any(g => g.path == path) { group_has_values(path,fields,counts) }
  else { for i in 0..<fields.length() { if fields[i].source_path == path { return counts[i] > 0 } }; false }
}

///|
fn group_enabled(path : String, fields : ReadOnlyArray[SchemaField], counts : Array[Int]) -> Bool {
  let mut branch=path
  let mut next=schema_groups.iter().find_first(g => g.path == path)
  while next is Some(group) {
    if group.choice && !choice_branch_active(branch,fields,counts) { return false }
    branch=group.path
    next=schema_groups.iter().find_first(g => g.path == group.parent)
  }
  true
}

///|
fn field_enabled(field : SchemaField, fields : ReadOnlyArray[SchemaField], counts : Array[Int]) -> Bool {
  let mut branch=field.source_path
  let mut next=schema_groups.iter().find_first(g => g.path == field.group)
  while next is Some(group) {
    if group.choice && !choice_branch_active(branch,fields,counts) { return false }
    if group.minimum == 0 && !group_has_values(group.path,fields,counts) { return false }
    branch=group.path
    next=schema_groups.iter().find_first(g => g.path == group.parent)
  }
  true
}

///|
fn ValidationLog::structure_node(self : ValidationLog, node : IndexedElement) -> Unit {
  let element=node.element
  if node.payload { return }
  guard element.value_type is Some(type_name) else {
    self.add(Structure,"bpmn/invalid-type","Element has no declared schema type",Some(node),None); return
  }
  if element.kind.declared_type() is Some(declared) && !value_subtype(type_name,declared) {
    self.add(Structure,"bpmn/invalid-type","Actual type is not derived from the element declaration",Some(node),None)
  }
  if simple_type(element.value_type) {
    if !element.children.is_empty() { self.add(Structure,"bpmn/invalid-containment","Simple content cannot contain child elements",Some(node),None) }
    if !element.text_value.map(value => scalar_conforms(value,type_name)).unwrap_or(false) { self.add(Structure,"bpmn/invalid-field","Invalid simple content",Some(node),None) }
    for attr in element.values {
      let allowed=attr.name.map(name => name.namespace_uri == "http://www.w3.org/2001/XMLSchema-instance" && ["type","nil","schemaLocation","noNamespaceSchemaLocation"].contains(name.local_name)).unwrap_or(false)
      if !allowed { self.add(Structure,"bpmn/invalid-field","Simple content does not declare this attribute",Some(node),attr.name,attribute=attr) }
      if attr.name == Some(ExpandedName::new("http://www.w3.org/2001/XMLSchema-instance","type")) && (match attr.value { Reference(r) => r.name != element.value_type; _ => true }) { self.add(Structure,"bpmn/invalid-type","xsi:type differs from the actual simple type",Some(node),attr.name,attribute=attr) }
      if attr.name == Some(ExpandedName::new("http://www.w3.org/2001/XMLSchema-instance","nil")) && !["false","0"].contains(collapse_space(attr.value.token())) { self.add(Structure,"bpmn/invalid-field","This declaration is not nillable",Some(node),attr.name,attribute=attr) }
    }
    return
  }
  guard schema_type(type_name) is Some(schema) else {
    self.add(Structure,"bpmn/invalid-type","Unknown schema type",Some(node),None); return
  }
  if schema.abstract_type || schema_elements.iter().any(e => e.name == element.kind.name() && e.abstract_element) {
    self.add(Structure,"bpmn/abstract-element","An abstract schema element or type cannot be instantiated",Some(node),None)
  }
  let fields=schema.fields(); let counts=Array::make(fields.length(),0)
  let mut previous = -1
  for child in element.children {
    if self.stopped { return }
    let mut selected : Int? = None
    for i in 0..<fields.length() {
      if field_matches(fields[i],child,schema.name) { selected=Some(i); break }
    }
    guard selected is Some(i) else {
      self.add(Structure,"bpmn/invalid-containment","Child "+child.kind.local_name()+" is not allowed in "+element.kind.local_name(),Some(node),Some(child.kind.name())); continue
    }
    let field=fields[i]; counts[i]+=1
    if field.kind == Child && opaque_kind(child.kind) { self.add(Structure,"bpmn/invalid-type","Declared semantic child has only an opaque XML representation",Some(node),field.name) }
    if i < previous { self.add(Structure,"bpmn/child-order","Child is out of schema containment order",Some(node),field.name) }
    previous=i
    if field.kind == Child && !opaque_kind(child.kind) && field.value_type is Some(expected) {
      let expected=if field.reference_element != None { child.kind.declared_type().unwrap_or(expected) } else { expected }
      let valid=match child.value_type { Some(actual) => value_subtype(actual,expected); None => false }
      if !valid { self.add(Structure,"bpmn/invalid-type","Child has an incompatible schema type",Some(node),field.name) }
    }
  }
  for attr in element.values {
    if self.stopped { return }
    let mut selected : Int? = None
    for i in 0..<fields.length() { if fields[i].kind == Attribute && fields[i].name == attr.name { selected=Some(i); break } }
    match selected {
      Some(i) => {
        counts[i]+=1
        if !scalar_conforms(attr.value,fields[i].value_type.unwrap()) {
          self.add(Structure,"bpmn/invalid-field","Invalid attribute scalar",Some(node),attr.name,attribute=attr)
        }
        if fields[i].fixed_value is Some(fixed) && attr.value.token() != fixed { self.add(Structure,"bpmn/invalid-field","Attribute differs from its fixed value",Some(node),attr.name,attribute=attr) }
      }
      None => {
        let allowed=attr.name.map(name => name.namespace_uri == "http://www.w3.org/XML/1998/namespace" || name.namespace_uri == "http://www.w3.org/2001/XMLSchema-instance" || fields.iter().any(f => f.kind == AnyAttribute && wildcard_accepts(f.namespace_constraint,schema.name,name))).unwrap_or(false)
        if !allowed { self.add(Structure,"bpmn/invalid-field","Attribute is not declared for this type",Some(node),attr.name,attribute=attr) }
        if attr.name == Some(ExpandedName::new("http://www.w3.org/2001/XMLSchema-instance","type")) && (match attr.value { Reference(r) => r.name != element.value_type; _ => true }) {
          self.add(Structure,"bpmn/invalid-type","xsi:type differs from the actual type identity",Some(node),attr.name,attribute=attr)
        }
      }
    }
  }
  if !schema.has_mixed_content() && element.contents.iter().any(c => match c { Text(s) => !s.iter().all(c => space(c.to_int())); _ => false }) {
    self.add(Structure,"bpmn/invalid-containment","Element-only content contains text",Some(node),None)
  }
  for i in 0..<fields.length() {
    let f=fields[i]
    if f.kind == AnyAttribute { continue }
    if field_enabled(f,fields,counts) && counts[i] < f.minimum { self.add(Structure,"bpmn/required-field","Required field is absent: "+f.name.map(n => n.local_name).unwrap_or("wildcard"),Some(node),f.name) }
    if f.maximum is Some(maximum) && counts[i] > maximum { self.add(Structure,"bpmn/field-cardinality","Field exceeds its maximum occurrences",Some(node),f.name) }
  }
  for group in schema_groups {
    if !group.choice || !fields.iter().any(f => f.owner == group.owner) || !group_enabled(group.path,fields,counts) { continue }
    let mut branches=0
    for f in fields { if f.group == group.path && choice_branch_active(f.source_path,fields,counts) { branches+=1 } }
    for g in schema_groups { if g.parent == group.path && group_has_values(g.path,fields,counts) { branches+=1 } }
    if branches > 1 { self.add(Structure,"bpmn/choice-conflict","More than one schema choice branch is present",Some(node),None) }
  }
}

///|
/// Structural validation keeps incomplete documents inspectable. `complete`
/// describes processing, not whether the document has errors.
pub fn validate_structure(document : Document, resource_id? : String, limits? : Limits = Limits::new()) -> StructureResult {
  let log=ValidationLog::{limits:if valid_limits(limits) { limits } else { Limits::new() },findings:[],resource_id,stopped:false}
  let nodes : Array[IndexedElement] = []
  let ids : Map[String,Array[Int]] = Map([])
  let mut records=1
  let mut complete=true
  if !valid_limits(limits) { log.add(Structure,"bpmn/validation-invalid-limits","All validation limits must be positive",None,None); complete=false }
  if complete {
    for parts in [document.prolog,document.epilog] { for part in parts {
      if records >= limits.nodes { log.add(Structure,"bpmn/validation-node-limit","Validation outside-root node limit exceeded",None,None); complete=false; break }
      records+=1
      let oversized=match part { Text(s) | Comment(s) => s.length() > limits.token_units; ProcessingInstruction(target~,data~) => target.length() > limits.token_units || data.length() > limits.token_units; _ => false }
      if oversized { log.add(Structure,"bpmn/validation-token-limit","Outside-root token exceeds its validation limit",None,None); complete=false; break }
      match part {
        Element(_) => log.add(Structure,"bpmn/invalid-containment","Elements are not allowed outside the definitions root",None,None)
        Text(s) if !s.iter().all(c => space(c.to_int())) => log.add(Structure,"bpmn/invalid-containment","Non-whitespace text outside definitions",None,None)
        _ => ()
      }
    } }
    if document.root.kind.name() != Kind::Definitions.name() { log.add(Structure,"bpmn/invalid-containment","A BPMN document needs one definitions root",None,None) }
    else if opaque_kind(document.root.kind) { log.add(Structure,"bpmn/invalid-type","The definitions root has no typed schema representation",None,None) }
  }
  let stack : Array[(Element,Int?,Int,Int,Int?,Bool)] = [(document.root,None,0,1,None,false)]
  while complete && !stack.is_empty() && !log.stopped {
    let (element,parent,child_index,depth,scope,parent_opaque)=stack.pop().unwrap()
    let node=IndexedElement::{ordinal:nodes.length(),element,parent,child_index,children:[],depth,scope,payload:parent_opaque || opaque_kind(element.kind)}
    if depth > limits.depth { log.add(Structure,"bpmn/validation-depth-limit","Validation element depth limit exceeded",Some(node),None); complete=false; break }
    let mut remaining=limits.nodes-records
    for count in [1,element.values.length(),element.bindings.length(),element.contents.length()-element.children.length()] {
      if count > remaining { complete=false; break }; remaining-=count
    }
    if !complete || stack.length() > remaining || element.children.length() > remaining-stack.length() { log.add(Structure,"bpmn/validation-node-limit","Validation node/attribute limit exceeded",Some(node),None); complete=false; break }
    records=limits.nodes-remaining
    if element.kind.local_name().length() > limits.token_units || element.kind.namespace_uri().length() > limits.token_units || element.values.iter().any(a => a.raw_name.length() > limits.token_units || a.value.token().length() > limits.token_units) || element.contents.iter().any(c => match c { Text(s) | Comment(s) => s.length() > limits.token_units; ProcessingInstruction(target~,data~) => target.length() > limits.token_units || data.length() > limits.token_units; _ => false }) || element.bindings.iter().any(b => b.0.length() > limits.token_units || b.1.length() > limits.token_units) {
      log.add(Structure,"bpmn/validation-token-limit","Validation token limit exceeded",Some(node),None); complete=false; break
    }
    nodes.push(node)
    if !node.payload && schema_id(element) is Some(id) {
      match ids.get(id) { Some(found) => { found.push(node.ordinal); log.add(Structure,"bpmn/duplicate-id","Duplicate ID: "+id,Some(node),Some(ExpandedName::new("","id"))) }; None => ids[id]=[node.ordinal] }
    }
    log.structure_node(node)
    let next_scope=if flow_container(element) { Some(node.ordinal) } else { scope }
    for i=element.children.length()-1;i>=0;i=i-1 { stack.push((element.children[i],Some(node.ordinal),i,depth+1,next_scope,node.payload)) }
  }
  if log.stopped { complete=false }
  let child_lists : Array[Array[Int]] = Array::makei(nodes.length(),_ => [])
  for n in nodes { if n.parent is Some(p) { child_lists[p].push(n.ordinal) } }
  for i in 0..<nodes.length() { nodes[i]={..nodes[i],children:ReadOnlyArray::from_array(child_lists[i])} }
  let index=DocumentIndex::{document,nodes:ReadOnlyArray::from_array(nodes),complete,records,ids:@namespaces.HashMap::from_iter(ids.iter().map(pair => (pair.0,ReadOnlyArray::from_array(pair.1))))}
  {index,findings:ReadOnlyArray::from_array(log.findings),complete}
}
