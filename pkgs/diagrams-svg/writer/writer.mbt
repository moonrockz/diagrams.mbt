///|
/// A node of an XML document.
pub(all) enum Node {
  Element(String, ReadOnlyArray[(String, String)], ReadOnlyArray[Node])
  Text(String)
} derive(Eq, Debug)

///|
pub extend Node with Eq::{not_equal, equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
/// An element with the name `name`, its attributes in order and its children.
pub fn element(
  name : String,
  attrs? : ArrayView[(String, String)] = [],
  children? : ArrayView[Node] = [],
) -> Node {
  Element(
    name,
    ReadOnlyArray::from_array(attrs),
    ReadOnlyArray::from_array(children),
  )
}

///|
/// A text node.
pub fn text(content : String) -> Node {
  Text(content)
}

///|
/// True for a code point that XML 1.0 does not allow in a document.
fn forbidden(c : Char) -> Bool {
  let n = c.to_int()
  (n < 0x20 && n != 0x09 && n != 0x0a && n != 0x0d) ||
  (n >= 0xd800 && n <= 0xdfff) || n == 0xfffe || n == 0xffff
}

///|
fn write_escaped(buf : StringBuilder, s : String, attribute : Bool) -> Unit {
  for c in s {
    match c {
      '<' => buf.write_string("&lt;")
      '>' => buf.write_string("&gt;")
      '&' => buf.write_string("&amp;")
      '\t' if attribute => buf.write_string("&#x9;")
      '\n' if attribute => buf.write_string("&#xa;")
      '\r' => buf.write_string("&#xd;")
      '"' if attribute => buf.write_string("&quot;")
      _ => if !forbidden(c) { buf.write_char(c) }
    }
  }
}

///|
fn write_node(buf : StringBuilder, node : Node, depth : Int) -> Unit {
  match node {
    Text(s) => write_escaped(buf, s, false)
    Element(name, attrs, children) => {
      for _ in 0..<depth {
        buf.write_string("  ")
      }
      buf.write_string("<\{name}")
      for a in attrs {
        buf.write_string(" \{a.0}=\"")
        write_escaped(buf, a.1, true)
        buf.write_string("\"")
      }
      if children.length() == 0 {
        buf.write_string("/>\n")
        return
      }
      buf.write_string(">")
      let inline = children.iter().all(c => c is Text(_))
      if inline {
        for c in children {
          write_node(buf, c, 0)
        }
      } else {
        buf.write_string("\n")
        for c in children {
          match c {
            Text(_) => {
              for _ in 0..<(depth + 1) {
                buf.write_string("  ")
              }
              write_node(buf, c, 0)
              buf.write_string("\n")
            }
            Element(_, _, _) => write_node(buf, c, depth + 1)
          }
        }
        for _ in 0..<depth {
          buf.write_string("  ")
        }
      }
      buf.write_string("</\{name}>\n")
    }
  }
}

///|
/// The XML text of `node`. An element with only text children is on one line.
/// Child elements are on their own lines with two spaces of indentation for
/// each level. The text ends with a line break.
pub fn to_string(node : Node) -> String {
  let buf = StringBuilder()
  write_node(buf, node, 0)
  buf.to_string()
}
