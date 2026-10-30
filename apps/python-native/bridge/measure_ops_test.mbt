///|
test "measure_query and measure_walk count the same work as the public ops" {
  let (_, tree) = open_tree(
    "<b:process id='P'><b:userTask id='A' name='Approve'/><b:subProcess id='S'><b:userTask id='B'/></b:subProcess></b:process>",
  )
  let bindings = @python_native_bridge.Rec::list([
    @python_native_bridge.Rec::list([Str("bpmn"), Str(model_uri)]),
  ])
  guard ok("query_compile", [Str("(bpmn.userTask) @t"), bindings, Null])
    is List([Str("ok"), Int(plan), ..]) else {
    fail("compile failed")
  }
  let view = token(ok("query_view_open", [Int(tree)]))
  let fields = @python_native_bridge.Rec::list([Str("id")])
  assert_true(
    ok("measure_query", [Int(plan), Int(view), fields, Int(3)])
    is List([Int(2L), Str("complete")]),
  )
  // The document node, definitions, process, A, S and B; four have an ID.
  assert_true(
    ok("measure_walk", [Int(tree), Null, Str("ids"), Int(2)])
    is List([Int(6L), Int(4L)]),
  )
  // Pruning at the sub-process skips B.
  assert_true(
    ok("measure_walk", [Int(tree), Str("subProcess"), Str("none"), Int(1)])
    is List([Int(5L), Int(0L)]),
  )
  assert_eq(
    error_code("measure_walk", [Int(tree), Null, Str("none"), Int(0)]),
    "invalid-argument",
  )
  assert_true(
    ok("measure_walk", [Int(tree), Null, Str("records"), Int(1)])
    is List([Int(6L), Int(6L)]),
  )
  guard ok("measure_walk", [Int(tree), Null, Str("encoded"), Int(1)])
    is List([Int(6L), Int(bytes)]) else {
    fail("encoded walk failed")
  }
  assert_true(bytes > 0L)
  assert_eq(
    error_code("measure_walk", [Int(tree), Null, Str("other"), Int(1)]),
    "invalid-argument",
  )
  assert_eq(
    error_code("measure_query", [Int(plan), Int(tree), fields, Int(1)]),
    "wrong-token",
  )
}
