"""Behavior of ``diagrams_mbt.query`` beyond the shared corpus."""

from __future__ import annotations

import gc
import sys
import threading
import time
import unittest

import diagrams_mbt
from diagrams_mbt import _boundary, bpmn, query
from diagrams_mbt.bpmn_graph import DocumentGraph, GraphEndpoint

MODEL = "http://www.omg.org/spec/BPMN/20100524/MODEL"

SOURCE = (
    f"<definitions xmlns='{MODEL}' targetNamespace='urn:t'>"
    "<process id='P'>"
    "<userTask id='A' name='Approve'/>"
    "<subProcess id='Sub'><userTask id='B' name='Approve'/></subProcess>"
    "<task id='D'/><task id='D'/>"
    "<sequenceFlow id='F' sourceRef='A' targetRef='D'/>"
    "</process></definitions>"
)


def tree_of(source: str = SOURCE, source_id: str = "memory:q") -> bpmn.DocumentTree:
    return bpmn.read(source, source_id=source_id).document.tree().tree


def large_source(tasks: int) -> str:
    body = "".join(f"<task id='T{i}'/>" for i in range(tasks))
    return (
        f"<definitions xmlns='{MODEL}' targetNamespace='urn:t'><process id='P'>"
        f"{body}<userTask id='Needle' name='n'/></process></definitions>"
    )


class SchemaAndCompileTest(unittest.TestCase):
    def test_schema_is_the_moonbit_adapter_schema(self) -> None:
        schema = query.schema()
        self.assertEqual(schema.id, "moonrockz/bpmn-document-tree")
        self.assertEqual(schema.version, 1)
        self.assertEqual(schema.language_version, 1)
        self.assertIn("activity", schema.categories)
        self.assertIn(query.Name(MODEL, "userTask"), schema.kinds)
        self.assertIn(("bpmn", MODEL), schema.default_namespaces)
        self.assertTrue(schema.open_extensions)
        self.assertIn("query/unsupported-quantifier", schema.diagnostic_codes)
        self.assertIs(query.BPMN_SCHEMA, schema)

    def test_text_and_typed_forms_are_equal(self) -> None:
        text = (
            '((bpmn.process bpmn.flowElement: (bpmn.userTask) @t !bpmn.laneSet) @p'
            ' (#attr-in? @t "name" "Approve" "Other"))\n'
            "[(bpmn.task) (category.gateway)] @x"
        )
        form = query.QueryForm(
            (
                query.Rule(
                    query.NodePattern(
                        query.Kind(query.QName("process", "bpmn")),
                        (
                            query.Field(
                                query.QName("flowElement", "bpmn"),
                                query.NodePattern(
                                    query.Kind(query.QName("userTask", "bpmn")),
                                    captures=("t",),
                                ),
                            ),
                            query.Absent(query.QName("laneSet", "bpmn")),
                        ),
                        ("p",),
                    ),
                    (query.Predicate.attr_in("t", "name", ["Approve", "Other"]),),
                ),
                query.Rule(
                    query.Alternation(
                        (
                            query.NodePattern(query.Kind(query.QName("task", "bpmn"))),
                            query.NodePattern(query.Category("gateway")),
                        ),
                        ("x",),
                    )
                ),
            )
        )
        self.assertEqual(query.parse(text), form)
        a = query.compile(text)
        b = query.compile_form(form)
        self.assertEqual(a.normalized, b.normalized)
        self.assertEqual(a.capture_names, ("t", "p", "x"))
        tree = tree_of()
        ra = a.collect(tree, fields=("id",))
        rb = b.collect(tree, fields=("id",))
        self.assertEqual(
            [[(c.name, c.node.ordinal, c.values) for c in m.captures] for m in ra.matches],
            [[(c.name, c.node.ordinal, c.values) for c in m.captures] for m in rb.matches],
        )
        self.assertEqual(ra.state, "complete")

    def test_deep_forms_cross_the_boundary(self) -> None:
        # Each nesting level must not add record depth: 30 levels are valid
        # under the default nesting limit of 32.
        text = "(bpmn.process " * 29 + "(bpmn.task) @t" + ")" * 29
        form = query.parse(text)
        self.assertEqual(query.compile_form(form).normalized, query.compile(text).normalized)
        # A deeper typed form gets the MoonBit nesting diagnostic, not a
        # Python recursion error.
        deep = query.NodePattern(query.Kind(query.QName("task", "bpmn")))
        for _ in range(1500):
            deep = query.NodePattern(query.Wildcard(), (query.Child(deep),))
        with self.assertRaises(query.QueryCompileError) as caught:
            query.compile_form(query.QueryForm((query.Rule(deep),)))
        self.assertEqual(caught.exception.diagnostics[0].code, "query/nesting-limit")
        bigger = query.CompileLimits(nesting=1000)
        with self.assertRaises(query.QueryCompileError) as caught:
            query.compile_form(query.QueryForm((query.Rule(deep),)), limits=bigger)
        self.assertEqual(caught.exception.diagnostics[0].code, "query/nesting-limit")

    def test_typed_forms_have_the_same_checks_without_spans(self) -> None:
        bad = query.QueryForm(
            (query.Rule(query.NodePattern(query.Kind(query.QName("nope", "bpmn")))),)
        )
        with self.assertRaises(query.QueryCompileError) as caught:
            query.compile_form(bad)
        self.assertEqual(caught.exception.diagnostics[0].code, "query/unknown-kind")
        self.assertIsNone(caught.exception.diagnostics[0].span)
        regex = query.QueryForm(
            (
                query.Rule(
                    query.NodePattern(query.Wildcard(), captures=("n",)),
                    (query.Predicate("match?", "n", ("x",)),),
                ),
            )
        )
        with self.assertRaises(query.QueryCompileError) as caught:
            query.compile_form(regex)
        self.assertEqual(caught.exception.diagnostics[0].code, "query/unsupported-regex")

    def test_diagnostics_use_utf16_offsets(self) -> None:
        text = "; \U0001D518\r\n(bpmn.task)\r\n(\U0001D518"
        with self.assertRaises(query.QueryCompileError) as caught:
            query.compile(text)
        d = caught.exception.diagnostics[0]
        self.assertIsInstance(caught.exception, ValueError)
        self.assertEqual(d.code, "query/syntax")
        self.assertEqual((d.span.start.offset, d.span.end.offset), (20, 22))
        self.assertEqual((d.span.start.line, d.span.start.column), (3, 2))
        start = diagrams_mbt.code_point_index(text, d.span.start.offset)
        self.assertEqual(text[start], "\U0001D518")

    def test_compile_limits_and_namespace_map_are_checked(self) -> None:
        with self.assertRaises(query.QueryCompileError) as caught:
            query.compile("(bpmn.task)", limits=query.CompileLimits(source_units=3))
        self.assertEqual(caught.exception.diagnostics[0].code, "query/source-limit")
        with self.assertRaises(query.QueryCompileError) as caught:
            query.compile("(bpmn.task)", namespaces=[("bpmn", "urn:other")])
        self.assertEqual(caught.exception.diagnostics[0].code, "query/invalid-namespace-map")
        plan = query.compile("(v.thing) @t", namespaces=[("v", "urn:v")])
        self.assertEqual(plan.normalized, "({urn:v}thing) @t")


class ExecutionTest(unittest.TestCase):
    def test_captures_are_node_views_of_the_same_revision(self) -> None:
        tree = tree_of()
        result = query.compile(
            '((bpmn.userTask) @t (#attr-eq? @t "name" "Approve"))'
        ).collect(tree, fields=("id", "attr:name", "location", "path"))
        self.assertEqual([m.captures[0].node.id for m in result.matches], ["A", "B"])
        capture = result.matches[1].captures[0]
        self.assertEqual(capture.get("id"), query.Scalar("identifier", "B"))
        self.assertEqual(capture.get("attr:name"), query.Scalar("text", "Approve"))
        location = capture.get("location")
        self.assertEqual(location.source_id, "memory:q")
        self.assertEqual(location.start.offset, SOURCE.index("<userTask id='B'"))
        self.assertEqual(capture.node.handle, tree.node(capture.node.ordinal).handle)
        self.assertEqual(len(capture.get("path")), capture.node.depth)

    def test_retained_views_outlive_local_variables(self) -> None:
        tree = tree_of()
        plan = query.compile("(bpmn.userTask) @t")
        rows = plan.collect(tree, fields=("id",)).matches
        del tree
        gc.collect()
        node = rows[0].captures[0].node
        self.assertEqual(node.id, "A")
        self.assertEqual(node.parent().id, "P")

    def test_plans_are_reusable_and_cursors_independent(self) -> None:
        tree = tree_of()
        plan = query.compile("(category.activity) @a")
        first = plan.execute(tree, fields=("id",))
        second = plan.execute(tree, fields=("id",))
        a = first.next_batch(1)
        b = second.next_batch(3)
        self.assertEqual([r.captures[0].node.id for r in a.rows], ["A"])
        self.assertEqual(len(b.rows), 3)
        first.stop()
        self.assertEqual(first.next_batch(5).kind, "stopped")
        self.assertEqual(first.state, ("stopped", None))
        rest = second.next_batch(10)
        self.assertEqual([r.captures[0].node.id for r in rest.rows], ["D", "D"])
        self.assertEqual(second.next_batch(10).kind, "complete")
        second.close()
        second.close()
        # Closing the plan does not invalidate a cursor that is open.
        third = plan.execute(tree)
        plan.close()
        self.assertEqual(third.next_batch(1).kind, "rows")
        with self.assertRaises(_boundary.ClosedError):
            plan.execute(tree)
        third.close()
        with self.assertRaises(_boundary.ClosedError):
            third.next_batch(1)

    def test_limits_are_cumulative_and_truthful(self) -> None:
        tree = tree_of(large_source(200))
        plan = query.compile("(_) @n")
        cursor = plan.execute(tree, limits=query.ExecutionLimits(work=60))
        first = cursor.next_batch(5)
        self.assertEqual(first.kind, "rows")
        kinds = []
        while True:
            batch = cursor.next_batch(5)
            kinds.append(batch.kind)
            if batch.kind != "rows":
                break
        self.assertEqual(batch.kind, "failed")
        self.assertEqual(batch.failure, query.QueryFailure("limit", limit="work"))
        self.assertEqual(cursor.next_batch(5).failure.limit, "work")
        result = plan.collect(tree, limits=query.ExecutionLimits(results=3))
        self.assertEqual((len(result.matches), result.state), (3, "failed"))

    def test_unknown_projection_fields_are_input_failures(self) -> None:
        plan = query.compile("(bpmn.task) @t")
        with self.assertRaises(query.QueryCompileError) as caught:
            plan.execute(tree_of(), fields=("owner",))
        self.assertEqual(caught.exception.diagnostics[0].code, "query/unknown-projection-field")
        result = plan.collect(tree_of(), fields=("attr:name",))
        self.assertEqual([c.values for m in result.matches for c in m.captures], [(None,), (None,)])

    def test_concurrent_use_of_one_cursor_is_busy(self) -> None:
        cursor = query.compile("(_) @n").execute(tree_of())
        other = query.compile("(_) @n").execute(tree_of())
        with cursor._guard:
            with self.assertRaises(_boundary.BusyError):
                cursor.next_batch(1)
            self.assertEqual(other.next_batch(1).kind, "rows")
        self.assertEqual(cursor.next_batch(1).kind, "rows")

    def test_captured_handles_are_graph_endpoints(self) -> None:
        document = bpmn.read(SOURCE).document
        tree = document.tree().tree
        graph = DocumentGraph.new(document).graph
        rows = query.compile('((bpmn.task) @t (#attr-eq? @t "id" "D"))').collect(tree).matches
        second = rows[1].captures[0].node
        found = graph.lookup(second.handle)
        self.assertEqual(found.status, "Ok")
        self.assertEqual(found.node.node.ordinal, second.ordinal)
        self.assertEqual(graph.lookup(GraphEndpoint.id("D")).failure.kind, "Ambiguous")

    def test_a_selective_query_calls_no_python_code_per_candidate(self) -> None:
        plan = query.compile('((bpmn.userTask) @t (#attr-eq? @t "name" "n"))')
        counts = {}
        for size in (100, 3000):
            tree = tree_of(large_source(size))
            calls = []
            original = _boundary.call

            def counting(op, *args):
                calls.append(op)
                return original(op, *args)

            _boundary.call = counting
            python_calls = [0]

            def profile(frame, event, arg):
                if event == "call":
                    python_calls[0] += 1

            sys.setprofile(profile)
            try:
                result = plan.collect(tree, fields=("id",))
            finally:
                sys.setprofile(None)
                _boundary.call = original
            self.assertEqual([m.captures[0].node.id for m in result.matches], ["Needle"])
            counts[size] = (len(calls), python_calls[0])
        # The native call count and the Python call count do not grow with the
        # number of candidate nodes.
        self.assertEqual(counts[100][0], counts[3000][0])
        self.assertEqual(counts[100][1], counts[3000][1])
        self.assertLess(counts[3000][0], 10)

    def test_other_threads_run_during_a_long_native_query(self) -> None:
        # An ambiguous pattern with no match spends its whole work budget in
        # one native call before it reports the limit.
        tree = tree_of(large_source(3000))
        plan = query.compile("(bpmn.process (bpmn.task) (bpmn.task) (bpmn.serviceTask) @n)")
        ticks = []
        stop = threading.Event()

        def heartbeat() -> None:
            while not stop.is_set():
                ticks.append(time.perf_counter())
                time.sleep(0.0005)

        thread = threading.Thread(target=heartbeat)
        thread.start()
        try:
            time.sleep(0.01)
            cursor = plan.execute(tree, limits=query.ExecutionLimits(work=5_000_000))
            start = time.perf_counter()
            batch = cursor.next_batch(1)
            end = time.perf_counter()
        finally:
            stop.set()
            thread.join()
        during = [t for t in ticks if start < t < end]
        self.assertEqual(batch.failure, query.QueryFailure("limit", limit="work"))
        self.assertGreater(end - start, 0.02, "the native work must be long enough to observe")
        self.assertGreaterEqual(len(during), 3)


if __name__ == "__main__":
    unittest.main()
