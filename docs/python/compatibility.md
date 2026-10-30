---
title: MoonBit and Python compatibility map
summary: The checked map from each public MoonBit query, BPMN traversal, graph and rendering operation to its Python operation, with defaults, controls, failures, limits and source units.
order: 5
---
# MoonBit and Python compatibility map

This page is the single compatibility map of the Python package. Each row
gives the exact public MoonBit symbol and the Python symbol that calls it.
The test `apps/python-native/python/tests/test_compatibility_map.py` reads
these tables. It checks that each Python symbol exists, that each MoonBit
symbol is in a generated interface, and that no required operation is
missing. A missing mapped operation blocks a parity claim.

Symbol prefixes:

| Prefix | MoonBit package | Prefix | Python module |
| --- | --- | --- | --- |
| `@bpmn.` | `moonrockz/bpmn` | `bpmn.` | `diagrams_mbt.bpmn` |
| `@query.` | `moonrockz/diagrams-query` | `query.` | `diagrams_mbt.query` |
| `@query_bpmn.` | `moonrockz/diagrams-query/bpmn` | `bpmn_graph.` | `diagrams_mbt.bpmn_graph` (also in `bpmn.`) |
| `@mermaid.` | `moonrockz/diagrams-mermaid` | `diagrams_mbt.` | `diagrams_mbt` |
| `@render.` | `moonrockz/diagrams/render` | | |

Rules for every row:

- An optional MoonBit argument maps to a Python keyword argument with the
  default `None`, or to the same default value. `None` keeps the MoonBit
  default; Python adds no other default.
- MoonBit enums map to Python enums or `str` tags with the MoonBit
  constructor names. Optional values map to `None`. Read-only arrays map to
  tuples.
- Integers are Python `int`. MoonBit uses 32-bit `Int` for limits, ordinals,
  offsets and counts. A value outside that range raises
  `InvalidArgumentError`.
- Source units: offsets, columns and span ends count UTF-16 code units; lines
  and columns start at 1. `diagrams_mbt.code_point_index` converts an offset
  to a Python string index.
- A closed owner raises `ClosedError`; a token of another kind raises
  `InvalidTokenError`; concurrent use of one cursor or reader raises
  `BusyError`. The errors are in `diagrams_mbt._boundary`.

Details: [BPMN traversal](traversal.md) and [tree queries](query.md).

## Query schema, compilation, plans, execution and projection

| MoonBit | Python | Defaults and controls | Failures, limits and units |
| --- | --- | --- | --- |
| `@query.parse` | `query.parse` | Text to a typed `QueryForm`; no schema check | `QueryCompileError` (a `ValueError`) with `QueryDiagnostic` values; spans in UTF-16 units |
| `@query.compile`, `@query_bpmn.compile` | `query.compile` | `namespaces=()` adds to the BPMN default prefixes `bpmn`, `bpmndi`, `dc`, `di`, `tree` | `QueryCompileError`; a repeated default prefix gives `query/invalid-namespace-map` |
| `@query.compile_form`, `@query_bpmn.compile_form`, `@query.QueryForm::new` | `query.compile_form`, `query.QueryForm` | The same checks as text | Equal plans: `query.QueryPlan.normalized` |
| `@query.CompileLimits::new` | `query.CompileLimits` | 65,536 source units, 256 patterns, 4,096 pattern nodes, nesting 32, 256 captures, 1,024 predicates | A bound gives a compile diagnostic |
| `@query.QueryPlan::normalized` | `query.QueryPlan.normalized` | Immutable and reusable | |
| `@query_bpmn.schema` | `query.schema` | The BPMN adapter schema | |
| `@query.Projection::new`, `@query.Projection::identity` | `query.QueryPlan.execute`, `query.QueryPlan.collect` | Python `fields=()` is `Projection::identity`; names are `kind`, `category`, `text`, `location`, `path`, `depth`, `field`, attribute names and adapter extras | An unknown field gives `QueryCompileError` with `query/unknown-projection-field` |
| `@query.QueryPlan::execute` | `query.QueryPlan.execute`, `query.QueryCursor` | Root is the tree root, or a `bpmn.Node`; the search includes the root | `ExecutionLimits` apply per cursor |
| `@query.ExecutionLimits::new` | `query.ExecutionLimits` | 10,000,000 work, 100,000 pending, 1,000,000 results, 100,000,000 output units | Cumulative over all batches; no batch resets a budget |
| `@query.QueryCursor::next_batch`, `@query.QueryBatch` | `query.QueryCursor.next_batch`, `query.QueryBatch` | `Rows` never claim completion; the next request gives `Complete`, `Stopped` or `Failed` | `Failed(Limit(...))` names `work`, `pending`, `results` or `output` |
| `@query.QueryCursor::state`, `@query.CursorState` | `query.QueryCursor.state` | `running`, `complete`, `stopped`, `failed` | `QueryFailure` for `failed` |
| `@query.QueryCursor::stop`, `@query.QueryCursor::close` | `query.QueryCursor.stop`, `query.QueryCursor.close` | Close is idempotent | A closed cursor raises `ClosedError` |
| `@query.QueryPlan::collect`, `@query.QueryResult` | `query.QueryPlan.collect`, `query.QueryResult` | Runs to a terminal state | `QueryResult.state` tells if it completed |
| `@query.QueryMatch`, `@query_bpmn.BpmnTree::captured` | `query.QueryMatch`, `query.Capture.node` | Captures are `bpmn.Node` views of the same revision and ordinal | Absent projected values are `None` |
| `@query.QueryDiagnostic` | `query.QueryDiagnostic`, `query.QueryCompileError` | | UTF-16 offset, 1-based line and column |

## BPMN reading, trees and explicit resources

| MoonBit | Python | Defaults and controls | Failures, limits and units |
| --- | --- | --- | --- |
| `@bpmn.read`, `@bpmn.ReadResult` | `bpmn.read`, `bpmn.ReadResult` | `source_id=None`, `limits=None`; no I/O | `document` is `None` after a syntax error; `diagnostics` keep spans and locations |
| `@bpmn.Limits::new` | `bpmn.Limits`, `bpmn.Limits.defaults` | 16,777,216 source and output units, 1,000,000 nodes, depth 4,096, 1,048,576 token units, 256 diagnostics | A non-positive limit gives `xml/invalid-limits` or `bpmn/traversal-invalid-limits` |
| `@bpmn.DocumentTree::new`, `@bpmn.TreeBuildResult` | `bpmn.DocumentTree.new`, `bpmn.Document.tree`, `bpmn.TreeBuildResult` | `resource_id=None`, `limits=None` | `tree` is `None` with a `bpmn/traversal-*` diagnostic |
| `@bpmn.DocumentTree::root`, `@bpmn.DocumentTree::length`, `@bpmn.DocumentTree::resource_id` | `bpmn.DocumentTree.root`, `bpmn.DocumentTree.length`, `bpmn.DocumentTree.resource_id` | Ordinals are preorder indices | `bpmn.DocumentTree.node` raises `InvalidArgumentError` outside the tree |
| `@bpmn.DocumentTree::lookup`, `@bpmn.NodeLookup` | `bpmn.DocumentTree.lookup`, `bpmn.NodeLookup` | `Found`, `DocumentMismatch` or `InvalidHandle` | A handle of another revision or resource is `DocumentMismatch` |
| `@bpmn.ResourceSet::new`, `@bpmn.DocumentResource::new`, `@bpmn.ExternalResource::new` | `bpmn.ResourceSet`, `bpmn.DocumentResource`, `bpmn.ExternalResource` | Empty by default; literal location keys | No file or network access |
| `@bpmn.Diagnostic`, `@bpmn.Location`, `@bpmn.Position`, `@bpmn.Span` | `bpmn.Diagnostic`, `bpmn.Location`, `bpmn.Position`, `bpmn.Span` | Severity is `Error` or `Warning` | UTF-16 offsets; 1-based lines and columns |

## Node inspection, handles and paths

| MoonBit | Python | Defaults and controls | Failures, limits and units |
| --- | --- | --- | --- |
| `@bpmn.NodeRef::value`, `@bpmn.NodeValue` | `bpmn.Node.value`, `bpmn.NodeValue` | `Document`, `Element`, `Text`, `Comment` or `ProcessingInstruction` with `target` and `data` | |
| `@bpmn.NodeRef::element` | `bpmn.Node.element`, `bpmn.ElementView` | Lazy read-only projection | `None` for other values |
| `@bpmn.NodeRef::kind` | `bpmn.Node.kind`, `bpmn.Node.kind_class` | Expanded name; `standard`, `foreign` or `unknown` | Source prefixes are not identity |
| `@bpmn.NodeRef::category`, `@bpmn.NodeCategory` | `bpmn.Node.category`, `bpmn.Category` | Values are the MoonBit names | |
| `@bpmn.NodeRef::id` | `bpmn.Node.id` | | `None` when absent |
| `@bpmn.NodeRef::attributes`, `@bpmn.Attribute` | `bpmn.Node.attributes`, `bpmn.Attribute` | Present attributes only, in source order | No default values |
| `@bpmn.NodeRef::scalar`, `@bpmn.Scalar` | `bpmn.Node.scalar`, `bpmn.Scalar` | `tag` is the constructor name; `token` is `Scalar::token` | `Invalid` keeps its raw text and expected type |
| `@bpmn.NodeRef::fields`, `@bpmn.NodeRef::field`, `@bpmn.NodeField` | `bpmn.Node.fields`, `bpmn.Node.field`, `bpmn.NodeField` | Fields in first-appearance order | No field for an absent value |
| `@bpmn.NodeRef::children`, `@bpmn.NodeRef::parent` | `bpmn.Node.children`, `bpmn.Node.parent` | Document order | The root has no parent |
| `@bpmn.NodeRef::step`, `@bpmn.PathStep`, `@bpmn.PathField` | `bpmn.Node.step`, `bpmn.PathStep`, `bpmn.PathField` | `Named`, `Text`, `Comment`, `ProcessingInstruction`, `Root`, `Prolog`, `Epilog` | |
| `@bpmn.NodeRef::depth` | `bpmn.Node.depth` | The document node has depth 0 | |
| `@bpmn.NodeRef::span`, `@bpmn.NodeRef::location` | `bpmn.Node.span`, `bpmn.Node.location` | | `None` for constructed content; UTF-16 units |
| `@bpmn.NodeRef::resource_id` | `bpmn.Node.resource_id` | | |
| `@bpmn.NodeRef::path`, `@bpmn.NodePath::depth`, `@bpmn.NodePath::steps`, `@bpmn.NodePath::resolve` | `bpmn.Node.path`, `bpmn.NodePath.depth`, `bpmn.NodePath.steps`, `bpmn.NodePath.resolve` | Document-relative, also from a subtree | `resolve` in another revision is `DocumentMismatch` |
| `@bpmn.NodeRef::handle`, `@bpmn.NodeHandle` | `bpmn.Node.handle`, `bpmn.NodeHandle` | Equal only for the same revision, resource and ordinal | Never matches across revisions |

## Walk, fold, reduce and pruned reduce

| MoonBit | Python | Defaults and controls | Failures, limits and units |
| --- | --- | --- | --- |
| `@bpmn.Control::Continue`, `@bpmn.Control::SkipChildren`, `@bpmn.Control::Stop` | `bpmn.Control.CONTINUE`, `bpmn.Control.SKIP_CHILDREN`, `bpmn.Control.STOP` | Applied before the next event is read | Another return value raises `TypeError` |
| `@bpmn.walk` | `bpmn.walk`, `bpmn.TraversalStatus` | `leave=None`; a skipped node still leaves | MoonBit returns `Unit` and its caller knows its own `Stop`. Python returns `TraversalStatus.COMPLETE` or `STOPPED`. A callback exception propagates: the failed case |
| `@bpmn.fold` | `bpmn.fold` | `enter` returns `(value, control)`; `leave=None` | Returns the value, also after stop |
| `@bpmn.reduce` | `bpmn.reduce` | `combine(node, children)`; children in order | |
| `@bpmn.reduce_pruned` | `bpmn.reduce_pruned` | A skipped node gets `()`; root skip gives `combine(root, ())` | `None` after stop |

## Visitor and accept

| MoonBit | Python | Defaults and controls | Failures, limits and units |
| --- | --- | --- | --- |
| `@bpmn.accept` | `bpmn.accept` | Overridden methods are found once per traversal | Returns `TraversalStatus`; MoonBit returns `Unit` |
| `@bpmn.Visitor::enter`, `@bpmn.Visitor::leave` | `bpmn.Visitor.enter`, `bpmn.Visitor.leave` | `enter` first; `leave` for each visited node | A method that is not overridden is never called |
| `@bpmn.Visitor::visit_definitions`, `@bpmn.Visitor::visit_process`, `@bpmn.Visitor::visit_activity`, `@bpmn.Visitor::visit_event`, `@bpmn.Visitor::visit_gateway`, `@bpmn.Visitor::visit_sequence_flow`, `@bpmn.Visitor::visit_collaboration` | `bpmn.Visitor.visit_definitions`, `bpmn.Visitor.visit_process`, `bpmn.Visitor.visit_activity`, `bpmn.Visitor.visit_event`, `bpmn.Visitor.visit_gateway`, `bpmn.Visitor.visit_sequence_flow`, `bpmn.Visitor.visit_collaboration` | Runs after `enter` gives `CONTINUE`; `value` is an `ElementView` | Default `CONTINUE` |
| `@bpmn.Visitor::visit_participant`, `@bpmn.Visitor::visit_lane`, `@bpmn.Visitor::visit_choreography`, `@bpmn.Visitor::visit_choreography_activity`, `@bpmn.Visitor::visit_conversation`, `@bpmn.Visitor::visit_conversation_link`, `@bpmn.Visitor::visit_extension` | `bpmn.Visitor.visit_participant`, `bpmn.Visitor.visit_lane`, `bpmn.Visitor.visit_choreography`, `bpmn.Visitor.visit_choreography_activity`, `bpmn.Visitor.visit_conversation`, `bpmn.Visitor.visit_conversation_link`, `bpmn.Visitor.visit_extension` | The same as above | Default `CONTINUE` |
| `@bpmn.Visitor::visit_document`, `@bpmn.Visitor::visit_diagram_interchange`, `@bpmn.Visitor::visit_text`, `@bpmn.Visitor::visit_comment`, `@bpmn.Visitor::visit_processing_instruction`, `@bpmn.Visitor::visit_other` | `bpmn.Visitor.visit_document`, `bpmn.Visitor.visit_diagram_interchange`, `bpmn.Visitor.visit_text`, `bpmn.Visitor.visit_comment`, `bpmn.Visitor.visit_processing_instruction`, `bpmn.Visitor.visit_other` | Take only the node | Default `CONTINUE` |

## EventReader, EventSource and push_events

| MoonBit | Python | Defaults and controls | Failures, limits and units |
| --- | --- | --- | --- |
| `@bpmn.EventReader::new`, `@bpmn.TraversalEvent::Enter`, `@bpmn.TraversalEvent::Leave` | `bpmn.EventReader`, `bpmn.Enter`, `bpmn.Leave` | Enter and leave in document preorder | Two threads at once: `BusyError` |
| `@bpmn.EventReader::next`, `@bpmn.EventReader::iter` | `bpmn.EventReader.next`, `bpmn.EventReader.__iter__` | `None` (or `StopIteration`) at the end | |
| `@bpmn.EventReader::skip_children`, `@bpmn.EventReader::stop` | `bpmn.EventReader.skip_children`, `bpmn.EventReader.stop` | `skip_children` acts only right after an enter | After `stop` the reader gives no event |
| (none) | `bpmn.EventReader.next_batch`, `bpmn.EventReader.batches`, `bpmn.EventBatch`, `bpmn.EventReader.state` | Observational: no control is applied. Size 1 to 4,096, default 256 | `state` is `running`, `complete` (read past the end) or `stopped`; a full batch stays `running`; after `stop` it is never `complete` |
| `@bpmn.EventSource`, `@bpmn.push_events` | `bpmn.EventSource`, `bpmn.push_events` | Any object with `next`, `skip_children` and `stop`, also a Python one; `leave=None` | Returns `TraversalStatus`; MoonBit returns `Unit` |

## TreeCursor

| MoonBit | Python | Defaults and controls | Failures, limits and units |
| --- | --- | --- | --- |
| `@bpmn.TreeCursor::new` | `bpmn.TreeCursor` | Stays in the subtree of its start node | Two threads at once: `BusyError` |
| `@bpmn.TreeCursor::goto_parent`, `@bpmn.TreeCursor::goto_first_child`, `@bpmn.TreeCursor::goto_last_child`, `@bpmn.TreeCursor::goto_next_sibling`, `@bpmn.TreeCursor::goto_previous_sibling` | `bpmn.TreeCursor.goto_parent`, `bpmn.TreeCursor.goto_first_child`, `bpmn.TreeCursor.goto_last_child`, `bpmn.TreeCursor.goto_next_sibling`, `bpmn.TreeCursor.goto_previous_sibling` | Returns `True` after a move | A failed move returns `False` and keeps the position |
| `@bpmn.TreeCursor::node`, `@bpmn.TreeCursor::path`, `@bpmn.TreeCursor::depth` | `bpmn.TreeCursor.node`, `bpmn.TreeCursor.path`, `bpmn.TreeCursor.depth` | `depth` is relative to the start; `path` is document-relative | |

## DocumentGraph lookup, reachability and routes

| MoonBit | Python | Defaults and controls | Failures, limits and units |
| --- | --- | --- | --- |
| `@bpmn.DocumentGraph::new`, `@bpmn.GraphBuildResult` | `bpmn_graph.DocumentGraph.new`, `bpmn_graph.GraphBuildResult` | `resources=None`, `resource_id=None`, `limits=None`, `graph_limits=None` | `graph` is `None` with a `bpmn/graph-*` diagnostic; an absent import gives `bpmn/unresolved-import` |
| `@bpmn.DocumentGraph.nodes`, `@bpmn.DocumentGraph.edges`, `@bpmn.GraphNode::id`, `@bpmn.GraphEdge`, `@bpmn.ExternalNode` | `bpmn_graph.DocumentGraph.nodes`, `bpmn_graph.DocumentGraph.edges`, `bpmn_graph.GraphNode.id`, `bpmn_graph.GraphEdge`, `bpmn_graph.ExternalNode` | External symbols are leaves | |
| `@bpmn.GraphEndpoint::Node`, `@bpmn.GraphEndpoint::Id`, `@bpmn.GraphEndpoint::Qualified`, `@bpmn.GraphEndpoint::Symbol`, `@bpmn.ResolvedSymbol::new` | `bpmn_graph.GraphEndpoint.node`, `bpmn_graph.GraphEndpoint.id`, `bpmn_graph.GraphEndpoint.qualified`, `bpmn_graph.GraphEndpoint.symbol`, `bpmn_graph.ResolvedSymbol` | A node endpoint is a handle and never falls back to its ID | A `str` is not an endpoint: `TypeError` |
| `@bpmn.DocumentGraph::lookup` | `bpmn_graph.DocumentGraph.lookup`, `bpmn_graph.LookupResult` | `limits=None` | `Ok` or `Err` with a `GraphFailure` |
| `@bpmn.DocumentGraph::reachable`, `@bpmn.ReachabilityResult` | `bpmn_graph.DocumentGraph.reachable`, `bpmn_graph.ReachabilityResult` | `kinds=None` is `[SequenceFlow]`; `direction=None` is `Forward`; breadth first, start first | `Complete` or `Failed` |
| `@bpmn.DocumentGraph::route`, `@bpmn.RouteResult`, `@bpmn.GraphRoute` | `bpmn_graph.DocumentGraph.route`, `bpmn_graph.RouteResult`, `bpmn_graph.GraphRoute` | The same defaults; one shortest route; authored connection order breaks ties | `Found`, `Unreachable` or `Failed`; a limit is never `Unreachable` |
| `@bpmn.GraphEdgeKind`, `@bpmn.GraphDirection` | `bpmn_graph.GraphEdgeKind`, `bpmn_graph.GraphDirection` | `Containment`, `SequenceFlow`, `MessageFlow`, `Association`, `DataAssociation`, `ConversationLink`, `Reference`; `Forward`, `Reverse`, `Both` | |
| `@bpmn.GraphLimits::new`, `@bpmn.GraphLimit` | `bpmn_graph.GraphLimits`, `bpmn_graph.GraphLimits.defaults`, `bpmn_graph.GraphLimit` | 100,000 nodes, 200,000 edges, 100,000 results, 1,000,000 work | A non-positive limit gives `InvalidLimits` |
| `@bpmn.GraphFailure` | `bpmn_graph.GraphFailure` | | `InvalidEndpoint`, `DocumentMismatch`, `InvalidReference` (owner handle), `Ambiguous` (candidates), `Limit`, `InvalidLimits` |

## Mermaid rendering

| MoonBit | Python | Defaults and controls | Failures, limits and units |
| --- | --- | --- | --- |
| `@mermaid.render_svg`, `@render.Rendered` | `diagrams_mbt.render_svg`, `diagrams_mbt.Rendered` | The default SVG renderer | Diagram errors are returned diagnostics; a lone surrogate raises `UnicodeEncodeError` |
| (none) | `diagrams_mbt.code_point_index`, `diagrams_mbt.Diagnostic`, `diagrams_mbt.Span`, `diagrams_mbt.Position` | Converts a UTF-16 offset to a Python string index | 1-based lines and columns |

## Not mapped

MoonBit traits, generics, debug helpers (`to_repr`), derived `equal`
methods and model constructors are not mapped. Python equality of nodes and
handles uses the MoonBit revision rules. Other diagram readers, animation and
raster output are not in this map.
