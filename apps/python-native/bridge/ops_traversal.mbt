///|
/// BPMN reading, inspection, traversal and graph operations.
fn traversal_op(op : String, args : ArrayView[Rec]) -> Rec? {
  ignore(args)
  match op {
    _ => None
  }
}

///|
/// Open traversal objects by registry name.
fn traversal_live() -> Array[(String, Int32)] {
  []
}
