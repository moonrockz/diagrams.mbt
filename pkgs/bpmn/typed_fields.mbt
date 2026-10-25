///|
fn typed_element_is(element : Element, expected : TypeId) -> Bool {
  match element.value_type { Some(name) => schema_type(name).map(t => t.is_subtype_of(expected.name())).unwrap_or(false); None => false }
}

///|
fn typed_child_matches(element : Element, name : ExpandedName, substitution : Bool) -> Bool {
  if substitution { element.kind.substitutes(name) } else { element.kind.name() == name }
}

///|
fn[T] typed_single_child(element : Element, name : ExpandedName, substitution : Bool, project : (Element) -> Field[T]) -> Field[T] {
  let mut found : Field[T] = Absent
  let mut any=false
  for child in element.children {
    if !typed_child_matches(child,name,substitution) { continue }
    if any { return InvalidValue(Invalid(raw="duplicate child "+name.local_name,expected=name)) }
    found=project(child); any=true
  }
  found
}

///|
fn[T] typed_repeated_child(element : Element, name : ExpandedName, substitution : Bool, project : (Element) -> Field[T]) -> Field[ReadOnlyArray[T]] {
  let values : Array[T] = []
  for child in element.children {
    if !typed_child_matches(child,name,substitution) { continue }
    match project(child) { Present(value) => values.push(value); InvalidValue(value) => return InvalidValue(value); Absent => return InvalidValue(Invalid(raw=child.kind.local_name(),expected=name)) }
  }
  if values.is_empty() { Absent } else { Present(ReadOnlyArray::from_array(values)) }
}
