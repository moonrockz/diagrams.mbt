///|
/// Versioned export data carries the generated scene and validated plan into an
/// offline worker. It is a consistency protocol, not a signature or trust token.
pub struct GifDataResult {
  data : Json?
  diagnostics : ReadOnlyArray[RasterDiagnostic]
}

///|
/// Protocol entries share the XML-node budget; repeated metadata strings share
/// the source-unit budget even when a host Json value shares its backing arrays.
priv struct GifProtocolBudget {
  limits : RasterLimits
  mut entries : Int32
  mut units : Int32
}

///|
fn GifProtocolBudget::count(
  self : GifProtocolBudget,
  count : Int32,
) -> Unit raise RasterFailure {
  guard count <= self.limits.max_svg_nodes - self.entries else {
    raise raster_fail(
      "raster/gif-data", "GIF aggregate binding/step/group budget exhausted",
    )
  }
  self.entries += count
}

///|
fn GifProtocolBudget::text(
  self : GifProtocolBudget,
  text : String,
) -> Unit raise RasterFailure {
  guard text.length() <= self.limits.max_source_units - self.units else {
    raise raster_fail(
      "raster/source-limit", "GIF aggregate binding text budget exhausted",
    )
  }
  self.units += text.length()
}

///|
fn GifProtocolBudget::value(
  self : GifProtocolBudget,
  value : Json,
) -> Unit raise RasterFailure {
  if value is String(text) {
    self.text(text)
  }
}

///|
fn gif_kind_parts(kind : @svg.NodeBindingKind) -> (String, String) {
  match kind {
    Bpmn(id) => ("bpmn", id)
    Message(index) => ("message", index.to_string())
    Frame(index) => ("frame", index.to_string())
    Swimlane(id) => ("swimlane", id)
    Flowchart(id) => ("flowchart", id)
    State(id) => ("state", id)
    Architecture(id) => ("architecture", id)
    RailroadTerm(id) => ("term", id)
    DataRow(id) => ("row", id)
    DataBox(id) => ("box", id)
  }
}

///|
fn gif_kind_key(kind : @svg.NodeBindingKind) -> String {
  let (tag, id) = gif_kind_parts(kind)
  tag + ":" + id
}

///|
fn gif_source_id(canonical : String, display : String) -> String {
  let mut hash : UInt64 = 14695981039346656037
  for source in [canonical, display] {
    for i in 0..<source.length() {
      hash = (hash ^ source.code_unit_at(i).to_int().to_uint64()) *
        1099511628211
    }
    hash = (hash ^ 0xff) * 1099511628211
  }
  "gif1-" + hash.to_string(radix=16)
}

///|
fn gif_kind_data(kind : @svg.NodeBindingKind) -> Json {
  let (tag, value) = gif_kind_parts(kind)
  Json([Json(tag), Json(value)])
}

///|
/// Prepare a source-bound scene once. Browser route changes may supply another
/// bounded schedule over these same visible occurrence keys.
pub fn gif_export_data(
  scene : @svg.Scene,
  plan : @animation.PlaybackPlan,
  limits~ : RasterLimits = RasterLimits::default(),
) -> GifDataResult {
  if !plan.matches(scene.catalog) {
    return {
      data: None,
      diagnostics: gif_diagnostic(
        "raster/plan-mismatch",
        "Export scene and playback plan name different sources",
        scene.catalog.view_id,
      ),
    }
  }
  try {
    validate_raster_limits(limits)
    guard plan.duration_ms > 0L && !plan.steps.is_empty() else {
      raise raster_fail(
        "raster/gif-data", "GIF playback needs a positive duration and at least one occurrence",
      )
    }
    guard scene.canonical_svg.length() <= limits.max_source_units &&
      scene.display_svg.length() <= limits.max_source_units &&
      scene.paths.length() <= limits.max_svg_nodes &&
      scene.nodes.length() <= limits.max_svg_nodes &&
      plan.steps.length() <= limits.max_svg_nodes else {
      raise raster_fail(
        "raster/source-limit", "Export data exceeds its source/binding budget",
      )
    }
    let budget = GifProtocolBudget::{ limits, entries: 0, units: 0, }
    budget.count(scene.paths.length())
    budget.count(scene.nodes.length())
    budget.count(plan.steps.length())
    for path in scene.paths {
      budget.text(path.occurrence.key)
      budget.text(path.id)
      budget.text(path.path)
      if path.mask is Some(mask) {
        budget.text(mask)
      }
    }
    for node in scene.nodes {
      budget.text(node.endpoint)
      let (tag, id) = gif_kind_parts(node.kind)
      budget.text(tag)
      budget.text(id)
    }
    for step in plan.steps {
      budget.count(step.concurrent_groups.length())
      budget.text(step.occurrence.key)
      budget.text(step.start_ms.to_string())
      budget.text(step.duration_ms.to_string())
    }
    let source_id = gif_source_id(scene.canonical_svg, scene.display_svg)
    let paths = scene.paths
      .iter()
      .map(path => {
        Json({
          "key": Json(path.occurrence.key),
          "id": Json(path.id),
          "path": Json(path.path),
          "mask": path.mask.map(value => Json(value)).unwrap_or(Json(null)),
        })
      })
      .to_array()
    let nodes = scene.nodes
      .iter()
      .map(node => {
        Json({ "key": Json(node.endpoint), "kind": gif_kind_data(node.kind) })
      })
      .to_array()
    let steps = plan.steps
      .iter()
      .map(step => {
        Json({
          "key": Json(step.occurrence.key),
          "ordinal": Json(step.ordinal),
          "start_ms": Json(step.start_ms.to_string()),
          "duration_ms": Json(step.duration_ms.to_string()),
          "reversed": Json(step.reversed),
          "visit": Json(step.visit),
          "groups": Json(
            step.concurrent_groups.iter().map(group => Json(group)).to_array(),
          ),
        })
      })
      .to_array()
    let data : Json = {
      "version": 1,
      "source_id": Json(source_id),
      "canonical": Json(scene.canonical_svg),
      "display": Json(scene.display_svg),
      "paths": Json(paths),
      "nodes": Json(nodes),
      "plan": {
        "source_id": Json(source_id),
        "mode": Json(
          if plan.mode == Finite {
            "finite"
          } else {
            "illustrative"
          },
        ),
        "duration_ms": Json(plan.duration_ms.to_string()),
        "steps": Json(steps),
      },
    }
    { data: Some(data), diagnostics: [], }
  } catch {
    error => { data: None, diagnostics: [raster_diagnostic(error)], }
  }
}

///|
fn gif_field(value : Json, name : String) -> Json raise RasterFailure {
  guard value is Object(fields) && fields.get(name) is Some(value) else {
    raise raster_fail("raster/gif-data", "Missing export field: " + name)
  }
  value
}

///|
fn gif_string(value : Json) -> String raise RasterFailure {
  guard value is String(value) else {
    raise raster_fail("raster/gif-data", "Export field must be a string")
  }
  value
}

///|
fn gif_boolean(value : Json) -> Bool raise RasterFailure {
  match value {
    True => true
    False => false
    _ => raise raster_fail("raster/gif-data", "Export field must be a boolean")
  }
}

///|
fn gif_number(value : Json) -> Int64 raise RasterFailure {
  let number = match value {
    Number(number, ..) => number
    String(text) => {
      guard text.length() <= 32 else {
        raise raster_fail("raster/gif-data", "Export integer text is excessive")
      }
      @string.parse_double(text) catch {
        _ =>
          raise raster_fail("raster/gif-data", "Export time must be an integer")
      }
    }
    _ => raise raster_fail("raster/gif-data", "Export field must be an integer")
  }
  guard number >= 0.0 &&
    number <= 9007199254740991.0 &&
    number.floor() == number else {
    raise raster_fail(
      "raster/gif-data", "Export integer is outside the exact logical-time range",
    )
  }
  number.to_int64()
}

///|
fn gif_array(value : Json, limit : Int32) -> Array[Json] raise RasterFailure {
  guard value is Array(values) && values.length() <= limit else {
    raise raster_fail(
      "raster/gif-data", "Export array exceeds its binding budget",
    )
  }
  values
}

///|
/// Check aggregate metadata before parsing SVG, paths, fonts or group values.
fn gif_protocol_arrays(
  data : Json,
  plan : Json,
  limits : RasterLimits,
) -> (Array[Json], Array[Json], Array[Json]) raise RasterFailure {
  let paths = gif_array(gif_field(data, "paths"), limits.max_svg_nodes)
  let nodes = gif_array(gif_field(data, "nodes"), limits.max_svg_nodes)
  let steps = gif_array(gif_field(plan, "steps"), limits.max_svg_nodes)
  let budget = GifProtocolBudget::{ limits, entries: 0, units: 0, }
  budget.count(paths.length())
  budget.count(nodes.length())
  budget.count(steps.length())
  // Charge group array lengths before examining any individual group value.
  for step in steps {
    budget.count(
      gif_array(gif_field(step, "groups"), limits.max_svg_nodes).length(),
    )
  }
  for path in paths {
    for name in ["key", "id", "path"] {
      budget.text(gif_string(gif_field(path, name)))
    }
    let mask = gif_field(path, "mask")
    if !(mask is Null) {
      budget.text(gif_string(mask))
    }
  }
  for node in nodes {
    budget.text(gif_string(gif_field(node, "key")))
    let kind = gif_array(gif_field(node, "kind"), 2)
    guard kind.length() == 2 else {
      raise raster_fail(
        "raster/gif-data", "Node binding needs a kind and identity",
      )
    }
    for value in kind {
      budget.text(gif_string(value))
    }
  }
  for step in steps {
    budget.text(gif_string(gif_field(step, "key")))
    for name in ["ordinal", "start_ms", "duration_ms"] {
      budget.value(gif_field(step, name))
    }
    for group in gif_array(gif_field(step, "groups"), limits.max_svg_nodes) {
      budget.value(group)
    }
  }
  (paths, nodes, steps)
}

///|
fn gif_kind(value : Json) -> @svg.NodeBindingKind raise RasterFailure {
  let pair = gif_array(value, 2)
  guard pair.length() == 2 else {
    raise raster_fail(
      "raster/gif-data", "Node binding needs a kind and identity",
    )
  }
  let id = gif_string(pair[1])
  match gif_string(pair[0]) {
    "bpmn" => Bpmn(id)
    "swimlane" => Swimlane(id)
    "flowchart" => Flowchart(id)
    "state" => State(id)
    "architecture" => Architecture(id)
    "term" => RailroadTerm(id)
    "row" => DataRow(id)
    "box" => DataBox(id)
    "message" => {
      let n = gif_number(pair[1])
      guard n <= 2147483647L else {
        raise raster_unsupported("Invalid message binding")
      }
      Message(n.to_int())
    }
    "frame" => {
      let n = gif_number(pair[1])
      guard n <= 2147483647L else {
        raise raster_unsupported("Invalid frame binding")
      }
      Frame(n.to_int())
    }
    _ => raise raster_fail("raster/gif-data", "Unknown generated node binding")
  }
}

///|
priv struct GifWirePath {
  id : String
  path : String
  mask : String?
  geometry : GifPath
}

///|
priv struct GifWireStep {
  key : String
  start : Int64
  duration : Int64
  reversed : Bool
  visit : Bool
}

///|
fn export_gif_data_explicit(
  data : Json,
  selected : Json?,
  options : GifOptions,
  font_source : () -> FontSet,
  limits : RasterLimits,
) -> RasterResult {
  try {
    validate_raster_limits(limits)
    guard gif_number(gif_field(data, "version")) == 1L else {
      raise raster_fail(
        "raster/gif-data", "Unsupported GIF export protocol version",
      )
    }
    let canonical = gif_string(gif_field(data, "canonical"))
    let display = gif_string(gif_field(data, "display"))
    guard canonical.length() <= limits.max_source_units &&
      display.length() <= limits.max_source_units else {
      raise raster_fail(
        "raster/source-limit", "GIF export source exceeds its budget",
      )
    }
    let source_id = gif_string(gif_field(data, "source_id"))
    guard source_id == gif_source_id(canonical, display) else {
      raise raster_fail(
        "raster/plan-mismatch", "GIF export source fingerprint differs",
      )
    }
    let plan = selected.unwrap_or_else(() => gif_field(data, "plan"))
    guard gif_string(gif_field(plan, "source_id")) == source_id else {
      raise raster_fail(
        "raster/plan-mismatch", "Selected GIF plan belongs to another scene",
      )
    }
    let mode = gif_string(gif_field(plan, "mode"))
    guard mode == "finite" || mode == "illustrative" else {
      raise raster_fail("raster/gif-data", "Unknown playback mode")
    }
    let duration = gif_number(gif_field(plan, "duration_ms"))
    guard duration > 0L else {
      raise raster_fail(
        "raster/gif-data", "GIF playback duration must be positive",
      )
    }
    if mode == "finite" &&
      options.interval is Interval(end_ms~, ..) &&
      end_ms > duration {
      raise raster_fail(
        "raster/gif-options", "GIF interval exceeds the finite plan",
      )
    }
    let (path_values, node_values, step_values) = gif_protocol_arrays(
      data, plan, limits,
    )
    let (width, height) = still_dimensions(canonical, options.size, limits)
    let times = gif_times(duration, options, limits) catch {
      GifInvalid(message) => raise raster_fail("raster/gif-options", message)
    }
    let pixel_count = width.to_int64() * height.to_int64()
    guard times.length().to_int64() <=
      limits.max_cumulative_pixels / pixel_count else {
      raise raster_fail(
        "raster/cumulative-pixel-limit", "GIF exceeds its cumulative pixel budget",
      )
    }
    let tree = parse_svg_xml(display, max_nodes=limits.max_svg_nodes)
    let visit_indices = gif_visit_indices(tree)
    let ids : Map[String, Int32] = Map([])
    for index, node in tree {
      if gif_attr(node, "id") is Some(id) {
        guard !ids.contains(id) else {
          raise raster_fail(
            "raster/gif-data", "Duplicate generated SVG identity",
          )
        }
        ids[id] = index
      }
    }
    let paths : Map[String, GifWirePath] = Map([])
    let mut segments = limits.max_svg_nodes
    for value in path_values {
      let key = gif_string(gif_field(value, "key"))
      let id = gif_string(gif_field(value, "id"))
      let path = gif_string(gif_field(value, "path"))
      let mask = match gif_field(value, "mask") {
        Null => None
        value => Some(gif_string(value))
      }
      guard !paths.contains(key) &&
        ids.get(id) is Some(index) &&
        tree[index].raw_name == "path" &&
        gif_attr(tree[index], "d") == Some(path) &&
        gif_attr(tree[index], "mask") == mask else {
        raise raster_fail(
          "raster/plan-mismatch", "GIF connection binding differs from its generated path",
        )
      }
      guard @svg.ConnectorPath::parse(path) is Some(parsed) else {
        raise raster_fail("raster/gif-data", "Malformed GIF bound path")
      }
      let geometry = gif_path(parsed, segments.min(8192)) catch {
        GifInvalid(message) => raise raster_fail("raster/gif-data", message)
      }
      segments -= geometry.segments.length()
      paths[key] = { id, path, mask, geometry, }
    }
    let nodes : Map[String, @svg.NodeBindingKind] = Map([])
    for value in node_values {
      let key = gif_string(gif_field(value, "key"))
      let kind = gif_kind(gif_field(value, "kind"))
      guard !nodes.contains(key) && visit_indices.contains(gif_kind_key(kind)) else {
        raise raster_fail(
          "raster/plan-mismatch", "GIF node binding is outside the generated scene",
        )
      }
      nodes[key] = kind
    }
    let steps : Array[GifWireStep] = []
    let ordinals : Map[Int64, Bool] = Map([])
    for value in step_values {
      let key = gif_string(gif_field(value, "key"))
      let ordinal = gif_number(gif_field(value, "ordinal"))
      guard ordinal <= limits.max_svg_nodes.to_int64() &&
        !ordinals.contains(ordinal) else {
        raise raster_fail(
          "raster/gif-data", "Duplicate or excessive occurrence ordinal",
        )
      }
      ordinals[ordinal] = true
      let start = gif_number(gif_field(value, "start_ms"))
      let step_duration = gif_number(gif_field(value, "duration_ms"))
      let reversed = gif_boolean(gif_field(value, "reversed"))
      let visit = gif_boolean(gif_field(value, "visit"))
      guard step_duration > 0L &&
        start <= duration &&
        step_duration <= duration - start &&
        (if visit {
          nodes.contains(key) && !reversed
        } else {
          paths.contains(key)
        }) else {
        raise raster_fail(
          "raster/gif-data", "GIF step timing or target is invalid",
        )
      }
      for group in gif_array(gif_field(value, "groups"), limits.max_svg_nodes) {
        guard gif_number(group) <= limits.max_svg_nodes.to_int64() else {
          raise raster_fail(
            "raster/gif-data", "GIF concurrent group exceeds its budget",
          )
        }
      }
      steps.push({ key, start, duration: step_duration, reversed, visit, })
    }
    guard !steps.is_empty() else {
      raise raster_fail(
        "raster/gif-data", "GIF playback needs at least one occurrence",
      )
    }
    let fonts = font_source()
    let delays = times.iter().map(time => time.1).to_array()
    let bytes = encode_gif_frames(
      width,
      height,
      delays,
      options.loop_behavior,
      limits,
      index => {
        let time = times[index].0
        let logical = if mode == "illustrative" {
          time % duration
        } else {
          time.min(duration)
        }
        let paints : Array[GifPaint] = []
        for step in steps {
          if logical < step.start || logical >= step.start + step.duration {
            continue
          }
          let numerator = logical - step.start
          let target = if step.visit {
            GifTarget::Visit(nodes[step.key])
          } else {
            let path = paths[step.key]
            let fraction = numerator.to_double() / step.duration.to_double()
            GifTarget::Connection(
              id=path.id,
              path=path.path,
              mask=path.mask,
              point=path.geometry.point(
                if step.reversed {
                  1.0 - fraction
                } else {
                  fraction
                },
              ),
            )
          }
          paints.push({
            target,
            numerator,
            denominator: step.duration,
            reversed: step.reversed,
          })
        }
        let source = gif_paint_svg(
          display,
          source_id,
          paints,
          limits,
          visit_indices~,
        )
        render_rgba(
          source,
          width,
          height,
          options.theme,
          fonts,
          options.background,
          limits,
        )
      },
    )
    {
      image: Some({
        bytes,
        media_type: "image/gif",
        width,
        height,
        format: Gif,
      }),
      diagnostics: [],
    }
  } catch {
    error => { image: None, diagnostics: [raster_diagnostic(error)], }
  }
}

///|
/// Decode the versioned scene/plan data emitted by gif_export_data. A selected
/// route must carry the same source_id and use its validated visible bindings.
pub fn export_gif_data(
  data : Json,
  plan? : Json,
  options~ : GifOptions = GifOptions::new(),
  fonts? : FontSet,
  limits~ : RasterLimits = RasterLimits::default(),
) -> RasterResult {
  export_gif_data_explicit(
    data,
    plan,
    options,
    () => fonts.unwrap_or_else(FontSet::default),
    limits,
  )
}
