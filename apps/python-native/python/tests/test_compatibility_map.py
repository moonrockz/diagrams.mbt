"""The compatibility map in docs/python/compatibility.md is complete and true.

The test reads every table row of the map. It checks that each Python symbol
resolves, that each MoonBit symbol is in a generated MoonBit interface, and
that a fixed list of required MoonBit operations has a row. Repository files
are found from DIAGRAMS_NATIVE_FIXTURES.
"""

from __future__ import annotations

import dataclasses
import importlib
import inspect
import os
import pathlib
import re
import unittest
from typing import Dict, List, Tuple


def repo_root() -> pathlib.Path:
    fixtures = pathlib.Path(os.environ["DIAGRAMS_NATIVE_FIXTURES"]).resolve()
    return fixtures.parents[2]


ROOT = repo_root()
MAP = ROOT / "docs" / "python" / "compatibility.md"

# MoonBit symbol prefix -> generated interface.
INTERFACES = {
    "bpmn": "pkgs/bpmn/pkg.generated.mbti",
    "query": "pkgs/diagrams-query/pkg.generated.mbti",
    "query_bpmn": "pkgs/diagrams-query/bpmn/pkg.generated.mbti",
    "mermaid": "pkgs/diagrams-mermaid/pkg.generated.mbti",
    "render": "pkgs/diagrams/render/pkg.generated.mbti",
}

# Python symbol prefix -> module.
MODULES = {
    "diagrams_mbt": "diagrams_mbt",
    "bpmn": "diagrams_mbt.bpmn",
    "bpmn_graph": "diagrams_mbt.bpmn_graph",
    "query": "diagrams_mbt.query",
}

SECTIONS = [
    "Query schema, compilation, plans, execution and projection",
    "BPMN reading, trees and explicit resources",
    "Node inspection, handles and paths",
    "Walk, fold, reduce and pruned reduce",
    "Visitor and accept",
    "EventReader, EventSource and push_events",
    "TreeCursor",
    "DocumentGraph lookup, reachability and routes",
    "Mermaid rendering",
]


def rows() -> List[Tuple[str, List[str], List[str]]]:
    """``(section, MoonBit symbols, Python symbols)`` for each table row."""
    out = []
    section = ""
    header_seen = False
    for line in MAP.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            header_seen = False
            continue
        if not line.startswith("|") or section not in SECTIONS:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not header_seen:
            assert cells[:2] == ["MoonBit", "Python"], (section, cells)
            header_seen = True
            continue
        if set(cells[0]) <= {"-", " "}:
            continue
        out.append(
            (
                section,
                re.findall(r"`([^`]+)`", cells[0]),
                re.findall(r"`([^`]+)`", cells[1]),
            )
        )
    return out


def resolve_python(symbol: str) -> bool:
    prefix, _, rest = symbol.partition(".")
    module = importlib.import_module(MODULES[prefix])
    value: object = module
    parts = rest.split(".") if rest else []
    for i, part in enumerate(parts):
        if hasattr(value, part):
            value = getattr(value, part)
            continue
        # The last part may be a dataclass field without a default or an
        # attribute that __init__ assigns.
        if i == len(parts) - 1 and inspect.isclass(value):
            if dataclasses.is_dataclass(value) and part in {f.name for f in dataclasses.fields(value)}:
                return True
            init = getattr(value, "__init__", None)
            try:
                source = inspect.getsource(init)  # type: ignore[arg-type]
            except (OSError, TypeError):
                return False
            return re.search(rf"\bself\.{re.escape(part)}\s*[:=]", source) is not None
        return False
    return True


_interfaces: Dict[str, str] = {}


def interface(prefix: str) -> str:
    if prefix not in _interfaces:
        _interfaces[prefix] = (ROOT / INTERFACES[prefix]).read_text(encoding="utf-8")
    return _interfaces[prefix]


def block(text: str, type_name: str) -> str:
    """The body of a ``struct``, ``enum`` or ``trait`` declaration."""
    match = re.search(
        rf"^pub(?:\((?:all|open)\))? (?:struct|enum|trait) {re.escape(type_name)}(?:\[[^\]]*\])? \{{\n(.*?)^\}}",
        text,
        flags=re.M | re.S,
    )
    return "" if match is None else match.group(1)


def moonbit_exists(symbol: str) -> bool:
    match = re.fullmatch(r"@(\w+)\.(.+)", symbol)
    if match is None:
        return False
    text = interface(match.group(1))
    name = match.group(2)
    if "::" in name:
        type_name, member = name.split("::", 1)
        fn = rf"^pub fn(?:\[[^\]]*\])? {re.escape(type_name)}::{re.escape(member)}\("
        if re.search(fn, text, flags=re.M):
            return True
        body = block(text, type_name)
        return re.search(rf"^  (?:fn )?{re.escape(member)}\b", body, flags=re.M) is not None
    if "." in name:
        type_name, field = name.split(".", 1)
        return re.search(rf"^  {re.escape(field)} :", block(text, type_name), flags=re.M) is not None
    declaration = (
        rf"^pub(?: fn(?:\[[^\]]*\])? {re.escape(name)}\(| let {re.escape(name)} :"
        rf"|(?:\((?:all|open)\))? (?:struct|enum|trait|type|suberror) {re.escape(name)}\b)"
    )
    return re.search(declaration, text, flags=re.M) is not None


def methods(prefix: str, type_name: str) -> List[str]:
    """The public methods of a type, without derived and debug helpers."""
    found = re.findall(
        rf"^pub fn(?:\[[^\]]*\])? {re.escape(type_name)}::(\w+)\(", interface(prefix), flags=re.M
    )
    return sorted(set(found) - {"equal", "not_equal", "to_repr", "hash", "hash_combine", "compare"})


def trait_methods(prefix: str, trait: str) -> List[str]:
    return re.findall(r"^  fn (\w+)\(", block(interface(prefix), trait), flags=re.M)


def required() -> List[str]:
    out = [f"@bpmn.NodeRef::{m}" for m in methods("bpmn", "NodeRef")]
    out += [f"@bpmn.DocumentTree::{m}" for m in ("new", "root", "length", "resource_id", "lookup")]
    out += [f"@bpmn.NodePath::{m}" for m in ("depth", "steps", "resolve")]
    out += ["@bpmn.walk", "@bpmn.fold", "@bpmn.reduce", "@bpmn.reduce_pruned", "@bpmn.accept"]
    out += [f"@bpmn.Visitor::{m}" for m in trait_methods("bpmn", "Visitor")]
    out += [f"@bpmn.EventReader::{m}" for m in ("new", "iter", "next", "skip_children", "stop")]
    out += ["@bpmn.push_events", "@bpmn.EventSource"]
    out += [f"@bpmn.TreeCursor::{m}" for m in methods("bpmn", "TreeCursor")]
    out += [f"@bpmn.DocumentGraph::{m}" for m in ("new", "lookup", "reachable", "route")]
    out += ["@bpmn.read"]
    out += [
        "@query.compile",
        "@query.compile_form",
        "@query.parse",
        "@query.QueryPlan::execute",
        "@query.QueryPlan::collect",
        "@query.QueryCursor::next_batch",
        "@query.QueryCursor::stop",
        "@query.QueryCursor::close",
        "@query.Projection::new",
        "@mermaid.render_svg",
    ]
    return out


class CompatibilityMapTest(unittest.TestCase):
    def test_every_row_group_of_the_design_map_has_a_table(self) -> None:
        sections = {section for section, _, _ in rows()}
        self.assertEqual(sections, set(SECTIONS))

    def test_every_row_names_symbols_on_both_sides_or_none(self) -> None:
        for section, moonbit, python in rows():
            with self.subTest(section=section, moonbit=moonbit):
                self.assertTrue(python, "a row needs a Python symbol")

    def test_every_python_symbol_resolves(self) -> None:
        for _, _, python in rows():
            for symbol in python:
                with self.subTest(symbol=symbol):
                    self.assertTrue(resolve_python(symbol), symbol)

    def test_every_moonbit_symbol_is_in_a_generated_interface(self) -> None:
        for _, moonbit, _ in rows():
            for symbol in moonbit:
                with self.subTest(symbol=symbol):
                    self.assertTrue(moonbit_exists(symbol), symbol)

    def test_required_operations_are_mapped(self) -> None:
        mapped = {symbol for _, moonbit, _ in rows() for symbol in moonbit}
        needed = required()
        self.assertGreater(len(needed), 60)
        for symbol in needed:
            with self.subTest(symbol=symbol):
                self.assertTrue(moonbit_exists(symbol), f"{symbol} is not in its interface")
                self.assertIn(symbol, mapped)

    def test_the_checker_rejects_unknown_symbols(self) -> None:
        self.assertFalse(moonbit_exists("@bpmn.NodeRef::no_such_method"))
        self.assertFalse(moonbit_exists("@bpmn.no_such_function"))
        self.assertFalse(resolve_python("bpmn.Node.no_such_attribute"))
        self.assertTrue(moonbit_exists("@bpmn.Visitor::visit_activity"))
        self.assertTrue(moonbit_exists("@bpmn.Control::Stop"))
        self.assertTrue(moonbit_exists("@bpmn.DocumentGraph.nodes"))
        self.assertTrue(moonbit_exists("@bpmn.EventSource"))
        self.assertTrue(moonbit_exists("@bpmn.read"))
        self.assertFalse(moonbit_exists("@bpmn.NodeRe"))


if __name__ == "__main__":
    unittest.main()
