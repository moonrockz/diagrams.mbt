///|
/// A field that a projection reads from each captured node. The node identity
/// is always part of a capture, so a projection with no fields returns
/// identities alone.
pub(all) enum FieldRequest {
  Kind
  Category
  Text
  Location
  Path
  Depth
  Field
  Attribute(String)
  Extra(String)
} derive(Eq, Debug)

///|
pub extend FieldRequest with Eq::{equal, not_equal}

///|
pub extend FieldRequest with @debug.Debug::{to_repr}

///|
/// Parses a field name: `kind`, `category`, `text`, `location`, `path`,
/// `depth`, `field`, `attr:<attribute>` or an adapter extra field such as
/// `id`.
pub fn FieldRequest::parse(name : String) -> FieldRequest {
  match name {
    "kind" => Kind
    "category" => Category
    "text" => Text
    "location" => Location
    "path" => Path
    "depth" => Depth
    "field" => Field
    _ =>
      if name.has_prefix("attr:") {
        Attribute(name.view(start_offset=5).to_owned())
      } else {
        Extra(name)
      }
  }
}

///|
/// A projected value. `Absent` means that the node has no such value; it is
/// different from an empty string.
pub(all) enum Projected {
  Absent
  Text(String)
  Scalar(ScalarValue)
  Name(Name)
  Int(Int)
  Location(QueryLocation)
  Path(ReadOnlyArray[QueryPathStep])
} derive(Eq, Debug)

///|
pub extend Projected with Eq::{equal, not_equal}

///|
pub extend Projected with @debug.Debug::{to_repr}

///|
priv enum RField {
  RKind
  RCategory
  RText
  RLocation
  RPath
  RDepth
  RField
  RAttribute(Name)
  RExtra(String)
}

///|
/// A checked field selection for one schema.
pub struct Projection {
  schema_id : String
  schema_version : Int
  fields : ReadOnlyArray[FieldRequest]
  priv resolved : ReadOnlyArray[RField]
}

///|
pub impl @debug.Debug for Projection with to_repr(self) {
  @debug.Repr::Repr(self.fields.iter().to_array())
}

///|
pub extend Projection with @debug.Debug::{to_repr}

///|
/// The most fields that one projection can request.
pub let max_projection_fields : Int = 256

///|
/// Checks `fields` against `schema`. An unknown extra field, an unbound
/// attribute prefix or too many fields is an input failure.
pub fn Projection::new(
  schema : Schema,
  fields : ArrayView[FieldRequest],
  namespaces? : ArrayView[(String, String)] = [],
) -> Result[Projection, ReadOnlyArray[QueryDiagnostic]] {
  if fields.length() > max_projection_fields {
    return Err([
      error("query/projection-limit", "A projection requests too many fields.", None),
    ])
  }
  let diagnostics = []
  let resolved = []
  for field in fields {
    let r = match field {
      Kind => Some(RKind)
      Category => Some(RCategory)
      Text => Some(RText)
      Location => Some(RLocation)
      Path => Some(RPath)
      Depth => Some(RDepth)
      Field => Some(RField)
      Extra(name) =>
        if schema.extra_fields.iter().any(n => n == name) {
          Some(RExtra(name))
        } else {
          diagnostics.push(
            error(
              "query/unknown-projection-field",
              "The schema has no projection field \{name}.",
              None,
            ),
          )
          None
        }
      Attribute(name) =>
        match name.find(":") {
          None if name != "" => Some(RAttribute(Name::new("", name)))
          None => {
            diagnostics.push(
              error("query/invalid-name", "An attribute name cannot be empty.", None),
            )
            None
          }
          Some(colon) => {
            let prefix = name.view(end_offset=colon).to_owned()
            let local_name = name.view(start_offset=colon + 1).to_owned()
            match namespaces.iter().find_first(b => b.0 == prefix) {
              Some((_, uri)) if local_name != "" && !local_name.contains(":") =>
                Some(RAttribute(Name::new(uri, local_name)))
              Some(_) => {
                diagnostics.push(
                  error("query/invalid-name", "\{name} is not a valid attribute name.", None),
                )
                None
              }
              None => {
                diagnostics.push(
                  error(
                    "query/unbound-prefix",
                    "The prefix \{prefix} has no namespace binding.",
                    None,
                  ),
                )
                None
              }
            }
          }
        }
    }
    if r is Some(value) {
      resolved.push(value)
    }
  }
  if !diagnostics.is_empty() {
    return Err(ReadOnlyArray::from_array(diagnostics))
  }
  Ok({
    schema_id: schema.id,
    schema_version: schema.version,
    fields: ReadOnlyArray::from_array(fields.to_owned()),
    resolved: ReadOnlyArray::from_array(resolved),
  })
}

///|
/// A projection with no fields: identities only.
pub fn Projection::identity(schema : Schema) -> Projection {
  { schema_id: schema.id, schema_version: schema.version, fields: [], resolved: [] }
}

///|
fn[T : QueryTree] project(
  tree : T,
  node : Int,
  field : RField,
) -> Projected {
  match field {
    RKind =>
      match tree.kind(node) {
        Some(name) => Name(name)
        None => Absent
      }
    RCategory => Text(tree.category(node))
    RText =>
      match tree.text(node) {
        Some(text) => Text(text)
        None => Absent
      }
    RLocation =>
      match tree.location(node) {
        Some(location) => Location(location)
        None => Absent
      }
    RPath => Path(tree.path(node))
    RDepth => Int(tree.depth(node))
    RField =>
      match tree.field(node) {
        Some(name) => Name(name)
        None => Absent
      }
    RAttribute(name) =>
      match tree.attribute(node, name) {
        Some(value) => Scalar(value)
        None => Absent
      }
    RExtra(name) =>
      match tree.extra(node, name) {
        Some(value) => Scalar(value)
        None => Absent
      }
  }
}

///|
/// The output units of a projected value: one, plus its text code units.
fn Projected::units(self : Projected) -> Int {
  1 +
  (match self {
    Absent | Int(_) => 0
    Text(text) => text.length()
    Scalar(value) => value.tag.length() + value.text.length()
    Name(name) => name.namespace_uri.length() + name.local_name.length()
    Location(location) => location.source_id.map(s => s.length()).unwrap_or(0) + 6
    Path(steps) =>
      steps.iter().fold(init=0, (sum, step) => sum +
        step.field.namespace_uri.length() +
        step.field.local_name.length() +
        2)
  })
}
