"""BPMN reading, inspection and traversal through the shared MoonBit library.

Every domain operation calls the public ``moonrockz/bpmn`` API in the native
library. This module sequences Python callbacks and converts records; it has
no BPMN rule of its own. ``docs/python/traversal.md`` maps each name to its
MoonBit operation, with defaults, controls, failures, limits and units.

Source units: offsets and columns count UTF-16 code units; lines and columns
start at 1. Use ``diagrams_mbt.code_point_index`` to convert an offset to a
Python string index.

Ownership: a ``Document``, ``DocumentTree``, ``EventReader``, ``TreeCursor``,
``ResourceSet`` or ``DocumentGraph`` owns one native object. ``close()``
releases it at once and is idempotent; otherwise the last Python reference
releases it. A ``Node`` keeps its tree alive. A closed or stale owner gives
``diagrams_mbt._boundary.ClosedError`` or ``InvalidTokenError``.

Callbacks: ``walk``, ``fold``, ``reduce_pruned``, ``push_events`` and
``accept`` advance one native event at a time and run each callback outside
the runtime lock, so a callback can start another traversal or call
``render_svg``. A callback exception stops the traversal, releases its native
state, and propagates unchanged; no later callback runs.
"""

from __future__ import annotations

import enum
import weakref
from dataclasses import dataclass
from typing import (
    Any,
    Callable,
    Dict,
    Iterator,
    List,
    Optional,
    Protocol,
    Sequence,
    Tuple,
    TypeVar,
    Union,
)

from . import _boundary
from ._boundary import Exclusive

__all__ = [
    "Attribute",
    "Category",
    "Control",
    "Diagnostic",
    "Document",
    "DocumentTree",
    "ElementView",
    "Enter",
    "EventReader",
    "EventSource",
    "ExpandedName",
    "InvalidScalar",
    "Leave",
    "Limits",
    "Location",
    "Node",
    "NodeField",
    "NodeHandle",
    "NodeLookup",
    "NodePath",
    "NodeValue",
    "PathField",
    "PathStep",
    "Position",
    "ReadResult",
    "Reference",
    "Scalar",
    "Span",
    "Tree",
    "TraversalEvent",
    "TreeBuildResult",
    "TreeCursor",
    "Visitor",
    "accept",
    "fold",
    "push_events",
    "read",
    "reduce",
    "reduce_pruned",
    "walk",
]

A = TypeVar("A")
R = TypeVar("R")

# The largest observational batch of one native call.
MAX_EVENT_BATCH = 4096


def _release(token: int) -> None:
    """Close a native object. Used by finalizers; never raises."""
    try:
        _boundary.call("bpmn_close", token)
    except Exception:  # noqa: BLE001 - finalizers must not raise
        pass


class _Owner:
    """A Python object that owns one native token."""

    __slots__ = ("_token", "_finalizer", "__weakref__")

    def _own(self, token: int) -> None:
        self._token = token
        self._finalizer = weakref.finalize(self, _release, token)

    def close(self) -> None:
        """Release the native object now. Closing again does nothing."""
        self._finalizer()

    @property
    def closed(self) -> bool:
        return not self._finalizer.alive

    def __enter__(self):  # type: ignore[no-untyped-def]
        return self

    def __exit__(self, *exc_info: object) -> None:
        self.close()


# ---------------------------------------------------------------------------
# Values


@dataclass(frozen=True)
class ExpandedName:
    """A namespace-aware name. ``namespace_uri`` is ``""`` for no namespace."""

    namespace_uri: str
    local_name: str

    def __str__(self) -> str:
        return "{" + self.namespace_uri + "}" + self.local_name


@dataclass(frozen=True)
class Position:
    """``offset`` counts UTF-16 code units; ``line`` and ``column`` start at 1."""

    offset: int
    line: int
    column: int


@dataclass(frozen=True)
class Span:
    """Half-open UTF-16 offsets into the source."""

    start: int
    end: int


@dataclass(frozen=True)
class Location:
    source_id: Optional[str]
    start: Position
    end: Position


@dataclass(frozen=True)
class Diagnostic:
    """A reader, tree or graph finding. ``severity`` is ``"Error"`` or ``"Warning"``."""

    code: str
    severity: str
    message: str
    span: Optional[Span]
    location: Optional[Location]


@dataclass(frozen=True)
class Reference:
    """The detail of a ``Reference`` scalar. ``kind`` is ``"Id"`` or ``"QName"``."""

    kind: str
    spelling: str
    name: Optional[ExpandedName]


@dataclass(frozen=True)
class InvalidScalar:
    """The detail of an ``Invalid`` scalar: its raw text and expected type."""

    raw: str
    expected: ExpandedName


@dataclass(frozen=True)
class Scalar:
    """A typed attribute or text value.

    ``tag`` is the MoonBit ``Scalar`` constructor name: ``Text``,
    ``Identifier``, ``Uri``, ``Boolean``, ``Integer``, ``Number``,
    ``Reference``, ``Enumeration`` or ``Invalid``. ``token`` is
    ``Scalar::token``. ``detail`` is ``None``, a ``bool`` (``Boolean``), a
    ``Reference``, the enumeration type ``ExpandedName`` or an
    ``InvalidScalar``.
    """

    tag: str
    token: str
    detail: Union[None, bool, Reference, ExpandedName, InvalidScalar] = None


@dataclass(frozen=True)
class Attribute:
    """``name`` is ``None`` for an unbound prefixed name; ``raw_name`` is as written."""

    name: Optional[ExpandedName]
    raw_name: str
    value: Scalar
    span: Optional[Span]
    location: Optional[Location]


@dataclass(frozen=True)
class PathField:
    """A containment field. ``kind`` is ``Named`` (with ``name``), ``Text``,
    ``Comment``, ``ProcessingInstruction``, ``Root``, ``Prolog`` or ``Epilog``."""

    kind: str
    name: Optional[ExpandedName] = None

    @staticmethod
    def named(namespace_uri: str, local_name: str) -> "PathField":
        return PathField("Named", ExpandedName(namespace_uri, local_name))

    def __str__(self) -> str:
        return str(self.name) if self.kind == "Named" else self.kind


@dataclass(frozen=True)
class PathStep:
    """``index`` is within the field; ``content_index`` is the ordered-content index."""

    field: PathField
    index: int
    content_index: int


class Category(enum.Enum):
    """``NodeCategory``. The values are the MoonBit constructor names."""

    DOCUMENT = "Document"
    DEFINITIONS = "Definitions"
    PROCESS = "Process"
    ACTIVITY = "Activity"
    EVENT = "Event"
    GATEWAY = "Gateway"
    SEQUENCE_FLOW = "SequenceFlow"
    COLLABORATION = "Collaboration"
    PARTICIPANT = "Participant"
    LANE = "Lane"
    CHOREOGRAPHY = "Choreography"
    CHOREOGRAPHY_ACTIVITY = "ChoreographyActivity"
    CONVERSATION = "Conversation"
    CONVERSATION_LINK = "ConversationLink"
    DIAGRAM_INTERCHANGE = "DiagramInterchange"
    EXTENSION = "Extension"
    OTHER = "Other"
    TEXT = "Text"
    COMMENT = "Comment"
    PROCESSING_INSTRUCTION = "ProcessingInstruction"


class Control(enum.Enum):
    """The decision of an enter callback."""

    CONTINUE = "Continue"
    SKIP_CHILDREN = "SkipChildren"
    STOP = "Stop"


_CONTROL_CODE = {Control.CONTINUE: 0, Control.SKIP_CHILDREN: 1, Control.STOP: 2}


def _control_code(value: object) -> int:
    code = _CONTROL_CODE.get(value)  # type: ignore[call-overload]
    if code is None:
        raise TypeError(f"A callback must return a Control, not {value!r}")
    return code


@dataclass(frozen=True)
class Limits:
    """``Limits``. ``None`` keeps the MoonBit default; see ``Limits.defaults()``."""

    source_units: Optional[int] = None
    output_units: Optional[int] = None
    nodes: Optional[int] = None
    depth: Optional[int] = None
    token_units: Optional[int] = None
    diagnostics: Optional[int] = None

    @staticmethod
    def defaults() -> "Limits":
        """The values of ``Limits::new()``."""
        return Limits(*_boundary.call("bpmn_defaults")[0])

    def _record(self) -> Tuple[Optional[int], ...]:
        return (
            self.source_units,
            self.output_units,
            self.nodes,
            self.depth,
            self.token_units,
            self.diagnostics,
        )


def _limits(limits: Optional[Limits]) -> Optional[Tuple[Optional[int], ...]]:
    if limits is None:
        return None
    if not isinstance(limits, Limits):
        raise TypeError("limits must be a Limits")
    return limits._record()


# ---------------------------------------------------------------------------
# Record conversion. The layouts are in apps/python-native/bridge/traversal_records.mbt.


def _name(rec: Any) -> Optional[ExpandedName]:
    return None if rec is None else ExpandedName(rec[0], rec[1])


def _span(rec: Any) -> Optional[Span]:
    return None if rec is None else Span(rec[0], rec[1])


def _position(rec: Any) -> Position:
    return Position(rec[0], rec[1], rec[2])


def _location(rec: Any) -> Optional[Location]:
    if rec is None:
        return None
    return Location(rec[0], _position(rec[1]), _position(rec[2]))


def _diagnostics(recs: Sequence[Any]) -> Tuple[Diagnostic, ...]:
    return tuple(
        Diagnostic(r[0], r[1], r[2], _span(r[3]), _location(r[4])) for r in recs
    )


def _scalar(rec: Any) -> Optional[Scalar]:
    if rec is None:
        return None
    tag, token, detail = rec
    if tag == "Reference":
        detail = Reference(detail[0], detail[1], _name(detail[2]))
    elif tag == "Enumeration":
        detail = _name(detail)
    elif tag == "Invalid":
        detail = InvalidScalar(detail[0], ExpandedName(*detail[1]))
    return Scalar(tag, token, detail)


def _attribute(rec: Any) -> Attribute:
    return Attribute(
        _name(rec[0]), rec[1], _scalar(rec[2]), _span(rec[3]), _location(rec[4])  # type: ignore[arg-type]
    )


def _field(rec: Any) -> PathField:
    if rec[0] == "Named":
        return PathField("Named", ExpandedName(rec[1], rec[2]))
    return PathField(rec[0])


def _field_record(field: PathField) -> Tuple[str, ...]:
    if field.kind == "Named":
        if field.name is None:
            raise ValueError("A Named PathField needs a name")
        return ("Named", field.name.namespace_uri, field.name.local_name)
    return (field.kind,)


def _step(rec: Any) -> Optional[PathStep]:
    return None if rec is None else PathStep(_field(rec[0]), rec[1], rec[2])


# ---------------------------------------------------------------------------
# Reading and owners


@dataclass(frozen=True)
class ReadResult:
    """``read``: the document, absent after a syntax error, and the diagnostics."""

    document: Optional["Document"]
    diagnostics: Tuple[Diagnostic, ...]


@dataclass(frozen=True)
class TreeBuildResult:
    """``DocumentTree::new``: the tree, absent after a limit, and the diagnostics."""

    tree: Optional["DocumentTree"]
    diagnostics: Tuple[Diagnostic, ...]


def read(
    source: str, source_id: Optional[str] = None, limits: Optional[Limits] = None
) -> ReadResult:
    """``read(source, source_id?, limits?)``. Reads decoded XML without I/O."""
    token, diagnostics = _boundary.call("bpmn_read", source, source_id, _limits(limits))
    document = None if token is None else Document._wrap(token, source_id)
    return ReadResult(document, _diagnostics(diagnostics))


class Document(_Owner):
    """An immutable BPMN document that the native library owns."""

    __slots__ = ("source_id",)

    @staticmethod
    def _wrap(token: int, source_id: Optional[str]) -> "Document":
        document = Document.__new__(Document)
        document._own(token)
        document.source_id = source_id
        return document

    def tree(
        self, resource_id: Optional[str] = None, limits: Optional[Limits] = None
    ) -> TreeBuildResult:
        """``DocumentTree::new(self, resource_id?, limits?)``."""
        return DocumentTree.new(self, resource_id, limits)


class DocumentTree(_Owner):
    """``DocumentTree``: the indexed document, its revision and its nodes.

    Node ordinals are preorder indices. Two trees of the same document and
    resource identifier are the same revision and accept each other's handles.
    """

    __slots__ = ("length", "resource_id", "document", "_root")

    @staticmethod
    def new(
        document: Document,
        resource_id: Optional[str] = None,
        limits: Optional[Limits] = None,
    ) -> TreeBuildResult:
        """``DocumentTree::new(document, resource_id?, limits?)``."""
        if not isinstance(document, Document):
            raise TypeError("document must be a Document")
        token, diagnostics = _boundary.call(
            "bpmn_tree_new", document._token, resource_id, _limits(limits)
        )
        tree = None if token is None else DocumentTree._wrap(token, document)
        return TreeBuildResult(tree, _diagnostics(diagnostics))

    @staticmethod
    def _wrap(token: int, document: Optional[Document]) -> "DocumentTree":
        tree = DocumentTree.__new__(DocumentTree)
        tree._own(token)
        tree.document = document
        length, resource_id, root = _boundary.call("bpmn_tree_info", token)
        tree.length = length
        tree.resource_id = resource_id
        tree._root = Node._from_record(tree, root)
        return tree

    def root(self) -> "Node":
        """The document node, ordinal 0."""
        return self._root

    def node(self, ordinal: int) -> "Node":
        """The node with preorder ``ordinal``. ``InvalidArgumentError`` outside the tree."""
        return Node._from_record(self, _boundary.call("bpmn_node", self._token, ordinal))

    def lookup(self, handle: "NodeHandle") -> "NodeLookup":
        """``DocumentTree::lookup``: ``Found``, ``DocumentMismatch`` or ``InvalidHandle``."""
        handle = _as_handle(handle)
        rec = _boundary.call("bpmn_lookup", self._token, handle.tree._token, handle.ordinal)
        return _lookup(self, rec)

    def __repr__(self) -> str:
        return f"DocumentTree(resource_id={self.resource_id!r}, length={self.length})"


Tree = DocumentTree


# ---------------------------------------------------------------------------
# Nodes, handles and paths


@dataclass(frozen=True)
class NodeValue:
    """``NodeValue``. ``kind`` is ``Document``, ``Element``, ``Text``,
    ``Comment`` or ``ProcessingInstruction``. ``text`` holds text and comment
    content; ``target`` and ``data`` hold a processing instruction."""

    kind: str
    text: Optional[str] = None
    target: Optional[str] = None
    data: Optional[str] = None



def _value(rec: Any) -> NodeValue:
    kind = rec[0]
    if kind in ("Text", "Comment"):
        return NodeValue(kind, text=rec[1])
    if kind == "ProcessingInstruction":
        return NodeValue(kind, target=rec[1], data=rec[2])
    return NodeValue(kind)


@dataclass(frozen=True)
class NodeField:
    """``NodeField``: present attributes and children of one field, in order."""

    field: PathField
    attributes: Tuple[Attribute, ...]
    children: Tuple["Node", ...]


@dataclass(frozen=True)
class NodeLookup:
    """``NodeLookup``. ``status`` is ``Found`` (with ``node``),
    ``DocumentMismatch`` or ``InvalidHandle``."""

    status: str
    node: Optional["Node"] = None

    @property
    def found(self) -> bool:
        return self.status == "Found"


def _lookup(tree: DocumentTree, rec: Any) -> NodeLookup:
    if rec[0] == "Found":
        return NodeLookup("Found", Node._from_record(tree, rec[1]))
    return NodeLookup(rec[0])


class ElementView:
    """The read-only projection of an element value.

    Visitor family methods receive it as ``value``. It fetches its fields from
    the native library on first use only.
    """

    __slots__ = ("node", "_rec")

    def __init__(self, node: "Node") -> None:
        self.node = node
        self._rec: Any = None

    def _data(self) -> Any:
        if self._rec is None:
            self._rec = _boundary.call("bpmn_node_element", self.node._tree._token, self.node.ordinal)
        return self._rec

    @property
    def kind(self) -> ExpandedName:
        k = self._data()[0]
        return ExpandedName(k[0], k[1])

    @property
    def kind_class(self) -> str:
        """``standard``, ``foreign`` (``Kind::Foreign``) or ``unknown`` (``Kind::Unknown``)."""
        return self._data()[0][2]

    @property
    def bindings(self) -> Tuple[Tuple[str, str], ...]:
        """The ``(prefix, namespace_uri)`` bindings declared on the element."""
        return tuple((p, u) for p, u in self._data()[1])

    @property
    def value_type(self) -> Optional[ExpandedName]:
        return _name(self._data()[2])

    @property
    def text_value(self) -> Optional[Scalar]:
        return _scalar(self._data()[3])

    @property
    def content(self) -> str:
        return self._data()[4]

    @property
    def attributes(self) -> Tuple[Attribute, ...]:
        return self.node.attributes()

    def __repr__(self) -> str:
        return f"ElementView({self.node!r})"


class Node:
    """``NodeRef``: a read-only node view that keeps its tree alive.

    Snapshot properties need no native call: ``ordinal``, ``category``,
    ``kind``, ``kind_class``, ``id``, ``depth``, ``span``, ``step``,
    ``child_count``, ``value`` and ``handle``. Methods call the native library.
    """

    __slots__ = (
        "_tree",
        "ordinal",
        "category",
        "kind",
        "kind_class",
        "id",
        "depth",
        "_parent",
        "step",
        "span",
        "child_count",
        "value",
    )

    @staticmethod
    def _from_record(tree: DocumentTree, rec: Any) -> "Node":
        """A view of the node snapshot record ``rec`` of ``tree``."""
        node = Node.__new__(Node)
        node._tree = tree
        node.ordinal = rec[0]
        node.category = Category(rec[1])
        kind = rec[2]
        if kind is None:
            node.kind = None
            node.kind_class = None
        else:
            node.kind = ExpandedName(kind[0], kind[1])
            node.kind_class = kind[2]
        node.id = rec[3]
        node.depth = rec[4]
        node._parent = rec[5]
        node.step = _step(rec[6])
        node.span = _span(rec[7])
        node.child_count = rec[8]
        node.value = _value(rec[9])
        return node

    @property
    def tree(self) -> DocumentTree:
        return self._tree

    @property
    def resource_id(self) -> Optional[str]:
        return self._tree.resource_id

    @property
    def handle(self) -> "NodeHandle":
        return NodeHandle(self._tree, self.ordinal)

    def _call(self, op: str, *args: Any) -> Any:
        return _boundary.call(op, self._tree._token, self.ordinal, *args)

    def element(self) -> Optional[ElementView]:
        """The element projection, or ``None`` for other values."""
        return ElementView(self) if self.value.kind == "Element" else None

    def attributes(self) -> Tuple[Attribute, ...]:
        """Present attributes in source order, with no default values."""
        return tuple(_attribute(r) for r in self._call("bpmn_node_attributes"))

    def scalar(self, name: ExpandedName) -> Optional[Scalar]:
        return _scalar(self._call("bpmn_node_scalar", name.namespace_uri, name.local_name))

    def _node_field(self, rec: Any) -> NodeField:
        return NodeField(
            _field(rec[0]),
            tuple(_attribute(a) for a in rec[1]),
            tuple(Node._from_record(self._tree, c) for c in rec[2]),
        )

    def fields(self) -> Tuple[NodeField, ...]:
        return tuple(self._node_field(f) for f in self._call("bpmn_node_fields"))

    def field(self, field: PathField) -> Optional[NodeField]:
        rec = self._call("bpmn_node_field", _field_record(field))
        return None if rec is None else self._node_field(rec)

    def children(self) -> Tuple["Node", ...]:
        return tuple(Node._from_record(self._tree, c) for c in self._call("bpmn_node_children"))

    def parent(self) -> Optional["Node"]:
        return None if self._parent is None else self._tree.node(self._parent)

    def location(self) -> Optional[Location]:
        """The source location; ``None`` for constructed content."""
        return _location(self._call("bpmn_node_location"))

    def path(self) -> "NodePath":
        return NodePath(self)

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Node):
            return NotImplemented
        if self.ordinal != other.ordinal:
            return False
        if self._tree is other._tree:
            return True
        return bool(
            _boundary.call(
                "bpmn_node_equal", self._tree._token, self.ordinal, other._tree._token, other.ordinal
            )
        )

    def __hash__(self) -> int:
        return hash((self._tree.resource_id, self.ordinal))

    def __repr__(self) -> str:
        return f"Node(#{self.ordinal} {self.category.value} id={self.id!r})"


class NodeHandle:
    """``NodeHandle``: a revision-qualified node identity.

    Handles are equal only for the same ordinal in the same document revision
    and resource identifier. A handle never selects a node of another revision.
    """

    __slots__ = ("tree", "ordinal")

    def __init__(self, tree: DocumentTree, ordinal: int) -> None:
        self.tree = tree
        self.ordinal = ordinal

    @property
    def resource_id(self) -> Optional[str]:
        return self.tree.resource_id

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, NodeHandle):
            return NotImplemented
        if self.ordinal != other.ordinal:
            return False
        if self.tree is other.tree:
            return True
        return bool(
            _boundary.call(
                "bpmn_handle_equal", self.tree._token, self.ordinal, other.tree._token, other.ordinal
            )
        )

    def __hash__(self) -> int:
        return hash((self.tree.resource_id, self.ordinal))

    def __repr__(self) -> str:
        return f"NodeHandle(resource_id={self.resource_id!r}, ordinal={self.ordinal})"


def _as_handle(value: Union[NodeHandle, Node]) -> NodeHandle:
    if isinstance(value, Node):
        return value.handle
    if isinstance(value, NodeHandle):
        return value
    raise TypeError("expected a NodeHandle or a Node")


class NodePath:
    """``NodePath``: the document-relative path of a node."""

    __slots__ = ("node", "_steps")

    def __init__(self, node: Node) -> None:
        self.node = node
        self._steps: Optional[Tuple[PathStep, ...]] = None

    @property
    def depth(self) -> int:
        return self.node.depth

    def steps(self) -> Tuple[PathStep, ...]:
        if self._steps is None:
            self._steps = tuple(_step(s) for s in self.node._call("bpmn_node_path"))  # type: ignore[misc]
        return self._steps

    def resolve(self, tree: DocumentTree) -> NodeLookup:
        """``NodePath::resolve``: the same node in ``tree`` when it is the same revision."""
        rec = _boundary.call("bpmn_path_resolve", self.node._tree._token, self.node.ordinal, tree._token)
        return _lookup(tree, rec)

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, NodePath):
            return NotImplemented
        return self.node == other.node

    def __hash__(self) -> int:
        return hash(self.node)


# ---------------------------------------------------------------------------
# Events


@dataclass(frozen=True)
class TraversalEvent:
    node: Node


@dataclass(frozen=True)
class Enter(TraversalEvent):
    """``TraversalEvent::Enter``."""


@dataclass(frozen=True)
class Leave(TraversalEvent):
    """``TraversalEvent::Leave``."""


class EventSource(Protocol):
    """``EventSource``: any object with these methods drives ``push_events``."""

    def next(self) -> Optional[TraversalEvent]: ...

    def skip_children(self) -> None: ...

    def stop(self) -> None: ...


def _event(tree: DocumentTree, rec: Any) -> TraversalEvent:
    node = Node._from_record(tree, rec[1])
    return Enter(node) if rec[0] else Leave(node)


class EventReader(_Owner):
    """``EventReader``: pull events of a subtree in enter/leave order.

    ``skip_children()`` acts only right after an enter; ``stop()`` ends the
    reader. ``next_batch(n)`` observes up to ``n`` events in one native call;
    it never applies a control. Two threads that advance one reader at the
    same time get ``BusyError``.
    """

    __slots__ = ("_tree", "_guard")

    def __init__(self, root: Node) -> None:
        if not isinstance(root, Node):
            raise TypeError("root must be a Node")
        self._tree = root._tree
        self._guard = Exclusive("event reader")
        self._own(_boundary.call("bpmn_events_new", root._tree._token, root.ordinal))

    def _advance(self, control: int) -> Optional[TraversalEvent]:
        with self._guard:
            rec = _boundary.call("bpmn_events_next", self._token, control)
        return None if rec is None else _event(self._tree, rec)

    def next(self) -> Optional[TraversalEvent]:
        return self._advance(0)

    def skip_children(self) -> None:
        with self._guard:
            _boundary.call("bpmn_events_skip_children", self._token)

    def stop(self) -> None:
        with self._guard:
            _boundary.call("bpmn_events_stop", self._token)

    def next_batch(self, size: int = 256) -> Tuple[TraversalEvent, ...]:
        """Up to ``size`` (1 to 4096) next events; empty at the end."""
        with self._guard:
            recs = _boundary.call("bpmn_events_batch", self._token, size)
        return tuple(_event(self._tree, r) for r in recs)

    def batches(self, size: int = 256) -> Iterator[Tuple[TraversalEvent, ...]]:
        """Observational batches until the end."""
        while True:
            batch = self.next_batch(size)
            if not batch:
                return
            yield batch

    def __iter__(self) -> Iterator[TraversalEvent]:
        return self

    def __next__(self) -> TraversalEvent:
        event = self.next()
        if event is None:
            raise StopIteration
        return event


# ---------------------------------------------------------------------------
# Walking, folding and reduction


def _drive(
    root: Node,
    enter: Callable[[Node], Control],
    leave: Optional[Callable[[Node], None]],
) -> None:
    """``push_events(EventReader::new(root), enter, leave)``, one native event at a time.

    A control applies in the same native call that fetches the next event, so
    no event after a node is read before its enter decision.
    """
    if not isinstance(root, Node):
        raise TypeError("root must be a Node")
    tree = root._tree
    token = _boundary.call("bpmn_events_new", tree._token, root.ordinal)
    try:
        control = 0
        while True:
            rec = _boundary.call("bpmn_events_next", token, control)
            if rec is None:
                return
            node = Node._from_record(tree, rec[1])
            if rec[0]:
                control = _control_code(enter(node))
                if control == 2:
                    return
            else:
                control = 0
                if leave is not None:
                    leave(node)
    finally:
        _release(token)


def _observed(root: Node, size: int = 256) -> Iterator[TraversalEvent]:
    """All events of ``root`` through observational batches."""
    if not isinstance(root, Node):
        raise TypeError("root must be a Node")
    tree = root._tree
    token = _boundary.call("bpmn_events_new", tree._token, root.ordinal)
    try:
        while True:
            recs = _boundary.call("bpmn_events_batch", token, size)
            if not recs:
                return
            for rec in recs:
                yield _event(tree, rec)
    finally:
        _release(token)


def walk(
    root: Node,
    enter: Callable[[Node], Control],
    leave: Optional[Callable[[Node], None]] = None,
) -> None:
    """``walk(root, enter, leave?)``. A skipped node still leaves; stop ends at once."""
    _drive(root, enter, leave)


def fold(
    root: Node,
    initial: A,
    enter: Callable[[A, Node], Tuple[A, Control]],
    leave: Optional[Callable[[A, Node], A]] = None,
) -> A:
    """``fold(root, initial, enter, leave?)``. ``enter`` returns ``(value, control)``."""
    value = initial

    def on_enter(node: Node) -> Control:
        nonlocal value
        value, control = enter(value, node)
        return control

    def on_leave(node: Node) -> None:
        nonlocal value
        value = leave(value, node)  # type: ignore[misc]

    _drive(root, on_enter, None if leave is None else on_leave)
    return value


def reduce_pruned(
    root: Node,
    enter: Callable[[Node], Control],
    combine: Callable[[Node, Tuple[R, ...]], R],
) -> Optional[R]:
    """``reduce_pruned(root, enter, combine)``.

    A skipped node is combined with no child results; ``None`` after stop.
    """
    # One list of child results per entered node that has not left yet.
    stack: List[List[R]] = []
    result: List[R] = []

    def on_enter(node: Node) -> Control:
        control = enter(node)
        if control is not Control.STOP:
            stack.append([])
        return control

    def on_leave(node: Node) -> None:
        value = combine(node, tuple(stack.pop()))
        if stack:
            stack[-1].append(value)
        else:
            result.append(value)

    _drive(root, on_enter, on_leave)
    # After stop, the root never leaves, so there is no result.
    return result[0] if result else None


def reduce(root: Node, combine: Callable[[Node, Tuple[R, ...]], R]) -> R:
    """``reduce(root, combine)``: bottom-up, children in order.

    It has no control decision, so it reads observational batches.
    """
    stack: List[List[R]] = []
    for event in _observed(root):
        if isinstance(event, Enter):
            stack.append([])
        else:
            value = combine(event.node, tuple(stack.pop()))
            if not stack:
                return value
            stack[-1].append(value)
    raise RuntimeError("The traversal ended before its root")


def push_events(
    source: EventSource,
    enter: Callable[[Node], Control],
    leave: Optional[Callable[[Node], None]] = None,
) -> None:
    """``push_events(source, enter, leave?)`` over any ``EventSource``."""
    while True:
        event = source.next()
        if event is None:
            return
        if isinstance(event, Enter):
            control = _control_code(enter(event.node))
            if control == 1:
                source.skip_children()
            elif control == 2:
                source.stop()
                return
        elif isinstance(event, Leave):
            if leave is not None:
                leave(event.node)
        else:
            raise TypeError(f"An event source returned {event!r}")


# ---------------------------------------------------------------------------
# Visitors


class Visitor:
    """``Visitor``. Override only the methods you need.

    ``enter`` runs first. When it returns ``CONTINUE``, the family method of
    the node's category runs. ``leave`` runs for every visited node, including
    a node whose children were skipped. A method that a subclass does not
    override is never called. Typed family methods receive an
    ``ElementView`` as ``value``.
    """

    def enter(self, node: Node) -> Control:
        return Control.CONTINUE

    def leave(self, node: Node) -> None:
        return None

    def visit_definitions(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_process(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_activity(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_event(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_gateway(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_sequence_flow(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_collaboration(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_participant(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_lane(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_choreography(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_choreography_activity(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_conversation(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_conversation_link(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_extension(self, value: ElementView, node: Node) -> Control:
        return Control.CONTINUE

    def visit_document(self, node: Node) -> Control:
        return Control.CONTINUE

    def visit_diagram_interchange(self, node: Node) -> Control:
        return Control.CONTINUE

    def visit_text(self, node: Node) -> Control:
        return Control.CONTINUE

    def visit_comment(self, node: Node) -> Control:
        return Control.CONTINUE

    def visit_processing_instruction(self, node: Node) -> Control:
        return Control.CONTINUE

    def visit_other(self, node: Node) -> Control:
        return Control.CONTINUE


# The family method of each category, and whether it takes a typed value.
_FAMILIES: Dict[Category, Tuple[str, bool]] = {
    Category.DEFINITIONS: ("visit_definitions", True),
    Category.PROCESS: ("visit_process", True),
    Category.ACTIVITY: ("visit_activity", True),
    Category.EVENT: ("visit_event", True),
    Category.GATEWAY: ("visit_gateway", True),
    Category.SEQUENCE_FLOW: ("visit_sequence_flow", True),
    Category.COLLABORATION: ("visit_collaboration", True),
    Category.PARTICIPANT: ("visit_participant", True),
    Category.LANE: ("visit_lane", True),
    Category.CHOREOGRAPHY: ("visit_choreography", True),
    Category.CHOREOGRAPHY_ACTIVITY: ("visit_choreography_activity", True),
    Category.CONVERSATION: ("visit_conversation", True),
    Category.CONVERSATION_LINK: ("visit_conversation_link", True),
    Category.EXTENSION: ("visit_extension", True),
    Category.DOCUMENT: ("visit_document", False),
    Category.DIAGRAM_INTERCHANGE: ("visit_diagram_interchange", False),
    Category.TEXT: ("visit_text", False),
    Category.COMMENT: ("visit_comment", False),
    Category.PROCESSING_INSTRUCTION: ("visit_processing_instruction", False),
    Category.OTHER: ("visit_other", False),
}


def _implemented(visitor: object, name: str) -> Optional[Callable[..., Any]]:
    """The bound method ``name`` when ``visitor`` overrides the ``Visitor`` default."""
    method = getattr(type(visitor), name, None)
    if method is None or method is getattr(Visitor, name, None):
        return None
    return getattr(visitor, name)


def accept(root: Node, visitor: Visitor) -> None:
    """``accept(root, visitor)``. Overridden methods are resolved once."""
    enter = _implemented(visitor, "enter")
    leave = _implemented(visitor, "leave")
    families: Dict[Category, Tuple[Callable[..., Any], bool]] = {}
    for category, (name, typed) in _FAMILIES.items():
        method = _implemented(visitor, name)
        if method is not None:
            families[category] = (method, typed)
    if enter is None and not families:
        # No decision can change the order: observe without per-node controls.
        if leave is not None:
            for event in _observed(root):
                if isinstance(event, Leave):
                    leave(event.node)
        return

    def on_enter(node: Node) -> Control:
        control = Control.CONTINUE if enter is None else enter(node)
        if control is Control.CONTINUE:
            family = families.get(node.category)
            if family is not None:
                method, typed = family
                control = method(ElementView(node), node) if typed else method(node)
        return control

    _drive(root, on_enter, leave)


# ---------------------------------------------------------------------------
# Cursors


class TreeCursor(_Owner):
    """``TreeCursor``: moves within the subtree of its start node.

    A failed move returns ``False`` and keeps the position. ``depth()`` is
    relative to the start; ``path()`` is document-relative. Two threads that
    move one cursor at the same time get ``BusyError``.
    """

    __slots__ = ("_tree", "_guard", "_depth", "_node")

    def __init__(self, root: Node) -> None:
        if not isinstance(root, Node):
            raise TypeError("root must be a Node")
        self._tree = root._tree
        self._guard = Exclusive("tree cursor")
        token, depth, rec = _boundary.call("bpmn_cursor_new", root._tree._token, root.ordinal)
        self._own(token)
        self._depth = depth
        self._node = Node._from_record(self._tree, rec)

    def _move(self, move: str) -> bool:
        with self._guard:
            moved, depth, rec = _boundary.call("bpmn_cursor_move", self._token, move)
        if moved:
            self._depth = depth
            self._node = Node._from_record(self._tree, rec)
        return bool(moved)

    def goto_parent(self) -> bool:
        return self._move("parent")

    def goto_first_child(self) -> bool:
        return self._move("first_child")

    def goto_last_child(self) -> bool:
        return self._move("last_child")

    def goto_next_sibling(self) -> bool:
        return self._move("next_sibling")

    def goto_previous_sibling(self) -> bool:
        return self._move("previous_sibling")

    def node(self) -> Node:
        return self._node

    def depth(self) -> int:
        return self._depth

    def path(self) -> NodePath:
        return self._node.path()


# Graph queries live in bpmn_graph. They load on first use and are part of
# this namespace.
_GRAPH_NAMES = (
    "DocumentGraph",
    "DocumentResource",
    "ExternalNode",
    "ExternalResource",
    "GraphBuildResult",
    "GraphDirection",
    "GraphEdge",
    "GraphEdgeKind",
    "GraphEndpoint",
    "GraphFailure",
    "GraphLimit",
    "GraphLimits",
    "GraphNode",
    "GraphRoute",
    "IdEndpoint",
    "LookupResult",
    "NodeEndpoint",
    "QualifiedEndpoint",
    "ReachabilityResult",
    "ResolvedSymbol",
    "ResourceSet",
    "RouteResult",
    "SymbolEndpoint",
)

__all__ += list(_GRAPH_NAMES)


def __getattr__(name: str) -> Any:
    if name in _GRAPH_NAMES:
        from . import bpmn_graph

        return getattr(bpmn_graph, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
