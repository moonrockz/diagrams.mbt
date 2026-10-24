///|
fn corpus_svg(index : Int, mode : @svg.Mode) -> String raise {
  let e = @corpus.mermaid_12_2_0[index]
  let s = @mermaid.to_sequence(@mermaid.read(e.source).ast.unwrap()).sequence
  let r = @render.Renderer::render(@svg.SvgRenderer::new(mode~), Sequence(s))
  assert_eq(r.diagnostics.length(), 0, msg="example \{e.name}: \{r.diagnostics.map(d => d.message).iter().to_array().join("; ")}")
  let svg = r.output.unwrap()
  for forbidden in ["<script", "@import", "href=", "data:font", "<foreignObject", " onload="] { assert_false(svg.contains(forbidden), msg=e.name) }
  for url in svg.split("url(").drop(1) { assert_true(url.has_prefix("#"), msg=e.name) }
  svg
}

///|
test "corpus 01 adaptive" {
  let t = @test.Test("01-adaptive")
  t.write(corpus_svg(0, Adaptive))
  t.snapshot(filename="svg/01-adaptive.svg")
}

///|
test "corpus 01 dark" {
  let t = @test.Test("01-dark")
  t.write(corpus_svg(0, Fixed(Dark)))
  t.snapshot(filename="svg/01-dark.svg")
}

///|
test "corpus 01 light" {
  let t = @test.Test("01-light")
  t.write(corpus_svg(0, Fixed(Light)))
  t.snapshot(filename="svg/01-light.svg")
}

///|
test "corpus 02 adaptive" {
  let t = @test.Test("02-adaptive")
  t.write(corpus_svg(1, Adaptive))
  t.snapshot(filename="svg/02-adaptive.svg")
}

///|
test "corpus 02 dark" {
  let t = @test.Test("02-dark")
  t.write(corpus_svg(1, Fixed(Dark)))
  t.snapshot(filename="svg/02-dark.svg")
}

///|
test "corpus 02 light" {
  let t = @test.Test("02-light")
  t.write(corpus_svg(1, Fixed(Light)))
  t.snapshot(filename="svg/02-light.svg")
}

///|
test "corpus 03 adaptive" {
  let t = @test.Test("03-adaptive")
  t.write(corpus_svg(2, Adaptive))
  t.snapshot(filename="svg/03-adaptive.svg")
}

///|
test "corpus 03 dark" {
  let t = @test.Test("03-dark")
  t.write(corpus_svg(2, Fixed(Dark)))
  t.snapshot(filename="svg/03-dark.svg")
}

///|
test "corpus 03 light" {
  let t = @test.Test("03-light")
  t.write(corpus_svg(2, Fixed(Light)))
  t.snapshot(filename="svg/03-light.svg")
}

///|
test "corpus 04 adaptive" {
  let t = @test.Test("04-adaptive")
  t.write(corpus_svg(3, Adaptive))
  t.snapshot(filename="svg/04-adaptive.svg")
}

///|
test "corpus 04 dark" {
  let t = @test.Test("04-dark")
  t.write(corpus_svg(3, Fixed(Dark)))
  t.snapshot(filename="svg/04-dark.svg")
}

///|
test "corpus 04 light" {
  let t = @test.Test("04-light")
  t.write(corpus_svg(3, Fixed(Light)))
  t.snapshot(filename="svg/04-light.svg")
}

///|
test "corpus 05 adaptive" {
  let t = @test.Test("05-adaptive")
  t.write(corpus_svg(4, Adaptive))
  t.snapshot(filename="svg/05-adaptive.svg")
}

///|
test "corpus 05 dark" {
  let t = @test.Test("05-dark")
  t.write(corpus_svg(4, Fixed(Dark)))
  t.snapshot(filename="svg/05-dark.svg")
}

///|
test "corpus 05 light" {
  let t = @test.Test("05-light")
  t.write(corpus_svg(4, Fixed(Light)))
  t.snapshot(filename="svg/05-light.svg")
}

///|
test "corpus 06 adaptive" {
  let t = @test.Test("06-adaptive")
  t.write(corpus_svg(5, Adaptive))
  t.snapshot(filename="svg/06-adaptive.svg")
}

///|
test "corpus 06 dark" {
  let t = @test.Test("06-dark")
  t.write(corpus_svg(5, Fixed(Dark)))
  t.snapshot(filename="svg/06-dark.svg")
}

///|
test "corpus 06 light" {
  let t = @test.Test("06-light")
  t.write(corpus_svg(5, Fixed(Light)))
  t.snapshot(filename="svg/06-light.svg")
}

///|
test "corpus 07 adaptive" {
  let t = @test.Test("07-adaptive")
  t.write(corpus_svg(6, Adaptive))
  t.snapshot(filename="svg/07-adaptive.svg")
}

///|
test "corpus 07 dark" {
  let t = @test.Test("07-dark")
  t.write(corpus_svg(6, Fixed(Dark)))
  t.snapshot(filename="svg/07-dark.svg")
}

///|
test "corpus 07 light" {
  let t = @test.Test("07-light")
  t.write(corpus_svg(6, Fixed(Light)))
  t.snapshot(filename="svg/07-light.svg")
}

///|
test "corpus 08 adaptive" {
  let t = @test.Test("08-adaptive")
  t.write(corpus_svg(7, Adaptive))
  t.snapshot(filename="svg/08-adaptive.svg")
}

///|
test "corpus 08 dark" {
  let t = @test.Test("08-dark")
  t.write(corpus_svg(7, Fixed(Dark)))
  t.snapshot(filename="svg/08-dark.svg")
}

///|
test "corpus 08 light" {
  let t = @test.Test("08-light")
  t.write(corpus_svg(7, Fixed(Light)))
  t.snapshot(filename="svg/08-light.svg")
}

///|
test "corpus 09 adaptive" {
  let t = @test.Test("09-adaptive")
  t.write(corpus_svg(8, Adaptive))
  t.snapshot(filename="svg/09-adaptive.svg")
}

///|
test "corpus 09 dark" {
  let t = @test.Test("09-dark")
  t.write(corpus_svg(8, Fixed(Dark)))
  t.snapshot(filename="svg/09-dark.svg")
}

///|
test "corpus 09 light" {
  let t = @test.Test("09-light")
  t.write(corpus_svg(8, Fixed(Light)))
  t.snapshot(filename="svg/09-light.svg")
}

///|
test "corpus 10 adaptive" {
  let t = @test.Test("10-adaptive")
  t.write(corpus_svg(9, Adaptive))
  t.snapshot(filename="svg/10-adaptive.svg")
}

///|
test "corpus 10 dark" {
  let t = @test.Test("10-dark")
  t.write(corpus_svg(9, Fixed(Dark)))
  t.snapshot(filename="svg/10-dark.svg")
}

///|
test "corpus 10 light" {
  let t = @test.Test("10-light")
  t.write(corpus_svg(9, Fixed(Light)))
  t.snapshot(filename="svg/10-light.svg")
}

///|
test "corpus 11 adaptive" {
  let t = @test.Test("11-adaptive")
  t.write(corpus_svg(10, Adaptive))
  t.snapshot(filename="svg/11-adaptive.svg")
}

///|
test "corpus 11 dark" {
  let t = @test.Test("11-dark")
  t.write(corpus_svg(10, Fixed(Dark)))
  t.snapshot(filename="svg/11-dark.svg")
}

///|
test "corpus 11 light" {
  let t = @test.Test("11-light")
  t.write(corpus_svg(10, Fixed(Light)))
  t.snapshot(filename="svg/11-light.svg")
}

///|
test "corpus 12 adaptive" {
  let t = @test.Test("12-adaptive")
  t.write(corpus_svg(11, Adaptive))
  t.snapshot(filename="svg/12-adaptive.svg")
}

///|
test "corpus 12 dark" {
  let t = @test.Test("12-dark")
  t.write(corpus_svg(11, Fixed(Dark)))
  t.snapshot(filename="svg/12-dark.svg")
}

///|
test "corpus 12 light" {
  let t = @test.Test("12-light")
  t.write(corpus_svg(11, Fixed(Light)))
  t.snapshot(filename="svg/12-light.svg")
}

///|
test "corpus 13 adaptive" {
  let t = @test.Test("13-adaptive")
  t.write(corpus_svg(12, Adaptive))
  t.snapshot(filename="svg/13-adaptive.svg")
}

///|
test "corpus 13 dark" {
  let t = @test.Test("13-dark")
  t.write(corpus_svg(12, Fixed(Dark)))
  t.snapshot(filename="svg/13-dark.svg")
}

///|
test "corpus 13 light" {
  let t = @test.Test("13-light")
  t.write(corpus_svg(12, Fixed(Light)))
  t.snapshot(filename="svg/13-light.svg")
}

///|
test "corpus 14 adaptive" {
  let t = @test.Test("14-adaptive")
  t.write(corpus_svg(13, Adaptive))
  t.snapshot(filename="svg/14-adaptive.svg")
}

///|
test "corpus 14 dark" {
  let t = @test.Test("14-dark")
  t.write(corpus_svg(13, Fixed(Dark)))
  t.snapshot(filename="svg/14-dark.svg")
}

///|
test "corpus 14 light" {
  let t = @test.Test("14-light")
  t.write(corpus_svg(13, Fixed(Light)))
  t.snapshot(filename="svg/14-light.svg")
}

///|
test "corpus 15 adaptive" {
  let t = @test.Test("15-adaptive")
  t.write(corpus_svg(14, Adaptive))
  t.snapshot(filename="svg/15-adaptive.svg")
}

///|
test "corpus 15 dark" {
  let t = @test.Test("15-dark")
  t.write(corpus_svg(14, Fixed(Dark)))
  t.snapshot(filename="svg/15-dark.svg")
}

///|
test "corpus 15 light" {
  let t = @test.Test("15-light")
  t.write(corpus_svg(14, Fixed(Light)))
  t.snapshot(filename="svg/15-light.svg")
}

///|
test "corpus 16 adaptive" {
  let t = @test.Test("16-adaptive")
  t.write(corpus_svg(15, Adaptive))
  t.snapshot(filename="svg/16-adaptive.svg")
}

///|
test "corpus 16 dark" {
  let t = @test.Test("16-dark")
  t.write(corpus_svg(15, Fixed(Dark)))
  t.snapshot(filename="svg/16-dark.svg")
}

///|
test "corpus 16 light" {
  let t = @test.Test("16-light")
  t.write(corpus_svg(15, Fixed(Light)))
  t.snapshot(filename="svg/16-light.svg")
}

///|
test "corpus 17 adaptive" {
  let t = @test.Test("17-adaptive")
  t.write(corpus_svg(16, Adaptive))
  t.snapshot(filename="svg/17-adaptive.svg")
}

///|
test "corpus 17 dark" {
  let t = @test.Test("17-dark")
  t.write(corpus_svg(16, Fixed(Dark)))
  t.snapshot(filename="svg/17-dark.svg")
}

///|
test "corpus 17 light" {
  let t = @test.Test("17-light")
  t.write(corpus_svg(16, Fixed(Light)))
  t.snapshot(filename="svg/17-light.svg")
}

///|
test "corpus 18 adaptive" {
  let t = @test.Test("18-adaptive")
  t.write(corpus_svg(17, Adaptive))
  t.snapshot(filename="svg/18-adaptive.svg")
}

///|
test "corpus 18 dark" {
  let t = @test.Test("18-dark")
  t.write(corpus_svg(17, Fixed(Dark)))
  t.snapshot(filename="svg/18-dark.svg")
}

///|
test "corpus 18 light" {
  let t = @test.Test("18-light")
  t.write(corpus_svg(17, Fixed(Light)))
  t.snapshot(filename="svg/18-light.svg")
}

///|
test "corpus 19 adaptive" {
  let t = @test.Test("19-adaptive")
  t.write(corpus_svg(18, Adaptive))
  t.snapshot(filename="svg/19-adaptive.svg")
}

///|
test "corpus 19 dark" {
  let t = @test.Test("19-dark")
  t.write(corpus_svg(18, Fixed(Dark)))
  t.snapshot(filename="svg/19-dark.svg")
}

///|
test "corpus 19 light" {
  let t = @test.Test("19-light")
  t.write(corpus_svg(18, Fixed(Light)))
  t.snapshot(filename="svg/19-light.svg")
}

///|
test "corpus 20 adaptive" {
  let t = @test.Test("20-adaptive")
  t.write(corpus_svg(19, Adaptive))
  t.snapshot(filename="svg/20-adaptive.svg")
}

///|
test "corpus 20 dark" {
  let t = @test.Test("20-dark")
  t.write(corpus_svg(19, Fixed(Dark)))
  t.snapshot(filename="svg/20-dark.svg")
}

///|
test "corpus 20 light" {
  let t = @test.Test("20-light")
  t.write(corpus_svg(19, Fixed(Light)))
  t.snapshot(filename="svg/20-light.svg")
}

///|
test "corpus 21 adaptive" {
  let t = @test.Test("21-adaptive")
  t.write(corpus_svg(20, Adaptive))
  t.snapshot(filename="svg/21-adaptive.svg")
}

///|
test "corpus 21 dark" {
  let t = @test.Test("21-dark")
  t.write(corpus_svg(20, Fixed(Dark)))
  t.snapshot(filename="svg/21-dark.svg")
}

///|
test "corpus 21 light" {
  let t = @test.Test("21-light")
  t.write(corpus_svg(20, Fixed(Light)))
  t.snapshot(filename="svg/21-light.svg")
}

///|
test "corpus 22 adaptive" {
  let t = @test.Test("22-adaptive")
  t.write(corpus_svg(21, Adaptive))
  t.snapshot(filename="svg/22-adaptive.svg")
}

///|
test "corpus 22 dark" {
  let t = @test.Test("22-dark")
  t.write(corpus_svg(21, Fixed(Dark)))
  t.snapshot(filename="svg/22-dark.svg")
}

///|
test "corpus 22 light" {
  let t = @test.Test("22-light")
  t.write(corpus_svg(21, Fixed(Light)))
  t.snapshot(filename="svg/22-light.svg")
}

///|
test "corpus 23 adaptive" {
  let t = @test.Test("23-adaptive")
  t.write(corpus_svg(22, Adaptive))
  t.snapshot(filename="svg/23-adaptive.svg")
}

///|
test "corpus 23 dark" {
  let t = @test.Test("23-dark")
  t.write(corpus_svg(22, Fixed(Dark)))
  t.snapshot(filename="svg/23-dark.svg")
}

///|
test "corpus 23 light" {
  let t = @test.Test("23-light")
  t.write(corpus_svg(22, Fixed(Light)))
  t.snapshot(filename="svg/23-light.svg")
}

///|
test "corpus 24 adaptive" {
  let t = @test.Test("24-adaptive")
  t.write(corpus_svg(23, Adaptive))
  t.snapshot(filename="svg/24-adaptive.svg")
}

///|
test "corpus 24 dark" {
  let t = @test.Test("24-dark")
  t.write(corpus_svg(23, Fixed(Dark)))
  t.snapshot(filename="svg/24-dark.svg")
}

///|
test "corpus 24 light" {
  let t = @test.Test("24-light")
  t.write(corpus_svg(23, Fixed(Light)))
  t.snapshot(filename="svg/24-light.svg")
}

///|
test "corpus 25 adaptive" {
  let t = @test.Test("25-adaptive")
  t.write(corpus_svg(24, Adaptive))
  t.snapshot(filename="svg/25-adaptive.svg")
}

///|
test "corpus 25 dark" {
  let t = @test.Test("25-dark")
  t.write(corpus_svg(24, Fixed(Dark)))
  t.snapshot(filename="svg/25-dark.svg")
}

///|
test "corpus 25 light" {
  let t = @test.Test("25-light")
  t.write(corpus_svg(24, Fixed(Light)))
  t.snapshot(filename="svg/25-light.svg")
}

///|
test "corpus 26 adaptive" {
  let t = @test.Test("26-adaptive")
  t.write(corpus_svg(25, Adaptive))
  t.snapshot(filename="svg/26-adaptive.svg")
}

///|
test "corpus 26 dark" {
  let t = @test.Test("26-dark")
  t.write(corpus_svg(25, Fixed(Dark)))
  t.snapshot(filename="svg/26-dark.svg")
}

///|
test "corpus 26 light" {
  let t = @test.Test("26-light")
  t.write(corpus_svg(25, Fixed(Light)))
  t.snapshot(filename="svg/26-light.svg")
}

///|
test "corpus 27 adaptive" {
  let t = @test.Test("27-adaptive")
  t.write(corpus_svg(26, Adaptive))
  t.snapshot(filename="svg/27-adaptive.svg")
}

///|
test "corpus 27 dark" {
  let t = @test.Test("27-dark")
  t.write(corpus_svg(26, Fixed(Dark)))
  t.snapshot(filename="svg/27-dark.svg")
}

///|
test "corpus 27 light" {
  let t = @test.Test("27-light")
  t.write(corpus_svg(26, Fixed(Light)))
  t.snapshot(filename="svg/27-light.svg")
}

///|
test "corpus 28 adaptive" {
  let t = @test.Test("28-adaptive")
  t.write(corpus_svg(27, Adaptive))
  t.snapshot(filename="svg/28-adaptive.svg")
}

///|
test "corpus 28 dark" {
  let t = @test.Test("28-dark")
  t.write(corpus_svg(27, Fixed(Dark)))
  t.snapshot(filename="svg/28-dark.svg")
}

///|
test "corpus 28 light" {
  let t = @test.Test("28-light")
  t.write(corpus_svg(27, Fixed(Light)))
  t.snapshot(filename="svg/28-light.svg")
}

///|
test "corpus 29 adaptive" {
  let t = @test.Test("29-adaptive")
  t.write(corpus_svg(28, Adaptive))
  t.snapshot(filename="svg/29-adaptive.svg")
}

///|
test "corpus 29 dark" {
  let t = @test.Test("29-dark")
  t.write(corpus_svg(28, Fixed(Dark)))
  t.snapshot(filename="svg/29-dark.svg")
}

///|
test "corpus 29 light" {
  let t = @test.Test("29-light")
  t.write(corpus_svg(28, Fixed(Light)))
  t.snapshot(filename="svg/29-light.svg")
}

///|
test "corpus 30 adaptive" {
  let t = @test.Test("30-adaptive")
  t.write(corpus_svg(29, Adaptive))
  t.snapshot(filename="svg/30-adaptive.svg")
}

///|
test "corpus 30 dark" {
  let t = @test.Test("30-dark")
  t.write(corpus_svg(29, Fixed(Dark)))
  t.snapshot(filename="svg/30-dark.svg")
}

///|
test "corpus 30 light" {
  let t = @test.Test("30-light")
  t.write(corpus_svg(29, Fixed(Light)))
  t.snapshot(filename="svg/30-light.svg")
}

///|
test "corpus 31 adaptive" {
  let t = @test.Test("31-adaptive")
  t.write(corpus_svg(30, Adaptive))
  t.snapshot(filename="svg/31-adaptive.svg")
}

///|
test "corpus 31 dark" {
  let t = @test.Test("31-dark")
  t.write(corpus_svg(30, Fixed(Dark)))
  t.snapshot(filename="svg/31-dark.svg")
}

///|
test "corpus 31 light" {
  let t = @test.Test("31-light")
  t.write(corpus_svg(30, Fixed(Light)))
  t.snapshot(filename="svg/31-light.svg")
}

///|
test "corpus 32 adaptive" {
  let t = @test.Test("32-adaptive")
  t.write(corpus_svg(31, Adaptive))
  t.snapshot(filename="svg/32-adaptive.svg")
}

///|
test "corpus 32 dark" {
  let t = @test.Test("32-dark")
  t.write(corpus_svg(31, Fixed(Dark)))
  t.snapshot(filename="svg/32-dark.svg")
}

///|
test "corpus 32 light" {
  let t = @test.Test("32-light")
  t.write(corpus_svg(31, Fixed(Light)))
  t.snapshot(filename="svg/32-light.svg")
}

///|
test "corpus 33 adaptive" {
  let t = @test.Test("33-adaptive")
  t.write(corpus_svg(32, Adaptive))
  t.snapshot(filename="svg/33-adaptive.svg")
}

///|
test "corpus 33 dark" {
  let t = @test.Test("33-dark")
  t.write(corpus_svg(32, Fixed(Dark)))
  t.snapshot(filename="svg/33-dark.svg")
}

///|
test "corpus 33 light" {
  let t = @test.Test("33-light")
  t.write(corpus_svg(32, Fixed(Light)))
  t.snapshot(filename="svg/33-light.svg")
}

///|
test "corpus 34 adaptive" {
  let t = @test.Test("34-adaptive")
  t.write(corpus_svg(33, Adaptive))
  t.snapshot(filename="svg/34-adaptive.svg")
}

///|
test "corpus 34 dark" {
  let t = @test.Test("34-dark")
  t.write(corpus_svg(33, Fixed(Dark)))
  t.snapshot(filename="svg/34-dark.svg")
}

///|
test "corpus 34 light" {
  let t = @test.Test("34-light")
  t.write(corpus_svg(33, Fixed(Light)))
  t.snapshot(filename="svg/34-light.svg")
}

///|
test "corpus 35 adaptive" {
  let t = @test.Test("35-adaptive")
  t.write(corpus_svg(34, Adaptive))
  t.snapshot(filename="svg/35-adaptive.svg")
}

///|
test "corpus 35 dark" {
  let t = @test.Test("35-dark")
  t.write(corpus_svg(34, Fixed(Dark)))
  t.snapshot(filename="svg/35-dark.svg")
}

///|
test "corpus 35 light" {
  let t = @test.Test("35-light")
  t.write(corpus_svg(34, Fixed(Light)))
  t.snapshot(filename="svg/35-light.svg")
}

///|
test "corpus 36 adaptive" {
  let t = @test.Test("36-adaptive")
  t.write(corpus_svg(35, Adaptive))
  t.snapshot(filename="svg/36-adaptive.svg")
}

///|
test "corpus 36 dark" {
  let t = @test.Test("36-dark")
  t.write(corpus_svg(35, Fixed(Dark)))
  t.snapshot(filename="svg/36-dark.svg")
}

///|
test "corpus 36 light" {
  let t = @test.Test("36-light")
  t.write(corpus_svg(35, Fixed(Light)))
  t.snapshot(filename="svg/36-light.svg")
}

///|
test "corpus 37 adaptive" {
  let t = @test.Test("37-adaptive")
  t.write(corpus_svg(36, Adaptive))
  t.snapshot(filename="svg/37-adaptive.svg")
}

///|
test "corpus 37 dark" {
  let t = @test.Test("37-dark")
  t.write(corpus_svg(36, Fixed(Dark)))
  t.snapshot(filename="svg/37-dark.svg")
}

///|
test "corpus 37 light" {
  let t = @test.Test("37-light")
  t.write(corpus_svg(36, Fixed(Light)))
  t.snapshot(filename="svg/37-light.svg")
}

///|
test "corpus 38 adaptive" {
  let t = @test.Test("38-adaptive")
  t.write(corpus_svg(37, Adaptive))
  t.snapshot(filename="svg/38-adaptive.svg")
}

///|
test "corpus 38 dark" {
  let t = @test.Test("38-dark")
  t.write(corpus_svg(37, Fixed(Dark)))
  t.snapshot(filename="svg/38-dark.svg")
}

///|
test "corpus 38 light" {
  let t = @test.Test("38-light")
  t.write(corpus_svg(37, Fixed(Light)))
  t.snapshot(filename="svg/38-light.svg")
}
