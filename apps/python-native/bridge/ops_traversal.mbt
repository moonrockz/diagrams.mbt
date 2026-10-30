///|
/// BPMN reading, inspection, traversal and graph operations.
///
/// Each operation calls the public `moonrockz/bpmn` API. The record layouts
/// are in `traversal_records.mbt` and `traversal_graph.mbt`. A node argument
/// is a tree token (kind 6) followed by the node ordinal. Every `bpmn_close`
/// is idempotent.
fn traversal_op(op : String, args : ArrayView[Rec]) -> Rec? raise BridgeError {
  let value = match op {
    "bpmn_defaults" =>
      Rec::list([
        bp_limits_record(@bpmn.Limits::new()),
        bp_graph_limits_record(@bpmn.GraphLimits::new()),
      ])
    "bpmn_read" => {
      let source = arg_str(args, 0)
      let source_id = arg_str_opt(args, 1)
      let limits = bp_limits_of(bp_opt_arg(args, 2))
      let result = @bpmn.read(source, source_id?, limits~)
      Rec::list([
        match result.document {
          Some(document) => Int(bp_documents.add(document))
          None => Null
        },
        bp_diagnostics_record(result.diagnostics),
      ])
    }
    "bpmn_close" => Bool(bp_close_token(arg_int(args, 0)))
    "bpmn_tree_new" => {
      let document = bp_documents.get(arg_int(args, 0))
      let resource_id = arg_str_opt(args, 1)
      let limits = bp_limits_of(bp_opt_arg(args, 2))
      let result = @bpmn.DocumentTree::new(document, resource_id?, limits~)
      Rec::list([
        match result.tree {
          Some(tree) => Int(bp_add_tree(tree))
          None => Null
        },
        bp_diagnostics_record(result.diagnostics),
      ])
    }
    "bpmn_tree_info" => {
      let tree = tree_of(arg_int(args, 0))
      Rec::list([
        Rec::int(tree.length()),
        Rec::str_opt(tree.resource_id()),
        node_record(tree.root()),
      ])
    }
    "bpmn_node" => node_record(bp_node_arg(args, 0))
    "bpmn_node_element" =>
      match bp_node_arg(args, 0).element() {
        Some(element) => bp_element_record(element)
        None => Null
      }
    "bpmn_node_attributes" =>
      bp_attributes_record(bp_node_arg(args, 0).attributes())
    "bpmn_node_scalar" => {
      let node = bp_node_arg(args, 0)
      let name = @bpmn.ExpandedName::new(arg_str(args, 2), arg_str(args, 3))
      bp_scalar_opt_record(node.scalar(name))
    }
    "bpmn_node_fields" =>
      Rec::list(
        bp_node_arg(args, 0)
        .fields()
        .iter()
        .map(bp_node_field_record)
        .to_array(),
      )
    "bpmn_node_field" => {
      let node = bp_node_arg(args, 0)
      match node.field(bp_path_field_of(bp_opt_arg(args, 2))) {
        Some(field) => bp_node_field_record(field)
        None => Null
      }
    }
    "bpmn_node_children" => bp_nodes_record(bp_node_arg(args, 0).children())
    "bpmn_node_location" => bp_location_record(bp_node_arg(args, 0).location())
    "bpmn_node_path" =>
      Rec::list(
        bp_node_arg(args, 0)
        .path()
        .steps()
        .iter()
        .map(bp_step_record)
        .to_array(),
      )
    "bpmn_node_equal" => Bool(bp_node_arg(args, 0) == bp_node_arg(args, 2))
    "bpmn_handle_equal" =>
      Bool(bp_node_arg(args, 0).handle() == bp_node_arg(args, 2).handle())
    "bpmn_lookup" => {
      let tree = tree_of(arg_int(args, 0))
      bp_lookup_record(tree.lookup(bp_node_arg(args, 1).handle()))
    }
    "bpmn_path_resolve" => {
      let path = bp_node_arg(args, 0).path()
      bp_lookup_record(path.resolve(tree_of(arg_int(args, 2))))
    }
    "bpmn_events_new" =>
      Int(
        bp_readers.add({
          reader: @bpmn.EventReader::new(bp_node_arg(args, 0)),
          state: Running,
        }),
      )
    "bpmn_events_next" => {
      let entry = bp_readers.get(arg_int(args, 0))
      match arg_int32(args, 1) {
        0 => ()
        1 => entry.reader.skip_children()
        2 => entry.stop()
        _ => raise bp_invalid_argument("A control is 0, 1 or 2.")
      }
      match entry.next() {
        Some(event) => bp_event_record(event)
        None => Null
      }
    }
    "bpmn_events_skip_children" => {
      bp_readers.get(arg_int(args, 0)).reader.skip_children()
      Null
    }
    "bpmn_events_stop" => {
      bp_readers.get(arg_int(args, 0)).stop()
      Null
    }
    "bpmn_events_state" => Str(bp_readers.get(arg_int(args, 0)).state.name())
    "bpmn_events_batch" => {
      let entry = bp_readers.get(arg_int(args, 0))
      let size = arg_int32(args, 1)
      guard size >= 1 && size <= bp_max_event_batch else {
        raise bp_invalid_argument(
          "A batch size is from 1 to \{bp_max_event_batch}.",
        )
      }
      let events = []
      while events.length() < size && entry.next() is Some(event) {
        events.push(bp_event_record(event))
      }
      Rec::list([Rec::list(events), Str(entry.state.name())])
    }
    "bpmn_cursor_new" => {
      let cursor = @bpmn.TreeCursor::new(bp_node_arg(args, 0))
      let token = bp_cursors.add(cursor)
      Rec::list([
        Int(token),
        Rec::int(cursor.depth()),
        node_record(cursor.node()),
      ])
    }
    "bpmn_cursor_move" => {
      let cursor = bp_cursors.get(arg_int(args, 0))
      let moved = match arg_str(args, 1) {
        "parent" => cursor.goto_parent()
        "first_child" => cursor.goto_first_child()
        "last_child" => cursor.goto_last_child()
        "next_sibling" => cursor.goto_next_sibling()
        "previous_sibling" => cursor.goto_previous_sibling()
        "none" => false
        other => raise bp_invalid_argument("Unknown cursor move \{other}.")
      }
      Rec::list([
        Bool(moved),
        Rec::int(cursor.depth()),
        node_record(cursor.node()),
      ])
    }
    "bpmn_resources_new" => bp_resources_new(args)
    "bpmn_graph_new" => bp_graph_new(args)
    "bpmn_graph_tree" => bp_graph_tree(args)
    "bpmn_graph_content" => bp_graph_content(args)
    "bpmn_graph_lookup" => bp_graph_lookup(args)
    "bpmn_graph_reachable" => bp_graph_reachable(args)
    "bpmn_graph_route" => bp_graph_route(args)
    _ => return None
  }
  Some(value)
}

///|
/// The largest observational event batch.
let bp_max_event_batch : Int32 = 4096

///|
/// An event: `(is_enter, node record)`.
/// `bpmn_events_batch` returns `(events, state)`; `state` is `"running"`,
/// `"complete"` or `"stopped"`. A batch that fills up stays `"running"` even
/// when no event is left: only a read past the end shows `"complete"`.
fn bp_event_record(event : @bpmn.TraversalEvent) -> Rec {
  match event {
    Enter(node) => Rec::list([Bool(true), node_record(node)])
    Leave(node) => Rec::list([Bool(false), node_record(node)])
  }
}

///|
/// Open traversal objects by registry name.
fn traversal_live() -> Array[(String, Int32)] {
  [
    ("bpmn.document", bp_documents.live()),
    ("bpmn.graph", bp_graphs.live()),
    ("bpmn.event_reader", bp_readers.live()),
    ("bpmn.tree_cursor", bp_cursors.live()),
    ("bpmn.resources", bp_resource_sets.live()),
    ("bpmn.tree", bp_trees.live()),
  ]
}
