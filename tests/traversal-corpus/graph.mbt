///|
/// The graph section of a fixture. `README.md` describes the script format.
fn graph_node(node : @bpmn.GraphNode) -> String {
  match node {
    Document(n) => opt(n.resource_id()) + "#\{ord(n)}(" + opt(n.id()) + ")"
    External(e) =>
      "ext:" +
      e.symbol.resource_id +
      "|" +
      name(e.symbol.name) +
      "#\{e.occurrence}"
  }
}

///|
fn graph_nodes(nodes : ReadOnlyArray[@bpmn.GraphNode]) -> String {
  "[" + nodes.iter().map(graph_node).join(" ") + "]"
}

///|
fn edge_kind(kind : @bpmn.GraphEdgeKind) -> String {
  match kind {
    Containment => "Containment"
    SequenceFlow => "SequenceFlow"
    MessageFlow => "MessageFlow"
    Association => "Association"
    DataAssociation => "DataAssociation"
    ConversationLink => "ConversationLink"
    Reference => "Reference"
  }
}

///|
fn edge(e : @bpmn.GraphEdge) -> String {
  let via = match e.connection {
    Some(n) =>
      " via " + opt(n.resource_id()) + "#\{ord(n)}(" + opt(n.id()) + ")"
    None => ""
  }
  edge_kind(e.kind) +
  ":" +
  graph_node(e.source) +
  "->" +
  graph_node(e.target) +
  via
}

///|
fn failure(f : @bpmn.GraphFailure) -> String {
  match f {
    InvalidEndpoint => "InvalidEndpoint"
    DocumentMismatch => "DocumentMismatch"
    InvalidReference(h) =>
      "InvalidReference(" + opt(h.resource_id()) + "#\{h.ordinal})"
    Ambiguous(nodes) => "Ambiguous" + graph_nodes(nodes)
    Limit(limit) => {
      let text = match limit {
        Nodes => "Nodes"
        Edges => "Edges"
        Results => "Results"
        Work => "Work"
      }
      "Limit(" + text + ")"
    }
    InvalidLimits => "InvalidLimits"
  }
}

///|
fn split_once(text : String, sep : Char) -> (String, String) {
  match text.find(sep.to_string()) {
    Some(i) =>
      (
        text.view(end_offset=i).to_owned(),
        text.view(start_offset=i + 1).to_owned(),
      )
    None => (text, "")
  }
}

///|
fn graph_limits(text : String) -> @bpmn.GraphLimits {
  let values : Map[String, Int32] = Map([])
  for part in text.split(",") {
    let (key, number) = split_once(part.to_owned(), ':')
    guard ["nodes", "edges", "results", "work"].contains(key) else {
      abort("unknown limit " + key)
    }
    values[key] = @string.parse_int(number) catch {
      _ => abort("bad limit " + number)
    }
  }
  @bpmn.GraphLimits::new(
    nodes?=values.get("nodes"),
    edges?=values.get("edges"),
    results?=values.get("results"),
    work?=values.get("work"),
  )
}

///|
fn edge_kind_of(text : String) -> @bpmn.GraphEdgeKind {
  match text {
    "Containment" => Containment
    "SequenceFlow" => SequenceFlow
    "MessageFlow" => MessageFlow
    "Association" => Association
    "DataAssociation" => DataAssociation
    "ConversationLink" => ConversationLink
    "Reference" => Reference
    _ => abort("unknown edge kind " + text)
  }
}

///|
priv struct GraphContext {
  graph : @bpmn.DocumentGraph
  tree : @bpmn.DocumentTree
  foreign : @bpmn.DocumentTree
}

///|
fn node_at(tree : @bpmn.DocumentTree, ordinal : Int32) -> @bpmn.NodeRef {
  let mut found : @bpmn.NodeRef? = None
  @bpmn.walk(tree.root(), n => {
    if ord(n) == ordinal {
      found = Some(n)
      Stop
    } else {
      Continue
    }
  })
  found.unwrap()
}

///|
fn endpoint(context : GraphContext, text : String) -> @bpmn.GraphEndpoint {
  let (tag, rest) = split_once(text, ':')
  let parts = rest.split("|").map(p => p.to_owned()).to_array()
  let number = () => @string.parse_int(rest) catch { _ => abort("bad ordinal") }
  match tag {
    "id" => Id(rest)
    "qname" => Qualified(@bpmn.ExpandedName::new(parts[0], parts[1]))
    "symbol" =>
      Symbol(
        @bpmn.ResolvedSymbol::new(
          parts[0],
          @bpmn.ExpandedName::new(parts[1], parts[2]),
        ),
      )
    "node" => Node(node_at(context.tree, number()).handle())
    "foreign" => Node(node_at(context.foreign, number()).handle())
    _ => abort("unknown endpoint " + text)
  }
}

///|
/// Options after the positional words: `key=value` pairs.
fn options(words : ArrayView[String]) -> Map[String, Array[String]] {
  let map : Map[String, Array[String]] = Map([])
  for word in words {
    let (key, value) = split_once(word, '=')
    match map.get(key) {
      Some(values) => values.push(value)
      None => map[key] = [value]
    }
  }
  map
}

///|
fn graph_lines(
  out : Array[String],
  document : @bpmn.Document,
  script : String,
  files : (String) -> String?,
) -> Unit {
  let mut context : GraphContext? = None
  for raw in script.split("\n") {
    let line = raw.trim(chars="\r ").to_owned()
    if line == "" || line.has_prefix("#") {
      continue
    }
    out.push("> " + line)
    let words = line.split(" ").map(w => w.to_owned()).to_array()
    match words[0] {
      "graph" => {
        let opts = options(words[2:])
        let resource_id = opts.get("resource_id").map(v => v[0])
        let documents = opts
          .get("document")
          .unwrap_or([])
          .map(spec => {
            let (location, file) = split_once(spec, ':')
            let read = read_fixture(file, files(file).unwrap())
            @bpmn.DocumentResource::new(location, read.document.unwrap())
          })
        let external = opts
          .get("external")
          .unwrap_or([])
          .map(spec => {
            let p = spec.split("|").map(s => s.to_owned()).to_array()
            @bpmn.ExternalResource::new(
              p[0],
              p[1],
              p[2],
              p[3].split(",").map(s => s.to_owned()).to_array(),
            )
          })
        let graph_limits = match opts.get("limits") {
          Some(v) => graph_limits(v[0])
          None => @bpmn.GraphLimits::new()
        }
        let result = @bpmn.DocumentGraph::new(
          document,
          resources=@bpmn.ResourceSet::new(documents~, external~),
          resource_id?,
          graph_limits~,
        )
        out.push("  diagnostics=\{result.diagnostics.length()}")
        for d in result.diagnostics {
          out.push("  " + diagnostic(d))
        }
        match result.graph {
          Some(graph) => {
            out.push(
              "  graph nodes=\{graph.nodes.length()} edges=\{graph.edges.length()}",
            )
            let tree = @bpmn.DocumentTree::new(document, resource_id?).tree.unwrap()
            let foreign = @bpmn.DocumentTree::new(
              document,
              resource_id="corpus:foreign",
            ).tree.unwrap()
            context = Some({ graph, tree, foreign, })
          }
          None => {
            out.push("  graph none")
            context = None
          }
        }
      }
      "lookup" => {
        let c = context.unwrap()
        let opts = options(words[2:])
        let limits = match opts.get("limits") {
          Some(v) => graph_limits(v[0])
          None => @bpmn.GraphLimits::new()
        }
        let text = match c.graph.lookup(endpoint(c, words[1]), limits~) {
          Ok(node) => "Ok " + graph_node(node)
          Err(f) => "Err " + failure(f)
        }
        out.push("  " + text)
      }
      "reachable" | "route" => {
        let c = context.unwrap()
        let positional = if words[0] == "route" { 3 } else { 2 }
        let opts = options(words[positional:])
        let limits = match opts.get("limits") {
          Some(v) => graph_limits(v[0])
          None => @bpmn.GraphLimits::new()
        }
        let kinds = opts
          .get("kinds")
          .map(v => {
            v[0].split(",").map(k => edge_kind_of(k.to_owned())).to_array()
          })
        let direction : @bpmn.GraphDirection? = opts
          .get("direction")
          .map(v => {
            match v[0] {
              "Forward" => Forward
              "Reverse" => Reverse
              "Both" => Both
              other => abort("unknown direction " + other)
            }
          })
        let start = endpoint(c, words[1])
        let text = if words[0] == "reachable" {
          let result = match kinds {
            Some(kinds) =>
              c.graph.reachable(start, kinds=kinds[:], direction?, limits~)
            None => c.graph.reachable(start, direction?, limits~)
          }
          match result {
            Complete(nodes) => "Complete " + graph_nodes(nodes)
            Failed(f) => "Failed " + failure(f)
          }
        } else {
          let target = endpoint(c, words[2])
          let result = match kinds {
            Some(kinds) =>
              c.graph.route(start, target, kinds=kinds[:], direction?, limits~)
            None => c.graph.route(start, target, direction?, limits~)
          }
          match result {
            Found(route) =>
              "Found " +
              graph_nodes(route.nodes) +
              " edges=[" +
              route.edges.iter().map(edge).join(" ") +
              "]"
            Unreachable => "Unreachable"
            Failed(f) => "Failed " + failure(f)
          }
        }
        out.push("  " + text)
      }
      other => abort("unknown graph command " + other)
    }
  }
}
