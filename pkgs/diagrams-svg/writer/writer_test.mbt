///|
test "an element with attributes and text" {
  let n = @writer.element("text", attrs=[("x", "4"), ("class", "label")], children=[
    @writer.text("hi"),
  ])
  assert_eq(@writer.to_string(n), "<text x=\"4\" class=\"label\">hi</text>\n")
}

///|
test "an element without children closes itself" {
  assert_eq(
    @writer.to_string(@writer.element("rect", attrs=[("width", "10")])),
    "<rect width=\"10\"/>\n",
  )
}

///|
test "child elements are indented, one on each line" {
  let n = @writer.element("g", children=[
    @writer.element("rect"),
    @writer.element("g", children=[@writer.element("path")]),
  ])
  assert_eq(@writer.to_string(n), "<g>\n  <rect/>\n  <g>\n    <path/>\n  </g>\n</g>\n")
}

///|
test "attribute values and text are escaped" {
  let n = @writer.element("t", attrs=[("a", "<&\">")], children=[
    @writer.text("a < b & c > d \"q\""),
  ])
  assert_eq(
    @writer.to_string(n),
    "<t a=\"&lt;&amp;&quot;&gt;\">a &lt; b &amp; c &gt; d \"q\"</t>\n",
  )
}

///|
test "control characters that XML does not allow are removed" {
  let n = @writer.element("t", children=[@writer.text("a\u{0001}b\u{001f}c\td")])
  assert_eq(@writer.to_string(n), "<t>abc\td</t>\n")
}
