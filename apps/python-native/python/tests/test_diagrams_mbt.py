"""Tests of the diagrams_mbt Python binding: rendering parity and lifetime.

The build task sets these environment variables:

- DIAGRAMS_NATIVE_FIXTURES: the directory of the shared ``*.mmd`` fixtures.
- DIAGRAMS_NATIVE_ORACLE: the directory with the direct MoonBit results.
- DIAGRAMS_NATIVE_BADABI: optional, a build with a wrong boundary version.
- DIAGRAMS_NATIVE_REPEAT: optional, the rounds of repeated mixed calls.
"""

from __future__ import annotations

import gc
import importlib
import os
import pathlib
import subprocess
import sys
import unittest

import diagrams_mbt
from diagrams_mbt import _native

FIXTURES = pathlib.Path(os.environ["DIAGRAMS_NATIVE_FIXTURES"])
ORACLE = pathlib.Path(os.environ["DIAGRAMS_NATIVE_ORACLE"])
REPEAT = int(os.environ.get("DIAGRAMS_NATIVE_REPEAT", "50"))


def fixture_names() -> list[str]:
    return sorted(p.stem for p in FIXTURES.glob("*.mmd"))


def source(name: str) -> str:
    return (FIXTURES / f"{name}.mmd").read_bytes().decode("utf-8")


def escape(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace("\t", "\\t")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )


def result_text(rendered: diagrams_mbt.Rendered) -> str:
    """The same format that the native oracle writes."""
    lines = [
        f"media_type\t{rendered.media_type}",
        f"output\t{'present' if rendered.output is not None else 'absent'}",
    ]
    for d in rendered.diagnostics:
        if d.span is None:
            span = "-"
        else:
            s, e = d.span.start, d.span.end
            span = (
                f"{s.line}:{s.column}:{s.offset}-{e.line}:{e.column}:{e.offset}"
            )
        lines.append(
            f"diagnostic\t{d.severity}\t{d.code}\t{span}\t{escape(d.message)}"
        )
    return "\n".join(lines) + "\n"


class ParityTest(unittest.TestCase):
    def test_fixture_set_is_complete(self) -> None:
        names = fixture_names()
        for required in [
            "empty",
            "flowchart-invalid",
            "flowchart-valid",
            "unicode-non-bmp",
        ]:
            self.assertIn(required, names)

    def test_each_fixture_equals_direct_moonbit_output(self) -> None:
        for name in fixture_names():
            with self.subTest(fixture=name):
                rendered = diagrams_mbt.render_svg(source(name))
                expected = (ORACLE / f"{name}.result.txt").read_bytes()
                self.assertEqual(result_text(rendered), expected.decode("utf-8"))
                svg = ORACLE / f"{name}.svg"
                if rendered.output is None:
                    self.assertFalse(svg.exists())
                else:
                    self.assertEqual(
                        rendered.output.encode("utf-8"), svg.read_bytes()
                    )


class BehaviorTest(unittest.TestCase):
    def test_valid_flowchart_renders_svg(self) -> None:
        rendered = diagrams_mbt.render_svg(source("flowchart-valid"))
        self.assertTrue(rendered.ok)
        self.assertEqual(rendered.media_type, "image/svg+xml")
        self.assertTrue(rendered.output.startswith("<svg "))
        self.assertEqual(rendered.diagnostics, ())

    def test_invalid_syntax_gives_structured_diagnostics(self) -> None:
        rendered = diagrams_mbt.render_svg(source("flowchart-invalid"))
        self.assertFalse(rendered.ok)
        self.assertIsNone(rendered.output)
        [d] = rendered.diagnostics
        self.assertEqual(d.severity, "error")
        self.assertEqual(d.code, "flowchart/syntax")
        self.assertIsInstance(d.span, diagrams_mbt.Span)
        self.assertEqual((d.span.start.line, d.span.start.column), (2, 3))

    def test_empty_input_gives_diagnostic(self) -> None:
        rendered = diagrams_mbt.render_svg("")
        self.assertIsNone(rendered.output)
        self.assertEqual(
            [d.code for d in rendered.diagnostics], ["mermaid/missing-header"]
        )

    def test_non_bmp_text_keeps_its_value(self) -> None:
        rendered = diagrams_mbt.render_svg(source("unicode-non-bmp"))
        self.assertIsNotNone(rendered.output)
        for text in ["\U0001F680", "\U0001D518", "\U00010348", "漢字", "café"]:
            self.assertIn(text, rendered.output)

    def test_offsets_count_utf16_code_units(self) -> None:
        text = source("unicode-invalid")
        [d] = diagrams_mbt.render_svg(text).diagnostics
        start = diagrams_mbt.code_point_index(text, d.span.start.offset)
        end = diagrams_mbt.code_point_index(text, d.span.end.offset)
        self.assertEqual(text[start:end], 'A["\U0001F600 emoji"] --> B[')
        # The emoji counts as two UTF-16 code units, so the offset is one
        # more than the code-point index.
        self.assertEqual(d.span.end.offset, end + 1)

    def test_lone_surrogate_is_refused_before_the_call(self) -> None:
        before = _native._runtime_info()["calls"]
        with self.assertRaises(UnicodeEncodeError):
            diagrams_mbt.render_svg("flowchart TD\n  A[\ud800] --> B\n")
        after = _native._runtime_info()["calls"]
        self.assertEqual(before, after)

    def test_wrong_argument_type_raises_type_error(self) -> None:
        for value in [b"flowchart TD", None, 1]:
            with self.subTest(value=value), self.assertRaises(TypeError):
                diagrams_mbt.render_svg(value)

    def test_results_are_new_python_values(self) -> None:
        # The SVG text and every diagnostic come from C-owned copies, not
        # from MoonBit memory and not from a JSON document.
        first = diagrams_mbt.render_svg(source("flowchart-valid"))
        second = diagrams_mbt.render_svg(source("flowchart-valid"))
        self.assertEqual(first, second)
        self.assertIsNot(first.output, second.output)
        self.assertIs(type(first.diagnostics), tuple)

    def test_render_starts_no_child_process(self) -> None:
        events: list[str] = []
        watched = ("subprocess.", "os.posix_spawn", "os.fork", "os.exec", "os.system")

        def hook(event: str, args: object) -> None:
            if event.startswith(watched):
                events.append(event)

        sys.addaudithook(hook)
        for name in fixture_names():
            diagrams_mbt.render_svg(source(name))
        self.assertEqual(events, [])
        self.assertTrue(_native.__file__.endswith((".abi3.so", ".pyd")))


class LifetimeTest(unittest.TestCase):
    def test_runtime_is_initialized_once(self) -> None:
        first = sys.modules.pop("diagrams_mbt._native")
        sys.modules.pop("diagrams_mbt")
        try:
            module = importlib.import_module("diagrams_mbt")
            self.assertIsNot(module._native, first)
            self.assertEqual(module._native._runtime_info()["init_count"], 1)
            self.assertTrue(module.render_svg(source("state-valid")).ok)
        finally:
            sys.modules["diagrams_mbt._native"] = first
            sys.modules["diagrams_mbt"] = diagrams_mbt

    def test_repeated_mixed_calls_give_stable_results(self) -> None:
        names = fixture_names()
        sources = {name: source(name) for name in names}
        first = {name: diagrams_mbt.render_svg(sources[name]) for name in names}

        def mixed_round(round_index: int) -> int:
            refused = 0
            for offset in range(len(names)):
                name = names[(offset + round_index) % len(names)]
                if diagrams_mbt.render_svg(sources[name]) != first[name]:
                    self.fail(f"{name} changed in round {round_index}")
                try:
                    diagrams_mbt.render_svg("\udfff")
                except UnicodeEncodeError:
                    refused += 1
            return refused

        mixed_round(0)
        gc.collect()
        blocks = sys.getallocatedblocks()
        refused = sum(mixed_round(r) for r in range(REPEAT))
        gc.collect()
        self.assertEqual(refused, REPEAT * len(names))
        # A Python object leaked per call would add at least one block per
        # call, that is 2 * len(names) blocks per round.
        growth = sys.getallocatedblocks() - blocks
        self.assertLess(growth, 50, f"{growth} blocks after {REPEAT} rounds")

    @unittest.skipUnless(
        sys.version_info >= (3, 14), "concurrent.interpreters needs 3.14"
    )
    def test_isolated_subinterpreter_is_refused(self) -> None:
        from concurrent import interpreters

        interp = interpreters.create()
        try:
            with self.assertRaises(interpreters.ExecutionFailed) as caught:
                interp.exec("import diagrams_mbt._native")
            self.assertEqual(caught.exception.excinfo.type.__name__, "ImportError")
        finally:
            interp.close()

    @unittest.skipUnless(
        os.environ.get("DIAGRAMS_NATIVE_BADABI"), "no bad-ABI build"
    )
    def test_wrong_boundary_version_fails_import(self) -> None:
        env = dict(os.environ, PYTHONPATH=os.environ["DIAGRAMS_NATIVE_BADABI"])
        completed = subprocess.run(
            [sys.executable, "-c", "import diagrams_mbt"],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("ImportError", completed.stderr)
        self.assertIn("boundary version 2, adapter expects 0", completed.stderr)


if __name__ == "__main__":
    unittest.main()
