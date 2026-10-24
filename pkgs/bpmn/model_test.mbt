///|
test "constructor arrays are owned and walks keep containment order" {
  let attrs = [("id", "T")]
  let task = @bpmn.Element::new(Task, attributes=attrs)
  attrs[0] = ("id", "changed")
  let children = [task]
  let root = @bpmn.Element::new(Definitions, children~)
  children.clear()
  assert_eq(root.children.length(), 1)
  assert_eq(root.children[0].attribute("id"), Some("T"))
}

///|
test "malformed and unsupported sources reproduce without a complete document" {
  for source in ["<definitions>", "<!DOCTYPE d SYSTEM 'file:///secret'><definitions/>", "<x:definitions/>", "<definitions xmlns='http://www.omg.org/spec/BPMN/20100524/MODEL'><task></process></definitions>"] {
    let result = @bpmn.read(source)
    assert_eq(result.tree.text(), source)
    assert_eq(result.document, None)
    assert_true(result.diagnostics.length() > 0)
  }
}
