///|
/// A syntax-only tree adapter for the generated SVG profile. DOCTYPE is
/// rejected before parsing, so entity expansion cannot exceed caller budgets.
priv enum SvgXmlKind {
  Document
  Element
  Text
} derive(Eq)

///|
priv struct SvgXmlAttribute {
  raw_name : String
  value : String
}

///|
priv struct SvgXmlNode {
  kind : SvgXmlKind
  raw_name : String
  attributes : Array[SvgXmlAttribute]
  children : Array[Int32]
  value : String
}

///|
fn parse_svg_xml(
  source : String,
  max_nodes~ : Int32 = 200_000,
) -> Array[SvgXmlNode] raise RasterFailure {
  guard source.length() <= 16_777_216 && max_nodes > 0 else {
    raise raster_unsupported("XML source/node budget")
  }
  guard !source.contains("<!DOCTYPE") else {
    raise raster_unsupported("DOCTYPE is outside generated SVG")
  }
  let reader = @xml.Reader::from_string(source)
  let nodes : Array[SvgXmlNode] = [
    { kind: Document, raw_name: "", attributes: [], children: [], value: "", },
  ]
  let stack : Array[Int32] = [0]
  let mut units = 1
  while true {
    let event = reader.read_event() catch {
      e => raise raster_unsupported("malformed XML: " + e.to_string())
    }
    if event.kind is Eof {
      break
    }
    let node : SvgXmlNode = match event.kind {
      Start(e) | Empty(e) => {
        units += e.attributes.length()
        {
          kind: Element,
          raw_name: e.name,
          attributes: e.attributes.map(a => {
            raw_name: a.name,
            value: a.value,
          }),
          children: [],
          value: "",
        }
      }
      Text(value) | CData(value) =>
        { kind: Text, raw_name: "", attributes: [], children: [], value, }
      End(_) => {
        let _ = stack.pop()
        continue
      }
      Comment(_) | PI(..) | Decl(..) => continue
      _ => raise raster_unsupported("XML declaration outside generated SVG")
    }
    units += 1
    guard units <= max_nodes && stack.length() <= 256 else {
      raise raster_unsupported("XML node/depth budget")
    }
    let index = nodes.length()
    nodes[stack[stack.length() - 1]].children.push(index)
    nodes.push(node)
    if event.kind is Start(_) {
      stack.push(index)
    }
  }
  guard stack.length() == 1 else { raise raster_unsupported("unclosed SVG") }
  let roots = nodes[0].children.filter(i => nodes[i].kind == Element)
  guard roots.length() == 1 && nodes[roots[0]].raw_name == "svg" else {
    raise raster_unsupported("expected one SVG root")
  }
  nodes
}

///|
fn svg_xml_escape(s : String) -> String {
  s
  .replace(old="&", new="&amp;")
  .replace(old="\"", new="&quot;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
}

///|
fn svg_xml_write(
  nodes : Array[SvgXmlNode],
  index : Int32,
  output : StringBuilder,
  additions : Map[String, String],
  matched : Map[String, Bool],
) -> Unit {
  let node = nodes[index]
  if node.kind == Text {
    output.write_string(svg_xml_escape(node.value))
    return
  }
  if node.kind == Element {
    output.write_string("<" + node.raw_name)
    for attr in node.attributes {
      output.write_string(
        " " + attr.raw_name + "=\"" + svg_xml_escape(attr.value) + "\"",
      )
    }
    output.write_string(">")
  }
  for child in node.children {
    svg_xml_write(nodes, child, output, additions, matched)
  }
  if node.kind == Element {
    output.write_string("</" + node.raw_name + ">")
    for attr in node.attributes {
      if attr.raw_name == "id" {
        if additions.get(attr.value) is Some(markup) {
          output.write_string(markup)
          matched[attr.value] = true
        }
      }
    }
  }
}
