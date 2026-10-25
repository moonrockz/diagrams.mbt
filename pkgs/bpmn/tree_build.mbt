///|
priv struct PendingNode { value : NodeValue; parent : Int?; step : PathStep?; depth : Int; span : Span?; origin : SourceOrigin?; semantic : Bool }

///|
priv struct BuildingNode { value : NodeValue; parent : Int?; step : PathStep?; depth : Int; span : Span?; origin : SourceOrigin?; element_ordinal : Int?; children : Array[Int] }

///|
fn content_value(content : Content) -> NodeValue {
  match content { Element(e) => Element(e); Text(s) => Text(s); Comment(s) => Comment(s); ProcessingInstruction(target~,data~) => ProcessingInstruction(target~,data~) }
}

///|
fn content_field(parent : Element, content : Content) -> PathField {
  match content {
    Text(_) => Text; Comment(_) => Comment; ProcessingInstruction(..) => ProcessingInstruction
    Element(child) => {
      if parent.value_type is Some(name) && schema_type(name) is Some(schema) {
        for field in schema.fields() { if field_matches(field,child,schema.name) && field.name is Some(name) { return Named(name) } }
      }
      Named(child.kind.name())
    }
  }
}

///|
/// Build an index without requiring a semantically valid document or resolving
/// references. The arena contains document, element, text, comment and PI nodes.
/// It shares the original immutable document values.
fn build_tree(document : Document, resource_id : String?, limits : Limits, node_budget : Int) -> TreeBuildResult {
  fn failed(code : String, message : String, node : PendingNode?) -> TreeBuildResult {
    let span=node.map(n => n.span).unwrap_or(None)
    let map=node.map(n => n.origin.map(o => o.map)).unwrap_or(None)
    {tree:None,diagnostics:[finding(code,message,span?,map?)]}
  }
  if !valid_limits(limits) { return failed("bpmn/traversal-invalid-limits","All traversal limits must be positive",None) }
  let stack : Array[PendingNode] = [{value:Document,parent:None,step:None,depth:0,span:document.origin.map(o => Span::{start:0,end:o.source.length()}),origin:document.origin,semantic:false}]
  let nodes : Array[BuildingNode] = []
  let elements : Array[Int] = []
  let mut records=0
  while stack.pop() is Some(pending) {
    if nodes.length() >= node_budget { return failed("bpmn/traversal-node-limit","Traversal arena node limit exceeded",Some(pending)) }
    let mut metadata=0
    let mut contents : ReadOnlyArray[Content] = []
    let mut parent_element : Element? = None
    match pending.value {
      Element(element) => {
        if pending.depth > limits.depth { return failed("bpmn/traversal-depth-limit","Traversal element depth limit exceeded",Some(pending)) }
        let mut remaining=limits.nodes-records-stack.length()
        for count in [element.values.length(),element.bindings.length()] { if count > remaining { return failed("bpmn/traversal-node-limit","Traversal metadata limit exceeded",Some(pending)) }; remaining-=count; metadata+=count }
        if !element_tokens_within(element,limits.token_units) { return failed("bpmn/traversal-token-limit","Traversal name or value limit exceeded",Some(pending)) }
        contents=element.contents; parent_element=Some(element)
      }
      Text(s) | Comment(s) => if s.length() > limits.token_units { return failed("bpmn/traversal-token-limit","Traversal content token limit exceeded",Some(pending)) }
      ProcessingInstruction(target~,data~) => if target.length() > limits.token_units || data.length() > limits.token_units { return failed("bpmn/traversal-token-limit","Traversal PI token limit exceeded",Some(pending)) }
      Document => ()
    }
    if metadata >= limits.nodes-records || stack.length() > limits.nodes-records-metadata-1 { return failed("bpmn/traversal-node-limit","Traversal record limit exceeded",Some(pending)) }
    records+=metadata+1
    let child_count=if pending.value is Document { if document.prolog.length() >= limits.nodes || document.epilog.length() >= limits.nodes-document.prolog.length() { return failed("bpmn/traversal-node-limit","Document content limit exceeded",Some(pending)) }; document.prolog.length()+1+document.epilog.length() } else { contents.length() }
    if child_count > limits.nodes-records-stack.length() { return failed("bpmn/traversal-node-limit","Traversal child limit exceeded",Some(pending)) }
    if child_count > node_budget-nodes.length()-1-stack.length() { return failed("bpmn/traversal-node-limit","Traversal arena child limit exceeded",Some(pending)) }
    let ordinal=nodes.length()
    let element_ordinal=if pending.semantic && (pending.value is Element(_)) { let n=elements.length(); elements.push(ordinal); Some(n) } else { None }
    nodes.push({value:pending.value,parent:pending.parent,step:pending.step,depth:pending.depth,span:pending.span,origin:pending.origin,element_ordinal,children:[]})
    if pending.parent is Some(parent) { nodes[parent].children.push(ordinal) }
    let children : Array[PendingNode] = []
    if pending.value is Document {
      for i in 0..<document.prolog.length() { children.push({value:content_value(document.prolog[i]),parent:Some(ordinal),step:Some({field:Prolog,index:i,content_index:i}),depth:1,span:document.prolog_spans.get(i).unwrap_or(None),origin:document.origin,semantic:false}) }
      children.push({value:Element(document.root),parent:Some(ordinal),step:Some({field:Root,index:0,content_index:document.prolog.length()}),depth:1,span:document.root.span,origin:document.root.origin,semantic:true})
      for i in 0..<document.epilog.length() { children.push({value:content_value(document.epilog[i]),parent:Some(ordinal),step:Some({field:Epilog,index:i,content_index:document.prolog.length()+1+i}),depth:1,span:document.epilog_spans.get(i).unwrap_or(None),origin:document.origin,semantic:false}) }
    } else if parent_element is Some(parent) {
      let counts : Map[(String,String),Int] = Map([])
      for i in 0..<contents.length() {
        let content=contents[i]; let field=content_field(parent,content); let index=counts.get(field.key()).unwrap_or(0); counts[field.key()]=index+1
        let (span,origin)=match content { Element(e) => (e.span,e.origin); _ => (parent.content_spans.get(i).unwrap_or(None),parent.origin) }
        children.push({value:content_value(content),parent:Some(ordinal),step:Some({field,index,content_index:i}),depth:pending.depth+1,span,origin,semantic:pending.semantic})
      }
    }
    for i=children.length()-1;i>=0;i=i-1 { stack.push(children[i]) }
  }
  let records=ReadOnlyArray::from_array(nodes.map(n => TreeRecord::{value:n.value,parent:n.parent,children:ReadOnlyArray::from_array(n.children),step:n.step,depth:n.depth,span:n.span,origin:n.origin,element_ordinal:n.element_ordinal}))
  {tree:Some({document,revision:{document,resource_id},records,element_nodes:ReadOnlyArray::from_array(elements)}),diagnostics:[]}
}

///|
fn DocumentTree::element_node(self : DocumentTree, ordinal : Int) -> NodeRef? { self.element_nodes.get(ordinal).map(ordinal => NodeRef::{tree:self,ordinal}) }

///|
pub fn DocumentTree::new(document : Document, resource_id? : String, limits? : Limits = Limits::new()) -> TreeBuildResult { build_tree(document,resource_id,limits,limits.nodes) }
