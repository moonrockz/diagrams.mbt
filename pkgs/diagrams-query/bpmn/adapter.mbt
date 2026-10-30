///|
/// The namespace of the structural fields that are not XML names: text,
/// comment, processing-instruction, root, prolog and epilog.
pub let tree_namespace : String = "urn:moonrockz:bpmn:tree"

///|
/// The OMG namespaces whose kinds and fields must be in the schema inventory.
pub let reserved_namespaces : ReadOnlyArray[String] = [
  "http://www.omg.org/spec/BPMN/20100524/MODEL", "http://www.omg.org/spec/BPMN/20100524/DI",
  "http://www.omg.org/spec/DD/20100524/DC", "http://www.omg.org/spec/DD/20100524/DI", tree_namespace,
]

///|
/// The suggested query prefixes of the reserved namespaces.
pub let default_namespaces : ReadOnlyArray[(String, String)] = [
  ("bpmn", "http://www.omg.org/spec/BPMN/20100524/MODEL"),
  ("bpmndi", "http://www.omg.org/spec/BPMN/20100524/DI"),
  ("dc", "http://www.omg.org/spec/DD/20100524/DC"),
  ("di", "http://www.omg.org/spec/DD/20100524/DI"),
  ("tree", tree_namespace),
]

///|
/// The query name of each node category.
pub fn category_name(category : @model.NodeCategory) -> String {
  match category {
    Document => "document"
    Definitions => "definitions"
    Process => "process"
    Activity => "activity"
    Event => "event"
    Gateway => "gateway"
    SequenceFlow => "sequence-flow"
    Collaboration => "collaboration"
    Participant => "participant"
    Lane => "lane"
    Choreography => "choreography"
    ChoreographyActivity => "choreography-activity"
    Conversation => "conversation"
    ConversationLink => "conversation-link"
    DiagramInterchange => "diagram-interchange"
    Extension => "extension"
    Other => "other"
    Text => "text"
    Comment => "comment"
    ProcessingInstruction => "processing-instruction"
  }
}

///|
let categories : ReadOnlyArray[String] = [
  "document", "definitions", "process", "activity", "event", "gateway", "sequence-flow", "collaboration",
  "participant", "lane", "choreography", "choreography-activity", "conversation", "conversation-link",
  "diagram-interchange", "extension", "other", "text", "comment", "processing-instruction",
]

///|
/// The tag of a BPMN scalar value.
pub fn scalar_tag(value : @model.Scalar) -> String {
  match value {
    Text(_) => "text"
    Identifier(_) => "identifier"
    Uri(_) => "uri"
    Boolean(_) => "boolean"
    Integer(_) => "integer"
    Number(_) => "number"
    Reference(_) => "reference"
    Enumeration(_) => "enumeration"
    Invalid(..) => "invalid"
  }
}

///|
fn name_of(name : @model.ExpandedName) -> @query.Name {
  @query.Name::new(name.namespace_uri, name.local_name)
}

///|
/// The query field name of a path field.
pub fn field_name(field : @model.PathField) -> @query.Name {
  match field {
    Named(name) => name_of(name)
    Text => @query.Name::new(tree_namespace, "text")
    Comment => @query.Name::new(tree_namespace, "comment")
    ProcessingInstruction =>
      @query.Name::new(tree_namespace, "processing-instruction")
    Root => @query.Name::new(tree_namespace, "root")
    Prolog => @query.Name::new(tree_namespace, "prolog")
    Epilog => @query.Name::new(tree_namespace, "epilog")
  }
}

///|
fn build_schema() -> @query.Schema {
  let kinds : Array[@query.Name] = []
  let fields : Array[@query.Name] = []
  for element in @model.schema_elements {
    if !element.abstract_element {
      kinds.push(name_of(element.name))
    }
    // A child that matches no schema field is in the field of its own name.
    fields.push(name_of(element.name))
  }
  for field in @model.schema_fields {
    if field.kind is Child && field.name is Some(name) {
      fields.push(name_of(name))
    }
  }
  for special in [
    "text", "comment", "processing-instruction", "root", "prolog", "epilog",
  ] {
    fields.push(@query.Name::new(tree_namespace, special))
  }
  @query.Schema::new(
    id="moonrockz/bpmn-document-tree",
    version=1,
    kinds~,
    categories~,
    fields~,
    reserved_namespaces~,
    open_extensions=true,
    scalar_tags=[
      "text", "identifier", "uri", "boolean", "integer", "number", "reference", "enumeration",
      "invalid",
    ],
    extra_fields=["id"],
  )
}

///|
/// The published schema of the BPMN document-tree adapter.
pub let schema : @query.Schema = build_schema()

///|
/// A query view of one immutable BPMN document tree. It keeps the original
/// `NodeRef` values; adapter node `i` is the node whose handle ordinal is `i`.
/// The metadata index is built once, in linear time, without copying the
/// document.
pub struct BpmnTree {
  tree : @model.DocumentTree
  priv nodes : ReadOnlyArray[@model.NodeRef]
  priv children : ReadOnlyArray[ReadOnlyArray[Int]]
  priv kinds : ReadOnlyArray[@query.Name?]
  priv categories : ReadOnlyArray[String]
}

///|
pub impl @debug.Debug for BpmnTree with to_repr(self) {
  @debug.Repr::Repr(("BpmnTree", self.tree.resource_id(), self.nodes.length()))
}

///|
pub extend BpmnTree with @debug.Debug::{to_repr}

///|
pub fn BpmnTree::new(tree : @model.DocumentTree) -> BpmnTree {
  let nodes : Array[@model.NodeRef] = []
  let children : Array[ReadOnlyArray[Int]] = []
  let kinds : Array[@query.Name?] = []
  let categories : Array[String] = []
  let reader = @model.EventReader::new(tree.root())
  while reader.next() is Some(event) {
    guard event is Enter(node) else { continue }
    // Tree ordinals are preorder positions; the index relies on it.
    guard node.handle().ordinal == nodes.length() else {
      abort("BPMN tree ordinals are not in preorder")
    }
    nodes.push(node)
    children.push(node.children().map(child => child.handle().ordinal))
    kinds.push(node.kind().map(kind => name_of(kind.name())))
    categories.push(category_name(node.category()))
  }
  {
    tree,
    nodes: ReadOnlyArray::from_array(nodes),
    children: ReadOnlyArray::from_array(children),
    kinds: ReadOnlyArray::from_array(kinds),
    categories: ReadOnlyArray::from_array(categories),
  }
}

///|
/// The node with adapter index `node`.
pub fn BpmnTree::node(self : BpmnTree, node : Int) -> @model.NodeRef? {
  self.nodes.get(node)
}

///|
/// The adapter index of `node`, or `None` when it belongs to another
/// document revision.
pub fn BpmnTree::index(self : BpmnTree, node : @model.NodeRef) -> Int? {
  match self.tree.lookup(node.handle()) {
    Found(_) => Some(node.handle().ordinal)
    _ => None
  }
}

///|
/// The node of a capture from a cursor over this tree.
pub fn BpmnTree::captured(
  self : BpmnTree,
  capture : @query.CapturedNode,
) -> @model.NodeRef {
  self.nodes[capture.node]
}

///|
pub impl @query.QueryTree for BpmnTree with schema(_self) {
  schema
}

///|
pub impl @query.QueryTree for BpmnTree with root(_self) {
  0
}

///|
pub impl @query.QueryTree for BpmnTree with node_count(self) {
  self.nodes.length()
}

///|
pub impl @query.QueryTree for BpmnTree with kind(self, node) {
  self.kinds[node]
}

///|
pub impl @query.QueryTree for BpmnTree with category(self, node) {
  self.categories[node]
}

///|
pub impl @query.QueryTree for BpmnTree with children(self, node) {
  self.children[node][:]
}

///|
pub impl @query.QueryTree for BpmnTree with field(self, node) {
  self.nodes[node].step().map(step => field_name(step.field))
}

///|
pub impl @query.QueryTree for BpmnTree with attribute(self, node, name) {
  for attribute in self.nodes[node].attributes() {
    if attribute.name is Some(n) &&
      n.namespace_uri == name.namespace_uri &&
      n.local_name == name.local_name {
      return Some({ tag: scalar_tag(attribute.value), text: attribute.value.token() })
    }
  }
  None
}

///|
pub impl @query.QueryTree for BpmnTree with text(self, node) {
  match self.nodes[node].value() {
    Text(text) | Comment(text) => Some(text)
    ProcessingInstruction(data~, ..) => Some(data)
    Element(element) => element.text_value.map(value => value.token())
    Document => None
  }
}

///|
pub impl @query.QueryTree for BpmnTree with extra(self, node, name) {
  match name {
    "id" => self.nodes[node].id().map(id => { tag: "identifier", text: id })
    _ => None
  }
}

///|
pub impl @query.QueryTree for BpmnTree with location(self, node) {
  self.nodes[node]
  .location()
  .map(location => {
    source_id: location.source_id,
    start: {
      offset: location.start.offset,
      line: location.start.line,
      column: location.start.column,
    },
    end: {
      offset: location.end.offset,
      line: location.end.line,
      column: location.end.column,
    },
  })
}

///|
pub impl @query.QueryTree for BpmnTree with path(self, node) {
  self.nodes[node]
  .path()
  .steps()
  .map(step => {
    field: field_name(step.field),
    index: step.index,
    position: step.content_index,
  })
}

///|
pub impl @query.QueryTree for BpmnTree with depth(self, node) {
  self.nodes[node].depth()
}

///|
pub extend BpmnTree with @query.QueryTree::{
  schema,
  root,
  node_count,
  kind,
  category,
  children,
  field,
  attribute,
  text,
  extra,
  location,
  path,
  depth,
}

///|
/// Compiles `source` for this adapter with `default_namespaces` and any extra
/// bindings. Later bindings can not rebind a default prefix.
pub fn compile(
  source : String,
  namespaces? : ArrayView[(String, String)] = [],
  limits? : @query.CompileLimits = @query.CompileLimits::new(),
) -> Result[@query.QueryPlan, ReadOnlyArray[@query.QueryDiagnostic]] {
  let bindings = default_namespaces.iter().to_array()
  bindings.append(namespaces.to_owned())
  @query.compile(source, schema, namespaces=bindings, limits~)
}
