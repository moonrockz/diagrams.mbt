///|
fn codes(tree : @data_tree.DataTree) -> Array[String] {
  @data_tree.validate(tree).iter().map(d => d.code).collect()
}

///|
test "repeated names and equal values keep separate identities" {
  let tree = @data_tree.DataTree::new("d", "root", [
    @data_tree.Node::object("root", [
      @data_tree.Member::named("m1", "item", "v1"),
      @data_tree.Member::named("m2", "item", "v2"),
    ]),
    @data_tree.Node::new("v1", Text("same")),
    @data_tree.Node::new("v2", Text("same")),
  ])
  let index = @data_tree.Index::build(tree).index.unwrap()
  assert_eq(index.owner("v1").unwrap().id, "m1")
  assert_eq(index.owner("v2").unwrap().id, "m2")
}

///|
test "scalar kinds, exact numbers and roots stay distinct" {
  assert_true(@data_tree.Value::Text("true") != @data_tree.Value::Boolean(true))
  assert_true(@data_tree.valid_number("12345678901234567890123"))
  assert_true(@data_tree.valid_number("-0.0"))
  assert_false(@data_tree.valid_number("01"))
  for root in [@data_tree.Node::object("r", []), @data_tree.Node::array("r", []), @data_tree.Node::new("r", Null)] {
    assert_eq(codes(@data_tree.DataTree::new("d", "r", [root])), [])
  }
  // Text that looks like a reference is one scalar.
  let tree = @data_tree.DataTree::new("d", "r", [@data_tree.Node::new("r", Text("*customer"))])
  assert_eq(codes(tree), [])
}

///|
test "invalid containment, keys, numbers and highlights are reported" {
  assert_eq(
    codes(
      @data_tree.DataTree::new("d", "r", [
        @data_tree.Node::object("r", [@data_tree.Member::named("m", "a", "x")]),
        @data_tree.Node::object("x", [@data_tree.Member::named("n", "b", "r")]),
      ]),
    ),
    ["data-tree/containment-cycle"],
  )
  assert_eq(
    codes(
      @data_tree.DataTree::new("d", "r", [
        @data_tree.Node::object("r", [@data_tree.Member::named("m", "a", "missing")]),
      ]),
    ),
    ["data-tree/missing-node"],
  )
  assert_eq(
    codes(
      @data_tree.DataTree::new("d", "r", [
        @data_tree.Node::array("r", [@data_tree.Member::index("m", 1, "x")]),
        @data_tree.Node::new("x", Null),
      ]),
    ),
    ["data-tree/invalid-key"],
  )
  assert_eq(
    codes(@data_tree.DataTree::new("d", "r", [@data_tree.Node::new("r", Number("1e"))])),
    ["data-tree/invalid-number"],
  )
  assert_eq(
    codes(
      @data_tree.DataTree::new(
        "d",
        "r",
        [@data_tree.Node::new("r", Null)],
        highlights=[@data_tree.Highlight::new(["nope"])],
      ),
    ),
    ["data-tree/invalid-highlight"],
  )
}

///|
test "depth and work limits stop validation" {
  let nodes = [@data_tree.Node::array("n0", [@data_tree.Member::index("m0", 0, "n1")])]
  for i in 1..<50 {
    nodes.push(
      @data_tree.Node::array("n\{i}", [@data_tree.Member::index("m\{i}", 0, "n\{i + 1}")]),
    )
  }
  nodes.push(@data_tree.Node::new("n50", Null))
  let tree = @data_tree.DataTree::new("d", "n0", nodes)
  assert_eq(codes(tree), [])
  assert_eq(
    @data_tree.validate(tree, limits=@data_tree.Limits::new(depth=10))[0].code,
    "data-tree/model-limit",
  )
  assert_eq(
    @data_tree.validate(tree, limits=@data_tree.Limits::new(work=20))[0].code,
    "data-tree/model-limit",
  )
  // The tree does not share the caller array.
  nodes.clear()
  assert_eq(tree.nodes.length(), 51)
}
