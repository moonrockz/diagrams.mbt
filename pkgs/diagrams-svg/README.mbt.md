# moonrockz/diagrams-svg

Standalone SVG for the diagram models of diagrams.mbt, in the visual style of
archify. The SVG is one file with no scripts, no font data and no external
references, so it works in a web page, in a GitHub README and in Markdown.

This is the first part of the OpenSpec change `add-mermaid-sequence`. Today the
renderer draws participants, lifelines and solid messages with arrowheads. The
other sequence elements and the fixed-colour theme mode come in the next parts
of the change.

## Render a sequence

`SvgRenderer` implements the `Renderer` trait of `moonrockz/diagrams/render`.
The SVG uses the dark theme by default and the light theme when the viewer
prefers light. A `data-theme="dark"` or `data-theme="light"` attribute on the
root element overrides the viewer preference.

```mbt check
///|
test {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("Client"), @sequence.Participant::new("API")],
    [Message(@sequence.Message::new("Client", "API", "GET /forecast"))],
  )
  let r = @render.Renderer::render(@svg.SvgRenderer::new(), Sequence(s))
  assert_eq(r.media_type, "image/svg+xml")
  assert_eq(r.diagnostics.length(), 0)
  let svg = r.output.unwrap()
  assert_true(svg.contains("@media (prefers-color-scheme: light)"))
  assert_true(svg.contains("data-id=\"Client\""))
}
```

## Legibility

The layout is checked before it is painted. The check finds overlapping labels,
labels that do not fit, text smaller than 11 px, and text with less than 4.5:1
contrast against the colour behind it. The renderer gives each finding as a
`svg/legibility` warning. You can also check a layout with your own palette.

```mbt check
///|
test {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [Message(@sequence.Message::new("A", "B", "hello"))],
  )
  let g = @layout.layout(s)
  let theme = @theme.Theme::classic()
  assert_eq(@layout.check(g, theme.dark), [])
  assert_eq(@layout.check(g, theme.light), [])
}
```

## Notice

The colour values, shapes and spacing of the classic theme come from archify
(MIT licence). In the light theme, six text colours are darker shades of
archify's colours, so that text has at least 4.5:1 contrast.
