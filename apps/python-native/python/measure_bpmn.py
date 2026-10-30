"""BPMN query and traversal workloads of ``measure.py``.

The declared trees are generated BPMN documents: one process with ``S``
sub-processes, each with ``T`` tasks (``userTask`` and ``serviceTask`` in
turn) and ``T - 1`` sequence flows. One task in 100 has the name
``Approve``; the others have unique names.

=======  ======  ======  ========================================
Size     S       T       Tree nodes (document node included)
=======  ======  ======  ========================================
small    2       5       23
medium   10      25      503
large    50      100     10,003
=======  ======  ======  ========================================

Each workload returns a counter dict: ``items`` (matches, events or visited
nodes), ``callbacks`` (Python callbacks the binding made) and
``callback_ns`` (time inside the callback bodies). Equal-work pairs:

- ``query-all-b*``, ``visitor-fields`` and ``native-walk-ids`` all produce the
  ID of every node.
- ``query-selective-b*``, ``visitor-selective`` and ``native-query-selective``
  find the user tasks named ``Approve``.
- ``visitor-pruning`` and ``native-walk-pruned`` skip each sub-process body.
- ``native-walk-records`` and ``native-walk-encoded`` also build (and
  encode) the node snapshot record that each event, visitor callback and
  capture carries, so they separate record cost from traversal.
- ``native-*`` rows run the same MoonBit functions in one boundary call
  (``measure_query``, ``measure_walk``) and convert no record, so their time
  inside the runtime lock is the native oracle for the row they pair with.
"""

from __future__ import annotations

import hashlib
import pathlib
import time
from typing import Callable, Dict, Tuple

from diagrams_mbt import _boundary, bpmn, query
from diagrams_mbt.bpmn import Control

SIZES: Dict[str, Tuple[int, int]] = {
    "small": (2, 5),
    "medium": (10, 25),
    "large": (50, 100),
}

SELECTIVE = '((bpmn.userTask) @t (#attr-eq? @t "name" "Approve"))'
MATCH_ALL = "(_) @n"
FIELDS = ("id",)
BATCHES = (1, 64, 256)
NAME = bpmn.ExpandedName("", "name")


def source(subs: int, tasks: int) -> str:
    out = [
        '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"'
        ' targetNamespace="urn:measure">',
        '<bpmn:process id="P">',
    ]
    for s in range(subs):
        out.append(f'<bpmn:subProcess id="S{s}" name="Sub {s}">')
        for t in range(tasks):
            kind = "userTask" if t % 2 == 0 else "serviceTask"
            name = "Approve" if (s * tasks + t) % 100 == 0 else f"Task {s}.{t}"
            out.append(f'<bpmn:{kind} id="T{s}_{t}" name="{name}"/>')
        for t in range(tasks - 1):
            out.append(
                f'<bpmn:sequenceFlow id="F{s}_{t}" sourceRef="T{s}_{t}" targetRef="T{s}_{t + 1}"/>'
            )
        out.append("</bpmn:subProcess>")
    out.append("</bpmn:process></bpmn:definitions>")
    return "\n".join(out)


_trees: Dict[str, bpmn.DocumentTree] = {}
_plans: Dict[str, query.QueryPlan] = {}


def tree(size: str) -> bpmn.DocumentTree:
    if size not in _trees:
        read = bpmn.read(source(*SIZES[size]), source_id=f"{size}.bpmn")
        built = read.document.tree().tree
        assert built is not None, f"the {size} tree did not build"
        _trees[size] = built
    return _trees[size]


def plan(text: str) -> query.QueryPlan:
    if text not in _plans:
        _plans[text] = query.compile(text)
    return _plans[text]


Call = Callable[[], dict]


def _query(size: str, text: str, batch: int) -> Call:
    t, p = tree(size), plan(text)

    def call() -> dict:
        result = p.collect(t, fields=FIELDS, batch_size=batch)
        assert result.state == "complete"
        return {"items": len(result.matches), "callbacks": 0, "callback_ns": 0}

    return call


def _native_query(size: str, text: str) -> Call:
    t, p = tree(size), plan(text)
    view = query._view(t)  # the same native index that public calls use

    def call() -> dict:
        matches, state = _boundary.call("measure_query", p._token, view.token, FIELDS, 1)
        assert state == "complete"
        return {"items": matches, "callbacks": 0, "callback_ns": 0}

    return call


def _native_walk(size: str, prune: object, mode: str) -> Call:
    t = tree(size)

    def call() -> dict:
        entered, _ = _boundary.call("measure_walk", t._token, prune, mode, 1)
        return {"items": entered, "callbacks": 0, "callback_ns": 0}

    return call


def _events(size: str, batch: int) -> Call:
    t = tree(size)

    def call() -> dict:
        reader = bpmn.EventReader(t.root())
        try:
            items = sum(len(b) for b in reader.batches(batch))
        finally:
            reader.close()
        return {"items": items, "callbacks": 0, "callback_ns": 0}

    return call


class _Counting(bpmn.Visitor):
    """Counts ``enter`` callbacks and the time inside their bodies."""

    def __init__(self) -> None:
        self.callbacks = 0
        self.callback_ns = 0

    def counters(self, items: int) -> dict:
        return {"items": items, "callbacks": self.callbacks, "callback_ns": self.callback_ns}


class _NoOp(_Counting):
    def enter(self, node: bpmn.Node) -> Control:
        t0 = time.perf_counter_ns()
        self.callbacks += 1
        self.callback_ns += time.perf_counter_ns() - t0
        return Control.CONTINUE


class _Fields(_Counting):
    def __init__(self) -> None:
        super().__init__()
        self.ids: list = []

    def enter(self, node: bpmn.Node) -> Control:
        t0 = time.perf_counter_ns()
        self.callbacks += 1
        self.ids.append(node.id)
        self.callback_ns += time.perf_counter_ns() - t0
        return Control.CONTINUE


class _Selective(_Counting):
    """The selective query in Python: user tasks named ``Approve``."""

    def __init__(self) -> None:
        super().__init__()
        self.found: list = []

    def enter(self, node: bpmn.Node) -> Control:
        t0 = time.perf_counter_ns()
        self.callbacks += 1
        if node.kind is not None and node.kind.local_name == "userTask":
            name = node.scalar(NAME)  # one native call for each user task
            if name is not None and name.token == "Approve":
                self.found.append(node.id)
        self.callback_ns += time.perf_counter_ns() - t0
        return Control.CONTINUE


class _Substantive(_Counting):
    """About 20 µs of hashing in each callback."""

    def enter(self, node: bpmn.Node) -> Control:
        t0 = time.perf_counter_ns()
        self.callbacks += 1
        digest = (node.id or "").encode()
        for _ in range(64):
            digest = hashlib.sha256(digest).digest()
        self.callback_ns += time.perf_counter_ns() - t0
        return Control.CONTINUE


class _Pruning(_Counting):
    def enter(self, node: bpmn.Node) -> Control:
        t0 = time.perf_counter_ns()
        self.callbacks += 1
        skip = node.kind is not None and node.kind.local_name == "subProcess"
        self.callback_ns += time.perf_counter_ns() - t0
        return Control.SKIP_CHILDREN if skip else Control.CONTINUE


def _visitor(size: str, cls: type) -> Call:
    t = tree(size)

    def call() -> dict:
        visitor = cls()
        status = bpmn.accept(t.root(), visitor)
        assert status is bpmn.TraversalStatus.COMPLETE
        return visitor.counters(visitor.callbacks)

    return call


def _factory(make: Callable[[], Call]) -> Callable[[pathlib.Path], Call]:
    return lambda fixtures: make()


def workloads() -> Dict[str, Callable[[pathlib.Path], Call]]:
    table: Dict[str, Callable[[pathlib.Path], Call]] = {}
    for size in SIZES:
        p = f"bpmn-{size}-"
        table[p + "native-query-selective"] = _factory(lambda s=size: _native_query(s, SELECTIVE))
        table[p + "native-query-all"] = _factory(lambda s=size: _native_query(s, MATCH_ALL))
        for b in BATCHES:
            table[p + f"query-selective-b{b}"] = _factory(lambda s=size, b=b: _query(s, SELECTIVE, b))
            table[p + f"query-all-b{b}"] = _factory(lambda s=size, b=b: _query(s, MATCH_ALL, b))
        table[p + "native-walk"] = _factory(lambda s=size: _native_walk(s, None, "none"))
        table[p + "native-walk-ids"] = _factory(lambda s=size: _native_walk(s, None, "ids"))
        table[p + "native-walk-records"] = _factory(lambda s=size: _native_walk(s, None, "records"))
        table[p + "native-walk-encoded"] = _factory(lambda s=size: _native_walk(s, None, "encoded"))
        table[p + "native-walk-pruned"] = _factory(lambda s=size: _native_walk(s, "subProcess", "none"))
        for b in BATCHES:
            table[p + f"events-b{b}"] = _factory(lambda s=size, b=b: _events(s, b))
        table[p + "visitor-noop"] = _factory(lambda s=size: _visitor(s, _NoOp))
        table[p + "visitor-fields"] = _factory(lambda s=size: _visitor(s, _Fields))
        table[p + "visitor-selective"] = _factory(lambda s=size: _visitor(s, _Selective))
        table[p + "visitor-substantive"] = _factory(lambda s=size: _visitor(s, _Substantive))
        table[p + "visitor-pruning"] = _factory(lambda s=size: _visitor(s, _Pruning))
    return table
