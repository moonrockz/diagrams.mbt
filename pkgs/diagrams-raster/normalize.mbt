///|
/// Generated SVG normalization; qualification lives in tests/raster-spike.
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
fn num(s : String) -> Double raise RasterFailure {
  let value = @string.parse_double(s) catch {
    _ => raise raster_unsupported("invalid generated numeric attribute: " + s)
  }
  guard raster_finite(value) else {
    raise raster_unsupported("generated numeric attributes must be finite")
  }
  value
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
) -> String raise RasterFailure {
  let mut result = value
  for key, color in vars {
    result = result.replace(old="var(" + key + ")", new=color)
  }
  if result.contains("var(") {
    raise raster_unsupported("unresolved generated palette: " + value)
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
  face : ParsedFontFace,
  fonts : ParsedFontSet,
  source_id : String,
  limits : RasterLimits,
) -> String raise RasterFailure {
  let shaped : Array[(ParsedFontFace, Int32, Double, Double)] = []
  let mut width = 0.0
  let mut previous : ParsedFontFace? = None
  let mut previous_gid = 0
  for scalar in text.iter() {
    let cp = scalar.to_int()
    guard !((cp >= 0x300 && cp <= 0x36f) ||
      (cp >= 0x590 && cp <= 0x8ff) ||
      (cp >= 0x900 && cp <= 0xdff)) else {
      raise raster_fail(
        "raster/font-shaping",
        "This text needs shaping outside the explicit static glyph profile",
        source_id~,
      )
    }
    let selected = glyph_face(fonts, face, cp, source_id)
    let gid = selected.font.glyph_index(cp)
    let advance = selected.font.glyph_metrics(gid).advance_width.to_double() *
      size /
      selected.font.units_per_em.to_double()
    let kern = match previous {
      Some(before) =>
        if before.face.data == selected.face.data {
          selected.font.kern_pair(previous_gid, gid).to_double() *
          size /
          selected.font.units_per_em.to_double()
        } else {
          0.0
        }
      None => 0.0
    }
    shaped.push((selected, cp, advance, kern))
    width += advance + kern
    previous = Some(selected)
    previous_gid = gid
  }
  let shift = match anchor {
    "middle" => width / 2.0
    "end" => width
    "start" => 0.0
    _ =>
      raise raster_fail(
        "raster/text-anchor",
        "Unsupported text anchor",
        source_id~,
      )
  }
  let output = SvgWriter::new(limits.max_source_units)
  let mut cursor = x - shift
  let mut units = 0
  for (selected, cp, advance, kern) in shaped {
    cursor += kern
    let d = @font.path_commands_to_svg_d(selected.font.scaled_outline(cp, size))
    if d != "" {
      let part = "<path d=\"" +
        xml_escape(d) +
        "\" transform=\"translate(" +
        cursor.to_string() +
        " " +
        y.to_string() +
        ")\"/>"
      guard part.length() <= limits.max_source_units - units else {
        raise raster_fail(
          "raster/normalized-limit",
          "Outlined text exceeds the derived SVG budget",
          source_id~,
        )
      }
      units += part.length()
      output.write_string(part)
    }
    cursor += advance
  }
  output.to_string()
}

///|
fn normalize_generated_svg(
  source : String,
  theme : String,
  fonts : ParsedFontSet,
  limits : RasterLimits,
) -> String raise RasterFailure {
  guard theme == "light" || theme == "dark" else {
    raise raster_unsupported("explicit theme required")
  }
  guard source.length() <= 16_777_216 else {
    raise raster_unsupported("source budget")
  }
  let nodes = parse_svg_xml(source, max_nodes=limits.max_svg_nodes)
  // Reject the aggregate before any font lookup, layout or outline allocation.
  validate_text_glyph_budget(nodes, limits)
  let roots = nodes[0].children.filter(i => nodes[i].kind == Element)
  let backgrounds = nodes[roots[0]].children.filter(i => {
    is_export_background(nodes[i], nodes[roots[0]])
  })
  let sheets = StringBuilder()
  for node in nodes {
    if node.raw_name == "style" {
      for child in node.children {
        let css = nodes[child].value
        for block in css.split("}") {
          let pieces = block.split("{").to_array()
          if pieces.length() < 2 {
            continue
          }
          for decl in pieces[pieces.length() - 1].split(";") {
            let pair = decl.split(":").to_array()
            if pair.length() == 2 && !pair[0].trim().has_prefix("--") {
              raise raster_fail(
                "raster/css-profile", "Only generated palette variables are supported in stylesheet normalization",
              )
            }
          }
        }
        sheets.write_string(css)
      }
    }
  }
  let vars = palette(sheets.to_string(), theme)
  let filters : Map[String, Int32] = Map([])
  for i, node in nodes {
    if node.raw_name == "filter" {
      if node_attr(node, "id") is Some(id) {
        filters[id] = i
      }
    }
  }
  let out = SvgWriter::new(limits.max_source_units)
  let mut emitted_units = 0
  fn walk(
    index : Int32,
    inherited_size : Double,
    inherited_anchor : String,
    inherited_weight : String,
    inherited_family : String,
    inherited_style : String,
  ) -> Unit raise RasterFailure {
    let node = nodes[index]
    match node.kind {
      Document =>
        for child in node.children {
          walk(
            child, inherited_size, inherited_anchor, inherited_weight, inherited_family,
            inherited_style,
          )
        }
      Text => out.write_string(xml_escape(node.value))
      Element => {
        let tag = node.raw_name
        if backgrounds.contains(index) {
          return
        }
        if tag == "style" || tag == "title" || tag == "desc" || tag == "filter" {
          return
        }
        let allowed = [
          "svg", "defs", "g", "rect", "path", "circle", "ellipse", "line", "polyline",
          "polygon", "marker", "symbol", "use", "linearGradient", "radialGradient",
          "stop", "clipPath", "mask", "text", "tspan", "filter", "feFlood", "feBlend",
        ]
        guard allowed.contains(tag) else {
          raise raster_unsupported("generated element not qualified: " + tag)
        }
        let size = match node_attr(node, "font-size") {
          Some(s) => num(s)
          None => inherited_size
        }
        let anchor = node_attr(node, "text-anchor").unwrap_or(inherited_anchor)
        let weight = node_attr(node, "font-weight").unwrap_or(inherited_weight)
        let family = node_attr(node, "font-family").unwrap_or(inherited_family)
        let style = node_attr(node, "font-style").unwrap_or(inherited_style)
        let source_id = node_attr(node, "id").unwrap_or(
          "svg-node-" + index.to_string(),
        )
        let is_text = tag == "text" || tag == "tspan"
        let filtered = node_attr(node, "filter")
        if filtered is Some(reference) {
          let id = reference
            .replace(old="url(#", new="")
            .replace(old=")", new="")
          guard filters.get(id) is Some(fi) else {
            raise raster_unsupported("unknown generated filter")
          }
          let filter = nodes[fi]
          let content = filter.children.filter(i => nodes[i].kind == Element)
          guard content.length() == 2 &&
            nodes[content[0]].raw_name == "feFlood" &&
            nodes[content[1]].raw_name == "feBlend" else {
            raise raster_unsupported("unqualified generated filter")
          }
          let flood = nodes[content[0]]
          let blend = nodes[content[1]]
          guard node_attr(blend, "in") == Some("SourceGraphic") &&
            node_attr(blend, "in2") == node_attr(flood, "result") else {
            raise raster_unsupported("unqualified filter blend")
          }
          out.write_string("<g")
          if node_attr(node, "transform") is Some(transform) {
            out.write_string(" transform=\"" + xml_escape(transform) + "\"")
          }
          out.write_string("><rect")
          for name in ["x", "y", "width", "height"] {
            guard node_attr(filter, name) is Some(value) else {
              raise raster_unsupported("filter viewport required")
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
          if name == "style" || name.has_prefix("on") {
            raise raster_fail(
              "raster/attribute-profile",
              "Inline styles and event handlers are outside generated SVG",
              source_id~,
            )
          }
          if name == "data-theme" ||
            name == "font-family" ||
            name == "font-size" ||
            name == "font-weight" ||
            name == "font-style" ||
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
              raise raster_unsupported("malformed rgba")
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
          let font = font_for_text(fonts, family, weight, style, source_id)
          if tag == "tspan" {
            guard node_attr(node, "x") is Some(_) &&
              node_attr(node, "y") is Some(_) else {
              raise raster_fail(
                "raster/text-profile",
                "Generated tspan requires explicit baseline coordinates",
                source_id~,
              )
            }
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
                let outlined = text_paths(
                  c.value,
                  x,
                  y,
                  size,
                  anchor,
                  font,
                  fonts,
                  source_id,
                  limits,
                )
                guard outlined.length() <= limits.max_source_units - emitted_units else {
                  raise raster_fail(
                    "raster/glyph-limit",
                    "Outlined SVG exceeds the glyph/source budget",
                    source_id~,
                  )
                }
                emitted_units += outlined.length()
                out.write_string(outlined)
              }
            } else {
              walk(child, size, anchor, weight, family, style)
            }
          }
        } else {
          for child in node.children {
            walk(child, size, anchor, weight, family, style)
          }
        }
        out.write_string("</" + output_tag + ">")
        if filtered is Some(_) {
          out.write_string("</g>")
        }
      }
    }
  }
  walk(0, 12.0, "start", "400", "monospace", "normal")
  out.to_string()
}

///|
/// Every normalization write checks the remaining UTF-16 budget before it
/// appends. This includes outlined labels and resource definitions.
priv struct SvgWriter {
  builder : StringBuilder
  mut units : Int32
  limit : Int32
}

///|
fn SvgWriter::new(limit : Int32) -> SvgWriter {
  { builder: StringBuilder(), units: 0, limit, }
}

///|
fn SvgWriter::write_string(
  self : SvgWriter,
  value : String,
) -> Unit raise RasterFailure {
  guard value.length() <= self.limit - self.units else {
    raise raster_fail(
      "raster/normalized-limit", "Derived SVG exceeds the source budget",
    )
  }
  self.units += value.length()
  self.builder.write_string(value)
}

///|
fn SvgWriter::to_string(self : SvgWriter) -> String {
  self.builder.to_string()
}

///|
/// Only the emitted complete canvas background participates in an explicit
/// export background override. A partial or nested rectangle remains content.
fn is_export_background(
  node : SvgXmlNode,
  root : SvgXmlNode,
) -> Bool raise RasterFailure {
  if node.raw_name != "rect" || node_attr(node, "class") != Some("bg") {
    return false
  }
  let mut width = node_attr(root, "width").unwrap_or("0")
  let mut height = node_attr(root, "height").unwrap_or("0")
  if node_attr(root, "viewBox") is Some(box) {
    let parts = box
      .replace(old=",", new=" ")
      .split(" ")
      .filter(part => part.trim() != "")
      .to_array()
    guard parts.length() == 4 else {
      raise raster_fail("raster/malformed-svg", "Invalid generated viewBox")
    }
    if num(parts[0].to_owned()) != 0.0 || num(parts[1].to_owned()) != 0.0 {
      return false
    }
    width = parts[2].to_owned()
    height = parts[3].to_owned()
  }
  num(node_attr(node, "x").unwrap_or("0")) == 0.0 &&
  num(node_attr(node, "y").unwrap_or("0")) == 0.0 &&
  num(node_attr(node, "width").unwrap_or("0")) == num(width) &&
  num(node_attr(node, "height").unwrap_or("0")) == num(height)
}

///|
fn validate_text_glyph_budget(
  nodes : Array[SvgXmlNode],
  limits : RasterLimits,
) -> Unit raise RasterFailure {
  let mut remaining = limits.max_glyphs
  for node in nodes {
    if node.raw_name == "text" || node.raw_name == "tspan" {
      for child in node.children {
        let content = nodes[child]
        if content.kind == Text && content.value.trim() != "" {
          for _ in content.value.iter() {
            guard remaining > 0 else {
              raise raster_fail(
                "raster/glyph-limit",
                "Text exceeds the aggregate glyph budget",
                source_id=node_attr(node, "id").unwrap_or("text"),
              )
            }
            remaining -= 1
          }
        }
      }
    }
  }
}
