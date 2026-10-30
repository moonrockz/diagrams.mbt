///|
fn batches(
  plan : @query.QueryPlan,
  tree : FsTree,
  size : Int,
  limits? : @query.ExecutionLimits = @query.ExecutionLimits::new(),
  projection? : @query.Projection,
) -> (Array[@query.QueryMatch], @query.QueryBatch) raise {
  let cursor = plan.execute(tree, projection?, limits~)
  let all = []
  while true {
    match cursor.next_batch(size) {
      Rows(rows) => {
        assert_true(rows.length() <= size)
        all.append(rows.iter().to_array())
      }
      terminal => return (all, terminal)
    }
  }
  panic()
}

///|
test "text and typed forms give equal plans and results" {
  let source = "((dir (file) @f meta: (link) @l !meta) @d (#attr-eq? @f \"name\" \"a.mbt\"))\n[(file) (x.widget)] @any"
  let form = @query.QueryForm::new([
    @query.Rule::new(
      @query.Pattern::node(
        Kind(@query.QName::new("dir")),
        parts=[
          Child(@query.Pattern::node(Kind(@query.QName::new("file")), captures=["f"])),
          Field(
            @query.QName::new("meta"),
            @query.Pattern::node(Kind(@query.QName::new("link")), captures=["l"]),
          ),
          Absent(@query.QName::new("meta")),
        ],
        captures=["d"],
      ),
      predicates=[@query.Predicate::attr_eq("f", "name", "a.mbt")],
    ),
    @query.Rule::new(
      @query.Pattern::alternation(
        [
          @query.Pattern::node(Kind(@query.QName::new("file"))),
          @query.Pattern::node(Kind(@query.QName::new("widget", prefix="x"))),
        ],
        captures=["any"],
      ),
    ),
  ])
  let parsed = @query.parse(source).unwrap()
  assert_eq(parsed, form)
  let from_text = @query.compile(source, fs_schema, namespaces=[("x", "urn:x")]).unwrap()
  let from_form = @query.compile_form(form, fs_schema, namespaces=[("x", "urn:x")]).unwrap()
  assert_eq(from_text.normalized(), from_form.normalized())
  inspect(
    from_text.normalized(),
    content=(
      #|((dir (file) @f meta: (link) @l !meta) @d (#attr-eq? @f "name" "a.mbt"))
      #|[(file) ({urn:x}widget)] @any
    ),
  )
  assert_eq(from_text.collect(sample()), from_form.collect(sample()))
  // The typed form has the same checks; it reports no source spans.
  let bad = @query.QueryForm::new([
    @query.Rule::new(@query.Pattern::node(Kind(@query.QName::new("folder")))),
  ])
  let diagnostics = @query.compile_form(bad, fs_schema).unwrap_err()
  inspect(diagnostics[0].code, content="query/unknown-kind")
  assert_eq(diagnostics[0].span, None)
  let regex = @query.QueryForm::new([
    @query.Rule::new(
      @query.Pattern::node(Wildcard, captures=["n"]),
      predicates=[@query.Predicate::new("match?", "n", operands=["x"])],
    ),
  ])
  inspect(
    @query.compile_form(regex, fs_schema).unwrap_err()[0].code,
    content="query/unsupported-regex",
  )
  let arity = @query.QueryForm::new([
    @query.Rule::new(
      @query.Pattern::node(Wildcard, captures=["n"]),
      predicates=[@query.Predicate::attr_in("n", "name", [])],
    ),
  ])
  inspect(
    @query.compile_form(arity, fs_schema).unwrap_err()[0].code,
    content="query/predicate-arity",
  )
}

///|
test "plans are reusable and cursors are independent" {
  let p = plan("(file) @f")
  let tree = sample()
  let a = p.execute(tree)
  let b = p.execute(tree)
  guard a.next_batch(1) is Rows(first_a) else { fail("no rows") }
  guard b.next_batch(3) is Rows(first_b) else { fail("no rows") }
  inspect(first_a[0].captures[0].node, content="2")
  inspect(first_b.length(), content="3")
  a.stop()
  debug_inspect(a.next_batch(10), content="Stopped")
  guard b.next_batch(10) is Rows(rest_b) else { fail("no rows") }
  debug_inspect(rest_b[0].captures[0].node, content="7")
  debug_inspect(b.next_batch(10), content="Complete")
  b.close()
  b.close()
  debug_inspect(b.state(), content="Complete")
  // Closing a running cursor stops it; it never claims completion.
  let c = p.execute(tree)
  c.close()
  debug_inspect(c.next_batch(1), content="Stopped")
  // The plan runs again on another tree.
  let other = FsTree::new()
  other.add("file") |> ignore
  inspect(rows(p.collect(other)), content=(
    #|0: f=0
    #|complete
  ))
}

///|
test "batch size does not change meaning" {
  let p = plan("(_) @n (category.leaf) @leaf [(dir (_) @c) (file)] @x")
  let tree = big_tree(300)
  let (one, end_one) = batches(p, tree, 1)
  let (mid, end_mid) = batches(p, tree, 64)
  let (big, end_big) = batches(p, tree, 256)
  assert_eq(one, mid)
  assert_eq(one, big)
  assert_eq(end_one, Complete)
  assert_eq(end_mid, Complete)
  assert_eq(end_big, Complete)
  assert_eq(one, p.collect(tree).matches.iter().to_array())
  assert_true(one.length() > 600)
}

///|
test "a bound reached after a batch is a failure, and budgets are cumulative" {
  let p = plan("(_) @n")
  let tree = big_tree(300)
  let limits = @query.ExecutionLimits::new(work=200)
  let cursor = p.execute(tree, limits~)
  guard cursor.next_batch(10) is Rows(first) else { fail("expected rows") }
  inspect(first.length(), content="10")
  let mut total = first.length()
  let mut terminal = @query.QueryBatch::Complete
  while true {
    match cursor.next_batch(10) {
      Rows(rows) => total += rows.length()
      other => {
        terminal = other
        break
      }
    }
  }
  debug_inspect(terminal, content="Failed(Limit(Work))")
  assert_true(total < 300)
  // Asking again does not reset the budget or claim completion.
  debug_inspect(cursor.next_batch(10), content="Failed(Limit(Work))")
  debug_inspect(cursor.state(), content="Failed(Limit(Work))")
  // The result bound: exactly the bound is complete, more is a failure.
  let exact = p.collect(tree, limits=@query.ExecutionLimits::new(results=300))
  debug_inspect(exact.outcome, content="Complete")
  let over = p.collect(tree, limits=@query.ExecutionLimits::new(results=299))
  debug_inspect(over.outcome, content="Failed(Limit(Results))")
  inspect(over.matches.length(), content="299")
  // Output units count projected text.
  let projection = @query.Projection::new(fs_schema, [Kind, Attribute("name")]).unwrap()
  let out = p.collect(
    tree,
    projection~,
    limits=@query.ExecutionLimits::new(output_units=50),
  )
  debug_inspect(out.outcome, content="Failed(Limit(Output))")
  // Pending partial matches bound ambiguous child assignments.
  let wide = FsTree::new()
  let root = wide.add("dir")
  for _ in 0..<40 {
    wide.add("file", parent=root) |> ignore
  }
  let ambiguous = plan("(dir (file) (file) (file) (file))")
  let pending = ambiguous.collect(wide, limits=@query.ExecutionLimits::new(pending=3))
  debug_inspect(pending.outcome, content="Failed(Limit(Pending))")
  let work = ambiguous.collect(wide, limits=@query.ExecutionLimits::new(work=5000))
  debug_inspect(work.outcome, content="Failed(Limit(Work))")
  // Work limits bound scans that find nothing.
  let none = plan("(x.widget) @w").collect(
    big_tree(300),
    limits=@query.ExecutionLimits::new(work=50),
  )
  debug_inspect(none.outcome, content="Failed(Limit(Work))")
  inspect(none.matches.length(), content="0")
  debug_inspect(
    p.collect(tree, limits=@query.ExecutionLimits::new(work=0)).outcome,
    content="Failed(InvalidLimits)",
  )
}

///|
test "incompatible schemas and invalid roots are refused without searching" {
  let other_schema = @query.Schema::new(
    id="test/fs",
    version=2,
    kinds=[@query.Name::new("", "file")],
    categories=[],
    fields=[],
  )
  let p = @query.compile("(file)", other_schema).unwrap()
  let cursor = p.execute(sample())
  debug_inspect(
    cursor.next_batch(1),
    content=(
      #|Failed(IncompatibleSchema(expected="test/fs@2", actual="test/fs@1"))
    ),
  )
  inspect(cursor.work(), content="0")
  debug_inspect(
    plan("(file)").collect(sample(), root=99).outcome,
    content="Failed(InvalidRoot)",
  )
  // A projection for another schema is refused too.
  let projection = @query.Projection::identity(other_schema)
  debug_inspect(
    plan("(file)").collect(sample(), projection~).outcome,
    content=(
      #|Failed(IncompatibleSchema(expected="test/fs@2", actual="test/fs@1"))
    ),
  )
}

///|
test "a subtree search includes its root and keeps document-relative paths" {
  let projection = @query.Projection::new(fs_schema, [Path, Depth]).unwrap()
  let result = plan("(file) @f").collect(sample(), root=1, projection~)
  inspect(rows(result), content=(
    #|0: f=2
    #|0: f=3
    #|complete
  ))
  debug_inspect(
    result.matches[1].captures[0].values.iter().to_array(),
    content=(
      #|[
      #|  Path(
      #|    <ReadOnlyArray:
      #|      [
      #|        {
      #|          field: { namespace_uri: "", local_name: "entry" },
      #|          index: 0,
      #|          position: 0,
      #|        },
      #|        {
      #|          field: { namespace_uri: "", local_name: "entry" },
      #|          index: 1,
      #|          position: 1,
      #|        },
      #|      ]>,
      #|  ),
      #|  Int(2),
      #|]

    ),
  )
}

///|
test "projection keeps absent, empty and scalar distinctions" {
  let projection = @query.Projection::new(fs_schema, [
    Kind,
    Category,
    Text,
    Field,
    Attribute("name"),
    Extra("size"),
    Location,
  ]).unwrap()
  let result = plan("(file) @f").collect(sample(), projection~)
  debug_inspect(
    result.matches[1].captures[0].values.iter().to_array(),
    content=(
      #|[
      #|  Name({ namespace_uri: "", local_name: "file" }),
      #|  Text("leaf"),
      #|  Text(""),
      #|  Name({ namespace_uri: "", local_name: "entry" }),
      #|  Scalar({ tag: "text", text: "" }),
      #|  Scalar({ tag: "number", text: "0" }),
      #|  Absent,
      #|]
    ),
  )
  debug_inspect(
    result.matches[2].captures[0].values.iter().to_array(),
    content=(
      #|[
      #|  Name({ namespace_uri: "", local_name: "file" }),
      #|  Text("leaf"),
      #|  Absent,
      #|  Name({ namespace_uri: "", local_name: "entry" }),
      #|  Absent,
      #|  Absent,
      #|  Absent,
      #|]
    ),
  )
  // Field selection does not change matching or capture order.
  assert_eq(
    result.matches.map(m => m.captures.map(c => c.node)),
    plan("(file) @f").collect(sample()).matches.map(m => m.captures.map(c => c.node)),
  )
  // Unknown fields are input failures, not absent data.
  let unknown = @query.Projection::new(fs_schema, [Extra("owner")])
  inspect(unknown.map_err(d => d[0].code).unwrap_err(), content="query/unknown-projection-field")
  let unbound = @query.Projection::new(fs_schema, [Attribute("v:flag")])
  inspect(unbound.map_err(d => d[0].code).unwrap_err(), content="query/unbound-prefix")
  debug_inspect(@query.FieldRequest::parse("attr:v:flag"), content="Attribute(\"v:flag\")")
  debug_inspect(@query.FieldRequest::parse("id"), content="Extra(\"id\")")
}

///|
/// A tree with `n` nodes: dirs with files, links and nested dirs.
fn big_tree(n : Int) -> FsTree {
  let t = FsTree::new()
  t.add("dir", attrs=[("name", "root")]) |> ignore
  for i in 1..<n {
    let parent = (i - 1) / 3
    let parent = if t.nodes[parent].kind == "dir" { parent } else { 0 }
    let kind = match i % 4 {
      0 => "dir"
      1 => "file"
      2 => "dir"
      _ => "link"
    }
    let field = if i % 5 == 0 { "meta" } else { "entry" }
    let attrs = if i % 3 == 0 { [] } else { [("name", "n\{i % 7}")] }
    t.add(kind, parent~, field~, attrs~) |> ignore
  }
  t
}

///|
test "10,000-depth trees match without host-stack recursion" {
  let t = FsTree::new()
  let mut parent = t.add("dir")
  for i in 1..<10000 {
    parent = t.add(if i == 9999 { "file" } else { "dir" }, parent~)
  }
  let result = plan("(dir (file) @f) @d").collect(t)
  inspect(rows(result), content=(
    #|0: f=9999 d=9998
    #|complete
  ))
  let all = plan("(_) @n").collect(t)
  inspect(all.matches.length(), content="10000")
  let projection = @query.Projection::new(fs_schema, [Depth]).unwrap()
  let deepest = plan("(file) @f").collect(t, projection~)
  debug_inspect(deepest.matches[0].captures[0].values.iter().to_array(), content="[Int(9999)]")
}
