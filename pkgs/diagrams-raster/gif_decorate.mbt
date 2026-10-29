///|
/// Match the same public scene bindings used by the offline player. These
/// predicates inspect generated XML attributes, never source label strings.
fn gif_attr(node : SvgXmlNode, name : String) -> String? {
  for attr in node.attributes {
    if attr.raw_name == name {
      return Some(attr.value)
    }
  }
  None
}

///|
fn gif_class(node : SvgXmlNode, name : String) -> Bool {
  gif_attr(node, "class").unwrap_or("").split(" ").any(part => part == name)
}

///|
fn gif_visit_indices(nodes : Array[SvgXmlNode]) -> Map[String, Int32] {
  let indices : Map[String, Int32] = Map([])
  let mut frame = 0
  fn add(kind : @svg.NodeBindingKind, index : Int32) -> Unit {
    let key = gif_kind_key(kind)
    if !indices.contains(key) {
      indices[key] = index
    }
  }
  for index, node in nodes {
    if node.kind != Element {
      continue
    }
    if gif_class(node, "bpmn-shape") {
      if gif_attr(node, "data-id") is Some(id) {
        add(Bpmn(id), index)
      }
    }
    if gif_class(node, "message") {
      if gif_attr(node, "data-index") is Some(text) {
        let number = @string.parse_int(text) catch { _ => -1 }
        if number >= 0 && number.to_string() == text {
          add(Message(number), index)
        }
      }
    }
    if node.raw_name == "rect" && gif_class(node, "frame") {
      add(Frame(frame), index)
      frame += 1
    }
    if gif_class(node, "swimlane-node") ||
      gif_class(node, "swimlane-group") ||
      gif_class(node, "swimlane-lane") {
      if gif_attr(node, "data-swimlane-id") is Some(id) {
        add(Swimlane(id), index)
      }
    }
    if gif_class(node, "flowchart-node") ||
      gif_class(node, "flowchart-group") ||
      gif_class(node, "flowchart-lane") {
      if gif_attr(node, "data-flowchart-id") is Some(id) {
        add(Flowchart(id), index)
      }
    }
    if gif_class(node, "state-node") || gif_class(node, "state-group") {
      if gif_attr(node, "data-state-id") is Some(id) {
        add(State(id), index)
      }
    }
    if gif_class(node, "architecture-service") ||
      gif_class(node, "architecture-junction") ||
      gif_class(node, "architecture-group") {
      if gif_attr(node, "data-id") is Some(id) {
        add(Architecture(id), index)
      }
    }
    if gif_class(node, "rr-term") {
      if gif_attr(node, "data-term") is Some(id) {
        add(RailroadTerm(id), index)
      }
    }
    if gif_class(node, "data-row") {
      if gif_attr(node, "data-member") is Some(id) {
        add(DataRow(id), index)
      }
    }
    if gif_class(node, "data-box") {
      if gif_attr(node, "data-node") is Some(id) {
        add(DataBox(id), index)
      }
    }
  }
  indices
}

///|
/// A translucent geometry overlay keeps labels and original styling readable.
/// Definitions stay in the untouched base tree. Copies reference those original
/// masks and clips, and never introduce duplicate SVG IDs.
fn gif_visit_write(
  nodes : Array[SvgXmlNode],
  index : Int32,
  out : StringBuilder,
) -> Unit {
  let node = nodes[index]
  if node.kind != Element ||
    [
      "text", "tspan", "title", "desc", "metadata", "style", "defs", "mask", "clipPath",
      "linearGradient", "radialGradient", "stop",
    ].contains(node.raw_name) {
    return
  }
  out.write_string("<" + node.raw_name)
  let shape = [
    "path", "rect", "circle", "ellipse", "polygon", "polyline", "line",
  ].contains(node.raw_name)
  for attr in node.attributes {
    if ["id", "class", "style"].contains(attr.raw_name) ||
      (shape && ["fill", "stroke", "stroke-width"].contains(attr.raw_name)) {
      continue
    }
    out.write_string(
      " " + attr.raw_name + "=\"" + svg_xml_escape(attr.value) + "\"",
    )
  }
  if shape {
    let fill = if gif_attr(node, "fill") == Some("none") ||
      node.raw_name == "line" ||
      node.raw_name == "polyline" {
      "none"
    } else {
      "#2563eb"
    }
    out.write_string(
      " fill=\"" + fill + "\" stroke=\"#2563eb\" stroke-width=\"2\"",
    )
  }
  out.write_string(">")
  for child in node.children {
    gif_visit_write(nodes, child, out)
  }
  out.write_string("</" + node.raw_name + ">")
}

///|
/// Derive a frame without changing the canonical SVG or live playback state.
fn gif_paint_svg(
  source : String,
  source_id : String,
  paints : ArrayView[GifPaint],
  limits : RasterLimits,
  visit_indices? : Map[String, Int32],
) -> String raise RasterFailure {
  let nodes = parse_svg_xml(source, max_nodes=limits.max_svg_nodes)
  let visit_indices = visit_indices.unwrap_or_else(() => {
    gif_visit_indices(nodes)
  })
  let additions : Map[String, StringBuilder] = Map([])
  let lengths : Map[String, Double] = Map([])
  let ids : Map[String, Int32] = Map([])
  for index, node in nodes {
    if gif_attr(node, "id") is Some(id) {
      ids[id] = index
    }
  }
  let mut used = 0
  fn append(id : String, markup : String) -> Unit raise RasterFailure {
    guard markup.length() <= limits.max_source_units - used else {
      raise RasterInvalid(
        "raster/source-limit",
        "GIF overlays exceed the derived SVG budget",
        Some(source_id),
      )
    }
    used += markup.length()
    let out = match additions.get(id) {
      Some(out) => out
      None => {
        let out = StringBuilder()
        additions[id] = out
        out
      }
    }
    out.write_string(markup)
  }
  for active in paints {
    match active.target {
      Connection(id~, path~, mask~, point~) => {
        guard ids.get(id) is Some(index) else {
          raise raster_unsupported("GIF connection target is outside the scene")
        }
        let clip = gif_attr(nodes[index], "clip-path")
        let separation = mask
          .map(value => " mask=\"" + svg_xml_escape(value) + "\"")
          .unwrap_or("") +
          clip
          .map(value => " clip-path=\"" + svg_xml_escape(value) + "\"")
          .unwrap_or("")
        let length = match lengths.get(path) {
          Some(length) => length
          None => {
            let geometry = match @svg.ConnectorPath::parse(path) {
              Some(path) =>
                gif_path(path, 8192) catch {
                  GifInvalid(message) => raise raster_unsupported(message)
                }
              None => raise raster_unsupported("Malformed GIF connection")
            }
            lengths[path] = geometry.length
            geometry.length
          }
        }
        let fraction = active.numerator.to_double() /
          active.denominator.to_double()
        let offset = length *
          fraction *
          (if active.reversed { 1.0 } else { -1.0 })
        append(
          id,
          "<g class=\"gif-motion-overlay\"" +
          separation +
          "><path d=\"" +
          svg_xml_escape(path) +
          "\" fill=\"none\" stroke=\"#2563eb\" stroke-width=\"3\" stroke-opacity=\"0.5\" stroke-dasharray=\"12 8\" stroke-dashoffset=\"" +
          offset.to_string() +
          "\"/><circle r=\"4\" cx=\"" +
          point.x.to_string() +
          "\" cy=\"" +
          point.y.to_string() +
          "\" fill=\"#2563eb\"/></g>",
        )
      }
      Visit(kind) => {
        guard visit_indices.get(gif_kind_key(kind)) is Some(index) else {
          raise raster_unsupported("GIF visit target is outside the scene")
        }
        let id = match gif_attr(nodes[index], "id") {
          Some(id) => id
          None => {
            let mut suffix = 0
            let mut id = "raster-gif-target-" + index.to_string()
            while ids.contains(id) {
              suffix += 1
              id = "raster-gif-target-" +
                index.to_string() +
                "-" +
                suffix.to_string()
            }
            nodes[index].attributes.push({ raw_name: "id", value: id, })
            ids[id] = index
            id
          }
        }
        let clone = StringBuilder()
        gif_visit_write(nodes, index, clone)
        append(
          id,
          "<g class=\"gif-visit-overlay\" opacity=\"0.35\">" +
          clone.to_string() +
          "</g>",
        )
      }
    }
  }
  let output = StringBuilder()
  let matched : Map[String, Bool] = Map([])
  let markup : Map[String, String] = Map([])
  for id, out in additions {
    markup[id] = out.to_string()
  }
  svg_xml_write(nodes, 0, output, markup, matched)
  guard matched.length() == additions.length() else {
    raise raster_unsupported("GIF target binding is missing")
  }
  let result = output.to_string()
  guard result.length() <= limits.max_source_units else {
    raise RasterInvalid(
      "raster/source-limit",
      "GIF frame exceeds the derived SVG budget",
      Some(source_id),
    )
  }
  result
}

///|
priv struct GifPaint {
  target : GifTarget
  numerator : Int64
  denominator : Int64
  reversed : Bool
}

///|
fn gif_frame_svg(
  scene : @svg.Scene,
  frame : GifFrameSample,
  limits : RasterLimits,
) -> String raise RasterFailure {
  let paints = frame.occurrences
    .iter()
    .map(active => GifPaint::{
      target: active.target,
      numerator: active.occurrence.numerator,
      denominator: active.occurrence.denominator,
      reversed: active.occurrence.reversed,
    })
    .to_array()
  gif_paint_svg(scene.display_svg, scene.catalog.view_id, paints, limits)
}
