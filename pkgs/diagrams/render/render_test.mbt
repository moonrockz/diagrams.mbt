///|
/// A renderer that supports no diagram kind.
struct Nothing {}

///|
impl @render.Renderer for Nothing with fn render(_, diagram) {
  @render.Rendered::unsupported("text/plain", diagram)
}

///|
/// A renderer that writes the number of participants.
struct Count {}

///|
impl @render.Renderer for Count with fn render(_, diagram) {
  match diagram {
    Bpmn(_) | Swimlane(_) | Regex(_) | Ebnf(_) | DataTree(_) =>
      @render.Rendered::unsupported("text/plain", diagram)
    Sequence(s) =>
      @render.Rendered::ok(s.participants.length().to_string(), "text/plain")
  }
}

///|
test "a renderer gives its output and media type" {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [],
  )
  let r = @render.Renderer::render(Count::{ }, @render.Diagram::Sequence(s))
  assert_eq(r.output, Some("2"))
  assert_eq(r.media_type, "text/plain")
  assert_eq(r.diagnostics.length(), 0)
}

///|
test "a renderer that does not support a diagram kind gives an error and no output" {
  let s = @sequence.Sequence::new([], [])
  let r = @render.Renderer::render(Nothing::{ }, @render.Diagram::Sequence(s))
  assert_eq(r.output, None)
  assert_eq(r.diagnostics.length(), 1)
  assert_eq(r.diagnostics[0].code, "render/unsupported-diagram")
  assert_eq(r.diagnostics[0].severity, @diagrams.Severity::Error)
}

///|
test "a failed result has no output and keeps its diagnostics" {
  let d = @diagrams.Diagnostic::error("x/y", "broken")
  let r = @render.Rendered::failed("image/svg+xml", [d])
  assert_eq(r.output, None)
  assert_eq(r.media_type, "image/svg+xml")
  assert_eq(r.diagnostics.iter().to_array(), [d])
}
