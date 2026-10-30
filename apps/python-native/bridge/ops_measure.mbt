///|
/// Measurement operations. They run the same public MoonBit work as the
/// query and traversal operations, `repeat` times, and return only counts.
/// So the time that the adapter measures inside the runtime lock is MoonBit
/// work without record conversion or Python objects (the "native oracle" of
/// `measure.py`). They change no state and open no object.
///
/// - `measure_query(plan, view, fields, repeat)` runs `QueryPlan::collect`
///   with the projection of `fields` and returns `(matches, state)` of the
///   last run. `state` is `complete`, `stopped` or `failed`.
/// - `measure_walk(tree, prune, mode, repeat)` runs `@bpmn.walk` from the
///   root. It returns `SkipChildren` for elements whose local kind name is
///   `prune` (a str or `None`). `mode` is `none`, `ids` (read `NodeRef::id`
///   of each node), `records` (build the node snapshot record of each node)
///   or `encoded` (build and encode it). It returns `(entered, count)` of the
///   last run; `count` is the IDs read or the encoded bytes.
fn measure_op(op : String, args : ArrayView[Rec]) -> Rec? raise BridgeError {
  match op {
    "measure_query" => {
      let plan = plans.get(arg_int(args, 0))
      let view = views.get(arg_int(args, 1))
      let fields = strings_of(args.get(2).unwrap_or(List([])), "Fields")
      let repeat = measure_repeat(args, 3)
      let projection = @query.Projection::new(
        @query_bpmn.schema,
        fields.map(@query.FieldRequest::parse),
      )
      guard projection is Ok(projection) else {
        raise BridgeError("invalid-argument", "A projection field is unknown.")
      }
      let mut result = plan.collect(view, projection~)
      for _ in 1..<repeat {
        result = plan.collect(view, projection~)
      }
      let state = match result.outcome {
        Complete => "complete"
        Stopped => "stopped"
        Failed(_) => "failed"
        _ => "open"
      }
      Some(Rec::list([Rec::int(result.matches.length()), Str(state)]))
    }
    "measure_walk" => {
      let tree = tree_of(arg_int(args, 0))
      let prune = arg_str_opt(args, 1)
      let mode = arg_str(args, 2)
      guard ["none", "ids", "records", "encoded"].contains(mode) else {
        raise BridgeError("invalid-argument", "Unknown measure_walk mode.")
      }
      let repeat = measure_repeat(args, 3)
      let mut entered = 0
      let mut count = 0
      for _ in 0..<repeat {
        entered = 0
        count = 0
        @bpmn.walk(tree.root(), node => {
          entered += 1
          match mode {
            "ids" => if node.id() is Some(_) { count += 1 }
            "records" => if node_record(node) is List(_) { count += 1 }
            "encoded" => count += encode_record(node_record(node)).length()
            _ => ()
          }
          match (prune, node.kind()) {
            (Some(name), Some(kind)) if kind.local_name() == name =>
              SkipChildren
            _ => Continue
          }
        })
      }
      Some(Rec::list([Rec::int(entered), Rec::int(count)]))
    }
    _ => None
  }
}

///|
fn measure_repeat(
  args : ArrayView[Rec],
  index : Int32,
) -> Int32 raise BridgeError {
  let repeat = arg_int32(args, index)
  guard repeat >= 1 && repeat <= 100000 else {
    raise BridgeError("invalid-argument", "repeat must be from 1 to 100000.")
  }
  repeat
}
