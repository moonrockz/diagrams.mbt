///|
fn simple() -> @sequence.Sequence {
  @sequence.Sequence::new(
    [@sequence.Participant::new("Client"), @sequence.Participant::new("API")],
    [Message(@sequence.Message::new("Client", "API", "GET /forecast"))],
  )
}

///|
fn svg_of(s : @sequence.Sequence) -> String {
  @render.Renderer::render(@svg.SvgRenderer::new(), Sequence(s)).output.unwrap()
}

///|
test "the SVG renderer renders a sequence" {
  let r = @render.Renderer::render(@svg.SvgRenderer::new(), Sequence(simple()))
  assert_eq(r.media_type, "image/svg+xml")
  assert_eq(r.diagnostics.length(), 0)
  let svg = r.output.unwrap()
  assert_true(svg.has_prefix("<svg xmlns=\"http://www.w3.org/2000/svg\""))
  assert_true(svg.has_suffix("</svg>\n"))
}

///|
test "the SVG has no scripts and no external references" {
  let svg = svg_of(simple())
  assert_eq(svg.find("<script"), None)
  assert_eq(svg.find("@import"), None)
  assert_eq(svg.find("href"), None)
  for part in svg.split("url(").drop(1) {
    assert_true(part.has_prefix("#"), msg="url( must point to a local # id")
  }
}

///|
test "the SVG has a title and a description" {
  let svg = svg_of(simple())
  assert_true(svg.contains("<title>Sequence diagram</title>"))
  assert_true(
    svg.contains(
      "<desc>Sequence diagram with 2 participants (Client, API) and 1 message.</desc>",
    ),
  )
  let titled = @sequence.Sequence::new([], [], title="Login flow")
  assert_true(svg_of(titled).contains("<title>Login flow</title>"))
}

///|
test "the adaptive SVG is dark by default and light when the viewer prefers light" {
  let svg = svg_of(simple())
  assert_true(svg.contains("--bg: #020617;"))
  assert_true(
    svg.contains("@media (prefers-color-scheme: light)") &&
    svg.contains("--bg: #f4f5f7;"),
  )
  assert_true(svg.contains("[data-theme=\"dark\"] {\n  --bg: #020617;"))
  assert_true(svg.contains("[data-theme=\"light\"] {\n  --bg: #f4f5f7;"))
}

///|
test "participant and message groups have data attributes" {
  let svg = svg_of(simple())
  assert_true(svg.contains("data-id=\"Client\""))
  assert_true(svg.contains("data-from=\"Client\" data-to=\"API\""))
}

///|
test "the SVG of a simple sequence" {
  let t = @test.Test("simple")
  t.write(svg_of(simple()))
  t.snapshot(filename="simple.svg")
}

///|
test "the description counts messages rather than other events" {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [
      Activate("A"),
      Frame(
        @sequence.Frame::new(
          Loop,
          @sequence.Section::new([
            Message(@sequence.Message::new("A", "B", "hello")),
          ]),
        ),
      ),
      Deactivate("A"),
    ],
  )
  assert_true(svg_of(s).contains("and 1 message.</desc>"))
}

///|
fn rich() -> @sequence.Sequence {
  let group = @sequence.BoxGroup::new(
    "g<&\"",
    "Servers\n<group>",
    colour="Purple",
  )
  let heads : Array[@sequence.Head] = [
    NoHead,
    Arrow,
    OpenArrow,
    Cross,
    Async,
    HalfArrow(upper=true, filled=true),
    HalfArrow(upper=false, filled=true),
    HalfArrow(upper=true, filled=false),
    HalfArrow(upper=false, filled=false),
    Central(Arrow),
    Central(NoHead),
  ]
  let events : Array[@sequence.Event] = [Activate("A"), Activate("A")]
  for i, h in heads {
    events.push(
      Message(
        @sequence.Message::new(
          "A",
          if i % 2 == 0 {
            "B"
          } else {
            "A"
          },
          "Head \{i}\n<&\"😀",
          sender_head=h,
          receiver_head=h,
          line=if i % 2 == 0 { Solid } else { Dotted },
        ),
      ),
    )
  }
  events.push(Deactivate("A"))
  events.push(Deactivate("A"))
  events.push(
    Frame(
      @sequence.Frame::new(
        Alt,
        @sequence.Section::new(
          [
            Note(@sequence.Note::new(Over, ["A", "B"], "note\n<&\"")),
            Frame(
              @sequence.Frame::new(
                Rect,
                @sequence.Section::new([
                  Message(
                    @sequence.Message::new(
                      "B",
                      "A",
                      "example.weather/City$name",
                      link=@sequence.Link::new(
                        Smithy,
                        "example.weather#City$name",
                      ),
                      properties=@sequence.MessageProperties::new(
                        sublabel="output",
                        description="<message description>",
                      ),
                      number=15,
                    ),
                  ),
                ]),
                colour="rgb(191, 223, 255)",
              ),
            ),
          ],
          label="success",
        ),
        rest=[
          @sequence.Section::new(
            [
              Create("C"),
              Message(@sequence.Message::new("B", "C", "create")),
              Message(@sequence.Message::new("C", "B", "goodbye")),
              Destroy("C"),
            ],
            label="else",
          ),
        ],
      ),
    ),
  )
  @sequence.Sequence::new(
    [
      @sequence.Participant::new(
        "A",
        label="A\n<&\"😀",
        properties=@sequence.ParticipantProperties::new(
          kind=Database,
          sublabel="v2026-01-01",
          description="<participant description>",
        ),
        link=@sequence.Link::new(Smithy, "example.weather#Weather"),
      ),
      @sequence.Participant::new("B", kind=Queue, group~),
      @sequence.Participant::new("C", group~),
    ],
    events,
    title="Paint all elements",
    accessibility_title="Login flow",
    accessibility_description="A < B & \"C\"",
  )
}

///|
test "rich adaptive" {
  let t = @test.Test("rich-adaptive")
  t.write(@svg.render_sequence(rich()))
  t.snapshot(filename="rich-adaptive.svg")
}

///|
test "rich fixed dark" {
  let t = @test.Test("rich-dark")
  t.write(@svg.render_sequence(rich(), mode=Fixed(Dark)))
  t.snapshot(filename="rich-dark.svg")
}

///|
test "rich fixed light" {
  let t = @test.Test("rich-light")
  t.write(@svg.render_sequence(rich(), mode=Fixed(Light)))
  t.snapshot(filename="rich-light.svg")
}

///|
test "fixed modes contain literal colours and every model element" {
  for
    (mode, bg) in [
      (@svg.Mode::Fixed(Dark), "#020617"),
      (Fixed(Light), "#f4f5f7"),
    ] {
    let svg = @svg.render_sequence(rich(), mode~)
    for bad in ["<style", "var(", "@media"] {
      assert_false(svg.contains(bad))
    }
    assert_true(svg.contains("rx=\"0\" fill=\"\{bg}\""))
    for
      class in [
        "box-group", "frame", "section-divider", "activation", "note", "destruction",
        "central-connection", "sublabel", "diagram-title",
      ] {
      assert_true(svg.contains("class=\"\{class}\""), msg=class)
    }
    assert_true(svg.contains("<title>Login flow</title>"))
    assert_true(svg.contains("<desc>A &lt; B &amp; \"C\"</desc>"))
    assert_true(svg.contains("data-link=\"smithy:example.weather#Weather\""))
    assert_true(svg.contains("data-link=\"smithy:example.weather#City$name\""))
    assert_true(
      svg.contains("data-description=\"&lt;message description&gt;\""),
    )
    assert_true(svg.contains(">15 City$name</tspan>"))
    assert_true(svg.contains(">v2026-01-01</tspan>"))
    assert_true(svg.contains("class=\"participant f-database\""))
    assert_true(svg.contains("class=\"participant f-messagebus\""))
  }
}

///|
test "unreadable author colours warn and fall back to the theme" {
  let s = @sequence.Sequence::new(
    [
      @sequence.Participant::new(
        "A",
        group=@sequence.BoxGroup::new("g", "Group", colour="notacolour"),
      ),
    ],
    [
      Frame(
        @sequence.Frame::new(
          Rect,
          @sequence.Section::new([]),
          colour="url(https://example.com)",
        ),
      ),
    ],
  )
  let r = @svg.SvgRenderer::new(mode=Fixed(Light)).render(Sequence(s))
  assert_eq(r.diagnostics.length(), 2)
  for d in r.diagnostics {
    assert_eq(d.code, "svg/invalid-colour")
  }
  assert_false(r.output.unwrap().contains("https://"))
  assert_true(r.output.unwrap().contains("class=\"box-group\""))
  assert_true(r.output.unwrap().contains("fill=\"rgba(148, 163, 184, 0.18)\""))
}

///|
test "author tints keep message labels legible in both palettes" {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [
      Frame(
        @sequence.Frame::new(
          Rect,
          @sequence.Section::new([
            Message(@sequence.Message::new("A", "B", "hello")),
          ]),
          colour="rgb(191, 223, 255)",
        ),
      ),
    ],
  )
  let r = @svg.SvgRenderer::new().render(Sequence(s))
  assert_eq(r.diagnostics.length(), 0)
  assert_true(r.output.unwrap().contains("rgba(191, 223, 255, 0.18)"))
}

///|
test "message lines retain accents while text uses shades and replies use grey" {
  let s = @sequence.Sequence::new(
    [
      @sequence.Participant::new("A", kind=Service),
      @sequence.Participant::new("B"),
    ],
    [
      Message(@sequence.Message::new("A", "B", "request")),
      Message(@sequence.Message::new("A", "B", "reply", line=Dotted)),
      Message(
        @sequence.Message::new(
          "B",
          "A",
          "failure",
          receiver_head=Cross,
          line=Dotted,
        ),
      ),
    ],
  )
  let svg = @svg.render_sequence(s, mode=Fixed(Light))
  assert_true(svg.contains("stroke=\"#059669\" stroke-width=\"1.4\""))
  assert_true(svg.contains("fill=\"#047d58\""))
  assert_true(
    svg.contains(
      "stroke=\"#64748b\" stroke-width=\"1.4\" stroke-dasharray=\"4 4\"",
    ),
  )
  assert_true(
    svg.contains(
      "stroke=\"#e11d48\" stroke-width=\"1.4\" stroke-dasharray=\"4 4\"",
    ),
  )
}

///|
test "rich geometry and paint agree about legibility" {
  for mode in [@svg.Mode::Adaptive, Fixed(Dark), Fixed(Light)] {
    let r = @svg.SvgRenderer::new(mode~).render(Sequence(rich()))
    assert_eq(
      r.diagnostics.length(),
      0,
      msg=r.diagnostics.map(d => d.message).iter().to_array().join("; "),
    )
  }
}

///|
test "caller prefixes distinguish identical diagrams and escape hostile IDs" {
  let a = @svg.render_sequence(simple(), id_prefix="one")
  let b = @svg.render_sequence(simple(), id_prefix="two")
  assert_false(a == b)
  assert_eq(a, @svg.render_sequence(simple(), id_prefix="one"))
  let hostile = @svg.render_sequence(simple(), id_prefix="x)\"<&")
  assert_false(hostile.contains("x)\"<&"))
  assert_true(hostile.contains("id=\"seq-u-78-29-22-3c-26-diagram\""))
  let renderer = @svg.SvgRenderer::new(id_prefix="one")
  assert_eq(renderer.render(Sequence(simple())).output.unwrap(), a)
}

///|
test "explicit namespace snapshot" {
  let t = @test.Test("namespaced")
  t.write(@svg.render_sequence(simple(), id_prefix="second"))
  t.snapshot(filename="namespaced.svg")
}

///|
test "all half-arrow directions snapshot" {
  let events : Array[@sequence.Event] = []
  for upper in [true, false] {
    for filled in [true, false] {
      for (a, b) in [("A", "B"), ("B", "A"), ("A", "A")] {
        let head = @sequence.Head::HalfArrow(upper~, filled~)
        events.push(
          Message(
            @sequence.Message::new(
              a,
              b,
              "\{a} to \{b}",
              sender_head=head,
              receiver_head=Central(head),
            ),
          ),
        )
      }
    }
  }
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    events,
  )
  let t = @test.Test("half-arrows")
  t.write(@svg.render_sequence(s, mode=Fixed(Light)))
  t.snapshot(filename="half-arrows-light.svg")
}

///|
test "custom adaptive palette snapshot" {
  let classic = @theme.Theme::classic()
  let theme = {
    ..classic,
    dark: { ..classic.dark, bg: @theme.Color::hex(0x101820), },
  }
  let t = @test.Test("custom-adaptive")
  t.write(@svg.render_sequence(simple(), theme~))
  t.snapshot(filename="custom-adaptive.svg")
}
