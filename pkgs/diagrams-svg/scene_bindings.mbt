///|
/// Decode only the entities emitted by our XML writer, with ampersand last so
/// escaped source text cannot be decoded twice.
fn scene_attribute_text(value : String) -> String {
  value
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&#x9;", new="\t")
  .replace_all(old="&#xa;", new="\n")
  .replace_all(old="&#xd;", new="\r")
  .replace_all(old="&amp;", new="&")
}

///|
fn scene_attribute(tag : String, name : String) -> String? {
  let prefix = " " + name + "=\""
  guard tag.find(prefix) is Some(start) else { return None }
  let tail = tag[start + prefix.length():]
  guard tail.find("\"") is Some(end) else { return None }
  Some(scene_attribute_text(tail[:end].to_owned()))
}

///|
/// Read final path bindings from this module's generated, line-oriented writer
/// output. This is not an XML parser for external SVG. Source text is escaped
/// before this step; only path tags marked by the connector finalizer qualify.
/// The caller already bounds the complete canonical artifact by output_units.
fn final_connector_bindings(
  canonical : String,
) -> Array[(String, String, String?)] {
  let result = []
  for line in canonical.split("\n") {
    let tag = line.trim_start().to_owned()
    if !tag.has_prefix("<path ") {
      continue
    }
    if scene_attribute(tag, "data-connector-route") is Some(route) &&
      scene_attribute(tag, "d") is Some(path) {
      result.push((route, path, scene_attribute(tag, "mask")))
    }
  }
  result
}

///|
test "final binding scanner reads only generated paths and decodes once" {
  let source = @writer.to_string(
    @writer.element("svg", children=[
      @writer.element("text", children=[
        @writer.text("<path data-connector-route=\"fake\" d=\"fake\"/>"),
      ]),
      @writer.element("path", attrs=[("d", "unmarked")]),
      @writer.element("path", attrs=[
        ("data-connector-route", "M0 0 L10 10"),
        ("d", "M0 0 Q5 3 10 10"),
        ("mask", "url(#prefix-&lt;mask)"),
      ]),
    ]),
  )
  assert_eq(final_connector_bindings(source), [
    ("M0 0 L10 10", "M0 0 Q5 3 10 10", Some("url(#prefix-&lt;mask)")),
  ])
}
