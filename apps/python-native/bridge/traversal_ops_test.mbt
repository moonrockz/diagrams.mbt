///|
let model_uri : String = "http://www.omg.org/spec/BPMN/20100524/MODEL"

///|
/// Calls `op` through the boundary. A failure gives `Err((code, message))`.
fn bpmn_call(
  op : String,
  args : Array[@python_native_bridge.Rec],
) -> Result[@python_native_bridge.Rec, (String, String)] raise {
  let request = @python_native_bridge.Rec::list([Str(op), ..args])
  let response = @python_native_bridge.call(
    @python_native_bridge.encode_record(request),
  )
  match @python_native_bridge.decode_record(response) {
    List([Int(0L), value]) => Ok(value)
    List([Int(1L), Str(code), Str(message)]) => Err((code, message))
    _ => fail("unexpected response")
  }
}

///|
fn ok(
  op : String,
  args : Array[@python_native_bridge.Rec],
) -> @python_native_bridge.Rec raise {
  match bpmn_call(op, args) {
    Ok(value) => value
    Err((code, message)) => fail("\{op} failed: \{code} \{message}")
  }
}

///|
fn error_code(
  op : String,
  args : Array[@python_native_bridge.Rec],
) -> String raise {
  match bpmn_call(op, args) {
    Ok(_) => fail("\{op} succeeded")
    Err((code, _)) => code
  }
}

///|
fn token(value : @python_native_bridge.Rec) -> Int64 raise {
  guard value is Int(token) else { fail("not a token:") }
  token
}

///|
fn source(body : String) -> String {
  "<b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:t'>\{body}</b:definitions>"
}

///|
/// Reads `body` and builds its tree. Returns `(document, tree)` tokens.
fn open_tree(body : String) -> (Int64, Int64) raise {
  guard ok("bpmn_read", [Str(source(body)), Str("memory:test"), Null])
    is List([Int(document), List([])]) else {
    fail("read failed")
  }
  guard ok("bpmn_tree_new", [Int(document), Null, Null])
    is List([Int(tree), List([])]) else {
    fail("tree failed")
  }
  (document, tree)
}

///|
fn ordinal_and_id(record : @python_native_bridge.Rec) -> (Int64, String?) raise {
  guard record is List(items) && items[0] is Int(ordinal) else {
    fail("not a node record:")
  }
  let id = match items[3] {
    Str(id) => Some(id)
    _ => None
  }
  (ordinal, id)
}

///|
fn live(name : String) -> Int64 raise {
  guard ok("live_objects", []) is List(counts) else { fail("no live counts") }
  for count in counts {
    if count is List([Str(n), Int(value)]) && n == name {
      return value
    }
  }
  fail("no live count \{name}")
}

///|
test "read keeps diagnostics with spans and locations and refuses invalid limits" {
  let read = ok("bpmn_read", [
    Str("<b:definitions xmlns:b='\{model_uri}'>"),
    Str("memory:bad"),
    Null,
  ])
  guard read is List([Null, List(diagnostics)]) else {
    fail("an incomplete source has no document:")
  }
  assert_true(diagnostics.length() > 0)
  guard diagnostics[0] is List([Str(_), Str("Error"), Str(_), _, location]) else {
    fail("diagnostic layout")
  }
  assert_true(location is List([Str("memory:bad"), List(_), List(_)]))
  let limited = ok("bpmn_read", [
    Str(source("")),
    Null,
    @python_native_bridge.Rec::list([
      Null,
      Null,
      @python_native_bridge.Rec::int(0),
      Null,
      Null,
      Null,
    ]),
  ])
  guard limited is List([Null, List([List([Str(code), ..]), ..])]) else {
    fail("limits refused")
  }
  assert_eq(code, "xml/invalid-limits")
  assert_eq(
    error_code("bpmn_read", [Str(""), Null, @python_native_bridge.Rec::list([])]),
    "invalid-argument",
  )
}

///|
test "node records walk and lookup through tokens" {
  let (document, tree) = open_tree(
    "<b:process id='P'><b:task id='A' name='Approve'/><!--c--></b:process>",
  )
  guard ok("bpmn_tree_info", [Int(tree)]) is List([Int(length), Null, root]) else {
    fail("tree info")
  }
  assert_eq(length, 5L)
  assert_eq(ordinal_and_id(root), (0L, None))
  let task = ok("bpmn_node", [Int(tree), @python_native_bridge.Rec::int(3)])
  assert_eq(ordinal_and_id(task), (3L, Some("A")))
  guard task
    is List(
      [
        _,
        Str("Activity"),
        List([Str(uri), Str("task"), Str("standard")]),
        _,
        Int(3L),
        Int(2L),
        List([List([Str("Named"), _, Str("flowElement")]), Int(0L), Int(0L)]),
        List([Int(_), Int(_)]),
        Int(0L),
        List([Str("Element")]),
      ]
    ) else {
    fail("task record")
  }
  assert_eq(uri, model_uri)
  let name = ok("bpmn_node_scalar", [
    Int(tree),
    @python_native_bridge.Rec::int(3),
    Str(""),
    Str("name"),
  ])
  assert_eq(
    name,
    @python_native_bridge.Rec::list([Str("Text"), Str("Approve"), Null]),
  )
  let id = ok("bpmn_node_scalar", [
    Int(tree),
    @python_native_bridge.Rec::int(3),
    Str(""),
    Str("id"),
  ])
  assert_eq(
    id,
    @python_native_bridge.Rec::list([Str("Identifier"), Str("A"), Null]),
  )
  guard ok("bpmn_node_location", [Int(tree), @python_native_bridge.Rec::int(3)])
    is List([Str("memory:test"), List([_, Int(1L), _]), _]) else {
    fail("location")
  }
  guard ok("bpmn_node_path", [Int(tree), @python_native_bridge.Rec::int(3)])
    is List(steps) else {
    fail("path")
  }
  assert_eq(steps.length(), 3)
  // A second tree of the same document is the same revision.
  guard ok("bpmn_tree_new", [Int(document), Null, Null])
    is List([Int(again), _]) else {
    fail("second tree")
  }
  guard ok("bpmn_lookup", [
      Int(again),
      Int(tree),
      @python_native_bridge.Rec::int(3),
    ])
    is List([Str("Found"), found]) else {
    fail("lookup")
  }
  assert_eq(found, task)
  assert_eq(
    ok("bpmn_node_equal", [
      Int(tree),
      @python_native_bridge.Rec::int(3),
      Int(again),
      @python_native_bridge.Rec::int(3),
    ]),
    Bool(true),
  )
  // A different resource identifier is another revision.
  guard ok("bpmn_tree_new", [Int(document), Str("other"), Null])
    is List([Int(other), _]) else {
    fail("resource tree")
  }
  assert_eq(
    ok("bpmn_lookup", [Int(other), Int(tree), @python_native_bridge.Rec::int(3)]),
    @python_native_bridge.Rec::list([Str("DocumentMismatch")]),
  )
  assert_eq(
    ok("bpmn_path_resolve", [
      Int(tree),
      @python_native_bridge.Rec::int(3),
      Int(other),
    ]),
    @python_native_bridge.Rec::list([Str("DocumentMismatch")]),
  )
  assert_eq(
    ok("bpmn_handle_equal", [
      Int(tree),
      @python_native_bridge.Rec::int(3),
      Int(other),
      @python_native_bridge.Rec::int(3),
    ]),
    Bool(false),
  )
  assert_eq(
    error_code("bpmn_node", [Int(tree), @python_native_bridge.Rec::int(99)]),
    "invalid-argument",
  )
  for t in [other, again, tree, document] {
    assert_eq(ok("bpmn_close", [Int(t)]), Bool(true))
    assert_eq(ok("bpmn_close", [Int(t)]), Bool(false))
  }
  assert_eq(
    error_code("bpmn_node", [Int(tree), @python_native_bridge.Rec::int(0)]),
    "closed-token",
  )
  assert_eq(error_code("bpmn_tree_info", [Int(document)]), "wrong-token")
  assert_eq(error_code("bpmn_close", [Int(1L << 60)]), "wrong-token")
}

///|
test "event readers apply controls before advancing and batches only observe" {
  let (document, tree) = open_tree(
    "<b:process id='P'><b:subProcess id='S'><b:task id='Hidden'/></b:subProcess><b:task id='B'/></b:process>",
  )
  let reader = token(
    ok("bpmn_events_new", [Int(tree), @python_native_bridge.Rec::int(0)]),
  )
  let log = []
  let mut control = 0
  while ok("bpmn_events_next", [
          Int(reader),
          @python_native_bridge.Rec::int(control),
        ])
        is List([Bool(enter), record]) {
    let (_, id) = ordinal_and_id(record)
    log.push((enter, id))
    control = if enter && id == Some("S") { 1 } else { 0 }
  }
  assert_false(log.contains((true, Some("Hidden"))))
  assert_true(log.contains((false, Some("S"))))
  assert_eq(log.length(), 10)
  let batched = token(
    ok("bpmn_events_new", [Int(tree), @python_native_bridge.Rec::int(0)]),
  )
  let sizes = []
  while ok("bpmn_events_batch", [
          Int(batched),
          @python_native_bridge.Rec::int(5),
        ])
        is List(events) &&
        events.length() > 0 {
    sizes.push(events.length())
  }
  assert_eq(sizes, [5, 5, 2])
  assert_eq(
    error_code("bpmn_events_batch", [
      Int(batched),
      @python_native_bridge.Rec::int(0),
    ]),
    "invalid-argument",
  )
  let stopped = token(
    ok("bpmn_events_new", [Int(tree), @python_native_bridge.Rec::int(0)]),
  )
  assert_true(
    ok("bpmn_events_next", [Int(stopped), @python_native_bridge.Rec::int(0)])
    is List(_),
  )
  assert_eq(
    ok("bpmn_events_next", [Int(stopped), @python_native_bridge.Rec::int(2)]),
    Null,
  )
  assert_eq(live("bpmn.event_reader"), 3L)
  for t in [reader, batched, stopped, tree, document] {
    ok("bpmn_close", [Int(t)]) |> ignore
  }
  assert_eq(live("bpmn.event_reader"), 0L)
}

///|
test "cursors keep their position after a failed move" {
  let (document, tree) = open_tree(
    "<b:process id='P'><b:task id='T'/></b:process>",
  )
  guard ok("bpmn_cursor_new", [Int(tree), @python_native_bridge.Rec::int(0)])
    is List([Int(cursor), Int(0L), _]) else {
    fail("cursor")
  }
  let go = (name : String) => ok("bpmn_cursor_move", [Int(cursor), Str(name)])
  guard go("parent") is List([Bool(false), Int(0L), root]) else {
    fail("parent")
  }
  assert_eq(ordinal_and_id(root), (0L, None))
  assert_true(go("last_child") is List([Bool(true), Int(1L), _]))
  assert_true(go("first_child") is List([Bool(true), Int(2L), _]))
  guard go("first_child") is List([Bool(true), Int(3L), task]) else {
    fail("task")
  }
  assert_eq(ordinal_and_id(task).1, Some("T"))
  guard go("next_sibling") is List([Bool(false), Int(3L), same]) else {
    fail("sibling")
  }
  assert_eq(same, task)
  assert_eq(
    error_code("bpmn_cursor_move", [Int(cursor), Str("up")]),
    "invalid-argument",
  )
  for t in [cursor, tree, document] {
    ok("bpmn_close", [Int(t)]) |> ignore
  }
}

///|
test "graph operations keep endpoints kinds failures and resources" {
  guard ok("bpmn_read", [
      Str(
        source(
          "<b:process><b:task id='A'/><b:task id='A'/><b:task id='B'/><b:sequenceFlow id='F' sourceRef='A' targetRef='B'/></b:process>",
        ),
      ),
      Null,
      Null,
    ])
    is List([Int(document), _]) else {
    fail("read")
  }
  guard ok("bpmn_resources_new", [
      @python_native_bridge.Rec::list([]),
      @python_native_bridge.Rec::list([]),
    ])
    is Int(resources) else {
    fail("resources")
  }
  guard ok("bpmn_graph_new", [Int(document), Int(resources), Null, Null, Null])
    is List([Int(graph), _]) else {
    fail("graph")
  }
  let id = (value : String) => {
    @python_native_bridge.Rec::list([Str("Id"), Str(value)])
  }
  guard ok("bpmn_graph_lookup", [Int(graph), id("A"), Null])
    is List([Str("Err"), List([Str("Ambiguous"), List(nodes)])]) else {
    fail("ambiguous")
  }
  assert_eq(nodes.length(), 2)
  guard nodes[0] is List([Str("Document"), Null, first]) else { fail("node") }
  let tree = token(ok("bpmn_graph_tree", [Int(graph), Null]))
  let endpoint = @python_native_bridge.Rec::list([
    Str("Node"),
    Int(tree),
    @python_native_bridge.Rec::int(ordinal_and_id(first).0.to_int()),
  ])
  guard ok("bpmn_graph_route", [Int(graph), endpoint, id("B"), Null, Null, Null])
    is List([Str("Failed"), List([Str("Ambiguous"), _])]) else {
    fail("route keeps the ambiguous connection")
  }
  guard ok("bpmn_graph_lookup", [Int(graph), endpoint, Null])
    is List([Str("Ok"), List([Str("Document"), Null, found])]) else {
    fail("handle lookup")
  }
  assert_eq(found, first)
  assert_eq(
    ok("bpmn_graph_reachable", [
      Int(graph),
      id("B"),
      @python_native_bridge.Rec::list([Str("SequenceFlow")]),
      Str("Reverse"),
      @python_native_bridge.Rec::list([
        Null,
        Null,
        Null,
        @python_native_bridge.Rec::int(1),
      ]),
    ]),
    @python_native_bridge.Rec::list([
      Str("Failed"),
      @python_native_bridge.Rec::list([Str("Limit"), Str("Work")]),
    ]),
  )
  assert_eq(
    ok("bpmn_graph_route", [
      Int(graph),
      id("B"),
      id("Missing"),
      Null,
      Null,
      Null,
    ]),
    @python_native_bridge.Rec::list([
      Str("Failed"),
      @python_native_bridge.Rec::list([Str("InvalidEndpoint")]),
    ]),
  )
  assert_eq(
    ok("bpmn_graph_route", [
      Int(graph),
      id("B"),
      id("B"),
      @python_native_bridge.Rec::list([Str("Containment")]),
      Str("Both"),
      @python_native_bridge.Rec::list([
        @python_native_bridge.Rec::int(0),
        Null,
        Null,
        Null,
      ]),
    ]),
    @python_native_bridge.Rec::list([
      Str("Failed"),
      @python_native_bridge.Rec::list([Str("InvalidLimits")]),
    ]),
  )
  assert_eq(
    error_code("bpmn_graph_route", [
      Int(graph),
      id("B"),
      id("B"),
      Null,
      Str("Up"),
      Null,
    ]),
    "invalid-argument",
  )
  assert_eq(live("bpmn.graph"), 1L)
  for t in [tree, graph, resources, document] {
    ok("bpmn_close", [Int(t)]) |> ignore
  }
  assert_eq(live("bpmn.graph"), 0L)
  assert_eq(live("bpmn.tree"), 0L)
  assert_eq(live("bpmn.document"), 0L)
  assert_eq(live("bpmn.resources"), 0L)
}

///|
test "absent external resources fail like MoonBit" {
  let body = "<b:import namespace='urn:types' location='types' importType='urn:external'/><b:itemDefinition id='Item' structureRef='t:Order'/>"
  let text = "<b:definitions xmlns:b='\{model_uri}' xmlns:t='urn:types' targetNamespace='urn:t'>\{body}</b:definitions>"
  guard ok("bpmn_read", [Str(text), Null, Null]) is List([Int(document), _]) else {
    fail("read")
  }
  let symbol = @python_native_bridge.Rec::list([
    Str("Symbol"),
    Str("types"),
    Str("urn:types"),
    Str("Order"),
  ])
  let item = @python_native_bridge.Rec::list([Str("Id"), Str("Item")])
  let kinds = @python_native_bridge.Rec::list([Str("Reference")])
  guard ok("bpmn_graph_new", [Int(document), Null, Null, Null, Null])
    is List([Int(without), _]) else {
    fail("graph without resources")
  }
  guard ok("bpmn_graph_route", [Int(without), item, symbol, kinds, Null, Null])
    is List([Str("Failed"), List([Str("InvalidEndpoint")])]) else {
    fail("absent symbol endpoint")
  }
  guard ok("bpmn_graph_reachable", [Int(without), item, kinds, Null, Null])
    is List(
      [Str("Failed"), List([Str("InvalidReference"), List([Null, Int(_)])])]
    ) else {
    fail("absent resource reference")
  }
  guard ok("bpmn_resources_new", [
      @python_native_bridge.Rec::list([]),
      @python_native_bridge.Rec::list([
        @python_native_bridge.Rec::list([
          Str("types"),
          Str("urn:types"),
          Str("urn:external"),
          @python_native_bridge.Rec::list([Str("Order")]),
        ]),
      ]),
    ])
    is Int(resources) else {
    fail("resources")
  }
  guard ok("bpmn_graph_new", [Int(document), Int(resources), Null, Null, Null])
    is List([Int(with_resources), _]) else {
    fail("graph with resources")
  }
  guard ok("bpmn_graph_route", [
      Int(with_resources),
      item,
      symbol,
      kinds,
      Null,
      Null,
    ])
    is List([Str("Found"), List(nodes), List(_)]) else {
    fail("external route")
  }
  assert_eq(
    nodes[1],
    @python_native_bridge.Rec::list([
      Str("External"),
      Str("types"),
      Str("urn:types"),
      Str("Order"),
      @python_native_bridge.Rec::int(0),
    ]),
  )
  for t in [without, with_resources, resources, document] {
    ok("bpmn_close", [Int(t)]) |> ignore
  }
}
