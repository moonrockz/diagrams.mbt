///|
fn first(text : String) -> String {
  match @query.compile(text, fs_schema, namespaces=[("x", "urn:x")]) {
    Ok(_) => "ok"
    Err(diagnostics) => {
      let d = diagnostics[0]
      let span = match d.span {
        Some(s) =>
          "\{s.start.offset}-\{s.end.offset} \{s.start.line}:\{s.start.column}-\{s.end.line}:\{s.end.column}"
        None => "-"
      }
      "\{d.code} \{span}"
    }
  }
}

///|
test "unsupported Tree-sitter features have stable codes and spans" {
  inspect(first("(file)*"), content="query/unsupported-quantifier 6-7 1:7-1:8")
  inspect(first("(dir (file)+ @f)"), content="query/unsupported-quantifier 11-12 1:12-1:13")
  inspect(first("(dir (file)? @f)"), content="query/unsupported-quantifier 11-12 1:12-1:13")
  inspect(first("(dir . (file))"), content="query/unsupported-anchor 5-6 1:6-1:7")
  inspect(
    first("((file) @f (#set! @f \"k\"))"),
    content="query/unsupported-directive 11-17 1:12-1:18",
  )
  inspect(
    first("((file) @f (#match? @f \"a.*\"))"),
    content="query/unsupported-regex 11-19 1:12-1:20",
  )
  inspect(
    first("((file) @f (#eq? @f \"a\"))"),
    content="query/unknown-predicate 11-24 1:12-1:25",
  )
  inspect(first("(dir \"+\")"), content="query/unsupported-anonymous-node 5-8 1:6-1:9")
  inspect(first("((file) (dir))"), content="query/unsupported-grouping 8-12 1:9-1:13")
  inspect(first("((file) @f)"), content="query/unsupported-grouping 0-11 1:1-1:12")
}

///|
test "malformed queries do not compile" {
  inspect(first(""), content="query/empty-query 0-0 1:1-1:1")
  inspect(first("  ; only a comment\n"), content="query/empty-query 0-19 1:1-2:1")
  inspect(first("(file"), content="query/syntax 5-5 1:6-1:6")
  inspect(first("(file))"), content="query/syntax 6-7 1:7-1:8")
  inspect(first("[]"), content="query/syntax 0-2 1:1-1:3")
  inspect(first("(1file)"), content="query/invalid-name 1-6 1:2-1:7")
  inspect(first("(a.b.c)"), content="query/invalid-name 1-6 1:2-1:7")
  inspect(first("(file) @"), content="query/invalid-name 7-8 1:8-1:9")
  inspect(first("((file) @f (#text-eq? @f \"x))"), content="query/unterminated-string 25-29 1:26-1:30")
  inspect(first("((file) @f (#text-eq? @f \"\\q\"))"), content="query/invalid-string 26-28 1:27-1:29")
  inspect(first("((file) @f (#text-eq? @f @f))"), content="query/predicate-arity 25-27 1:26-1:28")
  inspect(first("((file) @f (#text-eq? @f))"), content="query/predicate-arity 11-25 1:12-1:26")
  inspect(first("((file) @f (#attr-in? @f \"name\"))"), content="query/predicate-arity 11-32 1:12-1:33")
  inspect(first("(dir _)"), content="query/syntax 5-6 1:6-1:7")
}

///|
test "names resolve through the schema and the namespace map" {
  inspect(first("(folder)"), content="query/unknown-kind 1-7 1:2-1:8")
  inspect(first("(category.branch)"), content="query/unknown-category 1-16 1:2-1:17")
  inspect(first("(dir child: (file))"), content="query/unknown-field 5-10 1:6-1:11")
  inspect(first("(dir !child)"), content="query/unknown-field 6-11 1:7-1:12")
  inspect(first("(z.widget)"), content="query/unbound-prefix 1-9 1:2-1:10")
  inspect(first("((file) @f (#has-attr? @f \"z:flag\"))"), content="query/unbound-prefix 11-35 1:12-1:36")
  inspect(first("((file) @f (#has-attr? @g \"name\"))"), content="query/unknown-capture 11-33 1:12-1:34")
  inspect(first("(dir x.extra: (file))"), content="ok")
  // The namespace map itself is checked.
  let bad = @query.compile("(file)", fs_schema, namespaces=[("category", "urn:c")])
  inspect(bad.map_err(d => d[0].code).unwrap_err(), content="query/invalid-namespace-map")
  let dup = @query.compile("(file)", fs_schema, namespaces=[("a", "urn:a"), ("a", "urn:b")])
  inspect(dup.map_err(d => d[0].code).unwrap_err(), content="query/invalid-namespace-map")
}

///|
test "captures are unique within each successful alternative" {
  inspect(first("(dir (file) @a (file) @a)"), content="query/duplicate-capture 0-25 1:1-1:26")
  inspect(first("(dir (file) @a) @a"), content="query/duplicate-capture 0-18 1:1-1:19")
  // Different branches of one alternation may reuse a name.
  inspect(first("[(file) @a (link) @a]"), content="ok")
  inspect(first("[(file) @a (link) @a] @a"), content="query/duplicate-capture 0-24 1:1-1:25")
  // Capture scope is the rule: two rules may use the same name.
  inspect(first("(file) @a (link) @a"), content="ok")
  inspect(first("(file) @a ((link) @b (#has-attr? @a \"name\"))"), content="query/unknown-capture 21-43 1:22-1:44")
}

///|
test "query diagnostics count UTF-16 units and CRLF as one break" {
  // U+1D518 is two UTF-16 code units; CRLF is one line break.
  let text = "; \u{1D518}\r\n(file) @f\r\n(\u{1D518}"
  inspect(first(text), content="query/syntax 18-20 3:2-3:4")
  let lone_cr = "(file)\r(nope)"
  inspect(first(lone_cr), content="query/unknown-kind 8-12 2:2-2:6")
  // A string after a non-BMP literal keeps UTF-16 offsets.
  let s = "((file) @f (#text-eq? @f \"\u{1D518}\") (#bad? @f))"
  inspect(first(s), content="query/unknown-predicate 31-41 1:32-1:42")
}

///|
test "compile limits are explicit and checked before work" {
  let tight = @query.CompileLimits::new(source_units=5)
  let r = @query.compile("(file) @f", fs_schema, limits=tight)
  inspect(r.map_err(d => d[0].code).unwrap_err(), content="query/source-limit")
  let one = @query.CompileLimits::new(patterns=1)
  inspect(
    @query.compile("(file) (dir)", fs_schema, limits=one).map_err(d => d[0].code).unwrap_err(),
    content="query/pattern-limit",
  )
  let shallow = @query.CompileLimits::new(nesting=2)
  inspect(
    @query.compile("(dir (dir (file)))", fs_schema, limits=shallow).map_err(d => d[0].code).unwrap_err(),
    content="query/nesting-limit",
  )
  let few = @query.CompileLimits::new(captures=1)
  inspect(
    @query.compile("(dir (file) @a) @b", fs_schema, limits=few).map_err(d => d[0].code).unwrap_err(),
    content="query/capture-limit",
  )
  let small = @query.CompileLimits::new(pattern_nodes=2)
  inspect(
    @query.compile("(dir (dir (file)))", fs_schema, limits=small).map_err(d => d[0].code).unwrap_err(),
    content="query/pattern-limit",
  )
  let invalid = @query.CompileLimits::new(nesting=0)
  inspect(
    @query.compile("(file)", fs_schema, limits=invalid).map_err(d => d[0].code).unwrap_err(),
    content="query/invalid-limits",
  )
  // Deep query text stops at the nesting bound instead of using the host
  // stack for every level.
  let deep = "(dir " .repeat(5000) + ")".repeat(5000)
  inspect(
    @query.compile(deep, fs_schema).map_err(d => d[0].code).unwrap_err(),
    content="query/nesting-limit",
  )
}
