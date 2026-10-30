///|
/// Boundary records of the BPMN traversal operations.
///
/// Every value is a `Rec`. Python sees a list as a tuple. The layouts:
///
/// - name: `(namespace_uri, local_name)`.
/// - span: `(start, end)`, half-open UTF-16 offsets.
/// - position: `(offset, line, column)`. The offset counts UTF-16 code units;
///   the line and the column start at 1. The column counts UTF-16 code units.
/// - location: `(source_id | None, start position, end position)`.
/// - diagnostic: `(code, severity, message, span | None, location | None)`.
///   `severity` is `"Error"` or `"Warning"`.
/// - scalar: `(tag, token, detail)`. `tag` is the `@bpmn.Scalar` constructor
///   name. `token` is `Scalar::token`. `detail` is `None` for `Text`,
///   `Identifier`, `Uri`, `Integer` and `Number`, a bool for `Boolean`,
///   `(kind, spelling, name | None)` for `Reference` (`kind` is `"Id"` or
///   `"QName"`), the enumeration type name for `Enumeration` and
///   `(raw, expected name)` for `Invalid`.
/// - attribute: `(name | None, raw_name, scalar, span | None, location | None)`.
/// - path field: `("Named", namespace_uri, local_name)`, or a one-item tuple
///   with `"Text"`, `"Comment"`, `"ProcessingInstruction"`, `"Root"`,
///   `"Prolog"` or `"Epilog"`.
/// - path step: `(path field, index, content_index)`.
/// - kind: `(namespace_uri, local_name, class)`. `class` is `"standard"`,
///   `"foreign"` (`Kind::Foreign`) or `"unknown"` (`Kind::Unknown`).
/// - value: `("Document",)`, `("Element",)`, `("Text", text)`,
///   `("Comment", text)` or `("ProcessingInstruction", target, data)`.
///
/// The node snapshot record of `node_record` is
///
/// ```text
/// (ordinal, category, kind | None, id | None, depth, parent ordinal | None,
///  step | None, span | None, child count, value)
/// ```
///
/// - `ordinal` is `NodeHandle.ordinal`: the preorder index in its tree.
/// - `category` is the `@bpmn.NodeCategory` constructor name.
/// - `depth` is `NodeRef::depth`; the document node has depth 0.
/// - `span` is `NodeRef::span`. A constructed node has no span.
///
/// The record holds no tree token. The receiver pairs it with the tree that it
/// asked. Locations, attributes, fields and paths have their own operations.
fn bp_name_record(name : @bpmn.ExpandedName) -> Rec {
  Rec::list([Str(name.namespace_uri), Str(name.local_name)])
}

///|
fn bp_name_opt_record(name : @bpmn.ExpandedName?) -> Rec {
  match name {
    Some(name) => bp_name_record(name)
    None => Null
  }
}

///|
fn bp_span_record(span : @bpmn.Span?) -> Rec {
  match span {
    Some(span) => Rec::list([Rec::int(span.start), Rec::int(span.end)])
    None => Null
  }
}

///|
fn bp_position_record(position : @bpmn.Position) -> Rec {
  Rec::list([
    Rec::int(position.offset),
    Rec::int(position.line),
    Rec::int(position.column),
  ])
}

///|
fn bp_location_record(location : @bpmn.Location?) -> Rec {
  match location {
    Some(location) =>
      Rec::list([
        Rec::str_opt(location.source_id),
        bp_position_record(location.start),
        bp_position_record(location.end),
      ])
    None => Null
  }
}

///|
fn bp_diagnostic_record(diagnostic : @bpmn.Diagnostic) -> Rec {
  Rec::list([
    Str(diagnostic.code),
    Str(
      match diagnostic.severity {
        Error => "Error"
        Warning => "Warning"
      },
    ),
    Str(diagnostic.message),
    bp_span_record(diagnostic.span),
    bp_location_record(diagnostic.location),
  ])
}

///|
fn bp_diagnostics_record(diagnostics : ReadOnlyArray[@bpmn.Diagnostic]) -> Rec {
  Rec::list(diagnostics.iter().map(bp_diagnostic_record).to_array())
}

///|
fn bp_scalar_record(scalar : @bpmn.Scalar) -> Rec {
  let (tag, detail) : (String, Rec) = match scalar {
    Text(_) => ("Text", Null)
    Identifier(_) => ("Identifier", Null)
    Uri(_) => ("Uri", Null)
    Boolean(value) => ("Boolean", Bool(value))
    Integer(_) => ("Integer", Null)
    Number(_) => ("Number", Null)
    Reference(reference) =>
      (
        "Reference",
        Rec::list([
          Str(
            match reference.kind {
              Id => "Id"
              QName => "QName"
            },
          ),
          Str(reference.spelling),
          bp_name_opt_record(reference.name),
        ]),
      )
    Enumeration(value) =>
      ("Enumeration", bp_name_record(value.type_id().name()))
    Invalid(raw~, expected~) =>
      ("Invalid", Rec::list([Str(raw), bp_name_record(expected)]))
  }
  Rec::list([Str(tag), Str(scalar.token()), detail])
}

///|
fn bp_scalar_opt_record(scalar : @bpmn.Scalar?) -> Rec {
  match scalar {
    Some(scalar) => bp_scalar_record(scalar)
    None => Null
  }
}

///|
fn bp_attribute_record(attribute : @bpmn.Attribute) -> Rec {
  Rec::list([
    bp_name_opt_record(attribute.name),
    Str(attribute.raw_name),
    bp_scalar_record(attribute.value),
    bp_span_record(attribute.span),
    bp_location_record(attribute.location()),
  ])
}

///|
fn bp_attributes_record(attributes : ReadOnlyArray[@bpmn.Attribute]) -> Rec {
  Rec::list(attributes.iter().map(bp_attribute_record).to_array())
}

///|
fn bp_field_record(field : @bpmn.PathField) -> Rec {
  match field {
    Named(name) =>
      Rec::list([Str("Named"), Str(name.namespace_uri), Str(name.local_name)])
    Text => Rec::list([Str("Text")])
    Comment => Rec::list([Str("Comment")])
    ProcessingInstruction => Rec::list([Str("ProcessingInstruction")])
    Root => Rec::list([Str("Root")])
    Prolog => Rec::list([Str("Prolog")])
    Epilog => Rec::list([Str("Epilog")])
  }
}

///|
fn bp_step_record(step : @bpmn.PathStep) -> Rec {
  Rec::list([
    bp_field_record(step.field),
    Rec::int(step.index),
    Rec::int(step.content_index),
  ])
}

///|
fn bp_kind_record(kind : @bpmn.Kind) -> Rec {
  let class = match kind {
    Foreign(_) => "foreign"
    Unknown(_) => "unknown"
    _ => "standard"
  }
  Rec::list([Str(kind.namespace_uri()), Str(kind.local_name()), Str(class)])
}

///|
/// The `@bpmn.NodeCategory` constructor name.
fn bp_category_name(category : @bpmn.NodeCategory) -> String {
  match category {
    Document => "Document"
    Definitions => "Definitions"
    Process => "Process"
    Activity => "Activity"
    Event => "Event"
    Gateway => "Gateway"
    SequenceFlow => "SequenceFlow"
    Collaboration => "Collaboration"
    Participant => "Participant"
    Lane => "Lane"
    Choreography => "Choreography"
    ChoreographyActivity => "ChoreographyActivity"
    Conversation => "Conversation"
    ConversationLink => "ConversationLink"
    DiagramInterchange => "DiagramInterchange"
    Extension => "Extension"
    Other => "Other"
    Text => "Text"
    Comment => "Comment"
    ProcessingInstruction => "ProcessingInstruction"
  }
}

///|
fn bp_value_record(value : @bpmn.NodeValue) -> Rec {
  match value {
    Document => Rec::list([Str("Document")])
    Element(_) => Rec::list([Str("Element")])
    Text(text) => Rec::list([Str("Text"), Str(text)])
    Comment(text) => Rec::list([Str("Comment"), Str(text)])
    ProcessingInstruction(target~, data~) =>
      Rec::list([Str("ProcessingInstruction"), Str(target), Str(data)])
  }
}

///|
/// The node snapshot record. The layout is at the top of this file.
fn node_record(node : @bpmn.NodeRef) -> Rec {
  Rec::list([
    Rec::int(node.handle().ordinal),
    Str(bp_category_name(node.category())),
    match node.kind() {
      Some(kind) => bp_kind_record(kind)
      None => Null
    },
    Rec::str_opt(node.id()),
    Rec::int(node.depth()),
    Rec::int_opt(node.parent().map(p => p.handle().ordinal)),
    match node.step() {
      Some(step) => bp_step_record(step)
      None => Null
    },
    bp_span_record(node.span()),
    Rec::int(node.children().length()),
    bp_value_record(node.value()),
  ])
}

///|
fn bp_nodes_record(nodes : ReadOnlyArray[@bpmn.NodeRef]) -> Rec {
  Rec::list(nodes.iter().map(node_record).to_array())
}

///|
/// The read-only projection of an element value:
/// `(kind, bindings, value_type | None, text_value | None, content)`.
/// `bindings` is a tuple of `(prefix, namespace_uri)` pairs.
fn bp_element_record(element : @bpmn.Element) -> Rec {
  Rec::list([
    bp_kind_record(element.kind),
    Rec::list(
      element.bindings
      .iter()
      .map(p => Rec::list([Str(p.0), Str(p.1)]))
      .to_array(),
    ),
    bp_name_opt_record(element.value_type),
    bp_scalar_opt_record(element.text_value),
    Str(element.content),
  ])
}

///|
/// A field: `(path field, attributes, child node records)`.
fn bp_node_field_record(field : @bpmn.NodeField) -> Rec {
  Rec::list([
    bp_field_record(field.field),
    bp_attributes_record(field.attributes),
    bp_nodes_record(field.children),
  ])
}

///|
fn bp_lookup_record(lookup : @bpmn.NodeLookup) -> Rec {
  match lookup {
    Found(node) => Rec::list([Str("Found"), node_record(node)])
    DocumentMismatch => Rec::list([Str("DocumentMismatch")])
    InvalidHandle => Rec::list([Str("InvalidHandle")])
  }
}

///|
fn bp_invalid_argument(message : String) -> BridgeError {
  BridgeError("invalid-argument", message)
}

///|
fn bp_int32_of(value : Rec, what : String) -> Int32 raise BridgeError {
  guard value is Int(number) && number >= -2147483648L && number <= 2147483647L else {
    raise bp_invalid_argument("\{what} must be a 32-bit int.")
  }
  number.to_int()
}

///|
fn bp_int32_opt_of(value : Rec, what : String) -> Int32? raise BridgeError {
  match value {
    Null => None
    _ => Some(bp_int32_of(value, what))
  }
}

///|
fn bp_str_of(value : Rec, what : String) -> String raise BridgeError {
  guard value is Str(text) else {
    raise bp_invalid_argument("\{what} must be a str.")
  }
  text
}

///|
fn bp_list_of(
  value : Rec,
  what : String,
) -> ReadOnlyArray[Rec] raise BridgeError {
  guard value is List(items) else {
    raise bp_invalid_argument("\{what} must be a tuple.")
  }
  items
}

///|
fn bp_opt_arg(args : ArrayView[Rec], index : Int32) -> Rec {
  args.get(index).unwrap_or(Null)
}

///|
/// `None`, or a tuple of six values that are each an int or `None`. `None`
/// keeps the `@bpmn.Limits::new` default of that limit.
fn bp_limits_of(value : Rec) -> @bpmn.Limits raise BridgeError {
  if value is Null {
    return @bpmn.Limits::new()
  }
  let items = bp_list_of(value, "Limits")
  guard items.length() == 6 else {
    raise bp_invalid_argument("Limits must have six values.")
  }
  let source_units = bp_int32_opt_of(items[0], "source_units")
  let output_units = bp_int32_opt_of(items[1], "output_units")
  let nodes = bp_int32_opt_of(items[2], "nodes")
  let depth = bp_int32_opt_of(items[3], "depth")
  let token_units = bp_int32_opt_of(items[4], "token_units")
  let diagnostics = bp_int32_opt_of(items[5], "diagnostics")
  @bpmn.Limits::new(
    source_units?,
    output_units?,
    nodes?,
    depth?,
    token_units?,
    diagnostics?,
  )
}

///|
fn bp_limits_record(limits : @bpmn.Limits) -> Rec {
  Rec::list([
    Rec::int(limits.source_units),
    Rec::int(limits.output_units),
    Rec::int(limits.nodes),
    Rec::int(limits.depth),
    Rec::int(limits.token_units),
    Rec::int(limits.diagnostics),
  ])
}

///|
/// `None`, or `(nodes, edges, results, work)` with an int or `None` each.
fn bp_graph_limits_of(value : Rec) -> @bpmn.GraphLimits raise BridgeError {
  if value is Null {
    return @bpmn.GraphLimits::new()
  }
  let items = bp_list_of(value, "GraphLimits")
  guard items.length() == 4 else {
    raise bp_invalid_argument("GraphLimits must have four values.")
  }
  let nodes = bp_int32_opt_of(items[0], "nodes")
  let edges = bp_int32_opt_of(items[1], "edges")
  let results = bp_int32_opt_of(items[2], "results")
  let work = bp_int32_opt_of(items[3], "work")
  @bpmn.GraphLimits::new(nodes?, edges?, results?, work?)
}

///|
fn bp_graph_limits_record(limits : @bpmn.GraphLimits) -> Rec {
  Rec::list([
    Rec::int(limits.nodes),
    Rec::int(limits.edges),
    Rec::int(limits.results),
    Rec::int(limits.work),
  ])
}

///|
fn bp_path_field_of(value : Rec) -> @bpmn.PathField raise BridgeError {
  let items = bp_list_of(value, "PathField")
  guard items.get(0) is Some(Str(tag)) else {
    raise bp_invalid_argument("PathField must start with its tag.")
  }
  match (tag, items.length()) {
    ("Named", 3) =>
      Named(
        @bpmn.ExpandedName::new(
          bp_str_of(items[1], "namespace_uri"),
          bp_str_of(items[2], "local_name"),
        ),
      )
    ("Text", 1) => Text
    ("Comment", 1) => Comment
    ("ProcessingInstruction", 1) => ProcessingInstruction
    ("Root", 1) => Root
    ("Prolog", 1) => Prolog
    ("Epilog", 1) => Epilog
    _ => raise bp_invalid_argument("Unknown PathField \{tag}.")
  }
}
