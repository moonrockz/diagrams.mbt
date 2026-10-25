///|
priv struct GraphBuilder {
  limits : GraphLimits
  nodes : Array[GraphNode]
  edges : Array[GraphEdge]
  trees : Array[DocumentTree]
  offsets : Array[Int]
  element_targets : Map[(String,Int),Int]
  local_ids : Map[String,Array[Int]]
  qualified_ids : Map[(String,String),Array[Int]]
  symbols : Map[(String,String,String),Array[Int]]
  outgoing : Map[(Int,Int),Array[GraphArc]]
  incoming : Map[(Int,Int),Array[GraphArc]]
  diagnostics : Array[Diagnostic]
  mut slots : Int
  mut work : Int
  mut serial : Int
  mut stopped : Bool
}

///|
fn resource_key(resource_id : String?) -> String { match resource_id { None => "root"; Some(id) => "resource:"+id } }

///|
fn GraphBuilder::fail(self : GraphBuilder, code : String, message : String, owner : NodeRef?) -> Unit {
  if !self.stopped {
    self.diagnostics.push({code,severity:Error,message,span:owner.map(n => n.span()).unwrap_or(None),location:owner.map(n => n.location()).unwrap_or(None)})
  }
  self.stopped=true
}

///|
fn GraphBuilder::charge(self : GraphBuilder, work : Int) -> Bool {
  if work > self.limits.work-self.work { self.fail("bpmn/graph-work-limit","Graph construction work limit exceeded",None); return false }
  self.work+=work; true
}

///|
fn GraphBuilder::arc(self : GraphBuilder, source : Int, kind : GraphEdgeKind, arc : GraphArc, outgoing : Bool) -> Unit {
  if self.stopped { return }
  if self.slots >= self.limits.edges { self.fail("bpmn/graph-edge-limit","Graph adjacency entry limit exceeded",None); return }
  self.slots+=1
  let map=if outgoing { self.outgoing } else { self.incoming }
  let key=(source,kind.tag())
  match map.get(key) { Some(arcs) => arcs.push(arc); None => map[key]=[arc] }
}

///|
fn GraphBuilder::edge(self : GraphBuilder, kind : GraphEdgeKind, source : Int, target : Int, owner : NodeRef?, order : Int) -> Unit {
  if self.stopped { return }
  if self.limits.edges-self.slots < 2 { self.fail("bpmn/graph-edge-limit","Graph adjacency entry limit exceeded",owner); return }
  let edge=self.edges.length(); let serial=self.serial; self.serial+=1
  self.edges.push({kind,source:self.nodes[source],target:self.nodes[target],connection:owner})
  self.arc(source,kind,{neighbor:Some(target),edge:Some(edge),failure:None,order,serial},true)
  self.arc(target,kind,{neighbor:Some(source),edge:Some(edge),failure:None,order,serial},false)
}

///|
fn GraphBuilder::broken(self : GraphBuilder, kind : GraphEdgeKind, sources : ArrayView[Int], targets : ArrayView[Int], failure : GraphFailure, order : Int) -> Unit {
  for source in sources { if self.stopped { return }; let serial=self.serial; self.serial+=1; self.arc(source,kind,{neighbor:None,edge:None,failure:Some(failure),order,serial},true) }
  for target in targets { if self.stopped { return }; let serial=self.serial; self.serial+=1; self.arc(target,kind,{neighbor:None,edge:None,failure:Some(failure),order,serial},false) }
}

///|
fn GraphBuilder::include_document(self : GraphBuilder, resource : AvailableDocument, limits : Limits) -> Unit {
  if self.stopped { return }
  let result=build_tree(resource.index.document,resource.resource_id,limits,self.limits.nodes-self.nodes.length())
  guard result.tree is Some(tree) else { self.diagnostics.append(result.diagnostics); self.stopped=true; return }
  let offset=self.nodes.length(); self.offsets.push(offset); self.trees.push(tree)
  for i in 0..<tree.records.length() { self.nodes.push(Document({tree,ordinal:i})) }
  for node in resource.index.nodes {
    let node_ref=tree.element_node(node.ordinal).unwrap(); let global=offset+node_ref.ordinal
    self.element_targets[(resource_key(resource.resource_id),node.ordinal)]=global
    if !node.payload && schema_id(node.element) is Some(id) {
      if self.trees.length() == 1 { match self.local_ids.get(id) { Some(xs) => xs.push(global); None => self.local_ids[id]=[global] } }
      let key=(resource.namespace_uri,id)
      match self.qualified_ids.get(key) { Some(xs) => xs.push(global); None => self.qualified_ids[key]=[global] }
    }
  }
  for i in 0..<tree.records.length() { if self.stopped { return }; for child in tree.records[i].children { if self.stopped { return }; self.edge(Containment,offset+i,offset+child,None,offset+i) } }
}

///|
fn GraphBuilder::candidates(self : GraphBuilder, resolution : ReferenceResolution) -> Array[Int] {
  let found : Array[Int] = []
  let seen : Map[Int,Bool] = Map([])
  fn add(i : Int) -> Unit { if !seen.contains(i) { seen[i]=true; found.push(i) } }
  fn element(value : ResolvedElement) -> Unit { if self.element_targets.get((resource_key(value.resource_id),value.node.ordinal)) is Some(i) { add(i) } }
  fn symbol(value : ResolvedSymbol) -> Unit { if self.symbols.get((value.resource_id,value.name.namespace_uri,value.name.local_name)) is Some(xs) { for i in xs { add(i) } } }
  match resolution {
    Found(value) => element(value)
    External(value) => symbol(value)
    Ambiguous(elements,symbols) => { for value in elements { element(value) }; for value in symbols { symbol(value) } }
    _ => ()
  }
  found
}

///|
fn GraphBuilder::reference_failure(self : GraphBuilder, result : ReferenceResult, reference : ResolvedReference, owner : NodeRef, candidates : ArrayView[Int]) -> GraphFailure? {
  match reference.resolution {
    Ambiguous(_,_) => Some(Ambiguous(ReadOnlyArray::from_array(candidates.map(i => self.nodes[i]))))
    Found(_) | External(_) => if candidates.length() != 1 || result.findings.iter().any(f => f.node == Some(reference.source.ordinal) && f.field == Some(reference.field) && f.stage == References && f.resource_id == owner.tree.revision.resource_id) { Some(InvalidReference(owner.handle())) } else { None }
    Limit => Some(Limit(Work))
    _ => Some(InvalidReference(owner.handle()))
  }
}

///|
fn connection_kind(element : Element) -> GraphEdgeKind? {
  for (t,kind) in [(TypeId::SequenceFlow,GraphEdgeKind::SequenceFlow),(MessageFlow,MessageFlow),(Association,Association),(DataAssociation,DataAssociation),(ConversationLink,ConversationLink)] { if typed_element_is(element,t) { return Some(kind) } }
  None
}

///|
fn GraphBuilder::references(self : GraphBuilder, result : ReferenceResult, tree_index : Int, structure_findings : ReadOnlyArray[ValidationFinding]) -> Unit {
  let tree=self.trees[tree_index]; let offset=self.offsets[tree_index]
  let grouped : Map[Int,Array[ResolvedReference]] = Map([])
  for reference in result.references { match grouped.get(reference.source.ordinal) { Some(xs) => xs.push(reference); None => grouped[reference.source.ordinal]=[reference] } }
  for source in result.index.nodes {
    if self.stopped { break }
    if source.payload { continue }
    let owner=tree.element_node(source.ordinal).unwrap(); let owner_id=offset+owner.ordinal
    let refs=grouped.get(source.ordinal).unwrap_or([])
    for reference in refs {
      if self.stopped { return }
      let candidates=self.candidates(reference.resolution)
      if !self.charge(1) || !self.charge(candidates.length()) { return }
      match self.reference_failure(result,reference,owner,candidates) {
        Some(failure) => self.broken(Reference,[owner_id],candidates,failure,owner_id)
        None => self.edge(Reference,owner_id,candidates[0],Some(owner),owner_id)
      }
    }
    for finding in structure_findings {
      if self.stopped { return }
      if finding.node != Some(source.ordinal) || finding.field == None || refs.iter().any(r => Some(r.field) == finding.field) { continue }
      if source.element.value_type is Some(t) && schema_type(t) is Some(schema) && schema.fields().iter().any(f => f.name == finding.field && reference_rule(source.element,f) != None) { self.broken(Reference,[owner_id],[],InvalidReference(owner.handle()),owner_id) }
    }
    guard connection_kind(source.element) is Some(kind) else { continue }
    let sources=refs.filter(r => r.field.local_name == "sourceRef")
    let targets=refs.filter(r => r.field.local_name == "targetRef")
    let source_nodes : Array[Int] = []; let target_nodes : Array[Int] = []
    let mut failure : GraphFailure? = None
    for reference in sources { let candidates=self.candidates(reference.resolution); source_nodes.append(candidates); if failure == None { failure=self.reference_failure(result,reference,owner,candidates) } }
    for reference in targets { let candidates=self.candidates(reference.resolution); target_nodes.append(candidates); if failure == None { failure=self.reference_failure(result,reference,owner,candidates) } }
    // Source-less assignment associations are valid model data. Their target
    // remains a general reference; no graphical source is invented.
    if kind == DataAssociation && sources.is_empty() && targets.length() == 1 && failure == None { continue }
    if targets.length() != 1 || (kind != DataAssociation && sources.length() != 1) || (kind == SequenceFlow && source.scope == None) { failure=Some(InvalidReference(owner.handle())) }
    match failure {
      Some(failure) => self.broken(kind,if source_nodes.is_empty() { [owner_id] } else { source_nodes },if target_nodes.is_empty() { [owner_id] } else { target_nodes },failure,owner_id)
      None => for node in source_nodes { self.edge(kind,node,target_nodes[0],Some(owner),owner_id) }
    }
  }
}

///|
fn augment_resources(document : Document, resource_id : String?, resources : ResourceSet) -> ResourceSet {
  guard resource_id is Some(id) else { return resources }
  let documents=[DocumentResource::new(id,document)]
  for resource in resources.documents { if resource.location != id || resource.document != document { documents.push(resource) } }
  ResourceSet::new(documents~,external=resources.external)
}

///|
fn ordered_arcs(map : Map[(Int,Int),Array[GraphArc]]) -> @namespaces.HashMap[(Int,Int),ReadOnlyArray[GraphArc]] {
  @namespaces.HashMap::from_iter(map.iter().map(pair => {
    let arcs=pair.1
    arcs.sort_by((a,b) => if a.order == b.order { a.serial.compare(b.serial) } else { a.order.compare(b.order) })
    (pair.0,ReadOnlyArray::from_array(arcs))
  }))
}

///|
fn graph_findings(groups : ArrayView[ReadOnlyArray[ValidationFinding]], maximum : Int) -> (ReadOnlyArray[ValidationFinding],Bool) {
  let seen : Map[(String,Int,String),Array[ValidationFinding]] = Map([])
  let unique : Array[ValidationFinding] = []
  for group in groups { for finding in group {
    let key=(resource_key(finding.resource_id),finding.node.unwrap_or(-1),finding.diagnostic.code)
    let bucket=seen.get(key).unwrap_or([])
    if bucket.contains(finding) { continue }
    if unique.length() >= maximum { return combined_findings([ReadOnlyArray::from_array(unique),[finding]],maximum) }
    bucket.push(finding); seen[key]=bucket; unique.push(finding)
  } }
  (ReadOnlyArray::from_array(unique),true)
}

///|
/// Index the document and its explicit resource closure once. Semantic findings
/// coexist with a graph; a query fails when it encounters an invalid selected
/// reference. Processing exhaustion never exposes an apparently complete graph.
pub fn DocumentGraph::new(document : Document, resources? : ResourceSet = ResourceSet::new(), resource_id? : String, limits? : Limits = Limits::new(), graph_limits? : GraphLimits = GraphLimits::new()) -> GraphBuildResult {
  if !valid_limits(limits) || !graph_limits.valid() { return {graph:None,diagnostics:[finding("bpmn/graph-invalid-limits","All graph and document limits must be positive")]} }
  let bounded={..limits,nodes:if limits.nodes < graph_limits.work { limits.nodes } else { graph_limits.work }}
  let root=validate_structure(document,resource_id?,limits=bounded)
  if !root.complete { return {graph:None,diagnostics:root.findings.map(f => f.diagnostic)} }
  let resolved=resolve_references(root.index,resources~,resource_id?,limits=bounded)
  if !resolved.complete { return {graph:None,diagnostics:resolved.findings.map(f => f.diagnostic)} }
  let builder=GraphBuilder::{limits:graph_limits,nodes:[],edges:[],trees:[],offsets:[],element_targets:Map([]),local_ids:Map([]),qualified_ids:Map([]),symbols:Map([]),outgoing:Map([]),incoming:Map([]),diagnostics:[],slots:0,work:0,serial:0,stopped:false}
  let available=resolved.resolver.documents
  let mut resource_records=0
  for resource in available {
    if !builder.charge(resource.index.records) { break }
    resource_records+=resource.index.records
    builder.include_document(resource,bounded)
  }
  for resource in resolved.resolver.external_resources {
    if builder.stopped { break }
    if !builder.charge(resource.symbols.length()) { break }
    if resource.symbols.length() > graph_limits.nodes-builder.nodes.length() { builder.fail("bpmn/graph-node-limit","External graph node limit exceeded",None); break }
    for i in 0..<resource.symbols.length() {
      let name=ExpandedName::new(resource.namespace_uri,resource.symbols[i])
      let symbol=ResolvedSymbol::{resource_id:resource.location,name}
      let index=builder.nodes.length()
      builder.nodes.push(External({symbol,occurrence:i}))
      let qualified=(name.namespace_uri,name.local_name)
      match builder.qualified_ids.get(qualified) { Some(xs) => xs.push(index); None => builder.qualified_ids[qualified]=[index] }
      let key=(resource.location,name.namespace_uri,name.local_name)
      match builder.symbols.get(key) { Some(xs) => xs.push(index); None => builder.symbols[key]=[index] }
    }
  }
  if builder.stopped { return {graph:None,diagnostics:ReadOnlyArray::from_array(builder.diagnostics)} }
  let augmented=augment_resources(document,resource_id,resources)
  let finding_groups=[root.findings,resolved.findings]
  for i in 0..<available.length() {
    if builder.stopped { break }
    let resource=available[i]
    // Re-resolving from an imported document uses that document's own import
    // closure. Charge a bounded upper estimate before rebuilding its resolver.
    if i > 0 && (!builder.charge(resource_records) || !builder.charge(augmented.documents.length()) || !builder.charge(augmented.external.length())) { break }
    let references=if i == 0 { resolved } else { resolve_references(resource.index,resources=augmented,resource_id?=resource.resource_id,limits=bounded) }
    if !references.complete { builder.fail("bpmn/graph-work-limit","Imported reference processing did not complete",None); break }
    if i > 0 { finding_groups.push(references.findings) }
    let structure_findings=if i == 0 { root.findings } else { ReadOnlyArray::from_array(resolved.findings.iter().filter(f => f.stage == Structure && f.resource_id == resource.resource_id).to_array()) }
    builder.references(references,i,structure_findings)
  }
  if builder.stopped { return {graph:None,diagnostics:ReadOnlyArray::from_array(builder.diagnostics)} }
  let graph=DocumentGraph::{nodes:ReadOnlyArray::from_array(builder.nodes),edges:ReadOnlyArray::from_array(builder.edges),trees:ReadOnlyArray::from_array(builder.trees),offsets:ReadOnlyArray::from_array(builder.offsets),local_ids:@namespaces.HashMap::from_iter(builder.local_ids.iter().map(p => (p.0,ReadOnlyArray::from_array(p.1)))),qualified_ids:@namespaces.HashMap::from_iter(builder.qualified_ids.iter().map(p => (p.0,ReadOnlyArray::from_array(p.1)))),symbols:@namespaces.HashMap::from_iter(builder.symbols.iter().map(p => (p.0,ReadOnlyArray::from_array(p.1)))),outgoing:ordered_arcs(builder.outgoing),incoming:ordered_arcs(builder.incoming)}
  let (findings,complete)=graph_findings(finding_groups,limits.diagnostics)
  {graph:if complete { Some(graph) } else { None },diagnostics:findings.map(f => f.diagnostic)}
}
