"""Native owners are released exactly once, also under thread contention.

``live_objects`` gives the open objects of each native registry. Each test
compares it with the counts before the test, so objects that other tests keep
do not matter. Owners are released in three ways: ``close()``, a ``with``
block and a finalizer (``weakref.finalize``) that the cyclic collector runs,
possibly on another thread while the runtime lock is held elsewhere.
"""

from __future__ import annotations

import gc
import os
import threading
import time
import unittest
from typing import Dict

import diagrams_mbt
from diagrams_mbt import _boundary, _native, bpmn, query

DEADLINE = float(os.environ.get("DIAGRAMS_NATIVE_THREAD_DEADLINE", "60"))
MODEL = "http://www.omg.org/spec/BPMN/20100524/MODEL"
SOURCE = f"""<bpmn:definitions xmlns:bpmn="{MODEL}" targetNamespace="urn:owners">
  <bpmn:process id="P">
    <bpmn:startEvent id="Start"/>
    <bpmn:userTask id="Approve" name="Approve"/>
    <bpmn:subProcess id="Sub"><bpmn:task id="Inner"/></bpmn:subProcess>
    <bpmn:endEvent id="End"/>
    <bpmn:sequenceFlow id="F1" sourceRef="Start" targetRef="Approve"/>
    <bpmn:sequenceFlow id="F2" sourceRef="Approve" targetRef="Sub"/>
    <bpmn:sequenceFlow id="F3" sourceRef="Sub" targetRef="End"/>
  </bpmn:process>
</bpmn:definitions>"""
LONG_SOURCE = "flowchart TD\n" + "".join(f"  N{i} --> N{i + 1}\n" for i in range(40))


def live() -> Dict[str, int]:
    return {name: count for name, count in _boundary.call("live_objects")}


def settle() -> None:
    # Two passes: finalizers of the first pass can free more cycles.
    gc.collect()
    gc.collect()


class Cycle:
    """Keeps ``value`` in a reference cycle, so only the collector frees it."""

    def __init__(self, value: object) -> None:
        self.value = value
        self.self = self


class _NoCursor:
    def close(self) -> None:
        pass


def use_everything(round_index: int, *, queries: bool) -> int:
    """Opens one owner of each kind, uses it and releases it in one of three
    ways. Returns the number of query matches (1, or 1 without queries)."""
    read = bpmn.read(SOURCE, source_id=f"owners-{round_index}.bpmn")
    document = read.document
    tree = document.tree().tree
    plan = query.compile('((bpmn.userTask) @t (#attr-eq? @t "name" "Approve"))')
    if queries:
        matches = len(plan.collect(tree, fields=("id",)).matches)
        cursor = plan.execute(tree, fields=("id",))
        cursor.next_batch(1)
    else:
        matches = 1
        cursor = _NoCursor()
    reader = bpmn.EventReader(tree.root())
    reader.next_batch(4)
    walker = bpmn.TreeCursor(tree.root())
    graph = bpmn.DocumentGraph.new(document).graph
    graph.route(bpmn.GraphEndpoint.id("Start"), bpmn.GraphEndpoint.id("End"))
    mode = round_index % 3
    if mode == 0:
        for owner in (cursor, reader, walker, graph, plan, tree, document):
            owner.close()
            owner.close()  # closing again does nothing
    elif mode == 1:
        with reader, walker, graph:
            pass
        cursor.close()
        Cycle((plan, tree, document))
    else:
        Cycle((cursor, reader, walker, graph, plan, tree, document))
    return matches


class OwnerReleaseTest(unittest.TestCase):
    def test_close_releases_once_and_later_use_fails(self) -> None:
        settle()
        before = live()
        document = bpmn.read(SOURCE, source_id="once.bpmn").document
        tree = document.tree().tree
        reader = bpmn.EventReader(tree.root())
        opened = live()
        for name in ("bpmn.document", "bpmn.tree", "bpmn.event_reader"):
            self.assertEqual(opened[name], before[name] + 1, name)
        reader.close()
        reader.close()
        after_close = live()
        self.assertEqual(sum(after_close.values()), sum(opened.values()) - 1)
        with self.assertRaises(_boundary.ClosedError):
            reader.next()
        tree.close()
        document.close()
        settle()
        self.assertEqual(live(), before)

    def test_owners_return_to_zero_under_contention(self) -> None:
        self._run_contention(queries=False)

    # Known defect: diagrams_mbt.query caches one query view for each tree in a
    # module dict, and the view keeps a strong reference to its tree. So a
    # tree that a query used is never finalized, and its document, tree and
    # view stay open; tree.close() does not close the view. Remove the
    # decorators when the cache no longer keeps trees alive.
    def test_queried_owners_return_to_zero_under_contention(self) -> None:
        self._run_contention(queries=True)

    def test_a_dropped_queried_tree_releases_its_view(self) -> None:
        settle()
        before = live()
        document = bpmn.read(SOURCE, source_id="view.bpmn").document
        tree = document.tree().tree
        query.compile("(bpmn.userTask) @t").collect(tree)
        del document, tree
        settle()
        self.assertEqual(live(), before)

    def _run_contention(self, *, queries: bool) -> None:
        settle()
        before = live()
        stop = threading.Event()
        errors: list = []
        matches: list = []

        def contention() -> None:
            try:
                while not stop.is_set():
                    diagrams_mbt.render_svg(LONG_SOURCE)
            except BaseException as error:  # noqa: BLE001
                errors.append(error)

        def owners(worker: int) -> None:
            try:
                for i in range(25):
                    matches.append(use_everything(worker * 100 + i, queries=queries))
                    if i % 5 == 0:
                        gc.collect()  # finalizers run on this thread
            except BaseException as error:  # noqa: BLE001
                errors.append(error)

        old = gc.get_threshold()
        gc.set_threshold(50, 5, 5)
        busy = threading.Thread(target=contention, daemon=True)
        workers = [threading.Thread(target=owners, args=(w,), daemon=True) for w in range(4)]
        try:
            busy.start()
            for w in workers:
                w.start()
            end = time.monotonic() + DEADLINE
            for w in workers:
                w.join(max(0.0, end - time.monotonic()))
                self.assertFalse(w.is_alive(), "an owner thread passed the deadline")
        finally:
            stop.set()
            gc.set_threshold(*old)
        busy.join(DEADLINE)
        self.assertFalse(busy.is_alive())
        self.assertEqual(errors, [])
        self.assertEqual(matches, [1] * 100)
        settle()
        self.assertEqual(live(), before)
        self.assertEqual(_native._lock_stats()["max_inside"], 1)


if __name__ == "__main__":
    unittest.main()
