# moonrockz/diagrams-svg

Standalone SVG for the diagram models of diagrams.mbt, in the visual style of
archify. The SVG is one file with no scripts, no font data and no external
references, so it works in a web page, in a GitHub README and in Markdown.

The layout and painter cover every sequence element, including self-messages,
all arrowhead values, central connections, notes, nested activations, frames
with section dividers, box groups, creation and destruction.

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

## Fixed output and render properties

Use `mode=Fixed(Dark)` or `mode=Fixed(Light)` for slide tools and viewers that
need literal SVG presentation attributes. Fixed output has no style element,
CSS variables or media rules. Both entry points accept `theme` and `mode`.

```mbt check
///|
test {
  let s = @sequence.Sequence::new([], [], title="Login flow")
  let svg = @svg.render_sequence(s, mode=Fixed(Light))
  assert_false(svg.contains("<style"))
  assert_false(svg.contains("var("))
  assert_true(svg.contains("fill=\"#f4f5f7\""))
}
```

A participant's render kind selects its colour family. Actor and client use
cyan; service and control use green; database, collections and entity use
violet; queue uses orange; boundary uses rose; resource uses amber. Plain
participants cycle through cyan, green, violet, amber and orange. Only plain
participants advance the cycle. Requests use their sender's family, dotted
replies use grey dashed lines, and cross heads use rose. Text uses a shade of
the accent that passes 4.5:1 against both the background and opaque label chips.
The theme computes the shade by lowering HSL lightness in 0.01 steps.

Author colours on box groups and rect frames become 18 percent tints over an
opaque theme-background mask. Authored alpha multiplies the tint opacity.
Supported colours are the CSS named colours, transparent, hex with optional
alpha, and comma or space forms of `rgb()` and `rgba()`. Context-dependent
colours such as `currentColor` cannot resolve in standalone output. An
unreadable colour gives `svg/invalid-colour` and uses the theme's external fill.
Label chips and participant masks keep text contrast independent of those tints.

Participant and message sublabels appear below the main label. A Smithy shape
label that matches its link target shows the short shape name. Participant
groups expose `data-id`; message groups expose `data-index`, `data-from`,
`data-to`, `data-sender-head` and `data-receiver-head`. Both expose `data-link`
when present, and render descriptions as `data-description`. These attributes
are metadata, so they do not navigate or load a resource. The SVG title prefers
the accessibility title, then the diagram title. Its description prefers the
accessibility description, then a generated participant and message count.

## Renderer verification

`mise run test` checks stored SVG snapshots of all 38 corpus diagrams in
adaptive, fixed dark and fixed light modes on all four targets. Snapshots live
under `tests/acceptance/__snapshot__/svg/`. To refresh them after an intentional
paint change, run `mise exec -- moon test --target js --update` and review the
diff.

`mise run test:svg` also uses the pinned Playwright Chromium to parse the
standalone XML, reject active or external content, check local marker
references, exercise both system preferences and both root overrides, and
check contrast from the browser's resolved paint colours. The existing site
test path runs that browser check with its installed Chromium.

## Layout geometry

`layout.layout(sequence)` is a pure function. It measures monospace text with
`moonbit-community/metrics`, solves column widths and gaps, then advances a row
cursor through the ordered events. Multi-line labels accept newlines and
`<br>`, `<br/>` or `<br />`. `Label.content` has normalized newlines; its box
covers the widest line and every line's height. The baseline belongs to the
first line. Render sublabels, visible message numbers and short Smithy link
labels are measured before spacing is calculated.

Columns retain participant order. A message crossing several gaps distributes
any missing width equally among those gaps, with at most one pixel of rounding
difference. If activations or group borders block a label, the layout reserves
an additional clear interval and places its chip as close to the message centre
as that interval permits. Lifelines can pass behind opaque chips. Side notes
and self-messages reserve lanes beside their participants. Adjacent message
rows are at least 28 px apart; the ordinary row advance is 48 px and grows for
multi-line text, self-messages and other events.

`Geometry` exposes these values for painters and callers:

| Value | Geometry |
| --- | --- |
| `participants` | Boxes, labels, optional sublabels, source participants and each participant's lifeline start and end |
| `messages` | Chips, labels, optional sublabels, source messages and ordered `path` segments, including all three segments of a self-message |
| `notes` | A measured note box and its text; an over note spans its anchors and places text clear of activation bars |
| `activations` | Bars 10 px wide; each nesting depth moves 4 px right; an open activation ends at destruction or diagram end |
| `frames` | Frames in preorder, parent indices, header chips and ordered sections with their labels and divider segments |
| `groups` | Source groups, enclosing boxes and title chips; titles use separate member gaps when group extents interleave |
| `title` and `title_box` | The measured diagram title and its reserved area |

A newly created participant's box is centred on its following message row, and
its lifeline starts below the box. A destruction ends the lifeline at the
destroying message and marks the participant for a cross. An activation after
creation starts below the new box. The geometry keeps author colour spellings
on frame and group values for the painter. The aggregate `lifeline_top` and
`lifeline_bottom` describe the diagram extent; use the participant's own values
for its actual lifetime.

## Legibility

The public `layout.check(geometry, palette)` checks every text block, including
frame and section labels, group titles, notes, sublabels and the diagram title.
It checks measured width and height, containment in the actual box or chip and
canvas, a minimum size of 11 px, and contrast of at least 4.5:1.

Overlap checks include other labels and opaque chips, participant and note
boxes, activation bars, every message path segment, frame and group borders,
section dividers and destruction crosses. A label may cover its own element's
line or container. Lifelines are excluded because chips can mask them.

Contrast composes `Label.backdrop` layers in paint order over the palette
background, then composes the text alpha over that result. Layers can be a
palette mask, a family fill or an explicit `Layer::Tint(Color)`. Text can use a
palette role or an explicit `Ink::Color(Color)`. Palette backgrounds are opaque.
Both classic palettes pass the check for all 38 frozen corpus diagrams. The renderer gives each finding as a
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

The colour values, shapes, monospace font stack and spacing of the classic
theme come from archify v3.2 by tt-a1i, under the MIT licence. The painter and
layout are implemented in MoonBit for this library. In the light theme, six
text colours are darker shades of archify's colours, so that text has at least
4.5:1 contrast.
