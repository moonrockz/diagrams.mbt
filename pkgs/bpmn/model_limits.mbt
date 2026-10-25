///|
fn name_within(name : ExpandedName, maximum : Int) -> Bool { name.namespace_uri.length() <= maximum && name.local_name.length() <= maximum }

///|
fn scalar_within(value : Scalar, maximum : Int) -> Bool {
  if value.token().length() > maximum { return false }
  match value { Reference(r) => r.name.map(n => name_within(n,maximum)).unwrap_or(true); Invalid(expected~,..) => name_within(expected,maximum); _ => true }
}

///|
/// Expanded identities can inherit a large binding from a detached source
/// ancestor. Check those identities as well as their short lexical spellings.
fn element_tokens_within(element : Element, maximum : Int) -> Bool {
  name_within(element.kind.name(),maximum) && element.value_type.map(n => name_within(n,maximum)).unwrap_or(true) && element.text_value.map(v => scalar_within(v,maximum)).unwrap_or(true) && element.values.iter().all(a => a.raw_name.length() <= maximum && a.name.map(n => name_within(n,maximum)).unwrap_or(true) && scalar_within(a.value,maximum)) && element.bindings.iter().all(p => p.0.length() <= maximum && p.1.length() <= maximum)
}
