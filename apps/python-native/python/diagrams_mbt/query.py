"""Portable tree queries over BPMN document trees.

This module calls the public MoonBit query compiler and evaluator of
``moonrockz/diagrams-query`` and its BPMN adapter through the native
extension. It has no Python evaluator and no Python predicates: matching,
predicates, limits and projection run in MoonBit, and Python receives whole
batches of projected rows.

The query language is version 1 of the MoonBit package; see its README for
the grammar. ``compile`` and ``compile_form`` add the BPMN default namespace
bindings (``bpmn``, ``bpmndi``, ``dc``, ``di`` and ``tree``) to your bindings,
like ``@query_bpmn.compile`` in MoonBit. Query-source positions count UTF-16
code units; use ``diagrams_mbt.code_point_index`` to convert an offset.
"""

from __future__ import annotations

import weakref
from dataclasses import dataclass
from typing import Iterator, Optional, Sequence, Tuple, Union

from . import Position, Span, _boundary
from . import bpmn as _bpmn

__all__ = [
    "Absent",
    "Alternation",
    "BPMN_SCHEMA",
    "Capture",
    "Category",
    "Child",
    "CompileLimits",
    "ExecutionLimits",
    "Field",
    "Kind",
    "Location",
    "Name",
    "NodePattern",
    "PathStep",
    "Predicate",
    "QName",
    "QueryBatch",
    "QueryCompileError",
    "QueryCursor",
    "QueryDiagnostic",
    "QueryFailure",
    "QueryForm",
    "QueryMatch",
    "QueryPlan",
    "QueryResult",
    "Rule",
    "Scalar",
    "Schema",
    "Wildcard",
    "compile",
    "compile_form",
    "parse",
    "schema",
]


@dataclass(frozen=True)
class Name:
    """An expanded name. The empty URI means no namespace."""

    namespace_uri: str
    local_name: str


@dataclass(frozen=True)
class Scalar:
    """A present attribute or extra-field value with its schema scalar tag."""

    tag: str
    text: str


@dataclass(frozen=True)
class Location:
    """A source range; offsets and columns count UTF-16 code units."""

    source_id: Optional[str]
    start: Position
    end: Position


@dataclass(frozen=True)
class PathStep:
    """A document-relative path step: field, index in the field, position."""

    field: Name
    index: int
    position: int


@dataclass(frozen=True)
class Schema:
    """The published contract of the BPMN query adapter."""

    id: str
    version: int
    language_version: int
    kinds: Tuple[Name, ...]
    categories: Tuple[str, ...]
    fields: Tuple[Name, ...]
    reserved_namespaces: Tuple[str, ...]
    open_extensions: bool
    scalar_tags: Tuple[str, ...]
    extra_fields: Tuple[str, ...]
    default_namespaces: Tuple[Tuple[str, str], ...]
    diagnostic_codes: Tuple[str, ...]


@dataclass(frozen=True)
class QueryDiagnostic:
    """A compile or projection diagnostic. ``span`` is None for typed forms."""

    code: str
    severity: str
    message: str
    span: Optional[Span]


class QueryCompileError(ValueError):
    """Compilation or projection failed; ``diagnostics`` has the reasons."""

    def __init__(self, diagnostics: Tuple[QueryDiagnostic, ...]):
        self.diagnostics = diagnostics
        first = diagnostics[0] if diagnostics else None
        super().__init__(
            f"{first.code}: {first.message}" if first else "query failed"
        )


@dataclass(frozen=True)
class CompileLimits:
    """Compilation bounds; the defaults equal ``CompileLimits::new()``."""

    source_units: int = 65536
    patterns: int = 256
    pattern_nodes: int = 4096
    nesting: int = 32
    captures: int = 256
    predicates: int = 1024

    def _record(self) -> tuple:
        return (
            self.source_units,
            self.patterns,
            self.pattern_nodes,
            self.nesting,
            self.captures,
            self.predicates,
        )


@dataclass(frozen=True)
class ExecutionLimits:
    """Execution bounds, cumulative over all batches of one cursor."""

    work: int = 10_000_000
    pending: int = 100_000
    results: int = 1_000_000
    output_units: int = 100_000_000

    def _record(self) -> tuple:
        return (self.work, self.pending, self.results, self.output_units)


# Typed query form. These mirror the MoonBit QueryForm values.


@dataclass(frozen=True)
class QName:
    """An unresolved name; ``prefix`` is a query namespace prefix."""

    local_name: str
    prefix: Optional[str] = None


@dataclass(frozen=True)
class Kind:
    name: QName


@dataclass(frozen=True)
class Category:
    name: str


@dataclass(frozen=True)
class Wildcard:
    pass


Selector = Union[Kind, Category, Wildcard]


@dataclass(frozen=True)
class NodePattern:
    selector: Selector
    parts: Tuple["Part", ...] = ()
    captures: Tuple[str, ...] = ()


@dataclass(frozen=True)
class Alternation:
    branches: Tuple["Pattern", ...]
    captures: Tuple[str, ...] = ()


Pattern = Union[NodePattern, Alternation]


@dataclass(frozen=True)
class Child:
    pattern: Pattern


@dataclass(frozen=True)
class Field:
    name: QName
    pattern: Pattern


@dataclass(frozen=True)
class Absent:
    name: QName


Part = Union[Child, Field, Absent]


@dataclass(frozen=True)
class Predicate:
    """A native predicate; ``name`` has no ``#``, for example ``attr-eq?``."""

    name: str
    capture: str
    operands: Tuple[str, ...] = ()

    @staticmethod
    def has_attr(capture: str, attribute: str) -> "Predicate":
        return Predicate("has-attr?", capture, (attribute,))

    @staticmethod
    def missing_attr(capture: str, attribute: str) -> "Predicate":
        return Predicate("missing-attr?", capture, (attribute,))

    @staticmethod
    def attr_eq(capture: str, attribute: str, value: str) -> "Predicate":
        return Predicate("attr-eq?", capture, (attribute, value))

    @staticmethod
    def attr_not_eq(capture: str, attribute: str, value: str) -> "Predicate":
        return Predicate("attr-not-eq?", capture, (attribute, value))

    @staticmethod
    def attr_in(capture: str, attribute: str, values: Sequence[str]) -> "Predicate":
        return Predicate("attr-in?", capture, (attribute, *values))

    @staticmethod
    def text_eq(capture: str, value: str) -> "Predicate":
        return Predicate("text-eq?", capture, (value,))


@dataclass(frozen=True)
class Rule:
    pattern: Pattern
    predicates: Tuple[Predicate, ...] = ()


@dataclass(frozen=True)
class QueryForm:
    rules: Tuple[Rule, ...]


@dataclass(frozen=True)
class QueryFailure:
    """Why a cursor failed. ``limit`` is set for ``kind == "limit"``."""

    kind: str
    limit: Optional[str] = None
    expected: Optional[str] = None
    actual: Optional[str] = None


@dataclass(frozen=True)
class Capture:
    """A captured node and the projected values, in requested field order.

    A value is None when the node has no such value (absent), which differs
    from an empty string.
    """

    name: str
    node: "_bpmn.Node"
    fields: Tuple[str, ...]
    values: Tuple[object, ...]

    def get(self, field: str) -> object:
        """The value of a requested field."""
        return self.values[self.fields.index(field)]


@dataclass(frozen=True)
class QueryMatch:
    pattern: int
    captures: Tuple[Capture, ...]


@dataclass(frozen=True)
class QueryBatch:
    """``kind`` is ``rows``, ``complete``, ``stopped`` or ``failed``.

    Rows never claim completion; the next request gives the terminal state.
    """

    kind: str
    rows: Tuple[QueryMatch, ...] = ()
    failure: Optional[QueryFailure] = None


@dataclass(frozen=True)
class QueryResult:
    matches: Tuple[QueryMatch, ...]
    state: str
    failure: Optional[QueryFailure] = None


# Record conversion.


def _position(record: tuple) -> Position:
    offset, line, column = record
    return Position(line, column, offset)


def _diagnostics(records: tuple) -> Tuple[QueryDiagnostic, ...]:
    return tuple(
        QueryDiagnostic(
            code,
            severity,
            message,
            None if span is None else Span(_position(span[0]), _position(span[1])),
        )
        for code, severity, message, span in records
    )


def _qname_record(name: QName) -> tuple:
    return (name.prefix, name.local_name)


def _pattern_record(pattern: Pattern) -> tuple:
    if isinstance(pattern, NodePattern):
        selector = pattern.selector
        if isinstance(selector, Kind):
            sel = ("kind", *_qname_record(selector.name))
        elif isinstance(selector, Category):
            sel = ("category", selector.name)
        elif isinstance(selector, Wildcard):
            sel = ("any",)
        else:
            raise TypeError(f"unknown selector {selector!r}")
        parts = []
        for part in pattern.parts:
            if isinstance(part, Child):
                parts.append(("child", _pattern_record(part.pattern)))
            elif isinstance(part, Field):
                parts.append(
                    ("field", *_qname_record(part.name), _pattern_record(part.pattern))
                )
            elif isinstance(part, Absent):
                parts.append(("absent", *_qname_record(part.name)))
            else:
                raise TypeError(f"unknown part {part!r}")
        return ("node", sel, tuple(parts), tuple(pattern.captures))
    if isinstance(pattern, Alternation):
        return (
            "alt",
            tuple(_pattern_record(b) for b in pattern.branches),
            tuple(pattern.captures),
        )
    raise TypeError(f"unknown pattern {pattern!r}")


def _form_record(form: QueryForm) -> tuple:
    return tuple(
        (
            _pattern_record(rule.pattern),
            tuple((p.name, p.capture, tuple(p.operands)) for p in rule.predicates),
        )
        for rule in form.rules
    )


def _qname_of(prefix: Optional[str], local_name: str) -> QName:
    return QName(local_name, prefix)


def _pattern_of(record: tuple) -> Pattern:
    if record[0] == "node":
        _, sel, parts, captures = record
        if sel[0] == "kind":
            selector: Selector = Kind(_qname_of(sel[1], sel[2]))
        elif sel[0] == "category":
            selector = Category(sel[1])
        else:
            selector = Wildcard()
        decoded = []
        for part in parts:
            if part[0] == "child":
                decoded.append(Child(_pattern_of(part[1])))
            elif part[0] == "field":
                decoded.append(Field(_qname_of(part[1], part[2]), _pattern_of(part[3])))
            else:
                decoded.append(Absent(_qname_of(part[1], part[2])))
        return NodePattern(selector, tuple(decoded), tuple(captures))
    _, branches, captures = record
    return Alternation(tuple(_pattern_of(b) for b in branches), tuple(captures))


def _form_of(record: tuple) -> QueryForm:
    return QueryForm(
        tuple(
            Rule(
                _pattern_of(pattern),
                tuple(Predicate(n, c, tuple(o)) for n, c, o in predicates),
            )
            for pattern, predicates in record
        )
    )


def _failure(record: tuple) -> QueryFailure:
    kind = record[0]
    if kind == "limit":
        return QueryFailure(kind, limit=record[1])
    if kind == "incompatible-schema":
        return QueryFailure(kind, expected=record[1], actual=record[2])
    return QueryFailure(kind)


def _value(record: tuple) -> object:
    tag = record[0]
    if tag == "absent":
        return None
    if tag == "text":
        return record[1]
    if tag == "scalar":
        return Scalar(record[1], record[2])
    if tag == "name":
        return Name(record[1], record[2])
    if tag == "int":
        return record[1]
    if tag == "location":
        return Location(record[1], _position(record[2]), _position(record[3]))
    if tag == "path":
        return tuple(
            PathStep(Name(uri, local), index, position)
            for uri, local, index, position in record[1]
        )
    raise RuntimeError(f"unknown projected value {tag!r}")


def _release(op: str, token: int) -> None:
    # Finalizers must not raise; a token that is already closed is fine.
    try:
        _boundary.call(op, token)
    except Exception:
        pass


# Schema.

_schema_cache: Optional[Schema] = None


def schema() -> Schema:
    """The BPMN query adapter schema, read from the native library."""
    global _schema_cache
    if _schema_cache is None:
        r = _boundary.call("query_schema")
        _schema_cache = Schema(
            id=r[0],
            version=r[1],
            language_version=r[2],
            kinds=tuple(Name(u, n) for u, n in r[3]),
            categories=tuple(r[4]),
            fields=tuple(Name(u, n) for u, n in r[5]),
            reserved_namespaces=tuple(r[6]),
            open_extensions=r[7],
            scalar_tags=tuple(r[8]),
            extra_fields=tuple(r[9]),
            default_namespaces=tuple((p, u) for p, u in r[10]),
            diagnostic_codes=tuple(r[11]),
        )
    return _schema_cache


def __getattr__(name: str) -> object:
    if name == "BPMN_SCHEMA":
        return schema()
    raise AttributeError(name)


def _bindings(namespaces: Sequence[Tuple[str, str]]) -> tuple:
    return tuple(schema().default_namespaces) + tuple(
        (str(p), str(u)) for p, u in namespaces
    )


# Compilation.


def parse(text: str, *, limits: Optional[CompileLimits] = None) -> QueryForm:
    """Parse query text into its typed form, without schema checks."""
    r = _boundary.call("query_parse", text, None if limits is None else limits._record())
    if r[0] == "error":
        raise QueryCompileError(_diagnostics(r[1]))
    return _form_of(r[1])


def _plan(r: tuple) -> "QueryPlan":
    if r[0] == "error":
        raise QueryCompileError(_diagnostics(r[1]))
    return QueryPlan(r[1], r[2], r[3], r[4], r[5], r[6], tuple(r[7]))


def compile(
    text: str,
    *,
    namespaces: Sequence[Tuple[str, str]] = (),
    limits: Optional[CompileLimits] = None,
) -> "QueryPlan":
    """Compile query text for the BPMN adapter schema.

    Raises ``QueryCompileError`` with the MoonBit diagnostics.
    """
    return _plan(
        _boundary.call(
            "query_compile",
            text,
            _bindings(namespaces),
            None if limits is None else limits._record(),
        )
    )


def compile_form(
    form: QueryForm,
    *,
    namespaces: Sequence[Tuple[str, str]] = (),
    limits: Optional[CompileLimits] = None,
) -> "QueryPlan":
    """Compile a typed query form with the same checks as ``compile``."""
    return _plan(
        _boundary.call(
            "query_compile_form",
            _form_record(form),
            _bindings(namespaces),
            None if limits is None else limits._record(),
        )
    )


class _View:
    """The native query index of one tree, shared by its cursors."""

    def __init__(self, tree: "_bpmn.DocumentTree"):
        self.tree = tree
        self.token = _boundary.call("query_view_open", tree._token)
        weakref.finalize(self, _release, "query_view_close", self.token)


# One query index per live tree, keyed by the tree's unique native token. The
# entry goes away with the tree; open cursors keep their own view object.
_views: "dict[int, _View]" = {}


def _view(tree: "_bpmn.DocumentTree") -> _View:
    key = tree._token
    view = _views.get(key)
    if view is None:
        view = _View(tree)
        _views[key] = view
        weakref.finalize(tree, _views.pop, key, None)
    return view


class QueryPlan:
    """An immutable, reusable compiled query."""

    def __init__(
        self,
        token: int,
        normalized: str,
        language_version: int,
        schema_id: str,
        schema_version: int,
        pattern_count: int,
        capture_names: Tuple[str, ...],
    ):
        self._token = token
        self.normalized = normalized
        self.language_version = language_version
        self.schema_id = schema_id
        self.schema_version = schema_version
        self.pattern_count = pattern_count
        self.capture_names = capture_names
        self._finalizer = weakref.finalize(
            self, _release, "query_plan_close", token
        )

    def __repr__(self) -> str:
        return f"QueryPlan({self.normalized!r})"

    def close(self) -> None:
        """Release the native plan. Open cursors keep working."""
        self._finalizer()

    def execute(
        self,
        target: Union["_bpmn.DocumentTree", "_bpmn.Node"],
        *,
        fields: Sequence[str] = (),
        namespaces: Sequence[Tuple[str, str]] = (),
        limits: Optional[ExecutionLimits] = None,
    ) -> "QueryCursor":
        """Start an independent cursor below ``target``, including it.

        ``fields`` names the projected fields: ``kind``, ``category``,
        ``text``, ``location``, ``path``, ``depth``, ``field``,
        ``attr:<name>`` or ``id``. An unknown field raises
        ``QueryCompileError``.
        """
        if isinstance(target, _bpmn.Node):
            tree, root = target.tree, target.ordinal
        elif isinstance(target, _bpmn.DocumentTree):
            tree, root = target, None
        else:
            raise TypeError("target must be a bpmn.DocumentTree or bpmn.Node")
        view = _view(tree)
        fields = tuple(str(f) for f in fields)
        r = _boundary.call(
            "query_execute",
            self._token,
            view.token,
            root,
            fields,
            _bindings(namespaces),
            None if limits is None else limits._record(),
        )
        if r[0] == "error":
            raise QueryCompileError(_diagnostics(r[1]))
        return QueryCursor(r[1], self, view, fields)

    def collect(
        self,
        target: Union["_bpmn.DocumentTree", "_bpmn.Node"],
        *,
        fields: Sequence[str] = (),
        namespaces: Sequence[Tuple[str, str]] = (),
        limits: Optional[ExecutionLimits] = None,
        batch_size: int = 256,
    ) -> QueryResult:
        """Run a cursor to its terminal state and return all its matches."""
        cursor = self.execute(target, fields=fields, namespaces=namespaces, limits=limits)
        try:
            matches = []
            while True:
                batch = cursor.next_batch(batch_size)
                if batch.kind != "rows":
                    return QueryResult(tuple(matches), batch.kind, batch.failure)
                matches.extend(batch.rows)
        finally:
            cursor.close()


class QueryCursor:
    """An execution of a plan. Concurrent use of one cursor raises
    ``BusyError``; independent cursors do not share a position."""

    def __init__(self, token: int, plan: QueryPlan, view: _View, fields: Tuple[str, ...]):
        self._token = token
        self._plan = plan
        self._view = view
        self._fields = fields
        self._guard = _boundary.Exclusive()
        self._finalizer = weakref.finalize(self, _release, "query_close", token)

    def next_batch(self, size: int = 256) -> QueryBatch:
        """Return up to ``size`` rows, or the terminal state."""
        with self._guard:
            r = _boundary.call("query_next_batch", self._token, int(size))
        kind = r[0]
        if kind == "rows":
            tree = self._view.tree
            rows = tuple(
                QueryMatch(
                    pattern,
                    tuple(
                        Capture(
                            name,
                            _bpmn.Node._from_record(tree, node),
                            self._fields,
                            tuple(_value(v) for v in values),
                        )
                        for name, node, values in captures
                    ),
                )
                for pattern, captures in r[1]
            )
            return QueryBatch("rows", rows)
        if kind == "failed":
            return QueryBatch("failed", failure=_failure(r[1]))
        return QueryBatch(kind)

    @property
    def state(self) -> Tuple[str, Optional[QueryFailure]]:
        """``(state, failure)``; state is running, complete, stopped or failed."""
        with self._guard:
            r = _boundary.call("query_state", self._token)
        return (r[0], _failure(r[1]) if r[0] == "failed" else None)

    def stop(self) -> None:
        """Stop the cursor; it never claims completion afterwards."""
        with self._guard:
            _boundary.call("query_stop", self._token)

    def close(self) -> None:
        """Release the native cursor. Idempotent."""
        self._finalizer()

    def __iter__(self) -> Iterator[QueryMatch]:
        """Iterate the remaining matches. Check ``state`` afterwards: a
        failed or stopped cursor is not a complete result."""
        while True:
            batch = self.next_batch()
            if batch.kind != "rows":
                return
            yield from batch.rows
