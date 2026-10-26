///|
/// Review examples. Each has a native source, fixed dark and light SVGs and
/// offline players. The gallery task writes them from the snapshot.
let regex_example : String =
  #|@startregex
  #|title ISO date with optional time
  #|(?<year>\d{4})-(?<month>0[1-9]|1[0-2])-(?<day>\d{2})(?:T\d{2}:\d{2})?(?!\d)
  #|@endregex

///|
let regex_constraints : String =
  #|@startregex
  #|title Constraints and repetitions
  #|^(?<=@)[A-Za-z_][\w-]{0,30}+?(?:\.(?!\.)[^\s.]+)*$|\b(\d)\1+\B
  #|@endregex

///|
let ebnf_example : String =
  #|@startebnf
  #|title Arithmetic with recursion
  #|(* Expressions refer to terms; parentheses refer back to expressions. *)
  #|expression = term, { ("+" | "-"), term };
  #|term = factor, { ("*" | "/"), factor };
  #|factor = number | "(", expression, ")" | "-", factor;
  #|number = digit, { digit };
  #|digit = ? any decimal digit ? - "0" | "0";
  #|@endebnf

///|
let ebnf_constraints : String =
  #|@startebnf
  #|title Counts, options and exclusions
  #|identifier (* not a keyword *) = letter, { letter | digit | "_" };
  #|keyword = "if" | "else" | "while";
  #|name = identifier - keyword;
  #|code = 3 * digit, [ "-", 4 * digit ];
  #|list = name, { ",", name }-;
  #|letter = ? A to Z ?;
  #|empty = ;
  #|@endebnf

///|
let long_example : String =
  #|@startregex
  #|title A long pattern continues on new rows
  #|(?<scheme>https?|ftp)://(?<host>[a-z0-9.-]+)(?::(?<port>\d{1,5}))?(?<path>/[^\s?#]*)?(?:\?(?<query>[^\s#]*))?(?:#(?<fragment>\S*))?
  #|@endregex

///|
let json_example : String =
  #|@startjson
  #|title Order with nested collections
  #|#highlight "items" / "0" / "sku"
  #|{
  #|  "id": 12345678901234567890,
  #|  "paid": true,
  #|  "coupon": null,
  #|  "items": [
  #|    {"sku": "A-1", "qty": 2, "tags": ["gift", "gift"]},
  #|    {"sku": "B-2", "qty": 1, "tags": []}
  #|  ],
  #|  "notes": "A long note wraps inside its row without losing any character of the value text",
  #|  "meta": {}
  #|}
  #|@endjson

///|
let yaml_example : String =
  #|@startyaml
  #|title Native YAML keeps scalars as text
  #|#highlight "service" / "ports"
  #|service:
  #|  name: api
  #|  enabled: true
  #|  replicas: 3
  #|  ports: [80, "443"]
  #|  description: |
  #|    First line
  #|    Second line
  #|clients:
  #|  - name: web
  #|    weight: 0.5
  #|  - name: mobile
  #|    weight: 0.5
  #|@endyaml

///|
fn diagram_of(source : String) -> @render.Diagram {
  let read = @plantuml.read(source)
  for d in read.diagnostics {
    println(d.code + " " + d.message)
  }
  @plantuml.to_diagram(read.document.unwrap()).diagram.unwrap()
}

///|
fn svg(diagram : @render.Diagram, mode : @svg.Mode, trace? : @svg.TraceHighlight) -> String {
  let rendered = @render.Renderer::render(@svg.SvgRenderer::new(mode~, trace?), diagram)
  for d in rendered.diagnostics {
    if d.code.has_suffix("legibility") {
      println("LEGIBILITY " + d.message)
    }
  }
  rendered.output.unwrap()
}

///|
fn player(
  diagram : @render.Diagram,
  mode : @svg.Mode,
  playback? : @animation.PlaybackPlan,
  trace? : @svg.TraceHighlight,
) -> String {
  @render.Renderer::render(
    @animated.AnimatedRenderer::new(
      svg=@svg.SvgRenderer::new(mode~, trace?),
      playback?,
    ),
    diagram,
  ).output.unwrap()
}

///|
/// Test-only fixture helper: drawn steps between two points, found by a
/// breadth-first search. It builds scripted evidence; it does not match.
fn steps(
  t : @trace.Topology,
  from : String,
  to : String,
  spans? : Map[String, @trace.InputSpan] = Map([]),
) -> Array[@trace.Step] {
  let previous : Map[String, (String, @trace.Step)] = Map([])
  let queue = [from]
  let seen = Map([(from, true)])
  let mut cursor = 0
  while cursor < queue.length() && !seen.contains(to) {
    let point = queue[cursor]
    cursor += 1
    let next : Array[(String, @trace.Step)] = []
    for c in t.connectors_from(point) {
      if !c.constraint && c.role != Return {
        next.push((c.to, Traverse(c.id, false)))
      }
    }
    for term in t.terms {
      if term.entry == point && !term.constraint {
        next.push((term.exit, Visit(term.id, spans.get(term.id))))
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
/// A scripted gallery provider: one successful and one failed attempt.
struct GalleryStub {}

///|
impl @trace.RailroadTraceProvider for GalleryStub with trace(_, request) {
  let t = request.topology().topology.unwrap()
  let track = match request.subject {
    Ebnf(_, start) => t.tracks.iter().find_first(k => k.id == start).unwrap()
    Regex(_) => t.tracks[0]
  }
  let terms = t.terms.iter().filter(x => x.rule == track.id && !x.constraint).collect()
  let target = terms[terms.length() / 2]
  let attempts = [
    @trace.Attempt::new(
      "attempt-1",
      NotMatched,
      steps(t, track.start, target.entry),
      failure=@trace.FailurePoint::new(
        if target.kind is (Anchor | Assertion) {
          Assertion(target.id)
        } else {
          Terminal(target.id)
        },
        position=request.input.length() / 2,
        message="unexpected character",
      ),
    ),
  ]
  if request.input.has_prefix("ok") {
    attempts.push(@trace.Attempt::new("attempt-2", Matched, steps(t, track.start, track.end)))
    Matched(@trace.Trace::new(request, "gallery-stub", attempts))
  } else {
    NotMatched(@trace.Trace::new(request, "gallery-stub", attempts))
  }
}

///|
fn traced(
  diagram : @render.Diagram,
  input : String,
  start? : String,
  matched? : @svg.ChannelStyle = @svg.ChannelStyle::new(),
  not_matched? : @svg.ChannelStyle = @svg.ChannelStyle::new(dashed=true),
  taken? : @svg.ChannelStyle = @svg.ChannelStyle::hidden(),
  failure? : @svg.ChannelStyle = @svg.ChannelStyle::new(),
  mode? : @svg.Mode = Fixed(Light),
) -> String {
  let result = @svg.SvgRenderer::new(mode~).render_traced(
    diagram,
    GalleryStub::{  },
    input,
    start_rule?=start,
    matched~,
    not_matched~,
    taken~,
    failure~,
  )
  result.rendered.output.unwrap()
}

///|
fn first_rule(diagram : @render.Diagram) -> String? {
  match diagram {
    Ebnf(g) => Some(g.rules()[0].id)
    _ => None
  }
}

///|
test "PlantUML review gallery" (t : @test.Test) {
  let rows : Array[Json] = []
  fn row(name : String, kind : String, content : String) {
    rows.push(Json([Json(name), Json(kind), Json(content)]))
  }
  for
    pair in [
      ("regex-date", regex_example),
      ("regex-constraints", regex_constraints),
      ("regex-long", long_example),
      ("ebnf-arithmetic", ebnf_example),
      ("ebnf-constraints", ebnf_constraints),
      ("json-order", json_example),
      ("yaml-service", yaml_example),
    ] {
    let (name, source) = pair
    let diagram = diagram_of(source)
    row(name + ".puml", "source", source)
    for variant in [("dark", @svg.Mode::Fixed(Dark)), ("light", Fixed(Light))] {
      row(name + "-" + variant.0 + ".svg", "svg", svg(diagram, variant.1))
      row(name + "-" + variant.0 + ".html", "player", player(diagram, variant.1))
    }
    // Static export of a player equals the direct render.
    let scene = @svg.SvgRenderer::new(mode=Fixed(Dark)).scene(diagram).scene.unwrap()
    assert_eq(scene.canonical_svg, svg(diagram, Fixed(Dark)))
  }
  // Independent trace highlight channels for both subject kinds.
  for pair in [("regex-date", regex_example), ("ebnf-arithmetic", ebnf_example)] {
    let (name, source) = pair
    let diagram = diagram_of(source)
    let start = first_rule(diagram)
    let hidden = @svg.ChannelStyle::hidden()
    row(name + "-trace-success.svg", "svg", traced(diagram, "ok input", start?))
    row(
      name + "-trace-failure.svg",
      "svg",
      traced(diagram, "bad input", start?, matched=hidden),
    )
    row(
      name + "-trace-prefix.svg",
      "svg",
      traced(
        diagram,
        "bad input",
        start?,
        matched=hidden,
        not_matched=hidden,
        taken=@svg.ChannelStyle::new(),
        failure=hidden,
      ),
    )
    row(
      name + "-trace-terminal.svg",
      "svg",
      traced(diagram, "bad input", start?, matched=hidden, not_matched=hidden),
    )
    row(
      name + "-trace-dark.svg",
      "svg",
      traced(diagram, "ok input", start?, taken=@svg.ChannelStyle::new(), mode=Fixed(Dark)),
    )
  }
  // An explicit EBNF scenario that follows a branch and a return loop.
  let diagram = diagram_of(ebnf_example)
  let catalog = match diagram {
    Ebnf(g) => @animation.Catalog::ebnf(g).catalog.unwrap()
    _ => abort("ebnf")
  }
  let topology = match diagram {
    Ebnf(g) => @trace.Topology::ebnf(g).topology.unwrap()
    _ => abort("ebnf")
  }
  let track = topology.tracks[0]
  let walk = steps(topology, track.start, track.end)
  let back = topology.connectors.iter().find_first(c => c.rule == track.id && c.role == Return).unwrap()
  let actions = walk.map(s => match s {
    Visit(id, _) => @animation.Motion::Visit(@animation.railroad_key(catalog.view_id, id), 600L)
    Traverse(id, _) => Step(@animation.railroad_key(catalog.view_id, id), 400L)
  })
  actions.push(Step(@animation.railroad_key(catalog.view_id, back.id), 600L))
  let plan = @animation.PlaybackPlan::scenario(catalog, @animation.Motion::serial(actions)).plan.unwrap()
  row("ebnf-scenario.html", "player", player(diagram, Fixed(Light), playback=plan))
  // A player keeps configured static trace highlights in its canonical SVG.
  let request = @trace.TraceRequest::ebnf(
    match diagram {
      Ebnf(g) => g
      _ => abort("ebnf")
    },
    track.id,
    "bad input",
  )
  let evidence = match GalleryStub::{  }.trace(request) {
    NotMatched(t) => t
    _ => abort("trace")
  }
  let highlight = @svg.TraceHighlight::new(evidence, taken=@svg.ChannelStyle::new())
  row("ebnf-arithmetic-trace-light.svg", "svg", svg(diagram, Fixed(Light), trace=highlight))
  row(
    "ebnf-arithmetic-trace-light.html",
    "player",
    player(diagram, Fixed(Light), trace=highlight),
  )
  // Two inline copies with different prefixes and themes stay independent.
  let inline = [
    @render.Renderer::render(
      @svg.SvgRenderer::new(mode=Adaptive, id_prefix="first"),
      diagram_of(regex_example),
    ).output.unwrap(),
    @render.Renderer::render(
      @svg.SvgRenderer::new(mode=Adaptive, id_prefix="second"),
      diagram,
    ).output.unwrap(),
  ]
  row("inline.html", "inline", inline.join("\n"))
  t.write(Json(rows).stringify(indent=1))
  t.snapshot(filename="plantuml-gallery.json")
}

///|
extend GalleryStub with @trace.RailroadTraceProvider::{trace}
