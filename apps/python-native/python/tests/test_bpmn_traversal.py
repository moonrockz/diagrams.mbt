"""Callback control, ownership and concurrency of ``diagrams_mbt.bpmn``.

The normalized parity of every mapped operation is in ``test_bpmn_corpus``.
These tests check the Python-specific contract: implemented-handler-only
dispatch, immediate controls, exceptions, reentry, deep trees, retained
views, tokens and busy errors.
"""

from __future__ import annotations

import gc
import sys
import threading
import unittest
from typing import Dict, List, Optional

import diagrams_mbt
from diagrams_mbt import _boundary, bpmn
from diagrams_mbt.bpmn import Control

MODEL_URI = "http://www.omg.org/spec/BPMN/20100524/MODEL"

SOURCE = (
    f"<b:definitions xmlns:b='{MODEL_URI}' targetNamespace='urn:t'>"
    "<b:process id='P'>"
    "<b:task id='A'/>"
    "<b:subProcess id='Sub'><b:task id='Hidden'/><b:task id='Hidden2'/></b:subProcess>"
    "<b:userTask id='Visible'/>"
    "<b:sequenceFlow id='F' sourceRef='A' targetRef='Visible'/>"
    "</b:process></b:definitions>"
)

MERMAID = "flowchart LR\n  A --> B\n"


def live() -> Dict[str, int]:
    return {name: count for name, count in _boundary.call("live_objects")}


def tree_of(source: str = SOURCE, source_id: Optional[str] = "memory:test") -> bpmn.DocumentTree:
    result = bpmn.read(source, source_id)
    assert result.document is not None, result.diagnostics
    built = result.document.tree()
    assert built.tree is not None, built.diagnostics
    return built.tree


def by_id(tree: bpmn.DocumentTree, node_id: str) -> bpmn.Node:
    found: List[bpmn.Node] = []

    def enter(node: bpmn.Node) -> Control:
        if node.id == node_id:
            found.append(node)
            return Control.STOP
        return Control.CONTINUE

    bpmn.walk(tree.root(), enter)
    return found[0]


def log_walk(root: bpmn.Node, decide=lambda n: Control.CONTINUE) -> List[str]:  # type: ignore[no-untyped-def]
    log: List[str] = []

    def enter(node: bpmn.Node) -> Control:
        log.append(f"+{node.id or node.ordinal}")
        return decide(node)

    bpmn.walk(root, enter, lambda n: log.append(f"-{n.id or n.ordinal}"))
    return log


class Boom(Exception):
    pass


class DispatchTest(unittest.TestCase):
    def test_only_implemented_handlers_are_called(self) -> None:
        tree = tree_of()
        calls: Dict[str, int] = {}
        saved = {}
        names = ["enter", "leave"] + [n for n in dir(bpmn.Visitor) if n.startswith("visit_")]
        for name in names:
            original = getattr(bpmn.Visitor, name)
            saved[name] = original

            def counting(*args, _name=name, _original=original):  # type: ignore[no-untyped-def]
                calls[_name] = calls.get(_name, 0) + 1
                return _original(*args)

            setattr(bpmn.Visitor, name, counting)
        try:

            class OnlyActivity(bpmn.Visitor):
                def __init__(self) -> None:
                    self.seen: List[str] = []

                def visit_activity(self, value: bpmn.ElementView, node: bpmn.Node) -> Control:
                    self.seen.append(f"{node.id}:{value.kind.local_name}")
                    return Control.CONTINUE

            visitor = OnlyActivity()
            bpmn.accept(tree.root(), visitor)
        finally:
            for name, original in saved.items():
                setattr(bpmn.Visitor, name, original)
        self.assertEqual(calls, {})
        self.assertEqual(
            visitor.seen,
            ["A:task", "Sub:subProcess", "Hidden:task", "Hidden2:task", "Visible:userTask"],
        )

    def test_enter_runs_before_the_family_method_only_after_continue(self) -> None:
        tree = tree_of()

        class Logged(bpmn.Visitor):
            def __init__(self) -> None:
                self.log: List[str] = []

            def enter(self, node: bpmn.Node) -> Control:
                self.log.append(f"enter:{node.id}")
                return Control.SKIP_CHILDREN if node.id == "Sub" else Control.CONTINUE

            def visit_activity(self, value: bpmn.ElementView, node: bpmn.Node) -> Control:
                self.log.append(f"activity:{node.id}")
                return Control.CONTINUE

            def leave(self, node: bpmn.Node) -> None:
                self.log.append(f"leave:{node.id}")

        visitor = Logged()
        bpmn.accept(by_id(tree, "P"), visitor)
        self.assertEqual(
            visitor.log,
            [
                "enter:P",
                "enter:A",
                "activity:A",
                "leave:A",
                "enter:Sub",
                "leave:Sub",
                "enter:Visible",
                "activity:Visible",
                "leave:Visible",
                "enter:F",
                "leave:F",
                "leave:P",
            ],
        )

    def test_a_callback_must_return_a_control(self) -> None:
        tree = tree_of()
        with self.assertRaises(TypeError):
            bpmn.walk(tree.root(), lambda n: None)  # type: ignore[arg-type,return-value]


class ControlTest(unittest.TestCase):
    def test_skip_children_leaves_the_node_and_continues_with_its_sibling(self) -> None:
        tree = tree_of()
        log = log_walk(by_id(tree, "P"), lambda n: Control.SKIP_CHILDREN if n.id == "Sub" else Control.CONTINUE)
        self.assertEqual(log, ["+P", "+A", "-A", "+Sub", "-Sub", "+Visible", "-Visible", "+F", "-F", "-P"])

    def test_stop_emits_no_later_callback(self) -> None:
        tree = tree_of()
        log = log_walk(by_id(tree, "P"), lambda n: Control.STOP if n.id == "Sub" else Control.CONTINUE)
        self.assertEqual(log, ["+P", "+A", "-A", "+Sub"])

    def test_stop_before_a_child_is_observed(self) -> None:
        tree = tree_of()
        before = live()

        class StopAtSub(bpmn.Visitor):
            def __init__(self) -> None:
                self.log: List[str] = []

            def enter(self, node: bpmn.Node) -> Control:
                self.log.append(f"+{node.id}")
                return Control.CONTINUE

            def visit_activity(self, value: bpmn.ElementView, node: bpmn.Node) -> Control:
                return Control.STOP if node.id == "Sub" else Control.CONTINUE

            def leave(self, node: bpmn.Node) -> None:
                self.log.append(f"-{node.id}")

        visitor = StopAtSub()
        status = bpmn.accept(by_id(tree, "P"), visitor)
        self.assertEqual(visitor.log, ["+P", "+A", "-A", "+Sub"])
        self.assertIs(status, bpmn.TraversalStatus.STOPPED)
        self.assertIsNot(status, bpmn.TraversalStatus.COMPLETE)
        self.assertEqual(live(), before)
        self.assertIs(bpmn.accept(by_id(tree, "P"), bpmn.Visitor()), bpmn.TraversalStatus.COMPLETE)

    def test_walk_push_events_and_accept_report_complete_or_stopped(self) -> None:
        tree = tree_of()
        root = by_id(tree, "P")
        cont = lambda n: Control.CONTINUE  # noqa: E731
        stop_at_sub = lambda n: Control.STOP if n.id == "Sub" else Control.CONTINUE  # noqa: E731
        self.assertIs(bpmn.walk(root, cont), bpmn.TraversalStatus.COMPLETE)
        self.assertIs(bpmn.walk(root, stop_at_sub), bpmn.TraversalStatus.STOPPED)
        skip_all = lambda n: Control.SKIP_CHILDREN  # noqa: E731
        self.assertIs(bpmn.walk(root, skip_all), bpmn.TraversalStatus.COMPLETE)
        reader = bpmn.EventReader(root)
        self.assertIs(bpmn.push_events(reader, stop_at_sub), bpmn.TraversalStatus.STOPPED)
        self.assertEqual(reader.state, "stopped")
        reader = bpmn.EventReader(root)
        self.assertIs(bpmn.push_events(reader, cont), bpmn.TraversalStatus.COMPLETE)
        self.assertEqual(reader.state, "complete")

    def test_batches_after_stop_never_claim_completion(self) -> None:
        tree = tree_of()
        root = by_id(tree, "P")
        total = 2 * 7
        reader = bpmn.EventReader(root)
        self.assertEqual(reader.state, "running")
        first = reader.next_batch(3)
        self.assertEqual((len(first), first.state), (3, "running"))
        reader.stop()
        self.assertEqual(reader.state, "stopped")
        after = reader.next_batch(64)
        self.assertEqual((after.events, after.state), ((), "stopped"))
        self.assertIsNone(reader.next())
        self.assertEqual(reader.state, "stopped")
        # A full batch that reaches the last event is not yet complete.
        exact = bpmn.EventReader(root)
        full = exact.next_batch(total)
        self.assertEqual((len(full), full.state), (total, "running"))
        end = exact.next_batch(1)
        self.assertEqual((end.events, end.state), ((), "complete"))
        exact.stop()
        self.assertEqual(exact.state, "complete")
        short = bpmn.EventReader(root).next_batch(total + 1)
        self.assertEqual((len(short), short.state), (total, "complete"))
        # Stopping through push_events: no later event in a following batch.
        pushed = bpmn.EventReader(root)
        bpmn.push_events(pushed, lambda n: Control.STOP if n.id == "Sub" else Control.CONTINUE)
        self.assertEqual(pushed.next_batch(64).state, "stopped")

    def test_fold_and_reductions_keep_the_moonbit_order(self) -> None:
        tree = tree_of()
        root = by_id(tree, "P")
        folded = bpmn.fold(
            root,
            (),
            lambda acc, n: (acc + (f"+{n.id}",), Control.CONTINUE),
            lambda acc, n: acc + (f"-{n.id}",),
        )
        self.assertEqual(list(folded), log_walk(root))
        order: List[str] = []

        def combine(node: bpmn.Node, children: tuple) -> int:  # type: ignore[type-arg]
            order.append(f"{node.id}:{len(children)}")
            return 1 + sum(children)

        self.assertEqual(bpmn.reduce(root, combine), 7)
        self.assertEqual(order, ["A:0", "Hidden:0", "Hidden2:0", "Sub:2", "Visible:0", "F:0", "P:4"])
        order.clear()
        skipped = bpmn.reduce_pruned(
            root, lambda n: Control.SKIP_CHILDREN if n.id == "Sub" else Control.CONTINUE, combine
        )
        self.assertEqual(skipped, 5)
        self.assertEqual(order, ["A:0", "Sub:0", "Visible:0", "F:0", "P:4"])
        order.clear()
        self.assertIsNone(
            bpmn.reduce_pruned(root, lambda n: Control.STOP if n.id == "Hidden" else Control.CONTINUE, combine)
        )
        self.assertEqual(order, ["A:0"])
        order.clear()
        self.assertEqual(bpmn.reduce_pruned(root, lambda n: Control.SKIP_CHILDREN, combine), 1)
        self.assertEqual(order, ["P:0"])
        self.assertIsNone(bpmn.reduce_pruned(root, lambda n: Control.STOP, combine))

    def test_push_events_drives_a_python_event_source(self) -> None:
        tree = tree_of()
        root = by_id(tree, "P")
        events = list(bpmn.EventReader(root))

        class ListSource:
            def __init__(self) -> None:
                self.at = 0
                self.calls: List[str] = []

            def next(self) -> Optional[bpmn.TraversalEvent]:
                if self.at >= len(events):
                    return None
                self.at += 1
                return events[self.at - 1]

            def skip_children(self) -> None:
                self.calls.append("skip")

            def stop(self) -> None:
                self.calls.append("stop")

        source = ListSource()
        log: List[str] = []

        def enter(node: bpmn.Node) -> Control:
            log.append(f"+{node.id}")
            if node.id == "A":
                return Control.SKIP_CHILDREN
            return Control.STOP if node.id == "Hidden" else Control.CONTINUE

        bpmn.push_events(source, enter, lambda n: log.append(f"-{n.id}"))
        self.assertEqual(log, ["+P", "+A", "-A", "+Sub", "+Hidden"])
        self.assertEqual(source.calls, ["skip", "stop"])

    def test_reader_controls_and_independent_readers(self) -> None:
        tree = tree_of()
        root = by_id(tree, "Sub")
        first = bpmn.EventReader(root)
        second = bpmn.EventReader(root)
        first.skip_children()
        event = first.next()
        self.assertIsInstance(event, bpmn.Enter)
        first.skip_children()
        self.assertIsInstance(first.next(), bpmn.Leave)
        self.assertIsNone(first.next())
        self.assertEqual([type(e).__name__ for e in second.next_batch(3)], ["Enter", "Enter", "Leave"])
        second.stop()
        self.assertEqual(second.next_batch(10), bpmn.EventBatch((), "stopped"))
        with self.assertRaises(_boundary.InvalidArgumentError):
            bpmn.EventReader(root).next_batch(0)
        with self.assertRaises(ValueError):
            bpmn.EventReader(root).next_batch(bpmn.MAX_EVENT_BATCH + 1)


class ExceptionTest(unittest.TestCase):
    def test_an_exception_propagates_without_later_callbacks(self) -> None:
        tree = tree_of()
        before = live()

        class Raising(bpmn.Visitor):
            def __init__(self) -> None:
                self.log: List[str] = []

            def enter(self, node: bpmn.Node) -> Control:
                self.log.append(f"+{node.id}")
                return Control.CONTINUE

            def visit_activity(self, value: bpmn.ElementView, node: bpmn.Node) -> Control:
                if node.id == "Hidden":
                    raise Boom("hidden")
                return Control.CONTINUE

            def leave(self, node: bpmn.Node) -> None:
                self.log.append(f"-{node.id}")

        visitor = Raising()
        with self.assertRaises(Boom) as raised:
            bpmn.accept(by_id(tree, "P"), visitor)
        self.assertEqual(str(raised.exception), "hidden")
        self.assertEqual(visitor.log, ["+P", "+A", "-A", "+Sub", "+Hidden"])
        self.assertEqual(live(), before)
        # Later independent operations still succeed.
        self.assertEqual(len(log_walk(tree.root())), 2 * tree.length)
        self.assertTrue(diagrams_mbt.render_svg(MERMAID).ok)

    def test_exceptions_in_leave_fold_and_combine_propagate(self) -> None:
        tree = tree_of()
        root = by_id(tree, "P")
        seen: List[str] = []

        def leave(node: bpmn.Node) -> None:
            seen.append(f"-{node.id}")
            raise Boom("leave")

        with self.assertRaises(Boom):
            bpmn.walk(root, lambda n: Control.CONTINUE, leave)
        self.assertEqual(seen, ["-A"])

        def combine(node: bpmn.Node, children: tuple) -> int:  # type: ignore[type-arg]
            raise Boom("combine")

        with self.assertRaises(Boom):
            bpmn.reduce(root, combine)
        with self.assertRaises(Boom):
            bpmn.reduce_pruned(root, lambda n: Control.CONTINUE, combine)

        def fold_enter(acc: int, node: bpmn.Node):  # type: ignore[no-untyped-def]
            raise Boom("fold")

        with self.assertRaises(Boom):
            bpmn.fold(root, 0, fold_enter)
        self.assertEqual(live().get("bpmn.event_reader"), 0)


class ReentryTest(unittest.TestCase):
    def test_nested_walk_and_render_from_a_callback(self) -> None:
        tree = tree_of()
        root = tree.root()
        expected = log_walk(root)
        rendered: List[bool] = []
        nested: List[List[str]] = []

        class Nesting(bpmn.Visitor):
            def __init__(self) -> None:
                self.log: List[str] = []

            def enter(self, node: bpmn.Node) -> Control:
                self.log.append(f"+{node.id or node.ordinal}")
                return Control.CONTINUE

            def visit_activity(self, value: bpmn.ElementView, node: bpmn.Node) -> Control:
                nested.append(log_walk(root))
                rendered.append(diagrams_mbt.render_svg(MERMAID).ok)
                return Control.CONTINUE

            def leave(self, node: bpmn.Node) -> None:
                self.log.append(f"-{node.id or node.ordinal}")

        visitor = Nesting()
        bpmn.accept(root, visitor)
        self.assertEqual(visitor.log, expected)
        self.assertEqual(len(nested), 5)
        self.assertTrue(all(log == expected for log in nested))
        self.assertEqual(rendered, [True] * 5)


class DeepTest(unittest.TestCase):
    def test_ten_thousand_levels_need_no_python_recursion(self) -> None:
        depth = 10000
        source = (
            f"<b:definitions xmlns:b='{MODEL_URI}' targetNamespace='urn:deep'><b:process id='P'>"
            + "<b:subProcess>" * depth
            + "<b:task id='Deep'/>"
            + "</b:subProcess>" * depth
            + "</b:process></b:definitions>"
        )
        limits = bpmn.Limits(depth=20000)
        document = bpmn.read(source, None, limits).document
        self.assertIsNone(document.tree().tree)
        tree = document.tree(limits=limits).tree
        old = sys.getrecursionlimit()
        sys.setrecursionlimit(200)
        try:
            enters = [0]
            bpmn.walk(tree.root(), lambda n: (enters.__setitem__(0, enters[0] + 1), Control.CONTINUE)[1])
            self.assertEqual(enters[0], depth + 4)
            self.assertEqual(bpmn.reduce(tree.root(), lambda n, c: 1 + sum(c)), depth + 4)

            class Count(bpmn.Visitor):
                n = 0

                def visit_activity(self, value: bpmn.ElementView, node: bpmn.Node) -> Control:
                    Count.n += 1
                    return Control.CONTINUE

            bpmn.accept(tree.root(), Count())
            self.assertEqual(Count.n, depth + 1)
        finally:
            sys.setrecursionlimit(old)
        deep = tree.node(depth + 3)
        self.assertEqual(deep.id, "Deep")
        self.assertEqual(len(deep.path().steps()), depth + 3)


class OwnershipTest(unittest.TestCase):
    def test_a_retained_view_outlives_the_document_variable(self) -> None:
        gc.collect()
        before = live()
        result = bpmn.read(SOURCE, "memory:retained")
        document = result.document
        tree = document.tree().tree
        node = by_id(tree, "Visible")
        del result, document, tree
        gc.collect()
        self.assertEqual(node.id, "Visible")
        self.assertEqual(node.attributes()[0].value.token, "Visible")
        self.assertEqual(node.location().source_id, "memory:retained")
        self.assertEqual(node.parent().id, "P")
        self.assertEqual(live()["bpmn.tree"], before["bpmn.tree"] + 1)
        del node
        gc.collect()
        self.assertEqual(live(), before)

    def test_closed_stale_and_wrong_tokens_fail_safely(self) -> None:
        result = bpmn.read(SOURCE)
        tree = result.document.tree().tree
        node = by_id(tree, "A")
        stale = tree._token
        tree.close()
        tree.close()
        self.assertTrue(tree.closed)
        with self.assertRaises(_boundary.ClosedError):
            node.attributes()
        with self.assertRaises(_boundary.ClosedError):
            bpmn.EventReader(node)
        fresh = result.document.tree().tree
        self.assertNotEqual(fresh._token, stale)
        with self.assertRaises(_boundary.ClosedError):
            _boundary.call("bpmn_node", stale, 0)
        with self.assertRaises(_boundary.InvalidTokenError):
            _boundary.call("bpmn_node", result.document._token, 0)
        with self.assertRaises(_boundary.InvalidTokenError):
            _boundary.call("bpmn_close", 1 << 60)
        with self.assertRaises(_boundary.InvalidArgumentError):
            fresh.node(fresh.length)
        result.document.close()
        with self.assertRaises(_boundary.ClosedError):
            result.document.tree()
        # The fresh tree retains its own copy of the document.
        self.assertEqual(fresh.root().children()[0].id, None)

    def test_handles_are_revision_qualified(self) -> None:
        a = tree_of(source_id="a")
        same = tree_of(source_id="a")
        other_source = tree_of(source_id="b")
        node = by_id(a, "Visible")
        self.assertEqual(node.handle, by_id(same, "Visible").handle)
        self.assertEqual(node, by_id(same, "Visible"))
        self.assertNotEqual(node.handle, by_id(other_source, "Visible").handle)
        self.assertEqual(same.lookup(node.handle).node, by_id(same, "Visible"))
        self.assertEqual(other_source.lookup(node.handle).status, "DocumentMismatch")
        resource = bpmn.read(SOURCE, "a").document.tree("resource").tree
        self.assertEqual(resource.lookup(node).status, "DocumentMismatch")
        self.assertEqual(node.path().resolve(resource).status, "DocumentMismatch")
        self.assertEqual(node.path().resolve(same).status, "Found")


class ConcurrencyTest(unittest.TestCase):
    def test_concurrent_advancement_of_one_reader_or_cursor_is_busy(self) -> None:
        tree = tree_of()
        reader = bpmn.EventReader(tree.root())
        cursor = bpmn.TreeCursor(tree.root())
        for guard, advance in (
            (reader._guard, reader.next),
            (reader._guard, lambda: reader.next_batch(2)),
            (cursor._guard, cursor.goto_first_child),
        ):
            entered = threading.Event()
            release = threading.Event()

            def hold(guard=guard) -> None:  # type: ignore[no-untyped-def]
                with guard:
                    entered.set()
                    release.wait(10)

            holder = threading.Thread(target=hold)
            holder.start()
            self.assertTrue(entered.wait(10))
            try:
                with self.assertRaises(_boundary.BusyError):
                    advance()
            finally:
                release.set()
                holder.join(10)
        # The busy calls changed nothing: both still start at the root.
        self.assertEqual(reader.next().node.ordinal, 0)
        self.assertTrue(cursor.goto_first_child())

    def test_many_threads_on_one_reader_never_overlap(self) -> None:
        tree = tree_of()
        reader = bpmn.EventReader(tree.root())
        events: List[bpmn.TraversalEvent] = []
        busy = [0]
        lock = threading.Lock()

        def drain() -> None:
            while True:
                try:
                    event = reader.next()
                except _boundary.BusyError:
                    with lock:
                        busy[0] += 1
                    continue
                if event is None:
                    return
                with lock:
                    events.append(event)

        threads = [threading.Thread(target=drain) for _ in range(4)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(30)
        self.assertEqual(len(events), 2 * tree.length)
        self.assertEqual(sorted(e.node.ordinal for e in events if isinstance(e, bpmn.Enter)), list(range(tree.length)))

    def test_independent_cursors_move_separately(self) -> None:
        tree = tree_of()
        first = bpmn.TreeCursor(tree.root())
        second = bpmn.TreeCursor(tree.root())
        self.assertTrue(first.goto_first_child())
        self.assertTrue(first.goto_first_child())
        self.assertEqual(first.depth(), 2)
        self.assertEqual(second.depth(), 0)
        self.assertEqual(second.node(), tree.root())
        first.close()
        self.assertTrue(second.goto_last_child())
        self.assertEqual(second.node().category, bpmn.Category.DEFINITIONS)
        subtree = bpmn.TreeCursor(by_id(tree, "Sub"))
        self.assertFalse(subtree.goto_parent())
        self.assertFalse(subtree.goto_next_sibling())
        self.assertEqual(subtree.node().id, "Sub")
        self.assertTrue(subtree.goto_last_child())
        self.assertEqual((subtree.node().id, subtree.depth()), ("Hidden2", 1))
        self.assertEqual(len(subtree.path().steps()), 4)


class GraphTest(unittest.TestCase):
    DUPLICATES = (
        f"<b:definitions xmlns:b='{MODEL_URI}' targetNamespace='urn:t'><b:process>"
        "<b:task id='A'/><b:task id='A'/><b:task id='B'/><b:task id='C'/>"
        "<b:sequenceFlow id='F' sourceRef='B' targetRef='C'/></b:process></b:definitions>"
    )

    def test_handles_select_one_of_two_duplicate_ids(self) -> None:
        document = bpmn.read(self.DUPLICATES).document
        graph = bpmn.DocumentGraph.new(document).graph
        by_id_ = graph.lookup(bpmn.GraphEndpoint.id("A"))
        self.assertEqual(by_id_.status, "Err")
        self.assertEqual(by_id_.failure.kind, "Ambiguous")
        self.assertEqual([n.node.ordinal for n in by_id_.failure.nodes], [3, 4])
        tree = document.tree().tree
        second = tree.node(4)
        found = graph.lookup(bpmn.GraphEndpoint.node(second))
        self.assertEqual(found.status, "Ok")
        self.assertEqual(found.node.node, second)
        self.assertEqual(found.node.node.handle, second.handle)
        foreign = document.tree("elsewhere").tree.node(4)
        self.assertEqual(graph.lookup(bpmn.GraphEndpoint.node(foreign)).failure.kind, "DocumentMismatch")
        with self.assertRaises(TypeError):
            graph.lookup("A")

    def test_defaults_kinds_directions_and_limits(self) -> None:
        document = bpmn.read(self.DUPLICATES).document
        graph = bpmn.DocumentGraph.new(document).graph
        b, c = bpmn.GraphEndpoint.id("B"), bpmn.GraphEndpoint.id("C")
        self.assertEqual(graph.route(c, b).status, "Unreachable")
        explicit = graph.route(b, c, kinds=[bpmn.GraphEdgeKind.SEQUENCE_FLOW], direction=bpmn.GraphDirection.FORWARD)
        self.assertEqual(explicit, graph.route(b, c))
        reverse = graph.route(c, b, direction=bpmn.GraphDirection.REVERSE)
        self.assertEqual([n.id for n in reverse.route.nodes], ["C", "B"])
        self.assertEqual(reverse.route.edges[0].source.id, "B")
        self.assertEqual(reverse.route.edges[0].connection.id, "F")
        limited = graph.route(b, c, limits=bpmn.GraphLimits(nodes=1))
        self.assertEqual((limited.status, limited.failure.limit), ("Failed", bpmn.GraphLimit.NODES))
        self.assertEqual(graph.reachable(b, limits=bpmn.GraphLimits(work=0)).failure.kind, "InvalidLimits")
        self.assertEqual(bpmn.GraphLimits.defaults(), bpmn.GraphLimits(100000, 200000, 100000, 1000000))
        self.assertGreater(len(graph.nodes), 0)
        self.assertTrue(all(isinstance(e.kind, bpmn.GraphEdgeKind) for e in graph.edges))

    def test_absent_external_resource_fails_without_io(self) -> None:
        source = (
            f"<b:definitions xmlns:b='{MODEL_URI}' xmlns:t='urn:types' targetNamespace='urn:t'>"
            "<b:import namespace='urn:types' location='types' importType='urn:external'/>"
            "<b:itemDefinition id='Item' structureRef='t:Order'/></b:definitions>"
        )
        document = bpmn.read(source).document
        symbol = bpmn.GraphEndpoint.symbol("types", "urn:types", "Order")
        item = bpmn.GraphEndpoint.id("Item")
        reference = [bpmn.GraphEdgeKind.REFERENCE]
        bare = bpmn.DocumentGraph.new(document)
        self.assertIn("bpmn/unresolved-import", [d.code for d in bare.diagnostics])
        failed = bare.graph.reachable(item, kinds=reference)
        self.assertEqual(failed.failure.kind, "InvalidReference")
        self.assertEqual(failed.failure.handle.ordinal, by_id(document.tree().tree, "Item").ordinal)
        self.assertEqual(bare.graph.route(item, symbol, kinds=reference).failure.kind, "InvalidEndpoint")
        resources = bpmn.ResourceSet(external=[bpmn.ExternalResource("types", "urn:types", "urn:external", ["Order"])])
        full = bpmn.DocumentGraph.new(document, resources=resources).graph
        route = full.route(item, symbol, kinds=reference)
        self.assertEqual(route.status, "Found")
        self.assertEqual(route.route.nodes[-1].external, bpmn.ExternalNode(bpmn.ResolvedSymbol("types", bpmn.ExpandedName("urn:types", "Order")), 0))
        self.assertEqual(route.route.nodes[-1].id, "Order")

    def test_graph_and_resource_owners_release(self) -> None:
        gc.collect()
        before = live()
        document = bpmn.read(self.DUPLICATES).document
        resources = bpmn.ResourceSet()
        graph = bpmn.DocumentGraph.new(document, resources=resources).graph
        graph.lookup(bpmn.GraphEndpoint.id("B"))
        del document, resources, graph
        gc.collect()
        self.assertEqual(live(), before)


if __name__ == "__main__":
    unittest.main()
