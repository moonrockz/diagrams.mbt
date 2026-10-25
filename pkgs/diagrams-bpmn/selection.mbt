///|
pub(all) enum ViewSelector { Automatic; Process(String); Collaboration(String); Plane(String); View(String) } derive(Eq, Debug)

///|
pub extend ViewSelector with Eq::{equal,not_equal}

///|
pub extend ViewSelector with @debug.Debug::{to_repr}

///|
priv struct Source { id : String?; index : @bpmn.DocumentIndex; references : @bpmn.ReferenceResult; findings : ReadOnlyArray[@bpmn.ValidationFinding]; fields : Map[(Int,String),Array[@bpmn.ResolvedReference]] }

///|
priv struct Selected { resource : Int; node : Int; plane : Int? }

///|
priv struct Converter {
  ignore_di : Bool; sources : Array[Source]; dependencies : Map[(Int,Int),Bool]; resources : @bpmn.ResourceSet; limits : @bpmn.Limits
  diagnostics : Array[@diagrams.Diagnostic]; mut failed : Bool; mut work : Int
}

///|
fn actual(e : @bpmn.Element) -> @bpmn.TypeId? {
  if e.kind is Foreign(_) || e.kind is Unknown(_) { return None }
  e.value_type.bind(@bpmn.schema_type).map(t => t.id)
}

///|
fn is_type(e : @bpmn.Element, t : @bpmn.TypeId) -> Bool {
  if actual(e) == None { return false }
  e.value_type.bind(@bpmn.schema_type).map(v => v.is_subtype_of(t.name())).unwrap_or(false)
}

///|
fn mapped_location(location : @bpmn.Location?) -> @diagrams.Span? {
  location.map(l => @diagrams.Span::{start:{offset:l.start.offset,line:l.start.line,column:l.start.column},end:{offset:l.end.offset,line:l.end.line,column:l.end.column}})
}

///|
/// Public mapping retains code, severity and half-open UTF-16 source positions.
pub fn map_diagnostic(d : @bpmn.Diagnostic) -> @diagrams.Diagnostic {
  {code:d.code,severity:if d.severity == Error { Error } else { Warning },message:d.message,span:mapped_location(d.location)}
}

///|
fn Converter::add(self : Converter, code : String, message : String, e? : @bpmn.Element, warning? : Bool = false) -> Unit {
  if self.diagnostics.length() >= self.limits.diagnostics {
    self.diagnostics[self.limits.diagnostics-1]=@diagrams.Diagnostic::error("bpmn/conversion-limit","Conversion diagnostic limit exceeded")
    self.failed=true; return
  }
  self.diagnostics.push({code,severity:if warning { Warning } else { Error },message,span:mapped_location(e.bind(e => e.location()))})
  if !warning { self.failed=true }
}

///|
fn Converter::charge(self : Converter, count : Int) -> Bool {
  if count < 0 || count > self.limits.nodes-self.work { self.add("bpmn/conversion-limit","View conversion exceeded its node/work budget"); return false }
  self.work+=count; true
}

///|
fn reference_fields(references : @bpmn.ReferenceResult) -> Map[(Int,String),Array[@bpmn.ResolvedReference]] {
  let fields : Map[(Int,String),Array[@bpmn.ResolvedReference]]=Map([])
  for reference in references.references {
    let key=(reference.source.ordinal,reference.field.local_name)
    match fields.get(key) { Some(values) => values.push(reference); None => fields[key]=[reference] }
  }
  fields
}

///|
fn make_source(document : @bpmn.Document, id : String?, resources : @bpmn.ResourceSet, limits : @bpmn.Limits) -> Source {
  let structure=@bpmn.validate_structure(document,resource_id?=id,limits~)
  let references=@bpmn.resolve_references(structure.index,resources~,resource_id?=id,limits~)
  {id,index:structure.index,references,fields:reference_fields(references),findings:ReadOnlyArray::from_array(structure.findings.iter().concat(references.findings.iter()).to_array())}
}

///|
fn Converter::source_for(self : Converter, resolved : @bpmn.ResolvedElement) -> (Int,Int)? {
  if self.sources[0].id == resolved.resource_id { return Some((0,resolved.node.ordinal)) }
  for i,s in self.sources { if s.id == resolved.resource_id { return Some((i,resolved.node.ordinal)) } }
  guard resolved.resource_id is Some(id) else { self.add("bpmn/invalid-reference","Resolved resource has no caller identity"); return None }
  let available=self.sources[0].references.indexed_resources()
  let candidates=available.filter(d => d.resource_id == Some(id))
  guard candidates.length() == 1 else { self.add("bpmn/invalid-reference","Imported view resource is missing or ambiguous"); return None }
  // Each imported process resolves against its own closure. Charge an upper
  // estimate before rebuilding it, reusing the already validated source index.
  if !self.charge(available.length()+self.resources.documents.length()+self.resources.external.length()) { return None }
  for resource in available { if !self.charge(resource.records) { return None } }
  let index=candidates[0].index
  let references=@bpmn.resolve_references(index,resources=self.resources,resource_id=id,limits=self.limits)
  if !references.complete { self.add("bpmn/conversion-limit","Imported reference processing did not complete"); return None }
  let structure_findings=self.sources[0].references.findings.filter(f => f.stage == Structure && f.resource_id == Some(id))
  let source=Source::{id:Some(id),index,references,fields:reference_fields(references),findings:ReadOnlyArray::from_array(structure_findings.iter().concat(references.findings.iter()).to_array())}
  self.sources.push(source); Some((self.sources.length()-1,resolved.node.ordinal))
}

///|
fn Converter::resolve_field(self : Converter, resource : Int, ordinal : Int, field : String) -> Array[(Int,Int)] {
  let source=self.sources[resource]
  let out=[]
  let references=source.fields.get((ordinal,field)).unwrap_or([])
  if !self.charge(references.length()+1) { return out }
  for reference in references {
    match reference.resolution {
      Found(target) => if self.source_for(target) is Some(key) {
        out.push(key)
        if ["calledElement","dataObjectRef","dataStoreRef","categoryValueRef","eventDefinitionRef","labelStyle"].contains(field) {
          let known=self.dependencies.contains(key)
          self.dependencies[key]=true
          if field != "calledElement" && !known {
            let index=self.sources[key.0].index
            if self.charge(index.nodes.length()) {
              let members=Map([(key.1,true)])
              for n in index.nodes { if n.parent.map(p => members.contains(p)).unwrap_or(false) { members[n.ordinal]=true; self.dependencies[(key.0,n.ordinal)]=true } }
            }
          }
        }
      }
      _ => self.add("bpmn/invalid-reference","Selected \{field} reference is unresolved or ambiguous",e=source.index.nodes[ordinal].element)
    }
  }
  out
}

///|
fn Converter::identity(self : Converter, resource : Int, ordinal : Int) -> @model.SourceIdentity {
  let source=self.sources[resource]
  let node=source.index.nodes[ordinal]
  let reversed=[]
  let mut current=Some(ordinal)
  while current is Some(i) { if !self.charge(1) { break }; let n=source.index.nodes[i]; reversed.push(n.child_index); current=n.parent }
  let path=[]
  for i=reversed.length()-1; i>=0; i=i-1 { path.push(reversed[i]) }
  @model.SourceIdentity::new(source_id?=node.element.attribute("id"),resource_id?=source.id,path~)
}

///|
fn Converter::render_id(self : Converter, resource : Int, ordinal : Int, instance : String) -> String {
  let identity=self.identity(resource,ordinal)
  let suffix=identity.source_id.unwrap_or_else(() => "path-"+identity.path.iter().map(i => i.to_string()).join("-"))
  if resource == 0 && instance == "" && identity.source_id != None { return suffix }
  // Length-prefixed segments cannot collide with authored IDs or each other.
  if instance.length() > self.limits.token_units-64 || suffix.length() > self.limits.token_units-64-instance.length() { self.add("bpmn/conversion-limit","Generated identity exceeded the token budget"); return "" }
  "@bpmn:\{resource}:\{instance.length()}:\{instance}:\{suffix.length()}:\{suffix}"
}

///|
fn Converter::plane_target(self : Converter, plane : Int) -> (Int,Int)? {
  let targets=self.resolve_field(0,plane,"bpmnElement")
  if targets.length() == 1 {
    let key=targets[0]; let e=self.sources[key.0].index.nodes[key.1].element
    if actual(e) == Some(Process) || is_type(e,SubProcess) || is_type(e,Collaboration) { Some(key) }
    else { self.add("bpmn/invalid-reference","Selected plane does not reference a supported view container",e~); None }
  } else { self.add("bpmn/invalid-reference","Selected plane must identify exactly one view",e=self.sources[0].index.nodes[plane].element); None }
}

///|
fn Converter::select(self : Converter, selector : ViewSelector) -> Selected? {
  let index=self.sources[0].index
  let planes=index.nodes.filter(n => actual(n.element) == Some(BpmnBPMNPlane))
  let roots=index.nodes.filter(n => n.parent == Some(0))
  let candidates : Array[Int]=[]
  match selector {
    Automatic => {
      if !planes.is_empty() { for n in planes { candidates.push(n.ordinal) } }
      else {
        for n in roots { if is_type(n.element,Collaboration) { candidates.push(n.ordinal) } }
        if candidates.is_empty() { for n in roots { if actual(n.element) == Some(Process) { candidates.push(n.ordinal) } } }
      }
    }
    Plane(id) => for n in planes {
      if n.element.attribute("id") == Some(id) || n.parent.bind(p => index.nodes[p].element.attribute("id")) == Some(id) { candidates.push(n.ordinal) }
    }
    Process(id) | Collaboration(id) | View(id) => {
      for n in index.nodes { if n.element.attribute("id") == Some(id) && !n.payload { candidates.push(n.ordinal) } }
    }
  }
  if candidates.is_empty() {
    match selector { Plane(id) => if index.nodes.iter().any(n => actual(n.element) == Some(BpmnBPMNDiagram) && n.element.attribute("id") == Some(id)) { self.add("bpmn/missing-plane","Selected diagram contains no plane"); return None }; _ => () }
    self.add("bpmn/view-not-found","No view matches the selector"); return None
  }
  if candidates.length() != 1 {
    let identities=candidates.map(i => index.nodes[i].element.attribute("id").unwrap_or("path:\{i}")).join(", ")
    self.add("bpmn/ambiguous-view","Select one view from: \{identities}"); return None
  }
  let chosen=candidates[0]
  let e=index.nodes[chosen].element
  if actual(e) == Some(BpmnBPMNDiagram) {
    let children=index.nodes[chosen].children.filter(i => actual(index.nodes[i].element) == Some(BpmnBPMNPlane))
    if children.length() != 1 { self.add("bpmn/missing-plane","Selected diagram must contain one plane",e~); return None }
    return self.plane_target(children[0]).map(key => Selected::{resource:key.0,node:key.1,plane:Some(children[0])})
  }
  if actual(e) == Some(BpmnBPMNPlane) { return self.plane_target(chosen).map(key => Selected::{resource:key.0,node:key.1,plane:Some(chosen)}) }
  match selector {
    Process(_) if actual(e) != Some(Process) => { self.add("bpmn/unsupported-view","Selected identity is not a process",e~); return None }
    Collaboration(_) if actual(e) != Some(Collaboration) => { self.add("bpmn/unsupported-view","Selected identity is not a supported collaboration",e~); return None }
    _ => ()
  }
  if self.ignore_di { return Some({resource:0,node:chosen,plane:None}) }
  let matching=[]
  for p in planes {
    let references=self.sources[0].references.references.filter(r => r.source.ordinal == p.ordinal && r.field.local_name == "bpmnElement")
    if references.length() == 1 && references[0].resolution is Found(target) && target.resource_id == self.sources[0].id && target.node.ordinal == chosen { matching.push(p.ordinal) }
  }
  if matching.length() > 1 { self.add("bpmn/ambiguous-plane","Multiple planes depict the selected view; select a plane explicitly",e~); return None }
  Some({resource:0,node:chosen,plane:matching.get(0)})
}
