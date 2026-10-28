///|
/// Generated SVG normalization for the portable dependency qualification.
pub(all) suberror SpikeError {
  Unsupported(String)
}

///|
pub(all) struct SpikeFonts {
  regular : @font.TTFont
  bold : @font.TTFont
  fallbacks : Array[@font.TTFont]
}

///|
fn xml_escape(s : String) -> String {
  s
  .replace(old="&", new="&amp;")
  .replace(old="\"", new="&quot;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
}

///|
fn node_attr(node : SvgXmlNode, name : String) -> String? {
  for a in node.attributes {
    if a.raw_name == name {
      return Some(a.value)
    }
  }
  None
}

///|
fn num(s : String) -> Double raise SpikeError {
  @string.parse_double(s) catch {
    _ => raise Unsupported("invalid generated numeric attribute: " + s)
  }
}

///|
/// Generated stylesheet rules only set namespaced palette variables. The
/// explicit data-theme block is authoritative, independent of ambient media.
fn palette(source : String, theme : String) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  let wanted = "[data-theme=\"" + theme + "\"]"
  for block in source.split("}") {
    let pieces = block.split("{").to_array()
    if pieces.length() < 2 {
      continue
    }
    let header = pieces[pieces.length() - 2].to_owned()
    if !header.contains(wanted) {
      continue
    }
    for decl in pieces[pieces.length() - 1].split(";") {
      let pair = decl.split(":").to_array()
      if pair.length() == 2 {
        let key = pair[0].trim().to_owned()
        if key.has_prefix("--") {
          result[key] = pair[1].trim().to_owned()
        }
      }
    }
  }
  result
}

///|
fn resolve(
  value : String,
  vars : Map[String, String],
) -> String raise SpikeError {
  let mut result = value
  for key, color in vars {
    result = result.replace(old="var(" + key + ")", new=color)
  }
  if result.contains("var(") {
    raise Unsupported("unresolved generated palette: " + value)
  }
  result
}

///|
fn text_paths(
  text : String,
  x : Double,
  y : Double,
  size : Double,
  anchor : String,
  font : @font.TTFont,
  fallbacks : Array[@font.TTFont],
) -> String raise SpikeError {
  let positions = font.layout_text(text, size)
  let shaped : Array[(@font.TTFont, Int32, Double)] = []
  let mut width = 0.0
  for p in positions {
    let mut selected = font
    if selected.glyph_index(p.codepoint) == 0 {
      for fallback in fallbacks {
        if fallback.glyph_index(p.codepoint) != 0 {
          selected = fallback
          break
        }
      }
    }
    let gid = selected.glyph_index(p.codepoint)
    if gid == 0 {
      raise Unsupported("missing required glyph U+" + p.codepoint.to_string())
    }
    let advance = selected.glyph_metrics(gid).advance_width.to_double() *
      size /
      selected.units_per_em.to_double()
    shaped.push((selected, p.codepoint, advance))
    width += advance
  }
  let shift = match anchor {
    "middle" => width / 2.0
    "end" => width
    _ => 0.0
  }
  let out = StringBuilder()
  let mut cursor = x - shift
  for (selected, cp, advance) in shaped {
    let d = @font.path_commands_to_svg_d(selected.scaled_outline(cp, size))
    if d != "" {
      out.write_string(
        "<path d=\"" +
        xml_escape(d) +
        "\" transform=\"translate(" +
        cursor.to_string() +
        " " +
        y.to_string() +
        ")\"/>",
      )
    }
    cursor += advance
  }
  out.to_string()
}

///|
pub fn normalize_generated_svg(
  source : String,
  theme : String,
  fonts : SpikeFonts,
) -> String raise SpikeError {
  guard theme == "light" || theme == "dark" else {
    raise Unsupported("explicit theme required")
  }
  guard source.length() <= 16_777_216 else {
    raise Unsupported("source budget")
  }
  let nodes = parse_svg_xml(source)
  let vars = palette(source, theme)
  let filters : Map[String, Int32] = Map([])
  for i, node in nodes {
    if node.raw_name == "filter" {
      if node_attr(node, "id") is Some(id) {
        filters[id] = i
      }
    }
  }
  let out = StringBuilder()
  fn walk(
    index : Int32,
    inherited_size : Double,
    inherited_anchor : String,
    inherited_weight : String,
  ) -> Unit raise SpikeError {
    let node = nodes[index]
    match node.kind {
      Document =>
        for child in node.children {
          walk(child, inherited_size, inherited_anchor, inherited_weight)
        }
      Text => out.write_string(xml_escape(node.value))
      Element => {
        let tag = node.raw_name
        if tag == "style" || tag == "title" || tag == "desc" || tag == "filter" {
          return
        }
        let allowed = [
          "svg", "defs", "g", "rect", "path", "circle", "ellipse", "line", "polyline",
          "polygon", "marker", "symbol", "use", "linearGradient", "radialGradient",
          "stop", "clipPath", "mask", "text", "tspan", "filter", "feFlood", "feBlend",
        ]
        guard allowed.contains(tag) else {
          raise Unsupported("generated element not qualified: " + tag)
        }
        let size = match node_attr(node, "font-size") {
          Some(s) => num(s)
          None => inherited_size
        }
        let anchor = node_attr(node, "text-anchor").unwrap_or(inherited_anchor)
        let weight = node_attr(node, "font-weight").unwrap_or(inherited_weight)
        let is_text = tag == "text" || tag == "tspan"
        let filtered = node_attr(node, "filter")
        if filtered is Some(reference) {
          let id = reference
            .replace(old="url(#", new="")
            .replace(old=")", new="")
          guard filters.get(id) is Some(fi) else {
            raise Unsupported("unknown generated filter")
          }
          let filter = nodes[fi]
          let content = filter.children.filter(i => nodes[i].kind == Element)
          guard content.length() == 2 &&
            nodes[content[0]].raw_name == "feFlood" &&
            nodes[content[1]].raw_name == "feBlend" else {
            raise Unsupported("unqualified generated filter")
          }
          let flood = nodes[content[0]]
          let blend = nodes[content[1]]
          guard node_attr(blend, "in") == Some("SourceGraphic") &&
            node_attr(blend, "in2") == node_attr(flood, "result") else {
            raise Unsupported("unqualified filter blend")
          }
          out.write_string("<g")
          if node_attr(node, "transform") is Some(transform) {
            out.write_string(" transform=\"" + xml_escape(transform) + "\"")
          }
          out.write_string("><rect")
          for name in ["x", "y", "width", "height"] {
            guard node_attr(filter, name) is Some(value) else {
              raise Unsupported("filter viewport required")
            }
            out.write_string(" " + name + "=\"" + xml_escape(value) + "\"")
          }
          out.write_string(
            " fill=\"" +
            xml_escape(node_attr(flood, "flood-color").unwrap_or("black")) +
            "\"/>",
          )
        }
        let output_tag = if is_text { "g" } else { tag }
        out.write_string("<" + output_tag)
        for attr in node.attributes {
          let name = attr.raw_name
          if name == "data-theme" ||
            name == "font-family" ||
            name == "font-size" ||
            name == "font-weight" ||
            name == "text-anchor" ||
            (is_text && (name == "x" || name == "y")) {
            continue
          }
          if name == "filter" || (filtered is Some(_) && name == "transform") {
            continue
          }
          let mut value = resolve(attr.value, vars)
          if name == "orient" &&
            value == "auto-start-reverse" &&
            !node_attr(node, "id").unwrap_or("").has_suffix("-start") {
            value = "auto"
          }
          if (name == "fill" || name == "stroke") && value.has_prefix("rgba(") {
            let channels = value
              .replace(old="rgba(", new="")
              .replace(old=")", new="")
              .split(",")
              .to_array()
            guard channels.length() == 4 else {
              raise Unsupported("malformed rgba")
            }
            value = "rgb(" +
              channels[0].trim().to_owned() +
              "," +
              channels[1].trim().to_owned() +
              "," +
              channels[2].trim().to_owned() +
              ")"
            out.write_string(
              " " + name + "-opacity=\"" + channels[3].trim().to_owned() + "\"",
            )
          }
          out.write_string(" " + name + "=\"" + xml_escape(value) + "\"")
        }
        if tag == "rect" {
          if node_attr(node, "rx") is Some(rx) && node_attr(node, "ry") is None {
            out.write_string(" ry=\"" + xml_escape(rx) + "\"")
          }
          if node_attr(node, "ry") is Some(ry) && node_attr(node, "rx") is None {
            out.write_string(" rx=\"" + xml_escape(ry) + "\"")
          }
        }
        if tag == "svg" {
          out.write_string(" data-theme=\"" + theme + "\"")
        }
        out.write_string(">")
        if is_text {
          let font = if weight == "600" || weight == "700" || weight == "bold" {
            fonts.bold
          } else {
            fonts.regular
          }
          let x = match node_attr(node, "x") {
            Some(s) => num(s)
            None => 0.0
          }
          let y = match node_attr(node, "y") {
            Some(s) => num(s)
            None => 0.0
          }
          for child in node.children {
            let c = nodes[child]
            if c.kind == Text {
              if c.value.trim() != "" {
                out.write_string(
                  text_paths(c.value, x, y, size, anchor, font, fonts.fallbacks),
                )
              }
            } else {
              walk(child, size, anchor, weight)
            }
          }
        } else {
          for child in node.children {
            walk(child, size, anchor, weight)
          }
        }
        out.write_string("</" + output_tag + ">")
        if filtered is Some(_) {
          out.write_string("</g>")
        }
      }
    }
  }
  walk(0, 12.0, "start", "400")
  out.to_string()
}

///|
impl Show for SpikeError with fn output(self, logger) {
  match self {
    Unsupported(message) => logger.write_string(message)
  }
}

///|
/// Source-over composition is required; the dependency's convenience image
/// helper deliberately uses a raw pixel replacement callback.
pub fn render_normalized(
  source : String,
  width : Int32,
  height : Int32,
) -> @raster_svg.Image raise SpikeError {
  let rendered = @qualified_svg.render_svg(
    source,
    width,
    height,
    @qualified_svg.RenderOptions::default(),
  )
  guard rendered.diagnostics.length() == 0 else {
    raise Unsupported("raster backend resource diagnostic")
  }
  let result = @raster_svg.Image::new(width, height)
  for y in 0..<height {
    for x in 0..<width {
      let c = rendered.image.get_pixel(x, y)
      result.set_pixel(x, y, { r: c.r, g: c.g, b: c.b, a: c.a, })
    }
  }
  result
}
