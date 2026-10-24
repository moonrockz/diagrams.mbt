///|
fn escaped(s : String) -> String {
  let b = StringBuilder()
  for c in s {
    match c {
      '&' => b.write_string("&amp;"); '<' => b.write_string("&lt;")
      '>' => b.write_string("&gt;"); '"' => b.write_string("&quot;")
      '\r' => b.write_string("&#xd;"); '\n' => b.write_string("&#xa;"); '\t' => b.write_string("&#x9;")
      _ => b.write_char(c)
    }
  }
  b.to_string()
}

///|
/// First-slice deterministic compact writing. Source reproduction uses Cst::text.
/// The complete validating canonical/pretty writer is added in group 3.
pub fn write(document : Document) -> String {
  let b = StringBuilder()
  let stack = [(document.root, false, true)]
  while !stack.is_empty() {
    let (node, leave, root) = stack.pop().unwrap()
    let name = node.kind.qualified_name()
    if leave { b.write_string("</\{name}>"); continue }
    b.write_string("<\{name}")
    if root {
      b.write_string(" xmlns:bpmn=\"http://www.omg.org/spec/BPMN/20100524/MODEL\" xmlns:bpmndi=\"http://www.omg.org/spec/BPMN/20100524/DI\" xmlns:dc=\"http://www.omg.org/spec/DD/20100524/DC\" xmlns:di=\"http://www.omg.org/spec/DD/20100524/DI\"")
    }
    for (key, value) in node.attributes { b.write_string(" \{key}=\"\{escaped(value)}\"") }
    if node.children.is_empty() && node.content.is_empty() { b.write_string("/>"); continue }
    b.write_string(">\{escaped(node.content)}")
    stack.push((node, true, false))
    for i = node.children.length()-1; i >= 0; i = i-1 { stack.push((node.children[i], false, false)) }
  }
  b.to_string()
}
