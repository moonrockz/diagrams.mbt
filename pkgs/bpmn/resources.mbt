///|
/// Caller-supplied non-BPMN identities. This is an explicit symbol table, not an
/// XML Schema, WSDL or vendor-language validator.
pub struct ExternalResource {
  location : String
  namespace_uri : String
  import_type : String
  symbols : ReadOnlyArray[String]
} derive(Eq, Debug)

///|
pub extend ExternalResource with Eq::{equal, not_equal}

///|
pub extend ExternalResource with @debug.Debug::{to_repr}

///|
pub fn ExternalResource::new(location : String, namespace_uri : String, import_type : String, symbols : ArrayView[String]) -> ExternalResource {
  {location,namespace_uri,import_type,symbols:ReadOnlyArray::from_array(symbols)}
}

///|
pub struct DocumentResource { location : String; document : Document } derive(Eq, Debug)

///|
pub extend DocumentResource with Eq::{equal, not_equal}

///|
pub extend DocumentResource with @debug.Debug::{to_repr}

///|
pub fn DocumentResource::new(location : String, document : Document) -> DocumentResource { {location,document} }

///|
/// Literal import-location keys are supplied by the caller. No relative-path,
/// URL, filesystem, environment or network resolution is implicit.
pub struct ResourceSet {
  documents : ReadOnlyArray[DocumentResource]
  external : ReadOnlyArray[ExternalResource]
} derive(Eq, Debug)

///|
pub extend ResourceSet with Eq::{equal, not_equal}

///|
pub extend ResourceSet with @debug.Debug::{to_repr}

///|
pub fn ResourceSet::new(documents? : ArrayView[DocumentResource] = [], external? : ArrayView[ExternalResource] = []) -> ResourceSet {
  {documents:ReadOnlyArray::from_array(documents),external:ReadOnlyArray::from_array(external)}
}

///|
pub struct ResolvedElement { resource_id : String?; node : IndexedElement } derive(Eq, Debug)

///|
pub extend ResolvedElement with Eq::{equal, not_equal}

///|
pub extend ResolvedElement with @debug.Debug::{to_repr}

///|
pub struct ResolvedSymbol { resource_id : String; name : ExpandedName } derive(Eq, Debug)

///|
pub extend ResolvedSymbol with Eq::{equal, not_equal}

///|
pub extend ResolvedSymbol with @debug.Debug::{to_repr}

///|
pub fn ResolvedSymbol::new(resource_id : String, name : ExpandedName) -> ResolvedSymbol { {resource_id,name} }

///|
pub(all) enum ReferenceResolution {
  Found(ResolvedElement)
  External(ResolvedSymbol)
  Ambiguous(ReadOnlyArray[ResolvedElement],ReadOnlyArray[ResolvedSymbol])
  Unresolved
  Invalid
  Limit
} derive(Eq, Debug)

///|
pub extend ReferenceResolution with Eq::{equal, not_equal}

///|
pub extend ReferenceResolution with @debug.Debug::{to_repr}

///|
pub struct ResolvedReference {
  source : IndexedElement
  field : ExpandedName
  value : Reference
  target : ReferenceTarget
  resolution : ReferenceResolution
} derive(Eq, Debug)

///|
pub extend ResolvedReference with Eq::{equal, not_equal}

///|
pub extend ResolvedReference with @debug.Debug::{to_repr}

///|
pub struct ReferenceResult {
  index : DocumentIndex
  references : ReadOnlyArray[ResolvedReference]
  findings : ReadOnlyArray[ValidationFinding]
  complete : Bool
  priv resolver : ReferenceResolver
} derive(Debug)

///|
pub extend ReferenceResult with @debug.Debug::{to_repr}

///|
priv struct AvailableDocument { resource_id : String?; namespace_uri : String; index : DocumentIndex } derive(Debug)

///|
priv struct ReferenceResolver {
  documents : ReadOnlyArray[AvailableDocument]
  complete : Bool
  query_limit : Int
  token_limit : Int
  external_resources : ReadOnlyArray[ExternalResource]
  namespaces : @namespaces.HashMap[String,ReadOnlyArray[Int]]
  symbols : @namespaces.HashMap[(String,String),ReadOnlyArray[ResolvedSymbol]]
} derive(Debug)

///|
fn target_namespace(document : Document) -> String {
  document.root.attribute("targetNamespace").unwrap_or("")
}

///|
fn ReferenceResolver::lookup_bounded(self : ReferenceResolver, reference : Reference, budget : Int) -> (ReferenceResolution,Int) {
  if !self.complete { return (Limit,0) }
  guard reference.name is Some(name) else { return (Invalid,0) }
  if reference.spelling.length() > self.token_limit || name.namespace_uri.length() > self.token_limit || name.local_name.length() > self.token_limit { return (Limit,0) }
  if !ncname(name.local_name) || (reference.kind == Id && name.namespace_uri != "") { return (Invalid,0) }
  let candidates : ReadOnlyArray[Int] = if reference.kind == Id || name.namespace_uri == "" { [0] } else { self.namespaces.get(name.namespace_uri).unwrap_or([]) }
  let found : Array[ResolvedElement] = []
  let symbols : ReadOnlyArray[ResolvedSymbol] = if reference.kind == QName && name.namespace_uri != "" { self.symbols.get((name.namespace_uri,name.local_name)).unwrap_or([]) } else { [] }
  let mut work=0
  for i in candidates {
    if work >= budget { return (Limit,work) }; work+=1
    let resource=self.documents[i]
    if !resource.index.complete { return (Limit,work) }
    if resource.index.ids.get(name.local_name) is Some(indices) {
      if indices.length() > budget-work { return (Limit,work) }
      work+=indices.length()
      for ordinal in indices { found.push({resource_id:resource.resource_id,node:resource.index.nodes[ordinal]}) }
    }
  }
  if symbols.length() > budget-work { return (Limit,work) }; work+=symbols.length()
  let result=if found.length() > 1 || symbols.length() > 1 || (found.length() == 1 && symbols.length() == 1) { ReferenceResolution::Ambiguous(ReadOnlyArray::from_array(found),symbols) }
    else if found.length() == 1 { Found(found[0]) }
    else if symbols.length() == 1 { External(symbols[0]) }
    else { Unresolved }
  (result,work)
}

///|
fn ReferenceResolver::lookup(self : ReferenceResolver, reference : Reference) -> ReferenceResolution { self.lookup_bounded(reference,self.query_limit).0 }

///|
fn make_resolver(documents : Array[AvailableDocument], external : Array[ExternalResource], complete : Bool, query_limit : Int, token_limit : Int) -> ReferenceResolver {
  let namespaces : Map[String,Array[Int]] = Map([])
  let symbols : Map[(String,String),Array[ResolvedSymbol]] = Map([])
  for i in 0..<documents.length() { let uri=documents[i].namespace_uri; match namespaces.get(uri) { Some(xs) => xs.push(i); None => namespaces[uri]=[i] } }
  for r in external { for symbol in r.symbols { let key=(r.namespace_uri,symbol); let value=ResolvedSymbol::{resource_id:r.location,name:ExpandedName::new(r.namespace_uri,symbol)}; match symbols.get(key) { Some(xs) => xs.push(value); None => symbols[key]=[value] } } }
  {documents:ReadOnlyArray::from_array(documents),complete,query_limit,token_limit,external_resources:ReadOnlyArray::from_array(external),namespaces:@namespaces.HashMap::from_iter(namespaces.iter().map(p => (p.0,ReadOnlyArray::from_array(p.1)))),symbols:@namespaces.HashMap::from_iter(symbols.iter().map(p => (p.0,ReadOnlyArray::from_array(p.1))))}
}

///|
/// Lookup uses the same direct/transitive import closure as field resolution.
pub fn ReferenceResult::resolve(self : ReferenceResult, reference : Reference) -> ReferenceResolution { self.resolver.lookup(reference) }

///|
fn reference_target_matches(target : ReferenceTarget, element : Element) -> Bool {
  if opaque_kind(element.kind) { return false }
  match target {
    Bpmn(t) => typed_element_is(element,t)
    AnyElement => true
    InteractionNode => [TypeId::FlowNode,Participant,ConversationNode].iter().any(t => typed_element_is(element,t))
    ItemAwareElement => [TypeId::DataInput,DataOutput,DataObject,DataObjectReference,DataStore,DataStoreReference,Property].iter().any(t => typed_element_is(element,t))
    Plane => [TypeId::Process,SubProcess,Collaboration,SubChoreography].iter().any(t => typed_element_is(element,t))
    External => false
  }
}

///|
/// One immutable document index in the resolver's explicit import closure.
/// `records` counts the bounded element/attribute/content/namespace work, not
/// only elements. Hosts can reuse an index without fetching or reparsing XML.
pub struct IndexedResource { resource_id : String?; index : DocumentIndex; records : Int } derive(Debug)

///|
pub extend IndexedResource with @debug.Debug::{to_repr}

///|
pub fn ReferenceResult::indexed_resources(self : ReferenceResult) -> ReadOnlyArray[IndexedResource] {
  self.resolver.documents.map(d => IndexedResource::{resource_id:d.resource_id,index:d.index,records:d.index.records})
}
