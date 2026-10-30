///|
/// The version of the query language that this package compiles.
pub let language_version : Int = 1

///|
/// An expanded name: a namespace URI and a local name. The empty URI means
/// no namespace. Source prefixes are never part of a name.
pub struct Name {
  namespace_uri : String
  local_name : String
} derive(Eq, Hash, Compare, Debug)

///|
pub extend Name with Hash::{hash, hash_combine}

///|
pub extend Name with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Name with Eq::{equal, not_equal}

///|
pub extend Name with @debug.Debug::{to_repr}

///|
pub fn Name::new(namespace_uri : String, local_name : String) -> Name {
  { namespace_uri, local_name }
}

///|
/// Clark notation, `{uri}local`, or `local` with no namespace.
pub fn Name::clark(self : Name) -> String {
  if self.namespace_uri == "" {
    self.local_name
  } else {
    "{\{self.namespace_uri}}\{self.local_name}"
  }
}

///|
/// The published contract of a tree adapter.
///
/// `kinds`, `fields` and `categories` are the inventory that queries can
/// name. A kind or field in a namespace of `reserved_namespaces` must be in the
/// inventory. A kind or field in another namespace is valid when
/// `open_extensions` is true, also when no document contains it. With
/// `open_extensions` false, every kind and field must be in the inventory.
/// `scalar_tags` lists the tags of attribute values. `extra_fields` lists the
/// adapter-specific projection fields, for example `id`.
pub struct Schema {
  id : String
  version : Int
  kinds : ReadOnlyArray[Name]
  categories : ReadOnlyArray[String]
  fields : ReadOnlyArray[Name]
  reserved_namespaces : ReadOnlyArray[String]
  open_extensions : Bool
  scalar_tags : ReadOnlyArray[String]
  extra_fields : ReadOnlyArray[String]
  priv kind_set : Map[Name, Bool]
  priv field_set : Map[Name, Bool]
  priv category_set : Map[String, Bool]
}

///|
pub impl Eq for Schema with equal(a, b) {
  a.id == b.id &&
  a.version == b.version &&
  a.kinds == b.kinds &&
  a.categories == b.categories &&
  a.fields == b.fields &&
  a.reserved_namespaces == b.reserved_namespaces &&
  a.open_extensions == b.open_extensions &&
  a.scalar_tags == b.scalar_tags &&
  a.extra_fields == b.extra_fields
}

///|
pub extend Schema with Eq::{equal, not_equal}

///|
pub impl @debug.Debug for Schema with to_repr(self) {
  @debug.Repr::Repr(("Schema", self.id, self.version))
}

///|
pub extend Schema with @debug.Debug::{to_repr}

///|
pub fn Schema::new(
  id~ : String,
  version~ : Int,
  kinds~ : ArrayView[Name],
  categories~ : ArrayView[String],
  fields~ : ArrayView[Name],
  reserved_namespaces? : ArrayView[String] = [],
  open_extensions? : Bool = false,
  scalar_tags? : ArrayView[String] = ["text"],
  extra_fields? : ArrayView[String] = [],
) -> Schema {
  let kind_set : Map[Name, Bool] = Map([])
  for kind in kinds {
    kind_set[kind] = true
  }
  let field_set : Map[Name, Bool] = Map([])
  for field in fields {
    field_set[field] = true
  }
  let category_set : Map[String, Bool] = Map([])
  for category in categories {
    category_set[category] = true
  }
  {
    id,
    version,
    kinds: ReadOnlyArray::from_array(kinds.to_owned()),
    categories: ReadOnlyArray::from_array(categories.to_owned()),
    fields: ReadOnlyArray::from_array(fields.to_owned()),
    reserved_namespaces: ReadOnlyArray::from_array(reserved_namespaces.to_owned()),
    open_extensions,
    scalar_tags: ReadOnlyArray::from_array(scalar_tags.to_owned()),
    extra_fields: ReadOnlyArray::from_array(extra_fields.to_owned()),
    kind_set,
    field_set,
    category_set,
  }
}

///|
fn Schema::admits(
  self : Schema,
  name : Name,
  declared : Map[Name, Bool],
) -> Bool {
  if declared.contains(name) {
    return true
  }
  self.open_extensions &&
  !self.reserved_namespaces.iter().any(ns => ns == name.namespace_uri)
}

///|
/// True when queries can name `kind` under this schema.
pub fn Schema::admits_kind(self : Schema, kind : Name) -> Bool {
  self.admits(kind, self.kind_set)
}

///|
/// True when queries can name `field` under this schema.
pub fn Schema::admits_field(self : Schema, field : Name) -> Bool {
  self.admits(field, self.field_set)
}

///|
pub fn Schema::has_category(self : Schema, category : String) -> Bool {
  self.category_set.contains(category)
}

///|
/// True when a plan compiled for `self` can execute on a tree of `other`.
/// Compatibility depends on the declared identifier and version, not on the
/// contents of a document.
pub fn Schema::compatible(self : Schema, other : Schema) -> Bool {
  self.id == other.id && self.version == other.version
}
