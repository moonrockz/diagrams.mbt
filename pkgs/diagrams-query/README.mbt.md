# moonrockz/diagrams-query

A portable, bounded structural query language for immutable trees. The syntax
borrows Tree-sitter node patterns, fields, alternations and captures. It is
not Tree-sitter compatible: it has its own grammar, a fixed set of native
predicates and domain semantics that a tree adapter declares. The root package
imports only MoonBit core and runs on wasm, wasm-gc, js and native. The
opt-in package `moonrockz/diagrams-query/bpmn` adapts the BPMN document tree of
`moonrockz/bpmn`. The Python package `diagrams.mbt` uses the same compiler and
evaluator through its native extension.

## Language version 1

```text
query     := rule+
rule      := captured | '(' captured predicate+ ')'
captured  := node capture*
node      := '(' selector part* ')' | '[' captured+ ']'
part      := captured | field ':' captured | '!' field
selector  := qualified-kind | 'category.' category | '_'
capture   := '@' capture-name
predicate := '(' predicate-name capture string* ')'
```

- An identifier has ASCII letters, digits, `_` and `-`, and starts with a
  letter or `_`. A qualified name is `prefix.local`; an unqualified name has no
  namespace. Capture names can also contain `.` after the first character.
- Strings use JSON escapes and keep Unicode values. `;` starts a comment to the
  end of the line. Whitespace separates tokens.
- The namespace map of the compile call binds query prefixes to namespace
  URIs. Source-document prefixes have no effect. `category` is not a prefix.

| Construct | Meaning |
| --- | --- |
| `(prefix.kind)` | A node of that exact kind |
| `(category.name)` | A node of that adapter category |
| `(_)` | Any node |
| `(a (b))` | `b` is a direct containment child of `a` |
| `(a (b) (c))` | Distinct children `b` then `c`, in increasing positions; other siblings can be between them |
| `(a f: (b))` | A direct child `b` in field `f` |
| `(a !f)` | `a` has no child in field `f` |
| `[(a) (b)]` | Alternatives, tried in source order |
| `@name` | Capture the node (for an alternation, the node that the chosen branch matched) |

### Native predicates

Predicates are conjunctive. They run after all captures of a match are bound.
A predicate whose capture is not bound by the chosen alternative is false.

| Predicate | Operands | True when |
| --- | --- | --- |
| `#has-attr?` | capture, attribute | The attribute is present |
| `#missing-attr?` | capture, attribute | The attribute is absent |
| `#attr-eq?` | capture, attribute, value | The attribute is present and its decoded value equals `value` |
| `#attr-not-eq?` | capture, attribute, value | The attribute is present and its value differs; absent is false |
| `#attr-in?` | capture, attribute, value+ | The attribute is present and its value is one of the values |
| `#text-eq?` | capture, value | The node has adapter scalar text equal to `value`; no descendant text is joined |

An unqualified attribute string such as `"name"` has no namespace. A string
such as `"vendor:flag"` uses the query namespace map. A missing attribute is
different from an empty one. Queries never run host callbacks or external
code; an unregistered predicate is a compile error.

### Matching and order

Candidate roots are the search root and its containment descendants, in
preorder. At each root, rules are tried in source order. Successful child
assignments are enumerated in lexicographic order of child positions, and
alternatives in source order. Equal matches from different rules or branches
stay distinct; nothing is de-duplicated. Captures of a match are reported in
source order of their capture sites; one node can have several capture roles.
Capture names are unique within each successful alternative and are scoped to
their rule. Matching follows only the containment that the adapter declares.
IDs, references, coordinates and labels never create child edges.

### Unsupported features

Version 1 refuses these features with a stable code and the query-source span.
It never interprets them partially.

| Feature | Code |
| --- | --- |
| Quantifiers `*`, `+`, `?` | `query/unsupported-quantifier` |
| Anchors `.` | `query/unsupported-anchor` |
| Directives such as `#set!` | `query/unsupported-directive` |
| Regular expressions such as `#match?` | `query/unsupported-regex` |
| Anonymous string nodes such as `"+"` | `query/unsupported-anonymous-node` |
| Sibling groups such as `((a) (b))` | `query/unsupported-grouping` |
| Other predicates such as `#eq?` | `query/unknown-predicate` |

`query_diagnostic_codes` lists every compile and projection code. A diagnostic
has a code, severity, message and, for query text, a half-open span. Offsets
and columns count UTF-16 code units; lines and columns start at 1. CRLF, LF
and CR each count as one line break. Forms built in code have no spans.

```mbt check
///|
test "unsupported features fail with stable codes" {
  let schema = @query.Schema::new(
    id="example/tree",
    version=1,
    kinds=[@query.Name::new("", "box")],
    categories=["thing"],
    fields=[],
  )
  for case in [
    ("(box)*", "query/unsupported-quantifier"),
    ("(box . (box))", "query/unsupported-anchor"),
    ("((box) @b (#set! @b \"k\"))", "query/unsupported-directive"),
    ("((box) @b (#match? @b \"x\"))", "query/unsupported-regex"),
    ("(box \"+\")", "query/unsupported-anonymous-node"),
    ("((box) (box))", "query/unsupported-grouping"),
    ("((box) @b (#eq? @b \"x\"))", "query/unknown-predicate"),
  ] {
    let diagnostics = @query.compile(case.0, schema).unwrap_err()
    assert_eq(diagnostics[0].code, case.1)
    assert_true(diagnostics[0].span is Some(_))
  }
}
```

## Tree adapters and schemas

An adapter implements `QueryTree` over integer nodes. It publishes a `Schema`:
an identifier and version, the kind, category and field inventory, the
reserved namespaces (whose names must be in the inventory), whether other
namespaces are open extensions, the scalar tags and the extra projection
fields. A plan records the schema identifier and version. A cursor over a tree
with another schema fails with `IncompatibleSchema` before it searches.

`compile` (query text) and `compile_form` (a typed `QueryForm`) use the same
checks and limits and give equal plans. `QueryPlan::normalized` is the public
normalized form, with expanded `{uri}local` names.

```mbt check
///|
struct Shelf {
  kinds : Array[String]
  children : Array[Array[Int]]
  names : Array[String?]
}

///|
let shelf_schema : @query.Schema = @query.Schema::new(
  id="example/shelf",
  version=1,
  kinds=[@query.Name::new("", "shelf"), @query.Name::new("", "book")],
  categories=["item"],
  fields=[@query.Name::new("", "holds")],
  reserved_namespaces=[""],
)

///|
impl @query.QueryTree for Shelf with schema(_self) {
  shelf_schema
}

///|
impl @query.QueryTree for Shelf with root(_self) {
  0
}

///|
impl @query.QueryTree for Shelf with node_count(self) {
  self.kinds.length()
}

///|
impl @query.QueryTree for Shelf with kind(self, node) {
  Some(@query.Name::new("", self.kinds[node]))
}

///|
impl @query.QueryTree for Shelf with category(_self, _node) {
  "item"
}

///|
impl @query.QueryTree for Shelf with children(self, node) {
  self.children[node][:]
}

///|
impl @query.QueryTree for Shelf with field(_self, node) {
  if node == 0 {
    None
  } else {
    Some(@query.Name::new("", "holds"))
  }
}

///|
impl @query.QueryTree for Shelf with attribute(self, node, name) {
  if name == @query.Name::new("", "name") {
    self.names[node].map(text => @query.ScalarValue::{ tag: "text", text })
  } else {
    None
  }
}

///|
impl @query.QueryTree for Shelf with text(_self, _node) {
  None
}

///|
impl @query.QueryTree for Shelf with extra(_self, _node, _name) {
  None
}

///|
impl @query.QueryTree for Shelf with location(_self, _node) {
  None
}

///|
impl @query.QueryTree for Shelf with path(_self, _node) {
  []
}

///|
impl @query.QueryTree for Shelf with depth(_self, node) {
  if node == 0 {
    0
  } else {
    1
  }
}

///|
test "text and typed queries give the same plan and matches" {
  let shelf = Shelf::{
    kinds: ["shelf", "book", "book"],
    children: [[1, 2], [], []],
    names: [None, Some("Dune"), Some("")],
  }
  let text = "((shelf holds: (book) @b) @s (#attr-eq? @b \"name\" \"Dune\"))"
  let form = @query.QueryForm::new([
    @query.Rule::new(
      @query.Pattern::node(
        Kind(@query.QName::new("shelf")),
        parts=[
          Field(
            @query.QName::new("holds"),
            @query.Pattern::node(Kind(@query.QName::new("book")), captures=["b"]),
          ),
        ],
        captures=["s"],
      ),
      predicates=[@query.Predicate::attr_eq("b", "name", "Dune")],
    ),
  ])
  let a = @query.compile(text, shelf_schema).unwrap()
  let b = @query.compile_form(form, shelf_schema).unwrap()
  assert_eq(a.normalized(), b.normalized())
  let result = a.collect(shelf)
  assert_eq(result, b.collect(shelf))
  assert_eq(result.matches.length(), 1)
  assert_eq(result.matches[0].captures.map(c => (c.name, c.node)).iter().to_array(), [
    ("b", 1),
    ("s", 0),
  ])
  // A missing name and an empty name are different.
  let empty = @query.compile("((book) @b (#attr-eq? @b \"name\" \"\"))", shelf_schema)
    .unwrap()
    .collect(shelf)
  assert_eq(empty.matches.map(m => m.captures[0].node).iter().to_array(), [2])
}
```

## Execution, projection and limits

`QueryPlan::execute` starts an independent `QueryCursor`. Plans are immutable
and reusable. `next_batch(n)` returns `Rows` with up to `n` matches, or a
terminal state: `Complete`, `Stopped` or `Failed(reason)`. `Rows` never claims
completion; when a terminal state is found after some rows, the next request
returns it. `stop` and `close` end a running cursor as `Stopped`; `close` is
idempotent. `QueryPlan::collect` runs a cursor to its end.

A `Projection` asks for fields of each captured node in one operation:
`kind`, `category`, `text`, `location`, `path`, `depth`, `field`,
`attr:<name>` and the adapter's extra fields. A field that a node does not have
is `Absent`, which differs from an empty string. An unknown field is an input
failure. Projection does not change matching or capture order.

| Bound | Default | Failure |
| --- | --- | --- |
| `CompileLimits.source_units` | 65,536 | `query/source-limit` |
| `CompileLimits.patterns`, `pattern_nodes`, `predicates` | 256, 4,096, 1,024 | `query/pattern-limit` |
| `CompileLimits.nesting` (at most 1,000) | 32 | `query/nesting-limit` |
| `CompileLimits.captures` | 256 | `query/capture-limit` |
| `ExecutionLimits.work` | 10,000,000 | `Failed(Limit(Work))` |
| `ExecutionLimits.pending` | 100,000 | `Failed(Limit(Pending))` |
| `ExecutionLimits.results` | 1,000,000 | `Failed(Limit(Results))` |
| `ExecutionLimits.output_units` | 100,000,000 | `Failed(Limit(Output))` |

Execution bounds are cumulative over all batches of a cursor; a new batch does
not reset them. `work` counts candidate nodes, matching steps, child probes
and predicate checks, so it bounds scans that find nothing. `pending` bounds
open partial matches, which grow with ambiguous child assignments. Exactly
`results` matches complete; one more fails. Matching uses heap stacks, so
deep trees do not use the host stack; a 10,000-level tree runs on all targets.

```mbt check
///|
test "batches, cumulative limits and truthful terminal states" {
  let shelf = Shelf::{
    kinds: ["shelf", "book", "book", "book"],
    children: [[1, 2, 3], [], [], []],
    names: [None, Some("a"), None, Some("b")],
  }
  let plan = @query.compile("(book) @b", shelf_schema).unwrap()
  let projection = @query.Projection::new(shelf_schema, [Attribute("name")]).unwrap()
  let cursor = plan.execute(shelf, projection~)
  guard cursor.next_batch(2) is Rows(first) else { fail("no rows") }
  assert_eq(first.length(), 2)
  assert_eq(first[1].captures[0].values[0], Absent)
  guard cursor.next_batch(2) is Rows(second) else { fail("no rows") }
  assert_eq(second.length(), 1)
  assert_true(cursor.next_batch(2) is Complete)
  // A work bound reached after a batch is a failure, not completion.
  let bounded = plan.execute(shelf, limits=@query.ExecutionLimits::new(work=5))
  guard bounded.next_batch(1) is Rows(_) else { fail("no rows") }
  assert_true(bounded.next_batch(10) is Failed(Limit(Work)))
  assert_true(bounded.next_batch(10) is Failed(Limit(Work)))
}
```

## Guidance

- Compile a plan once and reuse it; each cursor has its own position and
  budgets.
- Prefer a narrow candidate root and exact kinds over wildcards for large
  trees. Set `work` and `pending` for untrusted queries.
- Request only the projection fields that you need; paths are materialized
  only when requested.
- Stop or close a cursor when you have enough rows. A stopped or failed cursor
  is never complete, and the rows it delivered are not the full result.
- Use the explicit graph operations of the domain library for references and
  reachability; tree queries do not follow them.

See the [BPMN adapter](bpmn/README.mbt.md) for the BPMN schema.
