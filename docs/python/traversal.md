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

The Python examples on this page run in order, in one namespace. The test
`test_doc_examples.py` runs them. This setup block gives their `source`:

```python
# Setup: the BPMN source of the examples on this page.
source = """<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" targetNamespace="urn:orders">
  <bpmn:process id="Orders">
    <bpmn:startEvent id="Start"/>
    <bpmn:task id="Check" name="Check order"/>
    <bpmn:subProcess id="Ship"><bpmn:task id="Pack"/></bpmn:subProcess>
    <bpmn:endEvent id="End"/>
    <bpmn:sequenceFlow id="F1" sourceRef="Start" targetRef="Check"/>
    <bpmn:sequenceFlow id="F2" sourceRef="Check" targetRef="Ship"/>
    <bpmn:sequenceFlow id="F3" sourceRef="Ship" targetRef="End"/>
  </bpmn:process>
</bpmn:definitions>"""
```

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
status = bpmn.walk(
    tree.root(),
    lambda node: Control.SKIP_CHILDREN if node.id == "Ship" else Control.CONTINUE,
    lambda node: print(node.id),
)
assert status is bpmn.TraversalStatus.COMPLETE
```

`walk` returns `TraversalStatus.STOPPED` after a `STOP` decision, else
`COMPLETE`. `read` returns a `ReadResult`. Its `document` is `None` after an XML syntax
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
assert tasks.names == ["task", "subProcess", "task"]
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
document = read.document
task = next(e.node for e in bpmn.EventReader(tree.root()) if e.node.id == "Check")
graph = bpmn.DocumentGraph.new(document).graph
result = graph.route(bpmn.GraphEndpoint.node(task), bpmn.GraphEndpoint.id("End"))
if result.status == "Found":
    print([node.id for node in result.route.nodes])  # ['Check', 'Ship', 'End']
elif result.status == "Failed":
    print(result.failure.kind)
assert [node.id for node in result.route.nodes] == ["Check", "Ship", "End"]
```

A node endpoint is a revision-bound handle. It never falls back to the node's
ID, so it selects one node when two nodes have the same ID. An `id` endpoint
still reports `Ambiguous`.

## Semantics

The [compatibility map](compatibility.md) lists each MoonBit operation and its
Python operation, with defaults, failures, limits and units. This section
gives the rules that the map refers to.

### Values

`Scalar.tag` is the MoonBit constructor name: `Text`, `Identifier`, `Uri`,
`Boolean`, `Integer`, `Number`, `Reference`, `Enumeration` or `Invalid`.
`Scalar.token` is `Scalar::token`. `Scalar.detail` is `None`, a `bool`, a
`Reference(kind, spelling, name)`, the enumeration type `ExpandedName` or an
`InvalidScalar(raw, expected)`. `PathField.kind` is `Named` (with `name`),
`Text`, `Comment`, `ProcessingInstruction`, `Root`, `Prolog` or `Epilog`.

### Traversal

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

Status of a traversal:

| Operation | MoonBit result | Python result |
| --- | --- | --- |
| `walk`, `accept`, `push_events` | `Unit`; the caller knows its own `Stop` decision | `TraversalStatus.COMPLETE` when the events end, `TraversalStatus.STOPPED` after a `STOP` decision |
| `fold`, `reduce`, `reduce_pruned` | The value (`None` after a stop in `reduce_pruned`) | The same value |
| A callback raises | (no exceptions in callbacks) | The exception propagates: the failed case. No status. |
| `EventReader.next_batch` | (Python only) | `EventBatch(events, state)`. `state` is `running` until a read past the last event (`complete`) or a `stop()` (`stopped`). A full batch stays `running`. After `stop()` the state is never `complete`. |

### Graphs

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
