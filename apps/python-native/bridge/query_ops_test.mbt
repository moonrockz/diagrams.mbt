///|
fn query_call(op : String, args : Array[@python_native_bridge.Rec]) -> @python_native_bridge.Rec {
  let items : Array[@python_native_bridge.Rec] = [Str(op)]
  items.append(args)
  let response = @python_native_bridge.decode_record(
    @python_native_bridge.call(@python_native_bridge.encode_record(@python_native_bridge.Rec::list(items))),
  ) catch {
    _ => abort("bad response")
  }
  response
}

///|
fn query_ok(response : @python_native_bridge.Rec) -> @python_native_bridge.Rec {
  guard response is List([Int(0L), value]) else {
    abort("call failed: \{response.to_repr()}")
  }
  value
}

///|
test "query records cross the boundary on every target" {
  let source = "<definitions xmlns='http://www.omg.org/spec/BPMN/20100524/MODEL' targetNamespace='urn:t'><process id='P'><userTask id='A' name='Approve'/><task id='T'/></process></definitions>"
  guard query_ok(query_call("bpmn_read", [Str(source), Null, Null])) is List([Int(document), _]) else {
    fail("read failed")
  }
  guard query_ok(query_call("bpmn_tree_new", [Int(document), Null, Null])) is List([Int(tree), _]) else {
    fail("tree failed")
  }
  let bindings = @python_native_bridge.Rec::list([
    @python_native_bridge.Rec::list([Str("bpmn"), Str("http://www.omg.org/spec/BPMN/20100524/MODEL")]),
  ])
  guard query_ok(query_call("query_compile", [Str("(bpmn.userTask) @t"), bindings, Null]))
    is List([Str("ok"), Int(plan), Str(normalized), ..]) else {
    fail("compile failed")
  }
  inspect(normalized, content="({http://www.omg.org/spec/BPMN/20100524/MODEL}userTask) @t")
  guard query_ok(query_call("query_view_open", [Int(tree)])) is Int(view) else { fail("view failed") }
  let fields = @python_native_bridge.Rec::list([Str("id"), Str("attr:name"), Str("attr:none")])
  guard query_ok(query_call("query_execute", [Int(plan), Int(view), Null, fields, bindings, Null]))
    is List([Str("ok"), Int(cursor)]) else {
    fail("execute failed")
  }
  guard query_ok(query_call("query_next_batch", [Int(cursor), Int(10L)]))
    is List([Str("rows"), List([List([Int(0L), List([List([Str("t"), _, values])])])])]) else {
    fail("no rows")
  }
  debug_inspect(
    values,
    content=(
      #|List(
      #|  <ReadOnlyArray:
      #|    [
      #|      List(<ReadOnlyArray: [Str("scalar"), Str("identifier"), Str("A")]>),
      #|      List(<ReadOnlyArray: [Str("scalar"), Str("text"), Str("Approve")]>),
      #|      List(<ReadOnlyArray: [Str("absent")]>),
      #|    ]>,
      #|)
    ),
  )
  assert_true(query_ok(query_call("query_next_batch", [Int(cursor), Int(10L)])) is List([Str("complete")]))
  // Errors are records, not exceptions; closed tokens fail safely.
  guard query_ok(query_call("query_compile", [Str("(bpmn.task)*"), bindings, Null]))
    is List([Str("error"), List([List([Str("query/unsupported-quantifier"), ..])])]) else {
    fail("expected a diagnostic")
  }
  assert_true(query_ok(query_call("query_close", [Int(cursor)])) is Bool(true))
  assert_true(query_ok(query_call("query_close", [Int(cursor)])) is Bool(false))
  assert_true(query_call("query_next_batch", [Int(cursor), Int(1L)]) is List([Int(1L), Str("closed-token"), _]))
  assert_true(query_call("query_next_batch", [Int(plan), Int(1L)]) is List([Int(1L), Str("wrong-token"), _]))
  assert_true(query_ok(query_call("query_plan_close", [Int(plan)])) is Bool(true))
  assert_true(query_ok(query_call("query_view_close", [Int(view)])) is Bool(true))
}
