///|
/// A syntax-only tree adapter for the generated SVG profile. DOCTYPE is
/// rejected before parsing, so entity expansion cannot exceed caller budgets.
pub(all) enum SvgXmlKind {
  Document
  Element
  Text
} derive(Eq)

///|
pub extend SvgXmlKind with Eq::{equal, not_equal}

///|
pub(all) struct SvgXmlAttribute {
  raw_name : String
  value : String
}

///|
pub(all) struct SvgXmlNode {
  kind : SvgXmlKind
  raw_name : String
  attributes : Array[SvgXmlAttribute]
  children : Array[Int32]
  value : String
}

///|
pub fn parse_svg_xml(
  source : String,
  max_nodes~ : Int32 = 200_000,
) -> Array[SvgXmlNode] raise SpikeError {
  guard source.length() <= 16_777_216 && max_nodes > 0 else {
    raise Unsupported("XML source/node budget")
  }
  guard !source.contains("<!DOCTYPE") else {
    raise Unsupported("DOCTYPE is outside generated SVG")
  }
  let reader = @xml.Reader::from_string(source)
  let nodes : Array[SvgXmlNode] = [
    { kind: Document, raw_name: "", attributes: [], children: [], value: "", },
  ]
  let stack : Array[Int32] = [0]
  let mut units = 1
  while true {
    let event = reader.read_event() catch {
      e => raise Unsupported("malformed XML: " + e.to_string())
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
      _ => raise Unsupported("XML declaration outside generated SVG")
    }
    units += 1
    guard units <= max_nodes && stack.length() <= 256 else {
      raise Unsupported("XML node/depth budget")
    }
    let index = nodes.length()
    nodes[stack[stack.length() - 1]].children.push(index)
    nodes.push(node)
    if event.kind is Start(_) {
      stack.push(index)
    }
  }
  guard stack.length() == 1 else { raise Unsupported("unclosed SVG") }
  let roots = nodes[0].children.filter(i => nodes[i].kind == Element)
  guard roots.length() == 1 && nodes[roots[0]].raw_name == "svg" else {
    raise Unsupported("expected one SVG root")
  }
  nodes
}
