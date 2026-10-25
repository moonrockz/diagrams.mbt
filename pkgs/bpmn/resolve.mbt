///|
fn supplied_resolver(index : DocumentIndex, resources : ResourceSet, log : ValidationLog) -> ReferenceResolver {
  let documents : Array[AvailableDocument] = [{resource_id:log.resource_id,namespace_uri:target_namespace(index.document),index}]
  let external : Array[ExternalResource] = []
  let mut complete=index.complete
  let mut records=index.records
  let original_id=log.resource_id
  let seen_documents : Map[Int,Bool] = Map([])
  let seen_external : Map[Int,Bool] = Map([])
  let locations : Map[String,Array[(Bool,Int)]] = Map([])
  if original_id is Some(key) { locations[key]=[(true,-1)] }
  if index.records > log.limits.nodes {
    log.add(References,"bpmn/resource-limit","The root index exceeds the reference-stage node budget",None,None)
    complete=false
  }
  if resources.documents.length() > log.limits.nodes || resources.external.length() > log.limits.nodes-resources.documents.length() {
    log.add(References,"bpmn/resource-limit","Explicit resource count exceeds the node budget",None,None)
    complete=false
  } else if resources.documents.iter().any(r => r.location.length() > log.limits.token_units) || resources.external.iter().any(r => r.location.length() > log.limits.token_units || r.namespace_uri.length() > log.limits.token_units || r.import_type.length() > log.limits.token_units) {
    log.add(References,"bpmn/validation-token-limit","Explicit resource metadata exceeds the token limit",None,None)
    complete=false
  } else {
    for i in 0..<resources.documents.length() { let key=resources.documents[i].location; if Some(key) == original_id && resources.documents[i].document == index.document { continue }; match locations.get(key) { Some(xs) => xs.push((true,i)); None => locations[key]=[(true,i)] } }
    for i in 0..<resources.external.length() { let key=resources.external[i].location; match locations.get(key) { Some(xs) => xs.push((false,i)); None => locations[key]=[(false,i)] } }
  }
  let mut next=0
  while complete && next < documents.length() && !log.stopped {
    let current=documents[next]; next+=1; log.resource_id=current.resource_id
    for node in current.index.nodes {
      if log.stopped || !complete { break }
      if node.payload || node.parent != Some(0) || current.index.document.root.kind != Definitions || node.element.kind != Import || !typed_element_is(node.element,TypeId::Import) { continue }
      guard node.element.attribute("location") is Some(location) && node.element.attribute("namespace") is Some(namespace_uri) && node.element.attribute("importType") is Some(import_type) else { continue }
      guard locations.get(location) is Some(matches) else {
        log.add(References,"bpmn/unresolved-import","No supplied resource for import location: "+location,Some(node),Some(ExpandedName::new("","location"))); continue
      }
      if matches.length() != 1 { log.add(References,"bpmn/ambiguous-import","Several supplied resources have import location: "+location,Some(node),Some(ExpandedName::new("","location"))); continue }
      let (is_document,i)=matches[0]
      let actual_namespace=if i == -1 { target_namespace(index.document) } else if is_document { target_namespace(resources.documents[i].document) } else { resources.external[i].namespace_uri }
      if actual_namespace != namespace_uri { log.add(References,"bpmn/import-namespace","Import namespace differs from the supplied resource",Some(node),Some(ExpandedName::new("","namespace"))); continue }
      let actual_type=if is_document { model_namespace } else { resources.external[i].import_type }
      if import_type != actual_type { log.add(References,"bpmn/import-type","Import type differs from the supplied resource",Some(node),Some(ExpandedName::new("","importType"))); continue }
      if i == -1 { continue }
      if is_document {
        if seen_documents.contains(i) { continue }; seen_documents[i]=true
        let resource=resources.documents[i]
        if records >= log.limits.nodes { log.add(References,"bpmn/resource-limit","Imported document budget exceeded",Some(node),None); complete=false; break }
        let result=validate_structure(resource.document,resource_id=resource.location,limits={..log.limits,nodes:log.limits.nodes-records})
        records+=result.index.records
        for item in result.findings {
          if log.findings.length() < log.limits.diagnostics { log.findings.push(item) }
          else { log.add(References,"bpmn/resource-limit","Imported finding budget exceeded",Some(node),None); break }
        }
        if !result.complete { complete=false }
        documents.push({resource_id:Some(resource.location),namespace_uri:actual_namespace,index:result.index})
      } else {
        if seen_external.contains(i) { continue }; seen_external[i]=true
        let resource=resources.external[i]
        if resource.symbols.length() >= log.limits.nodes-records { log.add(References,"bpmn/resource-limit","External symbol budget exceeded",Some(node),None); complete=false; break }
        records+=1+resource.symbols.length()
        if resource.symbols.iter().any(s => s.length() > log.limits.token_units) { log.add(References,"bpmn/validation-token-limit","External symbol exceeds the token limit",Some(node),None); complete=false; break }
        if resource.symbols.iter().any(s => !ncname(s)) { log.add(References,"bpmn/invalid-reference","External symbols must be NCNames",Some(node),None); continue }
        external.push(resource)
      }
    }
  }
  log.resource_id=original_id
  make_resolver(documents,external,complete && !log.stopped,log.limits.nodes,log.limits.token_units)
}

///|
fn reference_rule(element : Element, field : SchemaField) -> ReferenceRule? {
  reference_rules.iter().find_first(r => r.owner == field.owner && r.kind == field.kind && Some(r.field) == field.name && typed_element_is(element,field.owner))
}

///|
fn ValidationLog::resolved(self : ValidationLog, source : IndexedElement, field : ExpandedName, value : Reference, target : ReferenceTarget, resolution : ReferenceResolution, attribute : Attribute?) -> Unit {
  let suffix=" on "+source.element.attribute("id").unwrap_or(source.element.kind.local_name())+": "+value.spelling
  match resolution {
    Found(found) => {
      if !reference_target_matches(target,found.node.element) { self.add(References,"bpmn/wrong-reference-kind","Reference target has an incorrect kind"+suffix,Some(source),Some(field),attribute?) }
      if typed_element_is(source.element,TypeId::SequenceFlow) && (found.resource_id != self.resource_id || found.node.scope != source.scope) {
        self.add(References,"bpmn/sequence-flow-scope","Sequence flow crosses a containment scope"+suffix,Some(source),Some(field),attribute?)
      }
      if typed_element_is(source.element,TypeId::BoundaryEvent) && field.local_name == "attachedToRef" && (found.resource_id != self.resource_id || found.node.scope != source.scope || !typed_element_is(found.node.element,TypeId::Activity)) {
        self.add(References,"bpmn/boundary-attachment","Boundary event must attach to an activity in its flow scope"+suffix,Some(source),Some(field),attribute?)
      }
      if field.local_name == "default" && found.resource_id == self.resource_id && typed_element_is(found.node.element,TypeId::SequenceFlow) {
        let flow_source=found.node.element.reference("sourceRef").value()
        if flow_source.map(r => r.name.map(n => n.local_name)) != Some(source.element.attribute("id")) { self.add(References,"bpmn/reference-endpoint","Default flow does not originate at its owner"+suffix,Some(source),Some(field),attribute?) }
      }
      if typed_element_is(source.element,TypeId::Lane) && field.local_name == "flowNodeRef" && (found.resource_id != self.resource_id || found.node.scope != source.scope) {
        self.add(References,"bpmn/reference-endpoint","Lane references a flow node outside its flow scope"+suffix,Some(source),Some(field),attribute?)
      }
      if typed_element_is(source.element,TypeId::FlowNode) && ["incoming","outgoing"].contains(field.local_name) {
        let endpoint=if field.local_name == "incoming" { "targetRef" } else { "sourceRef" }
        if found.resource_id != self.resource_id || found.node.element.reference(endpoint).value().map(r => r.name.map(n => n.local_name)) != Some(source.element.attribute("id")) { self.add(References,"bpmn/reference-endpoint","Flow reference does not name the corresponding endpoint"+suffix,Some(source),Some(field),attribute?) }
      }
    }
    External(_) => if target != External && target != AnyElement { self.add(References,"bpmn/wrong-reference-kind","BPMN reference targets an external-language symbol"+suffix,Some(source),Some(field),attribute?) }
    Ambiguous(_,_) => self.add(References,"bpmn/ambiguous-reference","Reference target is ambiguous"+suffix,Some(source),Some(field),attribute?)
    Unresolved => self.add(References,"bpmn/unresolved-reference","Reference target was not found in the explicit import closure"+suffix,Some(source),Some(field),attribute?)
    Invalid => self.add(References,"bpmn/invalid-reference","Reference has no valid expanded identity"+suffix,Some(source),Some(field),attribute?)
    Limit => self.add(References,"bpmn/resource-limit","Reference lookup has an incomplete resource index"+suffix,Some(source),Some(field),attribute?)
  }
}

///|
/// Resolve declared BPMN references over one document and its explicit imports.
/// Missing imports are findings; they do not invalidate unrelated local lookups.
pub fn resolve_references(index : DocumentIndex, resources? : ResourceSet = ResourceSet::new(), resource_id? : String, limits? : Limits = Limits::new()) -> ReferenceResult {
  let log=ValidationLog::{limits:if valid_limits(limits) { limits } else { Limits::new() },findings:[],resource_id,stopped:false}
  if !valid_limits(limits) { log.add(References,"bpmn/validation-invalid-limits","All validation limits must be positive",None,None) }
  let resolver=if valid_limits(limits) { supplied_resolver(index,resources,log) } else { make_resolver([],[],false,0,0) }
  let references : Array[ResolvedReference] = []
  let mut remaining_work=log.limits.nodes
  let mut complete=resolver.complete
  for source in index.nodes {
    if log.stopped || !complete { break }
    if source.payload || source.element.value_type == None { continue }
    guard schema_type(source.element.value_type.unwrap()) is Some(schema) else { continue }
    for field in schema.fields() {
      if log.stopped || !complete { break }
      guard reference_rule(source.element,field) is Some(rule) else { continue }
      let occurrences : Array[(Reference,Attribute?,IndexedElement)] = []
      if field.kind == Attribute {
        for attribute in source.element.values { if attribute.name == field.name && attribute.value is Reference(value) { occurrences.push((value,Some(attribute),source)) } }
      } else {
        for child_index in source.children {
          let child=index.nodes[child_index]
          if child.payload || Some(child.element.kind.name()) != field.name { continue }
          if child.element.text_value is Some(Reference(value)) { occurrences.push((value,None,child)) }
        }
      }
      for (value,attribute,location_node) in occurrences {
        if log.stopped || !complete { break }
        let (resolution,work)=resolver.lookup_bounded(value,remaining_work)
        remaining_work-=work
        if resolution is Limit { complete=false }
        references.push({source,field:rule.field,value,target:rule.target,resolution})
        // Child text has its own source span but its owner supplies identity.
        let before=log.findings.length()
        log.resolved(source,rule.field,value,rule.target,resolution,attribute)
        if attribute == None && log.findings.length() > before {
          for i in before..<log.findings.length() { let item=log.findings[i]; log.findings[i]={..item,diagnostic:{..item.diagnostic,span:location_node.element.span,location:location_node.element.location()}} }
        }
      }
    }
  }
  {index,references:ReadOnlyArray::from_array(references),findings:ReadOnlyArray::from_array(log.findings),complete:complete && !log.stopped,resolver}
}
