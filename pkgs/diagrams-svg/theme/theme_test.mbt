///|
let families : Array[@theme.Family] = [
  Frontend, Backend, Database, Cloud, Security, MessageBus, External,
]

///|
test "colours write as hex or rgba" {
  assert_eq(@theme.Color::hex(0x020617).to_css(), "#020617")
  assert_eq(@theme.Color::rgba(8, 51, 68, 40).to_css(), "rgba(8, 51, 68, 0.4)")
  assert_eq(@theme.Color::rgba(34, 211, 238, 15).to_css(), "rgba(34, 211, 238, 0.15)")
}

///|
test "contrast follows the WCAG formula" {
  let black = @theme.Color::hex(0x000000)
  let white = @theme.Color::hex(0xffffff)
  assert_eq((@theme.contrast(black, white) * 100.0).round(), 2100.0)
  assert_eq(@theme.contrast(white, white), 1.0)
}

///|
test "the classic theme has archify's background colours" {
  let t = @theme.Theme::classic()
  assert_eq(t.dark.bg.to_css(), "#020617")
  assert_eq(t.light.bg.to_css(), "#f4f5f7")
  assert_eq(t.dark.family(Backend).stroke.to_css(), "#34d399")
  assert_eq(t.light.family(Backend).stroke.to_css(), "#059669")
}

///|
test "each text shade has a contrast of at least 4.5:1 in each palette" {
  let t = @theme.Theme::classic()
  for p in [t.dark, t.light] {
    for f in families {
      let c = @theme.contrast(p.family(f).ink, p.mask)
      assert_true(c >= 4.5, msg="\{f.name()} ink is \{c}:1")
      let c = @theme.contrast(p.family(f).ink, p.bg)
      assert_true(c >= 4.5, msg="\{f.name()} ink on bg is \{c}:1")
    }
  }
}

///|
test "light text shades are darker than their line colours where archify's colour fails" {
  let light = @theme.Theme::classic().light
  assert_eq(light.family(Backend).ink.to_css(), "#047d58")
  assert_eq(light.family(Database).ink.to_css(), "#7c3aed")
}

///|
test "participant kinds map to colour families and plain participants cycle" {
  assert_eq(@theme.family_of(Database, 0), @theme.Family::Database)
  assert_eq(@theme.family_of(Queue, 0), @theme.Family::MessageBus)
  assert_eq(@theme.family_of(Actor, 3), @theme.Family::Frontend)
  let cycle = [0, 1, 2, 3, 4, 5].map(i => @theme.family_of(Participant, i))
  assert_eq(cycle, [Frontend, Backend, Database, Cloud, MessageBus, Frontend])
}

///|
test "all computed classic shades stay stored and retain their accents" {
  let t = @theme.Theme::classic()
  assert_eq(families.map(f => t.light.family(f).ink.to_css()), [
    "#077995", "#047d58", "#7c3aed", "#a75c05", "#d81c45", "#c3490a", "#606f85",
  ])
  for f in families { assert_eq(t.dark.family(f).ink, t.dark.family(f).stroke) }
}

///|
test "CSS author colours parse without retaining executable CSS" {
  let cases = [
    ("Purple", "#800080"), ("rebeccapurple", "#663399"), ("LightGoldenRodYellow", "#fafad2"),
    ("#abc", "#aabbcc"), ("#aabbcc", "#aabbcc"), ("#abcd", "rgba(170, 187, 204, 0.87)"),
    ("#aabbcc80", "rgba(170, 187, 204, 0.5)"), ("rgb(191, 223, 255)", "#bfdfff"),
    ("rgba(191, 223, 255, .5)", "rgba(191, 223, 255, 0.5)"),
    ("rgb(100%, 0%, 50%)", "#ff0080"), ("rgb(256,-1,0)", "#ff0000"),
    ("rgb(191 223 255 / 50%)", "rgba(191, 223, 255, 0.5)"), ("rgba(1e2 0 0)", "#640000"), ("transparent", "rgba(0, 0, 0, 0)"),
  ]
  for (source, css) in cases { assert_eq(@theme.parse_color(source).unwrap().to_css(), css) }
  for invalid in ["notacolour", "currentColor", "url(https://example.com)", "red;fill:url(x)", "#zzzzzz", "#12", "rgb(1,2,3/.5)", "rgba(0,0,0,NaN)", "rgb(1,2)"] {
    assert_eq(@theme.parse_color(invalid), None, msg=invalid)
  }
  assert_eq(@theme.parse_color("Purple").unwrap().tint().to_css(), "rgba(128, 0, 128, 0.18)")
  assert_eq(@theme.parse_color("rgba(191,223,255,.5)").unwrap().tint().to_css(), "rgba(191, 223, 255, 0.09)")
}
