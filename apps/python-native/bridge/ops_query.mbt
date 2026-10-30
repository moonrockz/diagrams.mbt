///|
/// Query schema, compilation, execution and projection operations.
fn query_op(op : String, args : ArrayView[Rec]) -> Rec? {
  ignore(args)
  match op {
    _ => None
  }
}

///|
/// Open query objects by registry name.
fn query_live() -> Array[(String, Int32)] {
  []
}
