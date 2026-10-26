///|
test "a constructed grammar keeps a recursive reference symbolic" {
  let grammar = @ebnf.Grammar::new(
    "lists",
    [Rule(@ebnf.Rule::new("r", "list", body="s"))],
    [
      @ebnf.Node::new("s", Sequence(["x", "o"])),
      @ebnf.Node::new("x", Terminal("x", Double)),
      @ebnf.Node::new("o", Optional("again")),
      @ebnf.Node::new("again", Reference("list", None)),
    ],
  )
  let index = @ebnf.Index::build(grammar).index.unwrap()
  assert_eq(index.resolution("again"), Some(Resolved("r")))
  assert_eq(grammar.nodes.length(), 4)
}

///|
test "constructors copy caller arrays" {
  let nodes = [@ebnf.Node::new("t", Terminal("a", Single))]
  let items : Array[@ebnf.Item] = [Rule(@ebnf.Rule::new("r", "a", body="t"))]
  let grammar = @ebnf.Grammar::new("g", items, nodes)
  nodes.push(@ebnf.Node::new("u", Empty))
  items.clear()
  assert_eq(grammar.nodes.length(), 1)
  assert_eq(grammar.items.length(), 1)
  assert_eq(@ebnf.validate(grammar).length(), 0)
}

///|
fn codes(grammar : @ebnf.Grammar) -> Array[String] {
  @ebnf.validate(grammar).iter().map(d => d.code).collect()
}

///|
test "validation reports invalid constructed grammars without recursion" {
  let rule : @ebnf.Item = Rule(@ebnf.Rule::new("r", "a", body="s"))
  assert_eq(
    codes(@ebnf.Grammar::new("g", [rule], [@ebnf.Node::new("s", Sequence(["missing"]))])),
    ["ebnf/missing-node"],
  )
  // A containment cycle.
  assert_eq(
    codes(
      @ebnf.Grammar::new("g", [rule], [
        @ebnf.Node::new("s", Optional("o")),
        @ebnf.Node::new("o", ZeroOrMore("s")),
      ]),
    ),
    ["ebnf/containment-cycle"],
  )
  // A count must be decimal.
  assert_eq(
    codes(
      @ebnf.Grammar::new("g", [rule], [
        @ebnf.Node::new("s", Count("n", "t")),
        @ebnf.Node::new("t", Terminal("x", Double)),
      ]),
    ),
    ["ebnf/invalid-count"],
  )
  // An explicit target must name a rule; a name alone may stay unresolved.
  assert_eq(
    codes(@ebnf.Grammar::new("g", [rule], [@ebnf.Node::new("s", Reference("x", Some("nope")))])),
    ["ebnf/invalid-reference"],
  )
  assert_eq(
    codes(@ebnf.Grammar::new("g", [rule], [@ebnf.Node::new("s", Reference("x", None))])),
    ["ebnf/unresolved-reference"],
  )
  // An exclusion keeps both terms and validation terminates on recursion.
  let grammar = @ebnf.Grammar::new("g", [rule], [
    @ebnf.Node::new("s", Exclusion("l", "x")),
    @ebnf.Node::new("l", Reference("a", None)),
    @ebnf.Node::new("x", Terminal("b", Double)),
  ])
  assert_eq(codes(grammar), [])
  // An orphan node.
  assert_eq(
    codes(
      @ebnf.Grammar::new("g", [rule], [
        @ebnf.Node::new("s", Empty),
        @ebnf.Node::new("lost", Empty),
      ]),
    ),
    ["ebnf/orphan-node"],
  )
  // Explicit limits.
  let deep = @ebnf.Grammar::new("g", [rule], [
    @ebnf.Node::new("s", Optional("o")),
    @ebnf.Node::new("o", Optional("t")),
    @ebnf.Node::new("t", Terminal("x", Double)),
  ])
  assert_eq(
    @ebnf.validate(deep, limits=@ebnf.Limits::new(depth=1))[0].code,
    "ebnf/model-limit",
  )
  assert_eq(
    @ebnf.validate(deep, limits=@ebnf.Limits::new(work=2))[0].code,
    "ebnf/model-limit",
  )
}

///|
test "two rules with one name make references ambiguous" {
  let grammar = @ebnf.Grammar::new(
    "g",
    [
      Rule(@ebnf.Rule::new("r1", "a", body="x")),
      Rule(@ebnf.Rule::new("r2", "a", body="y")),
      Rule(@ebnf.Rule::new("r3", "b", body="z")),
    ],
    [
      @ebnf.Node::new("x", Terminal("1", Double)),
      @ebnf.Node::new("y", Terminal("2", Double)),
      @ebnf.Node::new("z", Reference("a", None)),
    ],
  )
  let index = @ebnf.Index::build(grammar).index.unwrap()
  assert_true(index.resolution("z") is Some(Ambiguous(_)))
  assert_eq(codes(grammar), ["ebnf/ambiguous-reference"])
}
