---
title: Tree queries in MoonBit and Python
summary: Select and project BPMN document nodes with the portable query language, with paired MoonBit and Python examples.
order: 4
---
# Tree queries in MoonBit and Python

The query language is a MoonBit library feature: `moonrockz/diagrams-query`
compiles and runs queries, and `moonrockz/diagrams-query/bpmn` adapts the BPMN
document tree. The Python module `diagrams_mbt.query` calls the same compiler
and evaluator in the native extension. Python has no second evaluator and no
Python predicates. Equal query text, namespace bindings and limits give equal
plans, matches, projected values, diagnostics and terminal states.

The [package README](../../pkgs/diagrams-query/README.mbt.md) has the full
version 1 grammar, the predicate table and the unsupported features. The
[BPMN adapter README](../../pkgs/diagrams-query/bpmn/README.mbt.md) has the
schema inventory.

The Python examples on this page run in order, in one namespace. The test
`test_doc_examples.py` runs them. This setup block gives their `source`:

```python
# Setup: the BPMN source of the examples on this page.
source = """<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" targetNamespace="urn:order">
  <bpmn:process id="Order">
    <bpmn:userTask id="Approve" name="Approve"/>
    <bpmn:userTask id="Review" name="Review"/>
  </bpmn:process>
</bpmn:definitions>"""
```

## Compile and run a query

MoonBit:

```moonbit
let document = @bpmn.read(source, source_id="order.bpmn").document.unwrap()
let tree = @query_bpmn.BpmnTree::new(@bpmn.DocumentTree::new(document).tree.unwrap())
let plan = @query_bpmn.compile(
  "((bpmn.userTask) @task (#attr-eq? @task \"name\" \"Approve\"))",
).unwrap()
let projection = @query.Projection::new(@query_bpmn.schema, [Extra("id"), Location]).unwrap()
let result = plan.collect(tree, projection~)
for m in result.matches {
  let node = tree.captured(m.captures[0]) // the original NodeRef
  println(node.id())
}
```

Python:

```python
from diagrams_mbt import bpmn, query

document = bpmn.read(source, source_id="order.bpmn").document
tree = document.tree().tree
plan = query.compile('((bpmn.userTask) @task (#attr-eq? @task "name" "Approve"))')
result = plan.collect(tree, fields=("id", "location"))
for m in result.matches:
    capture = m.captures[0]
    print(capture.node.id, capture.get("id"), capture.get("location"))
assert result.state == "complete"
assert [m.captures[0].node.id for m in result.matches] == ["Approve"]
```

`capture.node` is a `bpmn.Node` view of the same revision and ordinal as a walk
gives. It keeps its tree alive after you drop the local variables.

## Typed construction

Typed construction and query text use the same checks.

```moonbit
let form = @query.QueryForm::new([
  @query.Rule::new(
    @query.Pattern::node(Kind(@query.QName::new("userTask", prefix="bpmn")), captures=["task"]),
    predicates=[@query.Predicate::attr_eq("task", "name", "Approve")],
  ),
])
let plan = @query_bpmn.compile_form(form) // or @query.compile_form(form, @query_bpmn.schema, namespaces~)
```

```python
form = query.QueryForm((
    query.Rule(
        query.NodePattern(query.Kind(query.QName("userTask", "bpmn")), captures=("task",)),
        (query.Predicate.attr_eq("task", "name", "Approve"),),
    ),
))
plan = query.compile_form(form)
assert plan.normalized == query.compile(
    '((bpmn.userTask) @task (#attr-eq? @task "name" "Approve"))'
).normalized
```

## Batches and terminal states

| MoonBit | Python | Meaning |
| --- | --- | --- |
| `plan.execute(tree, root?, projection?, limits?)` | `plan.execute(tree_or_node, fields=..., namespaces=..., limits=...)` | Start an independent cursor below the root, including it |
| `cursor.next_batch(n)` gives `Rows(rows)` | `cursor.next_batch(n)` gives `QueryBatch("rows", rows)` | Up to `n` matches; never a claim of completion |
| `Complete`, `Stopped`, `Failed(reason)` | `QueryBatch("complete")`, `("stopped")`, `("failed", failure=...)` | Terminal states |
| `cursor.stop()`, `cursor.close()` | `cursor.stop()`, `cursor.close()` | Stop; close is idempotent |
| `plan.collect(...)` | `plan.collect(...)` | Run to the end; `QueryResult.state` tells if it completed |

Limits are cumulative over all batches of a cursor. A limit reached after a
delivered batch gives `failed` with the exhausted bound (`work`, `pending`,
`results` or `output`). A new batch request does not reset a budget.

## Values and failures

| MoonBit | Python |
| --- | --- |
| `QueryDiagnostic { code, severity, message, span }` | `QueryDiagnostic(code, severity, message, span)` in `QueryCompileError.diagnostics`; `QueryCompileError` is a `ValueError` |
| `QuerySpan` with UTF-16 `offset`, 1-based `line` and `column` | `diagrams_mbt.Span` with the same numbers; `diagrams_mbt.code_point_index` converts an offset |
| `Projected::Absent` | `None` |
| `Text(s)` | `str` |
| `Scalar({ tag, text })` | `query.Scalar(tag, text)` |
| `Name({ namespace_uri, local_name })` | `query.Name(namespace_uri, local_name)` |
| `Int(n)` | `int` |
| `Location({ source_id, start, end })` | `query.Location(source_id, start, end)` |
| `Path(steps)` | `tuple[query.PathStep, ...]` |
| `CompileLimits::new(...)`, `ExecutionLimits::new(...)` | `query.CompileLimits(...)`, `query.ExecutionLimits(...)` with the same defaults |
| An unknown projection field (`Projection::new` gives `Err`) | `QueryCompileError` with `query/unknown-projection-field` |
| Closed plan or cursor | `diagrams_mbt._boundary.ClosedError` |
| Concurrent `next_batch` on one cursor | `diagrams_mbt._boundary.BusyError`; other cursors stay usable |

`query.compile` and `query.compile_form` add the BPMN default prefixes
(`bpmn`, `bpmndi`, `dc`, `di`, `tree`) to your bindings, like
`@query_bpmn.compile`. A binding that repeats a default prefix fails with
`query/invalid-namespace-map`.

## Performance notes

A query runs its candidate search, predicates and projection in one native
call per batch. It calls no Python code for each candidate node. The GIL is
released during the native work and while a call waits for the runtime lock.
Native work is serialized: two threads do not run MoonBit code at the same
time. See [concurrency](concurrency.md).
