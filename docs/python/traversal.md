---
title: BPMN traversal in Python
summary: Read BPMN, inspect nodes and walk, visit, reduce, cursor and query graphs with diagrams_mbt.bpmn, mapped to the MoonBit API.
order: 4
---
# BPMN traversal in Python

The module `diagrams_mbt.bpmn` gives Python the BPMN reading, inspection,
traversal and graph-query operations of the MoonBit module `moonrockz/bpmn`.
Each Python operation calls the same MoonBit function in the native library.
Python adds no BPMN rule and no other default.

> The package is experimental (0.0.x). Its API can change in any release.

## Read a document and walk it

MoonBit:

```moonbit
let read = @bpmn.read(source, source_id="orders.bpmn")
let tree = @bpmn.DocumentTree::new(read.document.unwrap()).tree.unwrap()
@bpmn.walk(tree.root(), node => {
  if node.id() == Some("Ship") { SkipChildren } else { Continue }
}, leave=node => println(node.id()))
```

Python:

```python
from diagrams_mbt import bpmn
from diagrams_mbt.bpmn import Control

read = bpmn.read(source, source_id="orders.bpmn")
tree = read.document.tree().tree
bpmn.walk(
    tree.root(),
    lambda node: Control.SKIP_CHILDREN if node.id == "Ship" else Control.CONTINUE,
    lambda node: print(node.id),
)
```

`read` returns a `ReadResult`. Its `document` is `None` after an XML syntax
error; its `diagnostics` keep their spans and locations. `tree()` returns a
`TreeBuildResult` with `tree` and `diagnostics`; `tree` is `None` when a
traversal limit stops the build.

## Visit only the families you need

MoonBit:

```moonbit
struct Tasks { names : Array[String] }

impl @bpmn.Visitor for Tasks with visit_activity(self, activity, node) {
  self.names.push(activity.element.kind.local_name())
  Continue
}

let tasks = Tasks::{ names: [] }
@bpmn.accept(tree.root(), tasks)
```

Python:

```python
class Tasks(bpmn.Visitor):
    def __init__(self):
        self.names = []

    def visit_activity(self, value, node):
        self.names.append(value.kind.local_name)
        return Control.CONTINUE

tasks = Tasks()
bpmn.accept(tree.root(), tasks)
```

`accept` finds the methods that the subclass overrides once per traversal. It
never calls a method that the subclass does not override. `enter` runs first.
When `enter` returns `CONTINUE`, the family method of the node's category runs.
`leave` runs for each visited node, also when its children were skipped.
Typed family methods receive an `ElementView` as `value`. It reads its fields
from the native library only when you use them.

## Query a graph with a selected node

MoonBit:

```moonbit
let graph = @bpmn.DocumentGraph::new(document).graph.unwrap()
let task = tree.root() // a node from a walk, query or cursor
match graph.route(Node(task.handle()), Id("End")) {
  Found(route) => println(route.nodes.length())
  Unreachable => println("no route")
  Failed(failure) => println(failure)
}
```

Python:

```python
graph = bpmn.DocumentGraph.new(document).graph
result = graph.route(bpmn.GraphEndpoint.node(task), bpmn.GraphEndpoint.id("End"))
if result.status == "Found":
    print(len(result.route.nodes))
elif result.status == "Failed":
    print(result.failure.kind)
```

A node endpoint is a revision-bound handle. It never falls back to the node's
ID, so it selects one node when two nodes have the same ID. An `id` endpoint
still reports `Ambiguous`.

## Compatibility map

Each row maps a public MoonBit operation to its Python operation. "Same" means
the same name in snake case.

### Reading, owners and nodes

| MoonBit | Python | Notes |
| --- | --- | --- |
| `read(source, source_id?, limits?)` | `read(source, source_id=None, limits=None) -> ReadResult` | `ReadResult(document, diagnostics)`. No I/O. |
| `Limits::new(...)` | `Limits(source_units=None, ...)` | `None` keeps the MoonBit default. `Limits.defaults()` gives the values. |
| `DocumentTree::new(document, resource_id?, limits?)` | `DocumentTree.new(document, resource_id=None, limits=None)`, `document.tree(...)` | `TreeBuildResult(tree, diagnostics)` |
| `tree.root()`, `tree.length()`, `tree.resource_id()` | `tree.root()`, `tree.length`, `tree.resource_id` | `tree.node(ordinal)` gives the node at a preorder ordinal. |
| `tree.lookup(handle)` | `tree.lookup(handle)` | `NodeLookup(status, node)`: `Found`, `DocumentMismatch` or `InvalidHandle` |
| `NodeRef::value` | `node.value` | `NodeValue(kind, text, target, data)` |
| `NodeRef::element` | `node.element()` | `ElementView` or `None` |
| `NodeRef::kind` | `node.kind`, `node.kind_class` | `ExpandedName` or `None`; `standard`, `foreign` or `unknown` |
| `NodeRef::category` | `node.category` | `Category`; values are the MoonBit names |
| `NodeRef::id`, `depth`, `span`, `step` | `node.id`, `node.depth`, `node.span`, `node.step` | Snapshot values; no native call |
| `NodeRef::attributes` | `node.attributes()` | Present attributes only, in source order |
| `NodeRef::scalar(name)` | `node.scalar(ExpandedName(ns, local))` | `Scalar(tag, token, detail)` or `None` |
| `NodeRef::fields`, `field(f)` | `node.fields()`, `node.field(f)` | `NodeField(field, attributes, children)`; no absent defaults |
| `NodeRef::children`, `parent` | `node.children()`, `node.parent()` | |
| `NodeRef::location` | `node.location()` | `None` for constructed content |
| `NodeRef::resource_id` | `node.resource_id` | |
| `NodeRef::path`, `NodePath::steps`, `depth`, `resolve` | `node.path()`, `.steps()`, `.depth`, `.resolve(tree)` | Document-relative |
| `NodeRef::handle` | `node.handle` | `NodeHandle(tree, ordinal)`; equal only in the same revision |

`Scalar.tag` is the MoonBit constructor name: `Text`, `Identifier`, `Uri`,
`Boolean`, `Integer`, `Number`, `Reference`, `Enumeration` or `Invalid`.
`Scalar.token` is `Scalar::token`. `Scalar.detail` is `None`, a `bool`, a
`Reference(kind, spelling, name)`, the enumeration type `ExpandedName` or an
`InvalidScalar(raw, expected)`. `PathField.kind` is `Named` (with `name`),
`Text`, `Comment`, `ProcessingInstruction`, `Root`, `Prolog` or `Epilog`.

### Traversal

| MoonBit | Python | Notes |
| --- | --- | --- |
| `Control::Continue`, `SkipChildren`, `Stop` | `Control.CONTINUE`, `SKIP_CHILDREN`, `STOP` | Another return value raises `TypeError` |
| `walk(root, enter, leave?)` | `walk(root, enter, leave=None)` | |
| `fold(root, initial, enter, leave?)` | `fold(root, initial, enter, leave=None)` | `enter` returns `(value, control)` |
| `reduce(root, combine)` | `reduce(root, combine)` | `combine(node, children_tuple)`; bottom up |
| `reduce_pruned(root, enter, combine)` | `reduce_pruned(root, enter, combine)` | A skipped node gets `()`; `None` after stop |
| `Visitor`, `accept(root, visitor)` | `Visitor`, `accept(root, visitor)` | Same method names: `enter`, `leave`, `visit_definitions` to `visit_other` |
| `EventReader::new(root)`, `next`, `skip_children`, `stop`, `iter` | `EventReader(root)`, `next()`, `skip_children()`, `stop()`, iteration | `Enter(node)` and `Leave(node)` events |
| (none) | `EventReader.next_batch(size)`, `batches(size)` | Observational; never applies a control. `size` is 1 to 4096 |
| `EventSource`, `push_events(source, enter, leave?)` | `EventSource` protocol, `push_events(source, enter, leave=None)` | Any object with `next`, `skip_children` and `stop`, also a Python one |
| `TreeCursor::new(root)` and its moves | `TreeCursor(root)`, `goto_parent()`, `goto_first_child()`, `goto_last_child()`, `goto_next_sibling()`, `goto_previous_sibling()` | A failed move returns `False` and keeps the position |
| `TreeCursor::node`, `path`, `depth` | `cursor.node()`, `cursor.path()`, `cursor.depth()` | `depth` is relative to the start; `path` is document-relative |

Order and controls:

- Enter and leave events come in document preorder. A node leaves after all
  its children.
- `SKIP_CHILDREN` acts before the first child enters. The node still leaves.
- `STOP` ends the traversal at once. No later enter, family or leave callback
  runs.
- `fold` threads its value through enter and leave in that order.
- `reduce` and `reduce_pruned` combine children in document order, before
  their parent. A skipped node is combined at once with no child results.
  A root that returns `SKIP_CHILDREN` gives `combine(root, ())`. A stop gives
  `None`, also at the root.

### Graphs

| MoonBit | Python | Notes |
| --- | --- | --- |
| `ResourceSet::new(documents?, external?)` | `ResourceSet(documents=(), external=())` | `DocumentResource(location, document)`, `ExternalResource(location, namespace_uri, import_type, symbols)` |
| `DocumentGraph::new(document, resources?, resource_id?, limits?, graph_limits?)` | `DocumentGraph.new(document, resources=None, resource_id=None, limits=None, graph_limits=None)` | `GraphBuildResult(graph, diagnostics)` |
| `graph.nodes`, `graph.edges` | `graph.nodes`, `graph.edges` | `GraphNode`, `GraphEdge(kind, source, target, connection)` |
| `GraphEndpoint::Node`, `Id`, `Qualified`, `Symbol` | `GraphEndpoint.node(handle_or_node)`, `.id(id)`, `.qualified(ns, local)`, `.symbol(resource, ns, local)` | A `str` is not an endpoint |
| `graph.lookup(endpoint, limits?)` | `graph.lookup(endpoint, limits=None)` | `LookupResult(status, node, failure)`: `Ok` or `Err` |
| `graph.reachable(start, kinds?, direction?, limits?)` | `graph.reachable(start, kinds=None, direction=None, limits=None)` | `ReachabilityResult`: `Complete` or `Failed` |
| `graph.route(start, target, kinds?, direction?, limits?)` | `graph.route(start, target, kinds=None, direction=None, limits=None)` | `RouteResult`: `Found`, `Unreachable` or `Failed` |
| `GraphLimits::new(...)` | `GraphLimits(nodes=None, edges=None, results=None, work=None)` | `GraphLimits.defaults()` |

Defaults: `kinds=None` is `[SequenceFlow]`, `direction=None` is `Forward`,
and `limits=None` is `GraphLimits::new()`: 100,000 nodes, 200,000 edges,
100,000 results and 1,000,000 work units. Python passes `None` to the native
library, so MoonBit applies its own defaults.

`GraphFailure.kind` is one of:

| Kind | When | Extra field |
| --- | --- | --- |
| `InvalidEndpoint` | No node has the ID, name or symbol, or the handle ordinal is not in its tree | |
| `DocumentMismatch` | The handle belongs to another document revision or resource | |
| `InvalidReference` | The search meets a reference that is broken, unresolved or not supplied | `handle` of the owner |
| `Ambiguous` | An endpoint or a selected reference has more than one candidate | `nodes` |
| `Limit` | A search or a candidate list reaches a bound | `limit`: `GraphLimit.NODES`, `EDGES`, `RESULTS` or `WORK` |
| `InvalidLimits` | A limit is zero or negative | |

A limit is never reported as `Unreachable`. Resources come only from the
caller: an absent import gives `bpmn/unresolved-import` diagnostics and an
`InvalidReference` failure, without file or network access.

## Limits and source units

- `Limits` bound reading and tree building: source units, output units,
  nodes, element depth (default 4096), token units and diagnostics. A
  10,000-level tree needs `Limits(depth=...)` above 10,000 for both `read` and
  `tree`. Traversal of a deep tree uses no Python recursion.
- Offsets, columns and span ends count UTF-16 code units. Lines and columns
  start at 1. `Location.source_id` is the `source_id` given to `read`. Use
  `diagrams_mbt.code_point_index(source, offset)` for a Python string index.
- Integers are Python `int` values. MoonBit uses 32-bit `Int` for limits,
  ordinals, offsets and counts; a limit outside that range raises
  `InvalidArgumentError`.

## Ownership, failures and threads

| Situation | Result |
| --- | --- |
| A node is kept after the document and tree variables are gone | The node stays readable; it keeps its tree alive |
| The last reference to an owner is gone | The native object is released under the runtime lock. No Python callback runs. |
| `close()` on a document, tree, reader, cursor, resource set or graph | Releases it now. A second `close()` does nothing. |
| A call on a closed owner | `ClosedError` |
| A token of another object kind | `InvalidTokenError` |
| An ordinal outside the tree, a batch size outside 1 to 4096, a bad limit | `InvalidArgumentError` (also a `ValueError`) |
| Two threads advance one `EventReader` or `TreeCursor` at the same time | `BusyError`; the object does not change |
| A callback raises | The traversal stops, its native reader is released, and the same exception reaches the caller |

The errors are in `diagrams_mbt._boundary`. Callbacks run outside the native
runtime lock. A callback can start another traversal, use a cursor or call
`render_svg`; the outer traversal then continues at its position. Separate
readers and cursors are independent. Closing a reader or cursor does not
invalidate nodes that you keep.

## Parity evidence

The shared corpus in `tests/traversal-corpus` runs each mapped operation. The
MoonBit test compares its text on wasm, wasm-gc, js and native. The Python
test `test_bpmn_corpus.py` writes the same text through this module. See the
[corpus README](../../tests/traversal-corpus/README.md) for the format.
