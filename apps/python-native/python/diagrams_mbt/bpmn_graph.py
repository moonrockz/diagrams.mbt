"""Structural BPMN graph queries. Import the names from ``diagrams_mbt.bpmn``.

``DocumentGraph`` indexes a document and the resources that the caller
supplies. Nothing is fetched from a file or the network. ``lookup``,
``reachable`` and ``route`` call the MoonBit ``DocumentGraph`` methods. An
argument of ``None`` keeps the MoonBit default: edge kinds
``(GraphEdgeKind.SEQUENCE_FLOW,)``, direction ``GraphDirection.FORWARD`` and
``GraphLimits()`` (see ``GraphLimits.defaults()``).
"""

from __future__ import annotations

import enum
from dataclasses import dataclass
from typing import Any, Iterable, Optional, Sequence, Tuple, Union

from . import _boundary
from .bpmn import (
    Diagnostic,
    Document,
    DocumentTree,
    ExpandedName,
    Limits,
    Node,
    NodeHandle,
    _as_handle,
    _diagnostics,
    _limits,
    _Owner,
)

__all__ = [
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
]


class GraphEdgeKind(enum.Enum):
    """``GraphEdgeKind``. The values are the MoonBit constructor names."""

    CONTAINMENT = "Containment"
    SEQUENCE_FLOW = "SequenceFlow"
    MESSAGE_FLOW = "MessageFlow"
    ASSOCIATION = "Association"
    DATA_ASSOCIATION = "DataAssociation"
    CONVERSATION_LINK = "ConversationLink"
    REFERENCE = "Reference"


class GraphDirection(enum.Enum):
    FORWARD = "Forward"
    REVERSE = "Reverse"
    BOTH = "Both"


class GraphLimit(enum.Enum):
    """The bound of a ``Limit`` failure."""

    NODES = "Nodes"
    EDGES = "Edges"
    RESULTS = "Results"
    WORK = "Work"


@dataclass(frozen=True)
class GraphLimits:
    """``GraphLimits``. ``None`` keeps the MoonBit default; see ``defaults()``."""

    nodes: Optional[int] = None
    edges: Optional[int] = None
    results: Optional[int] = None
    work: Optional[int] = None

    @staticmethod
    def defaults() -> "GraphLimits":
        """The values of ``GraphLimits::new()``."""
        return GraphLimits(*_boundary.call("bpmn_defaults")[1])

    def _record(self) -> Tuple[Optional[int], ...]:
        return (self.nodes, self.edges, self.results, self.work)


def _graph_limits(limits: Optional[GraphLimits]) -> Any:
    if limits is None:
        return None
    if not isinstance(limits, GraphLimits):
        raise TypeError("limits must be a GraphLimits")
    return limits._record()


@dataclass(frozen=True)
class ResolvedSymbol:
    """An explicit external symbol: its resource location and expanded name."""

    resource_id: str
    name: ExpandedName


@dataclass(frozen=True)
class ExternalResource:
    """Caller-supplied non-BPMN identities for an import location."""

    location: str
    namespace_uri: str
    import_type: str
    symbols: Tuple[str, ...]

    def __init__(
        self, location: str, namespace_uri: str, import_type: str, symbols: Iterable[str]
    ) -> None:
        object.__setattr__(self, "location", location)
        object.__setattr__(self, "namespace_uri", namespace_uri)
        object.__setattr__(self, "import_type", import_type)
        object.__setattr__(self, "symbols", tuple(symbols))


@dataclass(frozen=True)
class DocumentResource:
    """A BPMN document for the literal import location ``location``."""

    location: str
    document: Document


class ResourceSet(_Owner):
    """``ResourceSet``: the explicit resources of a graph. No I/O happens."""

    __slots__ = ("documents", "external")

    def __init__(
        self,
        documents: Sequence[DocumentResource] = (),
        external: Sequence[ExternalResource] = (),
    ) -> None:
        self.documents = tuple(documents)
        self.external = tuple(external)
        for resource in self.documents:
            if not isinstance(resource, DocumentResource):
                raise TypeError("documents must hold DocumentResource values")
        for resource in self.external:
            if not isinstance(resource, ExternalResource):
                raise TypeError("external must hold ExternalResource values")
        token = _boundary.call(
            "bpmn_resources_new",
            tuple((r.location, r.document._token) for r in self.documents),
            tuple(
                (r.location, r.namespace_uri, r.import_type, r.symbols) for r in self.external
            ),
        )
        self._own(token)


@dataclass(frozen=True)
class NodeEndpoint:
    handle: NodeHandle


@dataclass(frozen=True)
class IdEndpoint:
    id: str


@dataclass(frozen=True)
class QualifiedEndpoint:
    name: ExpandedName


@dataclass(frozen=True)
class SymbolEndpoint:
    symbol: ResolvedSymbol


Endpoint = Union[NodeEndpoint, IdEndpoint, QualifiedEndpoint, SymbolEndpoint]


class GraphEndpoint:
    """Constructors of the four ``GraphEndpoint`` forms."""

    @staticmethod
    def node(handle: Union[NodeHandle, Node]) -> NodeEndpoint:
        """A revision-bound handle. It never falls back to the node's ID."""
        return NodeEndpoint(_as_handle(handle))

    @staticmethod
    def id(value: str) -> IdEndpoint:
        """A root-document ID."""
        return IdEndpoint(value)

    @staticmethod
    def qualified(namespace_uri: str, local_name: str) -> QualifiedEndpoint:
        return QualifiedEndpoint(ExpandedName(namespace_uri, local_name))

    @staticmethod
    def symbol(resource_id: str, namespace_uri: str, local_name: str) -> SymbolEndpoint:
        return SymbolEndpoint(ResolvedSymbol(resource_id, ExpandedName(namespace_uri, local_name)))


def _endpoint(value: Any) -> Tuple[Any, ...]:
    if isinstance(value, (Node, NodeHandle)):
        value = NodeEndpoint(_as_handle(value))
    if isinstance(value, NodeEndpoint):
        return ("Node", value.handle.tree._token, value.handle.ordinal)
    if isinstance(value, IdEndpoint):
        return ("Id", value.id)
    if isinstance(value, QualifiedEndpoint):
        return ("Qualified", value.name.namespace_uri, value.name.local_name)
    if isinstance(value, SymbolEndpoint):
        s = value.symbol
        return ("Symbol", s.resource_id, s.name.namespace_uri, s.name.local_name)
    raise TypeError(f"expected a graph endpoint, not {value!r}")


@dataclass(frozen=True)
class ExternalNode:
    symbol: ResolvedSymbol
    occurrence: int


@dataclass(frozen=True)
class GraphNode:
    """``GraphNode``: ``Document`` with ``node``, or ``External`` with ``external``."""

    kind: str
    node: Optional[Node] = None
    external: Optional[ExternalNode] = None

    @property
    def id(self) -> Optional[str]:
        """``GraphNode::id``."""
        if self.node is not None:
            return self.node.id
        return self.external.symbol.name.local_name  # type: ignore[union-attr]


@dataclass(frozen=True)
class GraphEdge:
    kind: GraphEdgeKind
    source: GraphNode
    target: GraphNode
    connection: Optional[Node]


@dataclass(frozen=True)
class GraphRoute:
    nodes: Tuple[GraphNode, ...]
    edges: Tuple[GraphEdge, ...]


@dataclass(frozen=True)
class GraphFailure:
    """``GraphFailure``. ``kind`` is ``InvalidEndpoint``, ``DocumentMismatch``,
    ``InvalidReference`` (with ``handle``), ``Ambiguous`` (with ``nodes``),
    ``Limit`` (with ``limit``) or ``InvalidLimits``."""

    kind: str
    handle: Optional[NodeHandle] = None
    nodes: Tuple[GraphNode, ...] = ()
    limit: Optional[GraphLimit] = None


@dataclass(frozen=True)
class LookupResult:
    """``Result[GraphNode, GraphFailure]``: ``status`` is ``Ok`` or ``Err``."""

    status: str
    node: Optional[GraphNode] = None
    failure: Optional[GraphFailure] = None


@dataclass(frozen=True)
class ReachabilityResult:
    """``ReachabilityResult``: ``status`` is ``Complete`` or ``Failed``."""

    status: str
    nodes: Tuple[GraphNode, ...] = ()
    failure: Optional[GraphFailure] = None


@dataclass(frozen=True)
class RouteResult:
    """``RouteResult``: ``status`` is ``Found``, ``Unreachable`` or ``Failed``."""

    status: str
    route: Optional[GraphRoute] = None
    failure: Optional[GraphFailure] = None


@dataclass(frozen=True)
class GraphBuildResult:
    graph: Optional["DocumentGraph"]
    diagnostics: Tuple[Diagnostic, ...]


def _kinds(kinds: Optional[Iterable[GraphEdgeKind]]) -> Any:
    if kinds is None:
        return None
    out = []
    for kind in kinds:
        if not isinstance(kind, GraphEdgeKind):
            raise TypeError("kinds must hold GraphEdgeKind values")
        out.append(kind.value)
    return tuple(out)


def _direction(direction: Optional[GraphDirection]) -> Any:
    if direction is None:
        return None
    if not isinstance(direction, GraphDirection):
        raise TypeError("direction must be a GraphDirection")
    return direction.value


class DocumentGraph(_Owner):
    """``DocumentGraph``: the explicit document and resource closure."""

    __slots__ = ("document", "resource_id", "resources", "_trees", "_content")

    @staticmethod
    def new(
        document: Document,
        resources: Optional[ResourceSet] = None,
        resource_id: Optional[str] = None,
        limits: Optional[Limits] = None,
        graph_limits: Optional[GraphLimits] = None,
    ) -> GraphBuildResult:
        """``DocumentGraph::new(document, resources?, resource_id?, limits?, graph_limits?)``."""
        if not isinstance(document, Document):
            raise TypeError("document must be a Document")
        if resources is not None and not isinstance(resources, ResourceSet):
            raise TypeError("resources must be a ResourceSet")
        token, diagnostics = _boundary.call(
            "bpmn_graph_new",
            document._token,
            None if resources is None else resources._token,
            resource_id,
            _limits(limits),
            _graph_limits(graph_limits),
        )
        graph = None
        if token is not None:
            graph = DocumentGraph.__new__(DocumentGraph)
            graph._own(token)
            graph.document = document
            graph.resource_id = resource_id
            graph.resources = resources
            graph._trees = {}
            graph._content = None
        return GraphBuildResult(graph, _diagnostics(diagnostics))

    def _tree_for(self, resource_id: Optional[str]) -> DocumentTree:
        """The tree of the graph document with ``resource_id``, made once."""
        tree = self._trees.get(resource_id)
        if tree is None:
            token = _boundary.call("bpmn_graph_tree", self._token, resource_id)
            document = self.document
            if resource_id != self.resource_id and self.resources is not None:
                for resource in self.resources.documents:
                    if resource.location == resource_id:
                        document = resource.document
                        break
            tree = DocumentTree._wrap(token, document)
            self._trees[resource_id] = tree
        return tree

    def _node(self, rec: Any) -> GraphNode:
        if rec[0] == "Document":
            return GraphNode("Document", node=Node._from_record(self._tree_for(rec[1]), rec[2]))
        symbol = ResolvedSymbol(rec[1], ExpandedName(rec[2], rec[3]))
        return GraphNode("External", external=ExternalNode(symbol, rec[4]))

    def _nodes(self, recs: Sequence[Any]) -> Tuple[GraphNode, ...]:
        return tuple(self._node(r) for r in recs)

    def _edge(self, rec: Any) -> GraphEdge:
        connection = None
        if rec[3] is not None:
            connection = Node._from_record(self._tree_for(rec[3][0]), rec[3][1])
        return GraphEdge(GraphEdgeKind(rec[0]), self._node(rec[1]), self._node(rec[2]), connection)

    def _failure(self, rec: Any) -> GraphFailure:
        kind = rec[0]
        if kind == "InvalidReference":
            return GraphFailure(kind, handle=NodeHandle(self._tree_for(rec[1][0]), rec[1][1]))
        if kind == "Ambiguous":
            return GraphFailure(kind, nodes=self._nodes(rec[1]))
        if kind == "Limit":
            return GraphFailure(kind, limit=GraphLimit(rec[1]))
        return GraphFailure(kind)

    def _load(self) -> Tuple[Tuple[GraphNode, ...], Tuple[GraphEdge, ...]]:
        if self._content is None:
            nodes, edges = _boundary.call("bpmn_graph_content", self._token)
            self._content = (self._nodes(nodes), tuple(self._edge(e) for e in edges))
        return self._content

    @property
    def nodes(self) -> Tuple[GraphNode, ...]:
        """All graph nodes in index order."""
        return self._load()[0]

    @property
    def edges(self) -> Tuple[GraphEdge, ...]:
        """All graph edges in index order."""
        return self._load()[1]

    def lookup(self, endpoint: Any, limits: Optional[GraphLimits] = None) -> LookupResult:
        """``DocumentGraph::lookup(endpoint, limits?)``."""
        rec = _boundary.call("bpmn_graph_lookup", self._token, _endpoint(endpoint), _graph_limits(limits))
        if rec[0] == "Ok":
            return LookupResult("Ok", node=self._node(rec[1]))
        return LookupResult("Err", failure=self._failure(rec[1]))

    def reachable(
        self,
        start: Any,
        kinds: Optional[Iterable[GraphEdgeKind]] = None,
        direction: Optional[GraphDirection] = None,
        limits: Optional[GraphLimits] = None,
    ) -> ReachabilityResult:
        """``DocumentGraph::reachable(start, kinds?, direction?, limits?)``: breadth first, start first."""
        rec = _boundary.call(
            "bpmn_graph_reachable",
            self._token,
            _endpoint(start),
            _kinds(kinds),
            _direction(direction),
            _graph_limits(limits),
        )
        if rec[0] == "Complete":
            return ReachabilityResult("Complete", nodes=self._nodes(rec[1]))
        return ReachabilityResult("Failed", failure=self._failure(rec[1]))

    def route(
        self,
        start: Any,
        target: Any,
        kinds: Optional[Iterable[GraphEdgeKind]] = None,
        direction: Optional[GraphDirection] = None,
        limits: Optional[GraphLimits] = None,
    ) -> RouteResult:
        """``DocumentGraph::route(start, target, kinds?, direction?, limits?)``: one shortest route."""
        rec = _boundary.call(
            "bpmn_graph_route",
            self._token,
            _endpoint(start),
            _endpoint(target),
            _kinds(kinds),
            _direction(direction),
            _graph_limits(limits),
        )
        if rec[0] == "Found":
            route = GraphRoute(self._nodes(rec[1]), tuple(self._edge(e) for e in rec[2]))
            return RouteResult("Found", route=route)
        if rec[0] == "Unreachable":
            return RouteResult("Unreachable")
        return RouteResult("Failed", failure=self._failure(rec[1]))
