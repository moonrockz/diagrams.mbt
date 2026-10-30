///|
test "an exact kind captures every candidate in preorder" {
  inspect(
    run("(file) @f"),
    content=(
      #|0: f=2
      #|0: f=3
      #|0: f=5
      #|0: f=7
      #|complete
    ),
  )
}

///|
test "categories and wildcards are distinct selectors" {
  inspect(
    run("(category.container) @c"),
    content=(
      #|0: c=0
      #|0: c=1
      #|0: c=6
      #|complete
    ),
  )
  inspect(run("(_) @n").split("\n").to_array().length(), content="9")
}

///|
test "direct children only, in lexicographic child order" {
  // The root has no file grandchildren in this constraint.
  inspect(
    run("(dir (file) @f) @d"),
    content=(
      #|0: f=5 d=0
      #|0: f=2 d=1
      #|0: f=3 d=1
      #|0: f=7 d=6
      #|complete
    ),
  )
  // Two child patterns take distinct children in increasing positions and
  // allow siblings between them.
  inspect(
    run("(dir (file) @a (link) @b)"),
    content=(
      #|0: a=2 b=4
      #|0: a=3 b=4
      #|complete
    ),
  )
  inspect(
    run("(dir (file) @a (file) @b)"),
    content=(
      #|0: a=2 b=3
      #|complete
    ),
  )
}

///|
test "fields constrain the containing field; absent fields need no child" {
  inspect(
    run("(dir meta: (_) @m) @d"),
    content=(
      #|0: m=4 d=1
      #|complete
    ),
  )
  inspect(
    run("(dir !meta) @d"),
    content=(
      #|0: d=0
      #|0: d=6
      #|complete
    ),
  )
  inspect(
    run("(dir entry: (link)) @d"),
    content=(
      #|
      #|complete
    ),
  )
}

///|
test "alternations keep source order and overlapping patterns stay distinct" {
  inspect(
    run("[(file) (link)] @x"),
    content=(
      #|0: x=2
      #|0: x=3
      #|0: x=4
      #|0: x=5
      #|0: x=7
      #|complete
    ),
  )
  // Two branches can match the same node; both results are kept.
  inspect(
    run("[(file) @a (category.leaf) @b]"),
    content=(
      #|0: a=2
      #|0: b=2
      #|0: a=3
      #|0: b=3
      #|0: b=4
      #|0: a=5
      #|0: b=5
      #|0: a=7
      #|0: b=7
      #|complete
    ),
  )
  // Two source patterns that match one node give two pattern indices.
  inspect(
    run("(link) @l\n(category.leaf) @l"),
    content=(
      #|1: l=2
      #|1: l=3
      #|0: l=4
      #|1: l=4
      #|1: l=5
      #|1: l=7
      #|complete
    ),
  )
}

///|
test "one node can have two capture roles" {
  let result = plan("(link) @a @b").collect(sample())
  inspect(rows(result), content=(
    #|0: a=4 b=4
    #|complete
  ))
}

///|
test "native predicates distinguish missing and empty attributes" {
  inspect(
    run("((file) @f (#has-attr? @f \"name\"))"),
    content=(
      #|0: f=2
      #|0: f=3
      #|0: f=7
      #|complete
    ),
  )
  inspect(
    run("((file) @f (#missing-attr? @f \"name\"))"),
    content=(
      #|0: f=5
      #|complete
    ),
  )
  inspect(
    run("((file) @f (#attr-eq? @f \"name\" \"\"))"),
    content=(
      #|0: f=3
      #|complete
    ),
  )
  // Absent attributes are false for both equality and inequality.
  inspect(
    run("((file) @f (#attr-not-eq? @f \"name\" \"\"))"),
    content=(
      #|0: f=2
      #|0: f=7
      #|complete
    ),
  )
  inspect(
    run("((_) @f (#attr-in? @f \"name\" \"src\" \"docs\"))"),
    content=(
      #|0: f=1
      #|0: f=6
      #|complete
    ),
  )
  inspect(
    run("((file) @f (#text-eq? @f \"\"))"),
    content=(
      #|0: f=3
      #|complete
    ),
  )
  // A node without scalar text never matches #text-eq?.
  inspect(
    run("((dir) @f (#text-eq? @f \"\"))"),
    content=(
      #|
      #|complete
    ),
  )
}

///|
test "predicates on a capture of an unselected branch are false" {
  inspect(
    run("([(link) @l (file) @f] (#has-attr? @f \"name\"))"),
    content=(
      #|0: f=2
      #|0: f=3
      #|0: f=7
      #|complete
    ),
  )
}

///|
test "extension namespaces resolve through the query namespace map" {
  let t = sample()
  t.add("widget", parent=6, ns="urn:x", attrs=[("name", "w")]) |> ignore
  inspect(
    run("(x.widget) @w", tree=t),
    content=(
      #|0: w=8
      #|complete
    ),
  )
  // A different prefix bound to the same URI selects the same nodes.
  let other = @query.compile("(y.widget) @w", fs_schema, namespaces=[
    ("y", "urn:x"),
  ]).unwrap()
  inspect(rows(other.collect(t)), content=(
    #|0: w=8
    #|complete
  ))
  // An extension name that no document contains still compiles.
  inspect(codes("(x.anything)"), content="ok")
  // The reserved empty namespace needs declared names.
  inspect(codes("(widget)"), content="query/unknown-kind")
}

///|
test "tree matching follows containment only" {
  // link 4 refers to a.mbt by attribute; that is not a child edge.
  inspect(
    run("(link (_) @target)"),
    content=(
      #|
      #|complete
    ),
  )
}
