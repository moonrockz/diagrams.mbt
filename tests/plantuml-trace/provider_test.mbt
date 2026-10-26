///|
/// The regex model `ab|cd` and grammar models used by the stubs.
fn regex_model() -> @regex.Regex {
  let read = @plantuml.read("@startregex\nab|cd\n@endregex\n")
  match @plantuml.to_diagram(read.document.unwrap()).diagram {
    Some(Regex(model)) => model
    _ => abort("regex")
  }
}

///|
fn grammar_model(source : String) -> @ebnf.Grammar {
  let read = @plantuml.read("@startebnf\n" + source + "\n@endebnf\n")
  match @plantuml.to_diagram(read.document.unwrap()).diagram {
    Some(Ebnf(grammar)) => grammar
    _ => abort("ebnf")
  }
}

///|
/// A test-only helper: the drawn steps from one point to another, found by a
/// breadth-first search over terms and connectors. Providers in real use map
/// engine events; this helper only builds fixtures.
fn steps_between(
  topology : @trace.Topology,
  from : String,
  to : String,
  spans? : Map[String, @trace.InputSpan] = Map([]),
) -> Array[@trace.Step] {
  let previous : Map[String, (String, @trace.Step)] = Map([])
  let queue = [from]
  let seen = Map([(from, true)])
  let mut cursor = 0
  while cursor < queue.length() {
    let point = queue[cursor]
    cursor += 1
    if point == to {
      break
    }
    let next : Array[(String, @trace.Step)] = []
    for c in topology.connectors_from(point) {
      if !c.constraint {
        next.push((c.to, Traverse(c.id, false)))
      }
    }
    for t in topology.terms {
      if t.entry == point && !t.constraint {
        next.push((t.exit, Visit(t.id, spans.get(t.id))))
      }
    }
    for pair in next {
      if !seen.contains(pair.0) {
        seen[pair.0] = true
        previous[pair.0] = (point, pair.1)
        queue.push(pair.0)
      }
    }
  }
  let out = []
  let mut at = to
  while at != from {
    guard previous.get(at) is Some((back, step)) else { abort("no path") }
    out.push(step)
    at = back
  }
  out.rev()
}

///|
fn topology_of(request : @trace.TraceRequest) -> @trace.Topology {
  request.topology().topology.unwrap()
}

///|
/// A regex-only stub. It knows the scripted inputs "ab" and "cx" for the
/// pattern `ab|cd` and supports no grammar.
struct RegexStub {
  calls : Ref[Int]
}

///|
impl @trace.RailroadTraceProvider for RegexStub with trace(self, request) {
  self.calls.val += 1
  guard request.subject is Regex(model) else {
    return Unsupported("this stub has no grammar support")
  }
  let t = topology_of(request)
  let start = t.tracks[0].start
  let end = t.tracks[0].end
  let first = t.term("p.0").unwrap()
  let second = t.term("p.1").unwrap()
  match request.input {
    "ab" =>
      Matched(
        @trace.Trace::new(request, "regex-stub", [
          @trace.Attempt::new(
            "a0",
            Matched,
            steps_between(t, start, end, spans=Map([("p.0", @trace.InputSpan::new(0, 2))])),
          ),
        ]),
      )
    "cx" => {
      // The first alternative fails at its terminal. The second consumes
      // "c" and then fails inside its terminal.
      let first_prefix = steps_between(t, start, first.entry)
      let second_prefix = steps_between(t, start, second.entry)
      NotMatched(
        @trace.Trace::new(request, "regex-stub", [
          @trace.Attempt::new(
            "a0",
            NotMatched,
            first_prefix,
            failure=@trace.FailurePoint::new(Terminal("p.0"), position=0, message="expected ab"),
          ),
          @trace.Attempt::new(
            "a1",
            NotMatched,
            second_prefix,
            failure=@trace.FailurePoint::new(Terminal("p.1"), position=1, message="expected d"),
          ),
        ]),
      )
    }
    "budget" => Exhausted("step budget of \{request.limits.steps}")
    "boom" => ProviderError("the engine stopped")
    _ => {
      ignore(model)
      NotMatched(@trace.Trace::new(request, "regex-stub", []))
    }
  }
}

///|
test "a regex-only provider renders success and failure evidence" {
  let stub = RegexStub::{ calls: Ref(0) }
  let diagram : @render.Diagram = Regex(regex_model())
  let renderer = @svg.SvgRenderer::new(mode=Fixed(Light), id_prefix="t")
  let ok = renderer.render_traced(diagram, stub, "ab")
  assert_true(ok.run.result is Some(Matched(_)))
  let svg = ok.rendered.output.unwrap()
  assert_true(svg.contains("rr-trace-matched"))
  assert_false(svg.contains("rr-trace-not-matched"))
  let failed = renderer.render_traced(diagram, stub, "cx")
  assert_true(failed.run.result is Some(NotMatched(_)))
  let svg = failed.rendered.output.unwrap()
  assert_true(svg.contains("rr-trace-not-matched"))
  assert_true(svg.contains("rr-trace-failure"))
  assert_true(svg.contains("expected d"))
  assert_eq(stub.calls.val, 2)
}

///|
test "a regex-only provider reports unsupported grammar requests" {
  let stub = RegexStub::{ calls: Ref(0) }
  let grammar = grammar_model("r = \"x\";")
  let rule = grammar.rules()[0].id
  let result = @svg.SvgRenderer::new().render_traced(
    Ebnf(grammar),
    stub,
    "x",
    start_rule=rule,
  )
  assert_true(result.run.result is Some(Unsupported(_)))
  assert_true(result.rendered.output is None)
  assert_eq(result.rendered.diagnostics[0].code, "trace/unsupported")
}

///|
test "exhausted and error outcomes are not non-matches" {
  let stub = RegexStub::{ calls: Ref(0) }
  let diagram : @render.Diagram = Regex(regex_model())
  let exhausted = @svg.SvgRenderer::new().render_traced(diagram, stub, "budget")
  assert_true(exhausted.rendered.output is None)
  assert_eq(exhausted.rendered.diagnostics[0].code, "trace/exhausted")
  let error = @svg.SvgRenderer::new().render_traced(diagram, stub, "boom")
  assert_true(error.rendered.output is None)
  assert_eq(error.rendered.diagnostics[0].code, "trace/provider-error")
}

///|
fn failure_trace() -> @trace.Trace {
  let stub = RegexStub::{ calls: Ref(0) }
  let request = @trace.TraceRequest::regex(regex_model(), "cx")
  match stub.trace(request) {
    NotMatched(trace) => trace
    _ => abort("trace")
  }
}

///|
fn render_with(highlight : @svg.TraceHighlight) -> String {
  @svg.render_regex(regex_model(), id_prefix="t", trace=highlight).output.unwrap()
}

///|
test "terminal-only and prefix-only highlights are independent" {
  let trace = failure_trace()
  let terminal = render_with(
    @svg.TraceHighlight::new(
      trace,
      matched=@svg.ChannelStyle::hidden(),
      not_matched=@svg.ChannelStyle::hidden(),
      taken=@svg.ChannelStyle::hidden(),
    ),
  )
  assert_true(terminal.contains("rr-trace-failure"))
  assert_false(terminal.contains("rr-trace-path"))
  let prefix = render_with(
    @svg.TraceHighlight::new(
      trace,
      matched=@svg.ChannelStyle::hidden(),
      not_matched=@svg.ChannelStyle::hidden(),
      taken=@svg.ChannelStyle::new(),
      failure=@svg.ChannelStyle::hidden(),
    ),
  )
  assert_true(prefix.contains("rr-trace-taken"))
  assert_false(prefix.contains("rr-trace-failure"))
  assert_false(prefix.contains("rr-trace-not-matched"))
}

///|
test "overlapping attempts keep both classifications and can be selected" {
  let request = @trace.TraceRequest::regex(regex_model(), "ab")
  let t = topology_of(request)
  let start = t.tracks[0].start
  let end = t.tracks[0].end
  let back = @trace.Trace::new(request, "regex-stub", [
    @trace.Attempt::new(
      "fail",
      NotMatched,
      steps_between(t, start, t.term("p.1").unwrap().entry),
      failure=@trace.FailurePoint::new(Terminal("p.1"), position=0),
    ),
    @trace.Attempt::new("pass", Matched, steps_between(t, start, end)),
  ])
  let both = render_with(@svg.TraceHighlight::new(back, taken=@svg.ChannelStyle::new()))
  // The start connector is in both attempts.
  let start_id = t.connector_of(t.tracks[0].id, Start).unwrap().id
  let layered = both.split("data-target=\"" + start_id + "\"").count() - 1
  assert_true(layered >= 3)
  assert_true(both.contains("data-attempts=\"pass\""))
  assert_true(both.contains("data-attempts=\"fail\""))
  let only = render_with(@svg.TraceHighlight::new(back, attempts=["pass"]))
  assert_false(only.contains("rr-trace-not-matched"))
  assert_true(only.contains("rr-trace-matched"))
}

///|
test "unvisited alternatives stay neutral" {
  let request = @trace.TraceRequest::regex(regex_model(), "ab")
  let t = topology_of(request)
  let trace = @trace.Trace::new(request, "regex-stub", [
    @trace.Attempt::new("a", Matched, steps_between(t, t.tracks[0].start, t.tracks[0].end)),
  ])
  let svg = render_with(@svg.TraceHighlight::new(trace))
  let second = t.connector_of("p", Split(1)).unwrap().id
  assert_false(svg.contains("data-target=\"" + second + "\""))
  assert_false(svg.contains("data-target=\"p.1\""))
}

///|
test "stale or foreign traces and invalid spans are rejected" {
  let trace = failure_trace()
  // An equal-label model with another identity.
  let other = @plantuml.to_diagram(
    @plantuml.read("@startregex\nab|cd\n@endregex").document.unwrap(),
    id="other",
  ).diagram.unwrap()
  let renderer = @svg.SvgRenderer::new(trace=@svg.TraceHighlight::new(trace))
  let foreign = @render.Renderer::render(renderer, other)
  assert_true(foreign.output is None)
  assert_eq(foreign.diagnostics[0].code, "trace/subject-mismatch")
  // Same identity, changed structure.
  let changed = @plantuml.to_diagram(
    @plantuml.read("@startregex\nab|ce\n@endregex").document.unwrap(),
  ).diagram.unwrap()
  let stale = @render.Renderer::render(renderer, changed)
  assert_eq(stale.diagnostics[0].code, "trace/stale")
  // A span outside the input.
  let request = @trace.TraceRequest::regex(regex_model(), "ab")
  let t = topology_of(request)
  let bad = @trace.Trace::new(request, "regex-stub", [
    @trace.Attempt::new(
      "a",
      Matched,
      steps_between(t, t.tracks[0].start, t.tracks[0].end, spans=Map([("p.0", @trace.InputSpan::new(1, 9))])),
    ),
  ])
  let result = @svg.render_regex(regex_model(), trace=@svg.TraceHighlight::new(bad))
  assert_true(result.output is None)
  assert_eq(result.diagnostics[0].code, "trace/invalid-span")
  // A discontinuous attempt and a label-only target.
  let jump = @trace.Trace::new(request, "regex-stub", [
    @trace.Attempt::new("a", Matched, [Traverse(t.connector_of("p", Join(0)).unwrap().id, false), Visit("p.1", None)]),
  ])
  assert_eq(
    @svg.render_regex(regex_model(), trace=@svg.TraceHighlight::new(jump)).diagnostics[0].code,
    "trace/discontinuous",
  )
  let label = @trace.Trace::new(request, "regex-stub", [
    @trace.Attempt::new("a", Matched, [Visit("ab", None)], continuous=false),
  ])
  assert_eq(
    @svg.render_regex(regex_model(), trace=@svg.TraceHighlight::new(label)).diagnostics[0].code,
    "trace/invalid-target",
  )
}

///|
test "no highlight request gives the ordinary bytes and geometry is unchanged" {
  let model = regex_model()
  let plain = @svg.render_regex(model, id_prefix="t").output.unwrap()
  let ordinary = @render.Renderer::render(
    @svg.SvgRenderer::new(id_prefix="t"),
    Regex(model),
  ).output.unwrap()
  assert_eq(plain, ordinary)
  let traced = render_with(@svg.TraceHighlight::new(failure_trace()))
  // Every drawn connector keeps its path.
  for part in plain.split("data-connector=\"").drop(1) {
    let id = part.split("\"").next().unwrap().to_owned()
    let d = part.split("d=\"").drop(1).next().unwrap().split("\"").next().unwrap().to_owned()
    assert_true(traced.contains("data-connector=\"" + id + "\""), msg=id)
    assert_true(traced.contains("d=\"" + d + "\""), msg=id)
  }
}

///|
/// A grammar stub: a matched parse of `r = "x", y;` with `y = "z";` for
/// input "xz", and a failure at the end boundary for "xzq".
struct GrammarStub {}

///|
impl @trace.RailroadTraceProvider for GrammarStub with trace(_, request) {
  guard request.subject is Ebnf(_, start) else {
    return Unsupported("this stub has no regex support")
  }
  let t = topology_of(request)
  let track = t.tracks.iter().find_first(k => k.id == start).unwrap()
  let main = steps_between(t, track.start, track.end)
  match request.input {
    "xz" =>
      Matched(@trace.Trace::new(request, "grammar-stub", [@trace.Attempt::new("p", Matched, main)]))
    _ =>
      NotMatched(
        @trace.Trace::new(request, "grammar-stub", [
          @trace.Attempt::new(
            "p",
            NotMatched,
            main,
            failure=@trace.FailurePoint::new(Exit(start), position=2, message="expected end of input"),
          ),
        ]),
      )
  }
}

///|
test "a grammar provider reports an end-boundary failure" {
  let source = "@startebnf\nr = \"x\", y;\ny = \"z\";\n@endebnf\n"
  let ok = @plantuml.render_traced_svg(source, GrammarStub::{  }, "xz", start_rule="r")
  assert_true(ok.run.result is Some(Matched(_)))
  assert_true(ok.rendered.output.unwrap().contains("rr-trace-matched"))
  let failed = @plantuml.render_traced_svg(source, GrammarStub::{  }, "xzq", start_rule="r")
  let svg = failed.rendered.output.unwrap()
  assert_true(svg.contains("rr-trace-boundary"))
  assert_true(svg.contains("expected end of input"))
  // A missing start rule never reaches the provider.
  let missing = @plantuml.render_traced_svg(source, GrammarStub::{  }, "xz", start_rule="nope")
  assert_true(missing.run.result is None)
  // A regex request to a grammar-only stub is unsupported.
  let regex = @svg.SvgRenderer::new().render_traced(Regex(regex_model()), GrammarStub::{  }, "x")
  assert_true(regex.run.result is Some(Unsupported(_)))
}

///|
test "rendering, scenes, playback and export never call a provider" {
  let stub = RegexStub::{ calls: Ref(0) }
  let trace = match stub.trace(@trace.TraceRequest::regex(regex_model(), "cx")) {
    NotMatched(trace) => trace
    _ => abort("trace")
  }
  assert_eq(stub.calls.val, 1)
  let renderer = @svg.SvgRenderer::new(id_prefix="t", trace=@svg.TraceHighlight::new(trace))
  let diagram : @render.Diagram = Regex(regex_model())
  let direct = @render.Renderer::render(renderer, diagram).output.unwrap()
  let scene = renderer.scene(diagram).scene.unwrap()
  assert_eq(scene.canonical_svg, direct)
  let html = @render.Renderer::render(@animated.AnimatedRenderer::new(svg=renderer), diagram)
  assert_true(html.output.unwrap().contains("rr-trace-failure"))
  assert_eq(stub.calls.val, 1)
}

///|
extend RegexStub with @trace.RailroadTraceProvider::{trace}

///|
/// A stub that returns cached evidence for another input.
struct CachedStub {}

///|
impl @trace.RailroadTraceProvider for CachedStub with trace(_, request) {
  let other = @trace.TraceRequest::regex(regex_model(), "ab")
  let t = topology_of(request)
  Matched(
    @trace.Trace::new(other, "cached", [
      @trace.Attempt::new("a", Matched, steps_between(t, t.tracks[0].start, t.tracks[0].end)),
    ]),
  )
}

///|
test "evidence for another input is rejected" {
  let result = @svg.SvgRenderer::new().render_traced(Regex(regex_model()), CachedStub::{  }, "cd")
  assert_true(result.run.validated is None)
  assert_true(result.rendered.output is None)
  assert_eq(result.rendered.diagnostics[0].code, "trace/input-mismatch")
}
