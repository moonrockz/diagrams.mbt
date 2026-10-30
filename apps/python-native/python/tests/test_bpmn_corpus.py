"""The shared traversal corpus through ``diagrams_mbt.bpmn``.

This file writes the normalized text of ``tests/traversal-corpus`` with the
Python facade. It must equal the checked-in MoonBit oracle text exactly.
``tests/traversal-corpus/README.md`` describes the format; the MoonBit writer
is ``tests/traversal-corpus/normalize.mbt`` and ``graph.mbt``.

DIAGRAMS_TRAVERSAL_CORPUS can name the corpus directory. Otherwise it is found
from DIAGRAMS_NATIVE_FIXTURES (``apps/python-native/fixtures``).
"""

from __future__ import annotations

import os
import pathlib
import unittest
from typing import Callable, Dict, List, Optional, Tuple

from diagrams_mbt import bpmn
from diagrams_mbt.bpmn import Control


def corpus_dir() -> pathlib.Path:
    explicit = os.environ.get("DIAGRAMS_TRAVERSAL_CORPUS")
    if explicit:
        return pathlib.Path(explicit)
    fixtures = pathlib.Path(os.environ["DIAGRAMS_NATIVE_FIXTURES"]).resolve()
    return fixtures.parents[2] / "tests" / "traversal-corpus"


CORPUS = corpus_dir()
MODEL_URI = "http://www.omg.org/spec/BPMN/20100524/MODEL"


def corpus_file(name: str) -> Optional[str]:
    path = CORPUS / "fixtures" / name
    if not path.exists():
        return None
    return path.read_bytes().decode("utf-8")


def esc(text: str) -> str:
    out = ['"']
    for c in text:
        if c == "\\":
            out.append("\\\\")
        elif c == '"':
            out.append('\\"')
        elif c == "\n":
            out.append("\\n")
        elif c == "\r":
            out.append("\\r")
        elif c == "\t":
            out.append("\\t")
        else:
            out.append(c)
    out.append('"')
    return "".join(out)


def opt(text: Optional[str]) -> str:
    return "-" if text is None else text


def name(n: bpmn.ExpandedName) -> str:
    return "{" + n.namespace_uri + "}" + n.local_name


def name_opt(n: Optional[bpmn.ExpandedName]) -> str:
    return "-" if n is None else name(n)


def span(s: Optional[bpmn.Span]) -> str:
    return "-" if s is None else f"{s.start}-{s.end}"


def position(p: bpmn.Position) -> str:
    return f"{p.line}:{p.column}:{p.offset}"


def location(loc: Optional[bpmn.Location]) -> str:
    if loc is None:
        return "-"
    return opt(loc.source_id) + "@" + position(loc.start) + "-" + position(loc.end)


def scalar(s: bpmn.Scalar) -> str:
    detail = ""
    if s.tag == "Boolean":
        detail = ":" + ("true" if s.detail else "false")
    elif s.tag == "Reference":
        r = s.detail
        detail = ":" + r.kind + "," + esc(r.spelling) + "," + name_opt(r.name)
    elif s.tag == "Enumeration":
        detail = ":" + name(s.detail)
    elif s.tag == "Invalid":
        detail = ":" + esc(s.detail.raw) + "," + name(s.detail.expected)
    return s.tag + "(" + esc(s.token) + ")" + detail


def scalar_opt(s: Optional[bpmn.Scalar]) -> str:
    return "-" if s is None else scalar(s)


def kind(node_kind: Optional[bpmn.ExpandedName], kind_class: Optional[str]) -> str:
    if node_kind is None:
        return "-"
    return name(node_kind) + "/" + str(kind_class)


def field(f: bpmn.PathField) -> str:
    return name(f.name) if f.kind == "Named" else f.kind


def step(s: bpmn.PathStep) -> str:
    return f"{field(s.field)}[{s.index}]@{s.content_index}"


def steps(path: bpmn.NodePath) -> str:
    parts = [step(s) for s in path.steps()]
    return "/".join(parts) if parts else "(root)"


def value(v: bpmn.NodeValue) -> str:
    if v.kind == "Text":
        return "Text(" + esc(v.text) + ")"
    if v.kind == "Comment":
        return "Comment(" + esc(v.text) + ")"
    if v.kind == "ProcessingInstruction":
        return "PI(" + esc(v.target) + "," + esc(v.data) + ")"
    return v.kind


def lookup(result: bpmn.NodeLookup) -> str:
    if result.status == "Found":
        return f"Found#{result.node.ordinal}"
    return result.status


def diagnostic(d: bpmn.Diagnostic) -> str:
    return (
        f"  diag {d.code} {d.severity} span={span(d.span)} loc={location(d.location)}"
        f" msg={esc(d.message)}"
    )


def tokens(out: List[str], items: List[str]) -> None:
    for i in range(0, len(items), 16):
        out.append("  " + " ".join(items[i : i + 16]))


def skip_rule(node: bpmn.Node) -> Control:
    return Control.SKIP_CHILDREN if node.ordinal % 5 == 2 else Control.CONTINUE


def node_lines(
    out: List[str],
    tree: bpmn.DocumentTree,
    rebuilt: bpmn.DocumentTree,
    other: bpmn.DocumentTree,
) -> None:
    def visit(node: bpmn.Node) -> Control:
        parent = node.parent()
        out.append(
            f"#{node.ordinal} d={node.depth} {node.category.value} kind={kind(node.kind, node.kind_class)}"
            f" id={opt(node.id)} parent={'-' if parent is None else parent.ordinal}"
            f" step={'-' if node.step is None else step(node.step)} span={span(node.span)}"
            f" loc={location(node.location())} res={opt(node.resource_id)}"
            f" children={len(node.children())} value={value(node.value)}"
        )
        element = node.element()
        if element is not None:
            bindings = ",".join(p + "=" + u for p, u in element.bindings)
            out.append(
                f"  element kind={kind(element.kind, element.kind_class)} bindings=[{bindings}]"
                f" value_type={name_opt(element.value_type)}"
                f" text_value={scalar_opt(element.text_value)} content={esc(element.content)}"
            )
        for a in node.attributes():
            out.append(
                f"  attr {name_opt(a.name)} raw={esc(a.raw_name)} {scalar(a.value)}"
                f" span={span(a.span)} loc={location(a.location)}"
            )
        if element is not None:
            out.append(
                "  scalar id=" + scalar_opt(node.scalar(bpmn.ExpandedName("", "id")))
                + " name=" + scalar_opt(node.scalar(bpmn.ExpandedName("", "name")))
            )
        fields = node.fields()
        for f in fields:
            out.append(
                f"  field {field(f.field)} attrs=[{','.join(a.raw_name for a in f.attributes)}]"
                f" children=[{','.join(str(c.ordinal) for c in f.children)}]"
            )
        if fields:
            again = node.field(fields[0].field)
            text = "absent" if again is None else ",".join(str(c.ordinal) for c in again.children)
            out.append(f"  field? {field(fields[0].field)} children=[{text}]")
        out.append("  children [" + ",".join(str(c.ordinal) for c in node.children()) + "]")
        out.append(f"  path {steps(node.path())} depth={node.path().depth}")
        handle = node.handle
        out.append(
            f"  handle res={opt(handle.resource_id)} ord={handle.ordinal}"
            f" same={lookup(tree.lookup(handle))} rebuilt={lookup(rebuilt.lookup(handle))}"
            f" other={lookup(other.lookup(handle))}"
            f" resolve={lookup(node.path().resolve(rebuilt))}"
            f" resolve-other={lookup(node.path().resolve(other))}"
        )
        return Control.CONTINUE

    bpmn.walk(tree.root(), visit)


def enter_token(node: bpmn.Node) -> str:
    return f"+{node.ordinal}"


def leave_token(node: bpmn.Node) -> str:
    return f"-{node.ordinal}"


class ActivityVisitor(bpmn.Visitor):
    def __init__(self, prune: bool) -> None:
        self.log: List[str] = []
        self.prune = prune

    def visit_activity(self, value: bpmn.ElementView, node: bpmn.Node) -> Control:
        self.log.append(f"{node.ordinal}:{value.kind.local_name}")
        if self.prune and node.ordinal % 2 == 0:
            return Control.SKIP_CHILDREN
        return Control.CONTINUE


def _family(name_: str, typed: bool) -> Callable[..., Control]:
    if typed:

        def typed_method(self, value, node):  # type: ignore[no-untyped-def]
            return self.family(name_, node, value.kind.local_name)

        return typed_method

    def method(self, node):  # type: ignore[no-untyped-def]
        element = node.element()
        suffix = None if element is None or name_ not in ("diagram_interchange", "other") else element.kind.local_name
        return self.family(name_, node, suffix)

    return method


class FullVisitor(bpmn.Visitor):
    def __init__(self, stop: int) -> None:
        self.log: List[str] = []
        self.stop = stop

    def family(self, family: str, node: bpmn.Node, kind_local: Optional[str]) -> Control:
        suffix = "" if kind_local is None else ":" + kind_local
        self.log.append(f"{family}:{node.ordinal}{suffix}")
        return Control.STOP if node.ordinal == self.stop else Control.CONTINUE

    def enter(self, node: bpmn.Node) -> Control:
        self.log.append(enter_token(node))
        return skip_rule(node)

    def leave(self, node: bpmn.Node) -> None:
        self.log.append(leave_token(node))

    visit_definitions = _family("definitions", True)
    visit_process = _family("process", True)
    visit_activity = _family("activity", True)
    visit_event = _family("event", True)
    visit_gateway = _family("gateway", True)
    visit_sequence_flow = _family("sequence_flow", True)
    visit_collaboration = _family("collaboration", True)
    visit_participant = _family("participant", True)
    visit_lane = _family("lane", True)
    visit_choreography = _family("choreography", True)
    visit_choreography_activity = _family("choreography_activity", True)
    visit_conversation = _family("conversation", True)
    visit_conversation_link = _family("conversation_link", True)
    visit_extension = _family("extension", True)
    visit_document = _family("document", False)
    visit_diagram_interchange = _family("diagram_interchange", False)
    visit_text = _family("text", False)
    visit_comment = _family("comment", False)
    visit_processing_instruction = _family("processing_instruction", False)
    visit_other = _family("other", False)


def count(children: Tuple[int, ...]) -> int:
    return 1 + sum(children)


def traversal_lines(out: List[str], tree: bpmn.DocumentTree) -> None:
    root = tree.root()
    stop = tree.length * 2 // 3

    def stop_or(rule: Callable[[bpmn.Node], Control]) -> Callable[[bpmn.Node], Control]:
        return lambda n: Control.STOP if n.ordinal == stop else rule(n)

    def logged(log: List[str], rule: Callable[[bpmn.Node], Control]) -> Callable[[bpmn.Node], Control]:
        def enter(node: bpmn.Node) -> Control:
            log.append(enter_token(node))
            return rule(node)

        return enter

    always = lambda n: Control.CONTINUE  # noqa: E731

    out.append("walk")
    log: List[str] = []
    bpmn.walk(root, logged(log, always), lambda n: log.append(leave_token(n)))
    tokens(out, log)
    out.append("walk-skip")
    log = []
    bpmn.walk(root, logged(log, skip_rule), lambda n: log.append(leave_token(n)))
    tokens(out, log)
    out.append(f"walk-stop at={stop}")
    log = []
    bpmn.walk(root, logged(log, stop_or(always)), lambda n: log.append(leave_token(n)))
    tokens(out, log)
    middle = tree.length // 2
    subtree = next(e.node for e in bpmn.EventReader(root) if isinstance(e, bpmn.Enter) and e.node.ordinal == middle)
    out.append(f"walk-subtree at={middle}")
    log = []
    bpmn.walk(subtree, logged(log, always), lambda n: log.append(leave_token(n)))
    tokens(out, log)

    out.append("fold")

    def fold_enter(acc: List[str], node: bpmn.Node) -> Tuple[List[str], Control]:
        acc.append(enter_token(node))
        return acc, skip_rule(node)

    def fold_leave(acc: List[str], node: bpmn.Node) -> List[str]:
        acc.append(leave_token(node))
        return acc

    folded = bpmn.fold(root, [], fold_enter, fold_leave)
    tokens(out, folded)
    out.append(f"  result={len(folded)}")

    def combine_into(log: List[str]) -> Callable[[bpmn.Node, Tuple[int, ...]], int]:
        def combine(node: bpmn.Node, children: Tuple[int, ...]) -> int:
            log.append(f"{node.ordinal}:{len(children)}")
            return count(children)

        return combine

    out.append("reduce")
    log = []
    reduced = bpmn.reduce(root, combine_into(log))
    tokens(out, log)
    out.append(f"  result={reduced}")
    out.append("reduce-pruned-skip")
    log = []
    pruned = bpmn.reduce_pruned(root, skip_rule, combine_into(log))
    tokens(out, log)
    out.append("  result=" + ("none" if pruned is None else str(pruned)))
    out.append(f"reduce-pruned-stop at={stop}")
    log = []
    stopped = bpmn.reduce_pruned(root, logged(log, stop_or(always)), combine_into(log))
    tokens(out, log)
    out.append("  result=" + ("none" if stopped is None else str(stopped)))

    out.append("visitor-activity")
    activity = ActivityVisitor(prune=True)
    bpmn.accept(root, activity)
    tokens(out, activity.log)
    out.append(f"visitor-full stop={stop}")
    full = FullVisitor(stop)
    bpmn.accept(root, full)
    tokens(out, full.log)

    out.append("events")
    tokens(out, [event_token(e) for e in bpmn.EventReader(root)])
    out.append(f"events-controls stop={stop}")
    reader = bpmn.EventReader(root)
    log = []
    while True:
        event = reader.next()
        if event is None:
            break
        if isinstance(event, bpmn.Enter):
            log.append(enter_token(event.node))
            if event.node.ordinal == stop:
                reader.stop()
            elif skip_rule(event.node) is Control.SKIP_CHILDREN:
                reader.skip_children()
        else:
            log.append(leave_token(event.node))
    log.append("end" if reader.next() is None else "more")
    tokens(out, log)
    out.append(f"push stop={stop}")
    log = []
    bpmn.push_events(bpmn.EventReader(root), logged(log, stop_or(skip_rule)), lambda n: log.append(leave_token(n)))
    tokens(out, log)
    cursor_lines(out, tree)


def event_token(event: bpmn.TraversalEvent) -> str:
    return enter_token(event.node) if isinstance(event, bpmn.Enter) else leave_token(event.node)


def at(cursor: bpmn.TreeCursor) -> str:
    return f"{cursor.node().ordinal}:{cursor.depth()}"


def cursor_lines(out: List[str], tree: bpmn.DocumentTree) -> None:
    out.append("cursor")
    cursor = bpmn.TreeCursor(tree.root())
    log = ["@" + at(cursor)]
    done = False
    while not done:
        if cursor.goto_first_child():
            log.append("fc>" + at(cursor))
            continue
        log.append("fc!")
        while not done:
            if cursor.goto_next_sibling():
                log.append("ns>" + at(cursor))
                break
            log.append("ns!")
            if cursor.goto_parent():
                log.append("p>" + at(cursor))
            else:
                log.append("p!")
                done = True
    tokens(out, log)
    start = tree.root()
    found: List[bpmn.Node] = []

    def first(node: bpmn.Node) -> Control:
        if node.depth >= 2 and len(node.children()) >= 2:
            found.append(node)
            return Control.STOP
        return Control.CONTINUE

    bpmn.walk(tree.root(), first)
    if found:
        start = found[0]
    out.append(f"cursor-subtree at={start.ordinal}")
    cursor = bpmn.TreeCursor(start)
    log = ["@" + at(cursor)]
    moves = [
        ("p", bpmn.TreeCursor.goto_parent),
        ("ps", bpmn.TreeCursor.goto_previous_sibling),
        ("ns", bpmn.TreeCursor.goto_next_sibling),
        ("lc", bpmn.TreeCursor.goto_last_child),
        ("ps", bpmn.TreeCursor.goto_previous_sibling),
        ("ns", bpmn.TreeCursor.goto_next_sibling),
        ("ns", bpmn.TreeCursor.goto_next_sibling),
        ("fc", bpmn.TreeCursor.goto_first_child),
        ("p", bpmn.TreeCursor.goto_parent),
        ("p", bpmn.TreeCursor.goto_parent),
        ("p", bpmn.TreeCursor.goto_parent),
    ]
    for label, go in moves:
        log.append(label + (">" if go(cursor) else "!") + at(cursor))
    tokens(out, log)
    out.append("  path " + steps(cursor.path()))


# ---------------------------------------------------------------------------
# Graph scripts


def graph_node(node: bpmn.GraphNode) -> str:
    if node.kind == "Document":
        n = node.node
        return f"{opt(n.resource_id)}#{n.ordinal}({opt(n.id)})"
    e = node.external
    return f"ext:{e.symbol.resource_id}|{name(e.symbol.name)}#{e.occurrence}"


def graph_nodes(nodes: Tuple[bpmn.GraphNode, ...]) -> str:
    return "[" + " ".join(graph_node(n) for n in nodes) + "]"


def edge(e: bpmn.GraphEdge) -> str:
    via = ""
    if e.connection is not None:
        c = e.connection
        via = f" via {opt(c.resource_id)}#{c.ordinal}({opt(c.id)})"
    return f"{e.kind.value}:{graph_node(e.source)}->{graph_node(e.target)}{via}"


def failure(f: bpmn.GraphFailure) -> str:
    if f.kind == "InvalidReference":
        return f"InvalidReference({opt(f.handle.resource_id)}#{f.handle.ordinal})"
    if f.kind == "Ambiguous":
        return "Ambiguous" + graph_nodes(f.nodes)
    if f.kind == "Limit":
        return f"Limit({f.limit.value})"
    return f.kind


def graph_limits(text: str) -> bpmn.GraphLimits:
    values: Dict[str, int] = {}
    for part in text.split(","):
        key, _, number = part.partition(":")
        assert key in ("nodes", "edges", "results", "work"), key
        values[key] = int(number)
    return bpmn.GraphLimits(**values)


def options(words: List[str]) -> Dict[str, List[str]]:
    out: Dict[str, List[str]] = {}
    for word in words:
        key, _, val = word.partition("=")
        out.setdefault(key, []).append(val)
    return out


def node_at(tree: bpmn.DocumentTree, ordinal: int) -> bpmn.Node:
    found: List[bpmn.Node] = []

    def enter(node: bpmn.Node) -> Control:
        if node.ordinal == ordinal:
            found.append(node)
            return Control.STOP
        return Control.CONTINUE

    bpmn.walk(tree.root(), enter)
    return found[0]


def read_fixture(file: str, source: str) -> bpmn.ReadResult:
    return bpmn.read(source, "corpus:" + file)


def graph_lines(out: List[str], document: bpmn.Document, script: str) -> None:
    context: Optional[Tuple[bpmn.DocumentGraph, bpmn.DocumentTree, bpmn.DocumentTree]] = None

    def endpoint(text: str):  # type: ignore[no-untyped-def]
        tag, _, rest = text.partition(":")
        parts = rest.split("|")
        if tag == "id":
            return bpmn.GraphEndpoint.id(rest)
        if tag == "qname":
            return bpmn.GraphEndpoint.qualified(parts[0], parts[1])
        if tag == "symbol":
            return bpmn.GraphEndpoint.symbol(parts[0], parts[1], parts[2])
        if tag == "node":
            return bpmn.GraphEndpoint.node(node_at(context[1], int(rest)).handle)
        if tag == "foreign":
            return bpmn.GraphEndpoint.node(node_at(context[2], int(rest)).handle)
        raise AssertionError(text)

    for raw in script.split("\n"):
        line = raw.strip("\r ")
        if line == "" or line.startswith("#"):
            continue
        out.append("> " + line)
        words = line.split(" ")
        command = words[0]
        if command == "graph":
            opts = options(words[2:])
            resource_id = opts.get("resource_id", [None])[0]
            documents = []
            for spec in opts.get("document", []):
                location_, _, file = spec.partition(":")
                documents.append(
                    bpmn.DocumentResource(location_, read_fixture(file, corpus_file(file)).document)
                )
            external = []
            for spec in opts.get("external", []):
                p = spec.split("|")
                external.append(bpmn.ExternalResource(p[0], p[1], p[2], p[3].split(",")))
            limits = graph_limits(opts["limits"][0]) if "limits" in opts else None
            result = bpmn.DocumentGraph.new(
                document,
                resources=bpmn.ResourceSet(documents, external),
                resource_id=resource_id,
                graph_limits=limits,
            )
            out.append(f"  diagnostics={len(result.diagnostics)}")
            for d in result.diagnostics:
                out.append("  " + diagnostic(d))
            if result.graph is not None:
                graph = result.graph
                out.append(f"  graph nodes={len(graph.nodes)} edges={len(graph.edges)}")
                tree = document.tree(resource_id).tree
                foreign = document.tree("corpus:foreign").tree
                context = (graph, tree, foreign)
            else:
                out.append("  graph none")
                context = None
        elif command == "lookup":
            graph = context[0]
            opts = options(words[2:])
            limits = graph_limits(opts["limits"][0]) if "limits" in opts else None
            result = graph.lookup(endpoint(words[1]), limits=limits)
            if result.status == "Ok":
                out.append("  Ok " + graph_node(result.node))
            else:
                out.append("  Err " + failure(result.failure))
        elif command in ("reachable", "route"):
            graph = context[0]
            positional = 3 if command == "route" else 2
            opts = options(words[positional:])
            limits = graph_limits(opts["limits"][0]) if "limits" in opts else None
            kinds = None
            if "kinds" in opts:
                kinds = [bpmn.GraphEdgeKind(k) for k in opts["kinds"][0].split(",")]
            direction = bpmn.GraphDirection(opts["direction"][0]) if "direction" in opts else None
            start = endpoint(words[1])
            if command == "reachable":
                result = graph.reachable(start, kinds=kinds, direction=direction, limits=limits)
                if result.status == "Complete":
                    out.append("  Complete " + graph_nodes(result.nodes))
                else:
                    out.append("  Failed " + failure(result.failure))
            else:
                target = endpoint(words[2])
                route = graph.route(start, target, kinds=kinds, direction=direction, limits=limits)
                if route.status == "Found":
                    out.append(
                        "  Found " + graph_nodes(route.route.nodes)
                        + " edges=[" + " ".join(edge(e) for e in route.route.edges) + "]"
                    )
                elif route.status == "Unreachable":
                    out.append("  Unreachable")
                else:
                    out.append("  Failed " + failure(route.failure))
        else:
            raise AssertionError(command)


def normalize(file: str) -> str:
    out = ["fixture " + file]
    read = read_fixture(file, corpus_file(file))
    out.append(
        f"read document={'yes' if read.document is not None else 'no'}"
        f" diagnostics={len(read.diagnostics)}"
    )
    for d in read.diagnostics:
        out.append(diagnostic(d))
    if read.document is None:
        return "\n".join(out) + "\n"
    document = read.document
    built = bpmn.DocumentTree.new(document)
    out.append(f"tree diagnostics={len(built.diagnostics)}")
    for d in built.diagnostics:
        out.append(diagnostic(d))
    if built.tree is None:
        return "\n".join(out) + "\n"
    tree = built.tree
    rebuilt = document.tree().tree
    other = document.tree("corpus:other").tree
    out.append(f"tree length={tree.length} res={opt(tree.resource_id)}")
    node_lines(out, tree, rebuilt, other)
    traversal_lines(out, tree)
    script = corpus_file(file[: -len(".bpmn")] + ".graph")
    if script is not None:
        graph_lines(out, document, script)
    return "\n".join(out) + "\n"


def deep_source(depth: int) -> str:
    return (
        f"<b:definitions xmlns:b='{MODEL_URI}' targetNamespace='urn:deep'><b:process id='P'>"
        + "<b:subProcess>" * depth
        + "<b:task id='Deep'/>"
        + "</b:subProcess>" * depth
        + "</b:process></b:definitions>"
    )


def normalize_deep() -> str:
    limits = bpmn.Limits(depth=20000)
    read = bpmn.read(deep_source(10000), "corpus:deep", limits)
    out = ["fixture deep", f"read diagnostics={len(read.diagnostics)}"]
    tree = read.document.tree(limits=limits).tree
    root = tree.root()
    out.append(f"tree length={tree.length}")
    state = {"enters": 0, "leaves": 0, "deepest": root}

    def enter(node: bpmn.Node) -> Control:
        state["enters"] += 1
        if node.depth > state["deepest"].depth:
            state["deepest"] = node
        return Control.CONTINUE

    def leave(_: bpmn.Node) -> None:
        state["leaves"] += 1

    bpmn.walk(root, enter, leave)
    deepest: bpmn.Node = state["deepest"]
    out.append(
        f"walk enters={state['enters']} leaves={state['leaves']} deepest=#{deepest.ordinal}"
        f" depth={deepest.depth} id={opt(deepest.id)} path-steps={len(deepest.path().steps())}"
    )
    counts = [0, 0]

    def counted(rule: Callable[[bpmn.Node], Control]) -> Callable[[bpmn.Node], Control]:
        def enter_(node: bpmn.Node) -> Control:
            counts[0] += 1
            return rule(node)

        return enter_

    def leave_(_: bpmn.Node) -> None:
        counts[1] += 1

    bpmn.walk(root, counted(lambda n: Control.SKIP_CHILDREN if n.ordinal == 5000 else Control.CONTINUE), leave_)
    out.append(f"walk-skip at=5000 enters={counts[0]} leaves={counts[1]}")
    counts = [0, 0]
    bpmn.walk(root, counted(lambda n: Control.STOP if n == deepest else Control.CONTINUE), leave_)
    out.append(f"walk-stop at=#{deepest.ordinal} enters={counts[0]} leaves={counts[1]}")
    folded = bpmn.fold(root, 0, lambda acc, n: (acc + n.depth, Control.CONTINUE))
    out.append(f"fold depth-sum={folded}")
    out.append(f"reduce result={bpmn.reduce(root, lambda _, c: count(c))}")
    pruned = bpmn.reduce_pruned(
        root, lambda n: Control.STOP if n == deepest else Control.CONTINUE, lambda _, c: count(c)
    )
    out.append("reduce-pruned-stop result=" + ("none" if pruned is None else str(pruned)))
    out.append(f"events count={sum(1 for _ in bpmn.EventReader(root))}")
    visitor = ActivityVisitor(prune=False)
    bpmn.accept(root, visitor)
    out.append(f"visitor-activity count={len(visitor.log)}")
    cursor = bpmn.TreeCursor(root)
    while cursor.goto_first_child():
        pass
    bottom = at(cursor)
    ups = 0
    while cursor.goto_parent():
        ups += 1
    out.append(f"cursor bottom={bottom} parents={ups}")
    return "\n".join(out) + "\n"


def expected(name_: str) -> str:
    return (CORPUS / "expected" / name_).read_bytes().decode("utf-8")


class CorpusTest(unittest.TestCase):
    maxDiff = None

    def test_every_fixture_equals_the_moonbit_oracle(self) -> None:
        names = sorted(p.name for p in (CORPUS / "fixtures").glob("*.bpmn"))
        self.assertGreaterEqual(len(names), 8)
        for file in names:
            with self.subTest(fixture=file):
                self.assertEqual(normalize(file), expected(file[: -len(".bpmn")] + ".txt"))

    def test_the_deep_tree_equals_the_moonbit_oracle(self) -> None:
        self.assertEqual(normalize_deep(), expected("deep.txt"))

    def test_observational_batches_concatenate_to_the_event_order(self) -> None:
        for file in ("process.bpmn", "vendor.bpmn", "choreography.bpmn"):
            tree = read_fixture(file, corpus_file(file)).document.tree().tree
            want = [event_token(e) for e in bpmn.EventReader(tree.root())]
            for size in (1, 3, 64, 256, 4096):
                with self.subTest(fixture=file, size=size):
                    reader = bpmn.EventReader(tree.root())
                    got = [event_token(e) for batch in reader.batches(size) for e in batch]
                    self.assertEqual(got, want)
                    self.assertTrue(all(len(b) <= size for b in bpmn.EventReader(tree.root()).batches(size)))

    def test_visitor_with_only_the_activity_method_matches_the_oracle(self) -> None:
        text = expected("process.txt")
        section = text.split("visitor-activity\n", 1)[1].split("visitor-full", 1)[0]
        tree = read_fixture("process.bpmn", corpus_file("process.bpmn")).document.tree().tree
        visitor = ActivityVisitor(prune=True)
        bpmn.accept(tree.root(), visitor)
        lines: List[str] = []
        tokens(lines, visitor.log)
        self.assertEqual("".join(line + "\n" for line in lines), section)


if __name__ == "__main__":
    unittest.main()
