///|
test "a large finite repeat stays one node" {
  let model = @regex.Regex::new("r", "p", [
    @regex.Node::new("p", Repeat(@regex.Bounds::new(1000000, max=1000000), "a")),
    @regex.Node::new("a", Literal("a")),
  ])
  assert_eq(@regex.validate(model).length(), 0)
  assert_eq(model.nodes.length(), 2)
  assert_eq(model.nodes[0].label(), "{1000000}")
}

///|
test "a negative lookahead is a constraint, not a consuming branch" {
  let model = @regex.Regex::new("r", "p", [
    @regex.Node::new("p", Sequence(["a", "n"])),
    @regex.Node::new("a", Literal("a")),
    @regex.Node::new("n", Assertion(Ahead, false, "b")),
    @regex.Node::new("b", Literal("b")),
  ])
  let index = @regex.Index::build(model).index.unwrap()
  assert_true(index.node("n").unwrap().kind is Assertion(Ahead, false, _))
  assert_eq(index.node("n").unwrap().label(), "?!")
}

///|
fn codes(model : @regex.Regex) -> Array[String] {
  @regex.validate(model).iter().map(d => d.code).collect()
}

///|
test "invalid bounds, missing nodes, cycles and orphans are reported" {
  assert_eq(
    codes(
      @regex.Regex::new("r", "p", [
        @regex.Node::new("p", Repeat(@regex.Bounds::new(3, max=2), "a")),
        @regex.Node::new("a", Literal("a")),
      ]),
    ),
    ["regex/invalid-bounds"],
  )
  assert_eq(
    codes(@regex.Regex::new("r", "p", [@regex.Node::new("p", Group(Capturing, "x"))])),
    ["regex/missing-node"],
  )
  assert_eq(
    codes(
      @regex.Regex::new("r", "p", [
        @regex.Node::new("p", Group(Capturing, "q")),
        @regex.Node::new("q", Group(NonCapturing, "p")),
      ]),
    ),
    ["regex/containment-cycle"],
  )
  assert_eq(
    codes(
      @regex.Regex::new("r", "p", [
        @regex.Node::new("p", Literal("a")),
        @regex.Node::new("x", Literal("b")),
      ]),
    ),
    ["regex/orphan-node"],
  )
  assert_eq(
    codes(
      @regex.Regex::new("r", "p", [
        @regex.Node::new("p", Literal("a")),
        @regex.Node::new("p", Literal("b")),
      ]),
    ),
    ["regex/duplicate-identity"],
  )
}

///|
test "constructors copy caller arrays" {
  let nodes = [@regex.Node::new("p", Literal("a"))]
  let model = @regex.Regex::new("r", "p", nodes)
  nodes.push(@regex.Node::new("q", Literal("b")))
  assert_eq(model.nodes.length(), 1)
}
