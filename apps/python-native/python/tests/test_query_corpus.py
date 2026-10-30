"""The shared normalized query corpus through ``diagrams_mbt.query``.

The cases, BPMN fixtures and expected text are in ``tests/query-corpus/fixtures``.
The MoonBit runner ``tests/query-corpus/corpus.mbt`` gives the same text on
wasm, wasm-gc, js and native. This file writes it through the Python API and
must give the checked-in text exactly, with batch sizes 1, 64 and 256.

DIAGRAMS_QUERY_CORPUS can name the fixtures directory. Otherwise it is found
from DIAGRAMS_NATIVE_FIXTURES (``apps/python-native/fixtures``).
"""

from __future__ import annotations

import json
import os
import pathlib
import unittest
from typing import List, Optional, Tuple

from diagrams_mbt import bpmn, query


def fixtures_dir() -> pathlib.Path:
    explicit = os.environ.get("DIAGRAMS_QUERY_CORPUS")
    if explicit:
        return pathlib.Path(explicit)
    fixtures = pathlib.Path(os.environ["DIAGRAMS_NATIVE_FIXTURES"]).resolve()
    return fixtures.parents[2] / "tests" / "query-corpus" / "fixtures"


FIXTURES = fixtures_dir()


def deep_document() -> str:
    return (
        "<b:definitions xmlns:b='http://www.omg.org/spec/BPMN/20100524/MODEL'"
        " xmlns:v='urn:v' targetNamespace='urn:deep'>"
        + "<v:n>" * 10000
        + "<v:leaf/>"
        + "</v:n>" * 10000
        + "</b:definitions>"
    )


def quote(text: str) -> str:
    out = ['"']
    for c in text:
        if c == '"':
            out.append('\\"')
        elif c == "\\":
            out.append("\\\\")
        elif c == "\n":
            out.append("\\n")
        elif c == "\r":
            out.append("\\r")
        elif c == "\t":
            out.append("\\t")
        elif ord(c) < 0x20:
            out.append("\\u00%02x" % ord(c))
        else:
            out.append(c)
    out.append('"')
    return "".join(out)


def name_text(name: query.Name) -> str:
    if name.namespace_uri == "":
        return name.local_name
    return "{%s}%s" % (name.namespace_uri, name.local_name)


def position_text(p) -> str:
    return "%d:%d:%d" % (p.offset, p.line, p.column)


def value_text(value: object) -> str:
    if value is None:
        return "-"
    if isinstance(value, str):
        return quote(value)
    if isinstance(value, query.Scalar):
        return "%s:%s" % (value.tag, quote(value.text))
    if isinstance(value, query.Name):
        return name_text(value)
    if isinstance(value, bool):
        raise AssertionError("unexpected bool")
    if isinstance(value, int):
        return str(value)
    if isinstance(value, query.Location):
        source = value.source_id if value.source_id is not None else "-"
        return "%s@%s-%s" % (source, position_text(value.start), position_text(value.end))
    if isinstance(value, tuple):
        return "".join(
            "/%s[%d@%d]" % (name_text(s.field), s.index, s.position) for s in value
        )
    raise AssertionError("unexpected value %r" % (value,))


def diagnostic_text(d: query.QueryDiagnostic) -> str:
    if d.span is None:
        span = "-"
    else:
        s = d.span
        span = "%d-%d %d:%d-%d:%d" % (
            s.start.offset,
            s.end.offset,
            s.start.line,
            s.start.column,
            s.end.line,
            s.end.column,
        )
    return "error %s %s" % (d.code, span)


def failure_text(f: query.QueryFailure) -> str:
    if f.kind == "limit":
        return "failed limit %s" % f.limit
    if f.kind == "incompatible-schema":
        return "failed incompatible-schema %s %s" % (f.expected, f.actual)
    return "failed %s" % f.kind


class Case:
    def __init__(self, name: str):
        self.name = name
        self.document = ""
        self.namespaces: List[Tuple[str, str]] = []
        self.fields: Tuple[str, ...] = ()
        self.limits: Optional[query.ExecutionLimits] = None
        self.root_id: Optional[str] = None
        self.query = ""


def parse_cases(text: str) -> List[Case]:
    cases: List[Case] = []
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        if not lines[i].startswith("=== "):
            i += 1
            continue
        case = Case(lines[i][4:])
        i += 1
        while i < len(lines) and not lines[i].startswith("=== "):
            line = lines[i]
            i += 1
            if line == "query:":
                body = []
                while i < len(lines) and not lines[i].startswith("=== "):
                    body.append(lines[i])
                    i += 1
                while body and body[-1] == "":
                    body.pop()
                case.query = "\n".join(body)
                break
            key, value = line.split(": ", 1)
            if key == "document":
                case.document = value
            elif key == "namespaces":
                prefix, uri = value.split(" ")
                case.namespaces.append((prefix, uri))
            elif key == "fields":
                case.fields = tuple(value.split(" "))
            elif key == "limits":
                case.limits = query.ExecutionLimits(*(int(v) for v in value.split(" ")))
            elif key == "root-id":
                case.root_id = value
            elif key == "query-json":
                case.query = json.loads(value)
            else:
                raise AssertionError("unknown key %s" % key)
        cases.append(case)
    return cases


def run_rows(
    plan: query.QueryPlan, target, case: Case, size: int
) -> List[str]:
    cursor = plan.execute(
        target, fields=case.fields, namespaces=case.namespaces, limits=case.limits
    )
    lines = []
    try:
        while True:
            batch = cursor.next_batch(size)
            if batch.kind == "rows":
                assert len(batch.rows) <= size
                for row in batch.rows:
                    captures = " ".join(
                        "%s=%s#%d{%s}"
                        % (
                            c.name,
                            case.document,
                            c.node.ordinal,
                            ",".join(value_text(v) for v in c.values),
                        )
                        for c in row.captures
                    )
                    lines.append("match %d: %s" % (row.pattern, captures))
            elif batch.kind == "failed":
                lines.append("end " + failure_text(batch.failure))
                return lines
            else:
                lines.append("end " + batch.kind)
                return lines
    finally:
        cursor.close()


def run_case(case: Case) -> List[str]:
    if case.document == "generated:deep":
        source = deep_document()
    else:
        source = (FIXTURES / case.document).read_bytes().decode("utf-8")
    limits = bpmn.Limits(depth=20000)
    document = bpmn.read(source, source_id=case.document, limits=limits).document
    tree = document.tree(limits=limits).tree
    try:
        plan = query.compile(case.query, namespaces=case.namespaces)
    except query.QueryCompileError as error:
        return [diagnostic_text(d) for d in error.diagnostics]
    lines = ["plan " + plan.normalized.replace("\n", " | ")]
    target = tree
    if case.root_id is not None:
        target = next(
            tree.node(o) for o in range(tree.length) if tree.node(o).id == case.root_id
        )
    try:
        one = run_rows(plan, target, case, 1)
    except query.QueryCompileError as error:
        return lines + [diagnostic_text(d) for d in error.diagnostics]
    mid = run_rows(plan, target, case, 64)
    big = run_rows(plan, target, case, 256)
    if one != mid or one != big:
        lines.append("batch-mismatch")
    return lines + one


class QueryCorpusTest(unittest.TestCase):
    def test_corpus_matches_the_moonbit_output(self) -> None:
        cases = parse_cases((FIXTURES / "cases.txt").read_bytes().decode("utf-8"))
        self.assertGreater(len(cases), 30)
        out = []
        for case in cases:
            out.append("=== %s" % case.name)
            out.extend(run_case(case))
        actual = "\n".join(out) + "\n"
        expected = (FIXTURES / "expected.txt").read_bytes().decode("utf-8")
        if actual != expected:
            a, e = actual.split("\n"), expected.split("\n")
            for i, (x, y) in enumerate(zip(a, e)):
                if x != y:
                    self.fail("line %d differs:\n  python: %s\n  moonbit: %s" % (i + 1, x, y))
        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
