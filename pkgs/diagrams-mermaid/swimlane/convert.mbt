///|
pub struct Conversion { swimlane : @model.Swimlane?; diagnostics : ReadOnlyArray[@diagrams.Diagnostic] } derive(Eq, Debug)
///|
priv struct Scope { id : String; label : String; direction : @model.Direction?; members : Array[String]; expanded : Bool }
///|
fn marker(value : String) -> @model.Marker { match value { "arrow" => Arrow; "circle" => Circle; "cross" => Cross; _ => None } }
///|
fn style(value : String) -> @model.LineStyle { match value { "thick" => Thick; "dotted" => Dotted; "invisible" => Invisible; _ => Solid } }
///|
fn truthy(value : Json) -> Bool {
 match value {
  Null | False => false
  String(value) => value != ""
  Number(value,..) => value != 0.0 && !value.is_nan()
  _ => true
 }
}
///|
pub fn to_swimlane(diagram : @ast.Diagram, limits? : @syntax.Limits = @syntax.Limits::new(), id? : String = "swimlane") -> Conversion {
 let diagnostics=[]; let nodes : Array[@model.Node]=[]; let node_index : Map[String,Int]=Map([]); let scopes : Array[Scope]=[]; let scope_index : Map[String,Int]=Map([]); let scope_order : Array[Int]=[]; let stack : Array[Int]=[]; let member_owner : Map[String,String]=Map([]); let connections : Array[@model.Connection]=[]; let edge_ids : Map[String,Bool]=Map([]); let pair_counts : Map[String,Int]=Map([]); let asset_shapes : Map[String,String]=Map([])
 let mut work=0; let mut failed=false; let mut title : String?=None; let mut accessibility_title : String?=None; let mut accessibility_description : String?=None
 fn error(code : String, message : String, span : @diagrams.Span?) { failed=true; let diagnostic=@diagrams.Diagnostic::error("swimlane/"+code,message,span?); if diagnostics.length() < limits.diagnostics.max(1) { diagnostics.push(diagnostic) } else { diagnostics[diagnostics.length()-1]=diagnostic } }
 fn warning(message : String, span : @diagrams.Span?) { if diagnostics.length() < limits.diagnostics.max(1) { diagnostics.push(@diagrams.Diagnostic::warning("swimlane/presentation-metadata",message,span?)) } }
 fn charge(units : Int) -> Bool { if units < 0 || units > limits.work-work { error("work-limit","Conversion work limit exceeded",None); false } else { work+=units; true } }
 fn node(decl : @ast.NodeDecl) {
  if !charge(1) || failed { return }
  if !charge(decl.id.length()) || !charge(decl.label.map(value => value.length()).unwrap_or(0)) || !charge(decl.shape.map(value => value.length()).unwrap_or(0)) || !charge(decl.metadata.length()) || !charge(decl.classes.length()) { return }
  for data in decl.metadata { if !charge(data.0.length()) || !charge(@ast.canonical_json(data.1,depth_limit=limits.metadata_depth,work_limit=(limits.work-work).max(0)).unwrap_or_else(() => { error("work-limit","Metadata limit exceeded",None); "" }).length()) { return } }
  for name in decl.classes { if !charge(name.length()) { return } }
  if scope_index.get(decl.id) is Some(index) {
   if stack.last() is Some(parent) { scopes[parent].members.push(decl.id) }
   for data in decl.metadata {
    if data.0 == "view" && data.1 == Json("collapsed") { let old=scopes[index]; scopes[index]={..old,expanded:false} }
    else { warning("Subgraph presentation metadata remains source data",None) }
   }
   return
  }
  if edge_ids.contains(decl.id) { warning("Edge presentation metadata remains source data",None); return }
  for data in decl.metadata {
   if data.0 == "shape" && truthy(data.1) {
    match data.1 {
     String(value) => if value.to_array().any(c => (c >= 'A' && c <= 'Z') || c == '_') { error("invalid-ast","Modern shape names must be lowercase without underscores: "+value,None); return }
     _ => { error("invalid-ast","A truthy shape declaration must be a string",None); return }
    }
   }
   if data.0 == "img" && truthy(data.1) { asset_shapes[decl.id]="image" }
   if data.0 == "icon" && truthy(data.1) && asset_shapes.get(decl.id) != Some("image") { asset_shapes[decl.id]="icon" }
  }
  let previous=node_index.get(decl.id)
  if previous == None && nodes.length() >= limits.nodes { error("node-limit","Node limit exceeded",None); return }
  let old=match previous { Some(index) => nodes[index]; None => @model.Node::new(decl.id) }
  let declared_shape=match decl.shape { Some(shape) => shape; None => old.shape }
  let shape=asset_shapes.get(decl.id).unwrap_or(declared_shape)
  let source_label=decl.label.unwrap_or(old.label)
  let label=if asset_shapes.contains(decl.id) && source_label == decl.id && decl.label.map(value => value.trim().is_empty()).unwrap_or(true) { "" } else { source_label }
  let label_kind=if decl.label == None { old.label_kind } else { match decl.label_kind { "markdown" => @model.LabelKind::Markdown; "html" => Html; _ => Text } }
  if !charge(old.metadata.length()) { return }
  let merged=old.metadata.iter().to_array(); let metadata_indices : Map[String,Int]=Map([])
  for index,pair in merged { metadata_indices[pair.0]=index }
  for data in decl.metadata {
   if (data.0 == "img" || data.0 == "icon") && !truthy(data.1) && metadata_indices.contains(data.0) { continue }
   let value=match data.1 { String(value) => value; _ => @ast.canonical_json(data.1,depth_limit=limits.metadata_depth,work_limit=(limits.work-work).max(0)).unwrap_or("") }
   match metadata_indices.get(data.0) { Some(index) => merged[index]=(data.0,value); None => { metadata_indices[data.0]=merged.length(); merged.push((data.0,value)) } }
  }
  let metadata=ReadOnlyArray::from_array(merged[:])
  let value=@model.Node::new(decl.id,label~,shape~,label_kind~,metadata=metadata[:])
  match previous { Some(index) => nodes[index]=value; None => { node_index[decl.id]=nodes.length(); nodes.push(value) } }
  if stack.last() is Some(index) { scopes[index].members.push(decl.id) }
  if !decl.classes.is_empty() { warning("Mermaid classes are retained as source data",None) }
 }
 fn close_scope() {
  if stack.pop() is Some(index) {
   let scope=scopes[index]; let accepted=[]
   for child in scope.members {
    if !charge(1) { break }
    if child != scope.id && !member_owner.contains(child) { member_owner[child]=scope.id; accepted.push(child) }
   }
   match scope_index.get(scope.id) {
    Some(existing) => for child in accepted { scopes[existing].members.push(child) }
    None => {
     if scope_index.length() >= limits.nodes { error("node-limit","Group limit exceeded",None); return }
     scopes[index]={..scope,members:accepted}; scope_index[scope.id]=index; scope_order.push(index)
    }
   }
  }
 }
 let anonymous : Map[Int,String]=Map([]); let open : Array[Int]=[]; let mut subgraph_count=0
 for index,statement in diagram.statements {
  if !charge(1) { break }
  match statement.kind {
   Subgraph(..) => open.push(index)
   End => if open.pop() is Some(start) {
    if diagram.statements[start].kind is Subgraph(id="",..) { anonymous[start]="subGraph"+subgraph_count.to_string() }
    subgraph_count+=1
   }
   _ => ()
  }
 }
 while open.pop() is Some(start) {
  if diagram.statements[start].kind is Subgraph(id="",..) { anonymous[start]="subGraph"+subgraph_count.to_string() }
  subgraph_count+=1
 }
 let direction=match diagram.direction { Some(value) => match @model.direction(value) { Some(direction) => direction; None => { error("direction","Unsupported direction "+value,None); @model.Direction::TB } }; None => @model.Direction::TB }
 if diagram.front_matter != None || !diagram.directives.is_empty() { warning("Mermaid renderer configuration remains source data; explicit library options apply",None) }
 for statement_index,statement in diagram.statements {
  if !charge(1) || failed { break }
  match statement.kind {
   Nodes(decls) => for decl in decls { node(decl) }
   Edges(chain) => {
    if chain.endpoints.is_empty() || chain.links.length() != chain.endpoints.length()-1 { error("invalid-ast","Connection chain has inconsistent endpoints",Some(statement.span)); break }
    for endpoint in chain.endpoints { for decl in endpoint { node(decl) } }
    for i,link in chain.links {
      if !charge(link.label.length()) || !charge(link.id.map(value => value.length()).unwrap_or(0)) { break }
      let sources=chain.endpoints[i]; let targets=chain.endpoints[i+1]
      if sources.length() > 0 && targets.length() > (limits.edges-connections.length())/sources.length() { error("edge-limit","Expanded connection limit exceeded",Some(statement.span)); break }
      for source_index,source in sources { for target_index,target in targets {
       if !charge(1) { break }
       let pair_key=source.id.length().to_string()+":"+source.id+target.id.length().to_string()+":"+target.id
       let count=pair_counts.get(pair_key).unwrap_or(0)
       let generated="L_"+source.id+"_"+target.id+"_"+(if count == 0 { 0 } else { count+1 }).to_string()
       let edge_id=match link.id { Some(name) if source_index == sources.length()-1 && target_index == 0 && !edge_ids.contains(name) => name; _ => generated }
       pair_counts[pair_key]=count+1
       edge_ids[edge_id]=true
       connections.push(@model.Connection::new(edge_id,source.id,target.id,label=link.label,label_kind=(match link.label_kind { "markdown" => @model.LabelKind::Markdown; "html" => Html; _ => Text }),style=style(link.style),source_marker=marker(link.source_marker),target_marker=marker(link.target_marker),min_length=link.length.min(10)))
      } }
    }
   }
   Subgraph(id~,label~) => {
    if !charge(id.length()) || !charge(label.length()) { error("node-limit","Group limit exceeded",Some(statement.span)); break }
    let id=if id == "" { anonymous.get(statement_index).unwrap_or("subGraph"+statement_index.to_string()) } else { id }
    if stack.length() >= limits.depth { error("depth-limit","Subgraph depth limit exceeded",Some(statement.span)); break }
    let index=scopes.length()
    scopes.push({id,label,direction:None,members:[],expanded:true})
    if stack.last() is Some(parent) { scopes[parent].members.push(id) }
    stack.push(index)
   }
   End => close_scope()
   Direction(value) => {
    match @model.direction(value) {
     Some(direction) => if stack.last() is Some(index) { let old=scopes[index]; scopes[index]={..old,direction:Some(direction)} }
     None => error("direction","Unsupported local direction "+value,Some(statement.span))
    }
   }
   Title(value) => title=Some(value)
   AccTitle(value) => accessibility_title=Some(value)
   AccDescription(value) => accessibility_description=Some(value)
   Metadata(keyword~,text~) => {
    if !charge(text.length()) { break }
    if keyword == "style" {
     let mut end=0
     while end < text.length() && !@syntax.is_space(text.at(end).to_int()) { end+=1 }
     if end > 0 {
      let old_stack=stack.iter().to_array(); stack.clear()
      node({id:text[:end].to_owned(),label:None,label_kind:"text",shape:None,metadata:[],classes:[],spelling:""})
      for index in old_stack { stack.push(index) }
     }
    }
    warning("Mermaid "+keyword+" behavior is retained as source data and is not applied",Some(statement.span))
   }
   Comment(_) => ()
  }
 }
 while !stack.is_empty() { close_scope() }
 let lanes=[]; let groups=[]
 fn ancestry(id : String) -> (String?,Array[String]) {
  let path=[]; let mut cursor=Some(id); let mut lane : String?=None; let seen : Map[String,Bool]=Map([])
  while cursor is Some(current) {
   if !charge(1) || seen.contains(current) || path.length() > limits.depth { error("ownership-cycle","Invalid group ancestry "+current,None); break }; seen[current]=true
   match scope_index.get(current) {
    Some(index) => { let scope=scopes[index]; if member_owner.get(scope.id) == None { lane=Some(scope.id); cursor=None } else { path.push(scope.id); cursor=member_owner.get(scope.id) } }
    None => { error("ownership","Missing group "+current,None); break }
   }
  }
  let ordered=[]; for i=path.length()-1; i>=0; i=i-1 { ordered.push(path[i]) }; (lane,ordered)
 }
 for index in scope_order {
  let scope=scopes[index]; let parent=member_owner.get(scope.id)
  if parent == None { lanes.push(@model.Lane::new(scope.id,label=scope.label,direction?=scope.direction,expanded=scope.expanded)) }
  else {
   let (lane,_)=ancestry(scope.id)
   groups.push(@model.Group::new(scope.id,label=scope.label,parent?=parent.filter(parent => member_owner.get(parent) != None),lane?,direction?=scope.direction,expanded=scope.expanded))
  }
 }
 let final_nodes=[]
 for node in nodes {
  if scope_index.contains(node.id) { continue }
  let (lane,path)=match member_owner.get(node.id) { Some(owner) => ancestry(owner); None => (None,[]) }
  final_nodes.push(@model.Node::new(node.id,label=node.label,label_kind=node.label_kind,shape=node.shape,metadata=node.metadata[:],lane?,groups=path[:],properties?=node.properties))
 }
 let model=@model.Swimlane::new(id,final_nodes[:],connections[:],direction~,lanes=lanes[:],groups=groups[:],title?,accessibility_title?,accessibility_description?)
 let validation=@model.validate(model,nodes_limit=limits.nodes,edges_limit=limits.edges,depth_limit=limits.metadata_depth,work_limit=(limits.work-work).max(0))
 for finding in validation { if diagnostics.length() < limits.diagnostics.max(1) { diagnostics.push(finding) }; failed=true }
 {swimlane:if failed { None } else { Some(model) },diagnostics:ReadOnlyArray::from_array(diagnostics[:])}
}
///|
pub extend Conversion with Eq::{equal,not_equal}
///|
pub extend Conversion with @debug.Debug::{to_repr}
///|
/// Stable conversion findings. Model validation findings are listed separately
/// by diagrams/swimlane.
pub let diagnostic_codes : ReadOnlyArray[String] = ["swimlane/work-limit","swimlane/node-limit","swimlane/edge-limit","swimlane/depth-limit","swimlane/direction","swimlane/ownership-cycle","swimlane/ownership","swimlane/invalid-ast","swimlane/presentation-metadata"]
