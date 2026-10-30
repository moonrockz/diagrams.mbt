///|
/// Graph records:
///
/// - graph node: `("Document", resource_id | None, node record)` or
///   `("External", resource_id, namespace_uri, local_name, occurrence)`.
///   Pair a document node record with the tree of `bpmn_graph_tree` for the
///   same resource identifier.
/// - edge: `(kind, source node, target node, connection | None)`. A
///   connection is `(resource_id | None, node record)`.
/// - failure: `("InvalidEndpoint",)`, `("DocumentMismatch",)`,
///   `("InvalidReference", (resource_id | None, ordinal))`,
///   `("Ambiguous", graph nodes)`, `("Limit", limit)` or `("InvalidLimits",)`.
///   `limit` is `"Nodes"`, `"Edges"`, `"Results"` or `"Work"`.
/// - endpoint argument: `("Node", tree token, ordinal)`, `("Id", id)`,
///   `("Qualified", namespace_uri, local_name)` or
///   `("Symbol", resource_id, namespace_uri, local_name)`.
fn bp_graph_node_record(node : @bpmn.GraphNode) -> Rec {
  match node {
    Document(node) =>
      Rec::list([
        Str("Document"),
        Rec::str_opt(node.resource_id()),
        node_record(node),
      ])
    External(node) =>
      Rec::list([
        Str("External"),
        Str(node.symbol.resource_id),
        Str(node.symbol.name.namespace_uri),
        Str(node.symbol.name.local_name),
        Rec::int(node.occurrence),
      ])
  }
}

///|
fn bp_graph_nodes_record(nodes : ReadOnlyArray[@bpmn.GraphNode]) -> Rec {
  Rec::list(nodes.iter().map(bp_graph_node_record).to_array())
}

///|
fn bp_edge_kind_name(kind : @bpmn.GraphEdgeKind) -> String {
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
fn bp_edge_kind_of(value : Rec) -> @bpmn.GraphEdgeKind raise BridgeError {
  match bp_str_of(value, "GraphEdgeKind") {
    "Containment" => Containment
    "SequenceFlow" => SequenceFlow
    "MessageFlow" => MessageFlow
    "Association" => Association
    "DataAssociation" => DataAssociation
    "ConversationLink" => ConversationLink
    "Reference" => Reference
    other => raise bp_invalid_argument("Unknown GraphEdgeKind \{other}.")
  }
}

///|
fn bp_edge_record(edge : @bpmn.GraphEdge) -> Rec {
  Rec::list([
    Str(bp_edge_kind_name(edge.kind)),
    bp_graph_node_record(edge.source),
    bp_graph_node_record(edge.target),
    match edge.connection {
      Some(node) =>
        Rec::list([Rec::str_opt(node.resource_id()), node_record(node)])
      None => Null
    },
  ])
}

///|
fn bp_failure_record(failure : @bpmn.GraphFailure) -> Rec {
  match failure {
    InvalidEndpoint => Rec::list([Str("InvalidEndpoint")])
    DocumentMismatch => Rec::list([Str("DocumentMismatch")])
    InvalidReference(handle) =>
      Rec::list([
        Str("InvalidReference"),
        Rec::list([Rec::str_opt(handle.resource_id()), Rec::int(handle.ordinal)]),
      ])
    Ambiguous(nodes) =>
      Rec::list([Str("Ambiguous"), bp_graph_nodes_record(nodes)])
    Limit(limit) =>
      Rec::list([
        Str("Limit"),
        Str(
          match limit {
            Nodes => "Nodes"
            Edges => "Edges"
            Results => "Results"
            Work => "Work"
          },
        ),
      ])
    InvalidLimits => Rec::list([Str("InvalidLimits")])
  }
}

///|
fn bp_endpoint_of(value : Rec) -> @bpmn.GraphEndpoint raise BridgeError {
  let items = bp_list_of(value, "GraphEndpoint")
  guard items.get(0) is Some(Str(tag)) else {
    raise bp_invalid_argument("GraphEndpoint must start with its tag.")
  }
  match (tag, items.length()) {
    ("Node", 3) => {
      guard items[1] is Int(token) else {
        raise bp_invalid_argument("A node endpoint needs a tree token.")
      }
      Node(node_of(token, bp_int32_of(items[2], "ordinal")).handle())
    }
    ("Id", 2) => Id(bp_str_of(items[1], "id"))
    ("Qualified", 3) =>
      Qualified(
        @bpmn.ExpandedName::new(
          bp_str_of(items[1], "namespace_uri"),
          bp_str_of(items[2], "local_name"),
        ),
      )
    ("Symbol", 4) =>
      Symbol(
        @bpmn.ResolvedSymbol::new(
          bp_str_of(items[1], "resource_id"),
          @bpmn.ExpandedName::new(
            bp_str_of(items[2], "namespace_uri"),
            bp_str_of(items[3], "local_name"),
          ),
        ),
      )
    _ => raise bp_invalid_argument("Unknown GraphEndpoint \{tag}.")
  }
}

///|
fn bp_direction_of(value : Rec) -> @bpmn.GraphDirection? raise BridgeError {
  match value {
    Null => None
    _ =>
      match bp_str_of(value, "GraphDirection") {
        "Forward" => Some(Forward)
        "Reverse" => Some(Reverse)
        "Both" => Some(Both)
        other => raise bp_invalid_argument("Unknown GraphDirection \{other}.")
      }
  }
}

///|
fn bp_kinds_of(value : Rec) -> Array[@bpmn.GraphEdgeKind]? raise BridgeError {
  match value {
    Null => None
    _ => {
      let kinds = []
      for item in bp_list_of(value, "kinds") {
        kinds.push(bp_edge_kind_of(item))
      }
      Some(kinds)
    }
  }
}

///|
/// `(documents, external)`. `documents` holds `(location, document token)`
/// pairs; `external` holds `(location, namespace_uri, import_type, symbols)`.
fn bp_resources_new(args : ArrayView[Rec]) -> Rec raise BridgeError {
  let documents_arg = arg_list(args, 0)
  let external_arg = arg_list(args, 1)
  let docs = []
  for item in documents_arg {
    let pair = bp_list_of(item, "DocumentResource")
    guard pair.length() == 2 && pair[1] is Int(token) else {
      raise bp_invalid_argument("A document resource is (location, document).")
    }
    docs.push(
      @bpmn.DocumentResource::new(
        bp_str_of(pair[0], "location"),
        bp_documents.get(token),
      ),
    )
  }
  let external = []
  for item in external_arg {
    let fields = bp_list_of(item, "ExternalResource")
    guard fields.length() == 4 else {
      raise bp_invalid_argument(
        "An external resource is (location, namespace_uri, import_type, symbols).",
      )
    }
    let symbols = []
    for symbol in bp_list_of(fields[3], "symbols") {
      symbols.push(bp_str_of(symbol, "symbol"))
    }
    external.push(
      @bpmn.ExternalResource::new(
        bp_str_of(fields[0], "location"),
        bp_str_of(fields[1], "namespace_uri"),
        bp_str_of(fields[2], "import_type"),
        symbols,
      ),
    )
  }
  Int(bp_resource_sets.add(@bpmn.ResourceSet::new(documents=docs, external~)))
}

///|
/// `(document, resources | None, resource_id | None, limits | None,
/// graph_limits | None)`. Returns `(graph token | None, diagnostics)`.
fn bp_graph_new(args : ArrayView[Rec]) -> Rec raise BridgeError {
  let document = bp_documents.get(arg_int(args, 0))
  let resources = match bp_opt_arg(args, 1) {
    Null => @bpmn.ResourceSet::new()
    Int(token) => bp_resource_sets.get(token)
    _ =>
      raise bp_invalid_argument("Argument 1 must be a resource token or None.")
  }
  let resource_id = arg_str_opt(args, 2)
  let limits = bp_limits_of(bp_opt_arg(args, 3))
  let graph_limits = bp_graph_limits_of(bp_opt_arg(args, 4))
  let result = @bpmn.DocumentGraph::new(
    document,
    resources~,
    resource_id?,
    limits~,
    graph_limits~,
  )
  let token = match result.graph {
    Some(graph) =>
      Int(bp_graphs.add({ graph, document, resource_id, resources, limits, }))
    None => Null
  }
  Rec::list([token, bp_diagnostics_record(result.diagnostics)])
}

///|
/// A new tree token for the document of `resource_id` in a graph. Its nodes
/// have the ordinals of the graph's document node records.
fn bp_graph_tree(args : ArrayView[Rec]) -> Rec raise BridgeError {
  let entry = bp_graphs.get(arg_int(args, 0))
  let resource_id = arg_str_opt(args, 1)
  let document = if resource_id == entry.resource_id {
    entry.document
  } else {
    match
      entry.resources.documents
      .iter()
      .find_first(r => Some(r.location) == resource_id) {
      Some(resource) => resource.document
      None => raise bp_invalid_argument("The graph has no such document.")
    }
  }
  let result = @bpmn.DocumentTree::new(
    document,
    resource_id?,
    limits=entry.limits,
  )
  guard result.tree is Some(tree) else {
    raise BridgeError(
      "resource-limit", "The graph document tree is not available.",
    )
  }
  Int(bp_add_tree(tree))
}

///|
fn bp_graph_lookup(args : ArrayView[Rec]) -> Rec raise BridgeError {
  let graph = bp_graphs.get(arg_int(args, 0)).graph
  let endpoint = bp_endpoint_of(bp_opt_arg(args, 1))
  let limits = bp_graph_limits_of(bp_opt_arg(args, 2))
  match graph.lookup(endpoint, limits~) {
    Ok(node) => Rec::list([Str("Ok"), bp_graph_node_record(node)])
    Err(failure) => Rec::list([Str("Err"), bp_failure_record(failure)])
  }
}

///|
fn bp_reachability_record(result : @bpmn.ReachabilityResult) -> Rec {
  match result {
    Complete(nodes) =>
      Rec::list([Str("Complete"), bp_graph_nodes_record(nodes)])
    Failed(failure) => Rec::list([Str("Failed"), bp_failure_record(failure)])
  }
}

///|
fn bp_route_record(result : @bpmn.RouteResult) -> Rec {
  match result {
    Found(route) =>
      Rec::list([
        Str("Found"),
        bp_graph_nodes_record(route.nodes),
        Rec::list(route.edges.iter().map(bp_edge_record).to_array()),
      ])
    Unreachable => Rec::list([Str("Unreachable")])
    Failed(failure) => Rec::list([Str("Failed"), bp_failure_record(failure)])
  }
}

///|
/// `(graph, start, kinds | None, direction | None, limits | None)`. `None`
/// keeps the MoonBit default.
fn bp_graph_reachable(args : ArrayView[Rec]) -> Rec raise BridgeError {
  let graph = bp_graphs.get(arg_int(args, 0)).graph
  let start = bp_endpoint_of(bp_opt_arg(args, 1))
  let kinds = bp_kinds_of(bp_opt_arg(args, 2))
  let direction = bp_direction_of(bp_opt_arg(args, 3))
  let limits = bp_graph_limits_of(bp_opt_arg(args, 4))
  let result = match kinds {
    Some(kinds) => graph.reachable(start, kinds=kinds[:], direction?, limits~)
    None => graph.reachable(start, direction?, limits~)
  }
  bp_reachability_record(result)
}

///|
/// `(graph, start, target, kinds | None, direction | None, limits | None)`.
fn bp_graph_route(args : ArrayView[Rec]) -> Rec raise BridgeError {
  let graph = bp_graphs.get(arg_int(args, 0)).graph
  let start = bp_endpoint_of(bp_opt_arg(args, 1))
  let target = bp_endpoint_of(bp_opt_arg(args, 2))
  let kinds = bp_kinds_of(bp_opt_arg(args, 3))
  let direction = bp_direction_of(bp_opt_arg(args, 4))
  let limits = bp_graph_limits_of(bp_opt_arg(args, 5))
  let result = match kinds {
    Some(kinds) =>
      graph.route(start, target, kinds=kinds[:], direction?, limits~)
    None => graph.route(start, target, direction?, limits~)
  }
  bp_route_record(result)
}

///|
fn bp_graph_content(args : ArrayView[Rec]) -> Rec raise BridgeError {
  let graph = bp_graphs.get(arg_int(args, 0)).graph
  Rec::list([
    bp_graph_nodes_record(graph.nodes),
    Rec::list(graph.edges.iter().map(bp_edge_record).to_array()),
  ])
}
