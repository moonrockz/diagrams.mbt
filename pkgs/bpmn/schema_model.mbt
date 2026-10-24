///|
/// Names are values; writer validation checks constructed names and bindings.
pub fn ExpandedName::new(namespace_uri : String, local_name : String) -> ExpandedName { { namespace_uri, local_name } }

///|
fn namespace_prefix(uri : String) -> String {
  match uri {
    "http://www.omg.org/spec/BPMN/20100524/MODEL" => "bpmn"
    "http://www.omg.org/spec/BPMN/20100524/DI" => "bpmndi"
    "http://www.omg.org/spec/DD/20100524/DC" => "dc"
    "http://www.omg.org/spec/DD/20100524/DI" => "di"
    "http://www.w3.org/XML/1998/namespace" => "xml"
    "http://www.w3.org/2001/XMLSchema-instance" => "xsi"
    _ => ""
  }
}

///|
pub struct SchemaType {
  id : TypeId
  name : ExpandedName
  base : ExpandedName?
  abstract_type : Bool
  mixed : Bool
  simple : Bool
  anonymous : Bool
  enum_values : ReadOnlyArray[String]
  union_members : ReadOnlyArray[ExpandedName]
} derive(Eq, Debug)

///|
pub extend SchemaType with Eq::{equal, not_equal}

///|
pub extend SchemaType with @debug.Debug::{to_repr}

///|
pub struct SchemaElement { name : ExpandedName; value_type : ExpandedName?; substitution_group : ExpandedName?; abstract_element : Bool } derive(Eq, Debug)

///|
pub extend SchemaElement with Eq::{equal, not_equal}

///|
pub extend SchemaElement with @debug.Debug::{to_repr}

///|
pub(all) enum SchemaFieldKind { Attribute; Child; AnyAttribute; AnyChild } derive(Eq, Debug)

///|
pub extend SchemaFieldKind with Eq::{equal, not_equal}

///|
pub extend SchemaFieldKind with @debug.Debug::{to_repr}

///|
pub struct SchemaField {
  owner : TypeId
  kind : SchemaFieldKind
  name : ExpandedName?
  value_type : ExpandedName?
  reference_element : ExpandedName?
  minimum : Int
  maximum : Int?
  default_value : String?
  fixed_value : String?
  group : String
  namespace_constraint : String
  source_path : String
} derive(Eq, Debug)

///|
pub extend SchemaField with Eq::{equal, not_equal}

///|
pub extend SchemaField with @debug.Debug::{to_repr}

///|
pub struct SchemaGroup { owner : TypeId; path : String; parent : String; choice : Bool; minimum : Int; maximum : Int? } derive(Eq, Debug)

///|
pub extend SchemaGroup with Eq::{equal, not_equal}

///|
pub extend SchemaGroup with @debug.Debug::{to_repr}

///|
pub fn schema_type(name : ExpandedName) -> SchemaType? { schema_types.iter().find_first(t => t.name == name) }

///|
pub fn TypeId::name(self : TypeId) -> ExpandedName { schema_types.iter().find_first(t => t.id == self).unwrap().name }

///|
pub fn Kind::name(self : Kind) -> ExpandedName { { namespace_uri: self.namespace_uri(), local_name: self.local_name() } }

///|
pub fn kind_from_name(name : ExpandedName) -> Kind? { standard_kinds.iter().find_first(k => k.name() == name) }

///|
/// Inherited fields are returned in base-to-derived declaration order. Choice
/// membership stays in schema_groups instead of making every alternative required.
pub fn SchemaType::fields(self : SchemaType) -> ReadOnlyArray[SchemaField] {
  let chain = [self]
  let mut next = self.base
  while next is Some(name) && schema_type(name) is Some(parent) {
    chain.push(parent); next = parent.base
    if chain.length() > schema_types.length() { break }
  }
  let fields : Array[SchemaField] = []
  for i = chain.length()-1; i >= 0; i = i-1 { for field in schema_fields { if field.owner == chain[i].id { fields.push(field) } } }
  ReadOnlyArray::from_array(fields)
}

///|
pub fn SchemaType::is_subtype_of(self : SchemaType, parent : ExpandedName) -> Bool {
  let mut current = self.name
  for _ in 0..<(schema_types.length()+1) {
    if current == parent { return true }
    guard schema_type(current) is Some(t) && t.base is Some(base) else { return false }
    current = base
  }
  false
}

///|
pub fn SchemaType::has_mixed_content(self : SchemaType) -> Bool {
  let mut current = Some(self)
  for _ in 0..<(schema_types.length()+1) {
    guard current is Some(t) else { return false }
    if t.mixed { return true }
    current = match t.base { Some(base) => schema_type(base); None => None }
  }
  false
}

///|
pub fn Kind::declared_type(self : Kind) -> ExpandedName? {
  let name = self.name()
  if schema_elements.iter().find_first(e => e.name == name) is Some(element) { return element.value_type }
  let mut found : ExpandedName? = None
  for field in schema_fields {
    if field.kind == Child && field.name == Some(name) && field.value_type is Some(t) {
      if found is Some(previous) && previous != t { return None }
      found = Some(t)
    }
  }
  found
}
