///|
/// `(ab|ab)+c*` with two equal literal alternatives.
fn pattern() -> @regex.Regex {
  @regex.Regex::new("pattern", "s", [
    @regex.Node::new("s", Sequence(["r", "z"])),
    @regex.Node::new("r", Repeat(@regex.Bounds::new(1), "c")),
    @regex.Node::new("c", Choice(["a", "b"])),
    @regex.Node::new("a", Literal("ab")),
    @regex.Node::new("b", Literal("ab")),
    @regex.Node::new("z", Repeat(@regex.Bounds::new(0), "l")),
    @regex.Node::new("l", Literal("c")),
  ])
}

///|
fn grammar() -> @ebnf.Grammar {
  @ebnf.Grammar::new(
    "grammar",
    [
      Rule(@ebnf.Rule::new("r1", "list", body="x")),
      Rule(@ebnf.Rule::new("r2", "item", body="t")),
    ],
    [
      @ebnf.Node::new("x", Sequence(["i", "o"])),
      @ebnf.Node::new("i", Reference("item", None)),
      @ebnf.Node::new("o", ZeroOrMore("q")),
      @ebnf.Node::new("q", Sequence(["comma", "again"])),
      @ebnf.Node::new("comma", Terminal(",", Double)),
      @ebnf.Node::new("again", Reference("list", None)),
      @ebnf.Node::new("t", Terminal("x", Double)),
    ],
  )
}

///|
fn key(id : String, view~ : String = "pattern") -> String {
  @animation.railroad_key(view, id)
}

///|
test "equal literal terms in two branches have separate visit targets" {
  let catalog = @animation.Catalog::regex(pattern()).catalog.unwrap()
  let a = catalog.occurrence(key("a")).unwrap()
  let b = catalog.occurrence(key("b")).unwrap()
  assert_true(a.is_visit() && b.is_visit())
  assert_true(a.key != b.key)
  assert_eq(a.railroad_term.unwrap().label, b.railroad_term.unwrap().label)
  // Every drawn connector is a path occurrence.
  let paths = catalog.occurrences
    .iter()
    .filter(o => o.railroad_connector is Some(_))
    .count()
  assert_eq(
    paths,
    @railroad_trace.Topology::regex(pattern()).topology.unwrap().connectors.length(),
  )
}

///|
test "a node visit samples halfway without a path and wrong kinds are refused" {
  let catalog = @animation.Catalog::regex(pattern()).catalog.unwrap()
  let plan = @animation.PlaybackPlan::scenario(catalog, Visit(key("a"), 1000L)).plan.unwrap()
  let sample = plan.sample_at(500L)
  assert_eq(sample.active.length(), 1)
  assert_true(sample.active[0].visit)
  assert_eq(sample.active[0].numerator, 500L)
  let start = @railroad_trace.connector_id("pattern", Start)
  let wrong = @animation.PlaybackPlan::scenario(catalog, Step(key("a"), 1000L))
  assert_eq(wrong.diagnostics[0].code, "animation/invalid-target-kind")
  let also = @animation.PlaybackPlan::scenario(
    catalog,
    Visit(key(start), 1000L),
  )
  assert_eq(also.diagnostics[0].code, "animation/invalid-target-kind")
  // Existing connection steps keep their orientation.
  let step = @animation.PlaybackPlan::scenario(
    catalog,
    OrientedStep(key(start), 100L, true),
  ).plan.unwrap()
  assert_true(step.steps[0].reversed && !step.steps[0].visit)
}

///|
test "routes follow drawn branch, return and bypass connectors in order" {
  let catalog = @animation.Catalog::regex(pattern()).catalog.unwrap()
  let t = @railroad_trace.Topology::regex(pattern()).topology.unwrap()
  // From after the second branch back to before the choice: only the drawn
  // return path of the repeat connects them.
  let from = t.term("b").unwrap().exit
  let to = t.entry("c").unwrap()
  guard catalog.graph.route(from, to) is Found(route) else { fail("no route") }
  let roles = route.edges.map(e => {
    catalog.occurrence(e.occurrence.unwrap()).unwrap().kind
  })
  assert_true(roles.contains(Railroad(Return)))
  // A finite plan follows the route with visits for terms.
  let plan = @animation.PlaybackPlan::route(catalog, route).plan.unwrap()
  assert_eq(plan.steps.length(), route.edges.length())
  // The default illustration is finite even with unbounded repeats.
  let walk = @animation.PlaybackPlan::illustrative(catalog).plan.unwrap()
  assert_eq(walk.steps.length(), t.walk.length())
  assert_eq(walk.mode, Illustrative)
}

///|
test "grammar references are inspectable and add no route between rules" {
  let catalog = @animation.Catalog::ebnf(grammar()).catalog.unwrap()
  assert_eq(catalog.reference_target(key("i", view="grammar")), Some("r2"))
  assert_eq(catalog.reference_target(key("again", view="grammar")), Some("r1"))
  let t = @railroad_trace.Topology::ebnf(grammar()).topology.unwrap()
  let first = t.tracks[0]
  let second = t.tracks[1]
  assert_eq(catalog.graph.route(first.start, second.start), Unreachable)
  // The recursive reference stays one occurrence.
  let references = catalog.occurrences
    .iter()
    .filter(o => {
      o.railroad_term.map(t => t.kind is Reference(_)).unwrap_or(false)
    })
    .count()
  assert_eq(references, 2)
}

///|
fn data() -> @data_tree.DataTree {
  @data_tree.DataTree::new("data", "root", [
    @data_tree.Node::object("root", [
      @data_tree.Member::named("m1", "name", "v1"),
      @data_tree.Member::named("m2", "items", "v2"),
      @data_tree.Member::named("m3", "name", "v3"),
    ]),
    @data_tree.Node::new("v1", Text("same")),
    @data_tree.Node::array("v2", [
      @data_tree.Member::index("e0", 0, "v4"),
      @data_tree.Member::index("e1", 1, "v5"),
    ]),
    @data_tree.Node::new("v3", Text("same")),
    @data_tree.Node::new("v4", Number("12345678901234567890")),
    @data_tree.Node::new("v5", Number("12345678901234567890")),
  ])
}

///|
test "hierarchy routes combine row visits with drawn connectors only" {
  let catalog = @animation.Catalog::data_tree(data()).catalog.unwrap()
  guard catalog.graph.route("root", "v5") is Found(route) else { fail("route") }
  let plan = @animation.PlaybackPlan::route(catalog, route).plan.unwrap()
  let kinds = plan.steps.map(s => (s.visit, s.occurrence.kind))
  // root box, link to the array box, array box, then the inline row.
  assert_eq(kinds.length(), 4)
  assert_true(kinds[0].0 && kinds[2].0 && kinds[3].0)
  assert_eq(kinds[1].1, DataConnector)
  // Equal values create no relation; containment has a direction.
  assert_eq(catalog.graph.route("v1", "v3"), Unreachable)
  assert_eq(catalog.graph.route("v5", "root"), Unreachable)
  guard catalog.graph.route("v5", "root", direction=Reverse) is Found(_) else {
    fail("ancestor route")
  }
  // A search limit is not an unreachable result.
  assert_eq(
    catalog.graph.route("root", "v5", limits=@animation.Limits::new(work=2)),
    Failed(Limit(Work)),
  )
  assert_eq(
    catalog.graph.route("root", "nope"),
    Failed(InvalidEndpoint("nope")),
  )
  // Repeated values keep separate rows.
  assert_true(
    catalog.occurrence(@animation.data_key("data", "row", "e0")) is Some(_),
  )
  assert_true(
    catalog.occurrence(@animation.data_key("data", "row", "e1")) is Some(_),
  )
}

///|
test "a plan for one source does not match another catalog" {
  let a = @animation.Catalog::regex(pattern()).catalog.unwrap()
  let b = @animation.Catalog::data_tree(data()).catalog.unwrap()
  let plan = @animation.PlaybackPlan::illustrative(a).plan.unwrap()
  assert_true(plan.matches(a))
  assert_false(plan.matches(b))
}
