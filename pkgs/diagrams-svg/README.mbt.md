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

Generated marker IDs and adaptive CSS use a deterministic namespace derived
from the output, including its palette and mode. For repeated inline copies of
the same diagram with separate root overrides, supply a distinct `id_prefix`
to each copy. Both entry points accept it. The prefix is encoded into an XML
and CSS safe identifier; labels and other user text stay unchanged.

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

## BPMN processes and collaborations

`SvgRenderer` also accepts `Diagram::Bpmn`. Its `bpmn_policy` is `PreferDi` by
default: complete selected DI is painted as supplied; missing or partial DI
computes the whole view with a warning. `RequireDi` requires every visible shape
and connection to have geometry. `Automatic` computes the whole view explicitly.
Invalid supplied coordinates return an error under the first two policies.
Source conversion and selection are provided by `moonrockz/diagrams-bpmn`.
Choreography and conversation rendering remain deferred.

Automatic layout condenses cycles, ranks scopes, allocates measured lane/group
bands and routes orthogonal connections around shapes and labels within bounded
search limits. Its checked module guide describes policies and failure results.

The separate `bpmn-layout` package retains exact decimal/exponent tokens for
shape bounds, label bounds and edge waypoints. Every element shares one viewport
translation, including pools, lanes, expanded subprocesses and boundary events.
The painter covers task icons, event definitions, gateway forms, activity and
collection markers, data, groups, annotations and all connection kinds. Collapsed
scopes hide their contents; message connections can anchor to a visible scope
without changing their semantic endpoints. Pools and expanded containers paint
behind their contents. Fonts and selected display flags come from typed DI.

BPMN uses the shared theme's hues with text shades checked at 4.5:1 against its
painted backgrounds. Adaptive and fixed modes, accessibility title/description,
caller ID prefixes and inert render metadata work for both diagram kinds.
`bpmn-layout.check` reports overlaps, text fit, 11 px minimum size, contrast,
containment, boundary attachment and endpoint attachment. It allows intentional
container and artifact overlap. Findings never rearrange supplied geometry.

`bpmn_limits` bounds nodes, connections, geometry work and output units. Numeric
coordinates must be finite, have positive shape extents and absolute magnitude
at most one billion. Exhaustion returns diagnostics with no partial output.
Generated coordinates use deterministic three-decimal formatting; supplied
coordinate tokens stay unchanged. Forbidden XML characters produce an error.

The rendering corpus under `tests/corpus/bpmn-render` provides complete supplied
process and collaboration examples. Portable snapshots cover all 38 standard
graphical kinds, the ten event definitions, activity and gateway markers, theme
modes, escaping and ID isolation. `mise run test:svg` also checks those snapshots
in Chromium, including both system preferences, contrast, translated coordinates
and offline playback. Existing sequence SVG snapshots remain byte-identical.

## Notice

The colour values, shapes, monospace font stack and spacing of the classic
theme come from archify v3.2 by tt-a1i, under the MIT licence. The painter and
layout are implemented in MoonBit for this library. In the light theme, six
text colours are darker shades of archify's colours, so that text has at least
4.5:1 contrast.

## Motion scenes

`SvgRenderer::scene` returns the ordinary canonical SVG, a script-free display
copy, a source catalog and immutable path/node bindings. Both copies use one
measured geometry. Only the display copy gains invisible scoped numeric paths;
existing symbols, labels, styles, arrowheads and coordinates are unchanged.
BPMN bindings inherit the common viewport translation. Sequence bindings retain
message containment paths, including self-loops and nested frame occurrences.

```mbt check
///|
test "canonical scene SVG equals the ordinary static renderer" {
  let sequence = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [Message(@sequence.Message::new("A", "B", "hello"))],
  )
  let renderer = @svg.SvgRenderer::new()
  let scene = renderer.scene(Sequence(sequence)).scene.unwrap()
  assert_eq(scene.canonical_svg, @svg.render_sequence(sequence))
  assert_false(scene.canonical_svg.contains("data-motion-paths"))
  assert_true(scene.display_svg.contains("data-motion-paths"))
  assert_eq(scene.paths.length(), 1)
}
```

Scenes accept separate catalog/search limits and a conservative total output
bound. Sequence scene input also bounds visible participants and text work before
layout. Invalid bindings or exhaustion return no partial scene. `id_prefix`
continues to isolate adjacent copies. Standalone playback and canonical download
are provided by `moonrockz/diagrams-animated`.

## Native Mermaid swimlanes

`Diagram::Swimlane` and `render_swimlane` use the independent immutable
`diagrams/swimlane` model. Mermaid source conversion is in the Mermaid module.
Swimlane geometry imports no BPMN model or document types. Existing sequence
and BPMN static SVG bytes remain unchanged.

```mbt check
///|
test "swimlane SVG and scene share one actual handoff path" {
  let view = @swimlane.Swimlane::new(
    "Request",
    [
      @swimlane.Node::new("Ask", lane="Customer", shape="stadium"),
      @swimlane.Node::new("Review", lane="Support", shape="diamond"),
    ],
    [@swimlane.Connection::new("handoff", "Ask", "Review", label="request")],
    lanes=[@swimlane.Lane::new("Customer"), @swimlane.Lane::new("Support")],
    direction=LR,
  )
  let renderer = @svg.SvgRenderer::new(id_prefix="request")
  let result = renderer.render(Swimlane(view))
  assert_eq(result.diagnostics, [])
  let scene = renderer.scene(Swimlane(view)).scene.unwrap()
  assert_eq(scene.canonical_svg, result.output.unwrap())
  assert_eq(scene.paths.length(), 1)
  assert_true(scene.canonical_svg.contains("d=\"" + scene.paths[0].path + "\""))
}
```

All four flow directions retain lane order across the flow axis. Local lane and
group directions use their own scope. Empty lanes and unowned nodes remain
visible. Nested groups reserve header text; collapsed groups hide descendants.
Cross-boundary handoffs retain logical endpoints and attach to the visible
collapsed ancestor. Internal hidden connections have no visible occurrence.

The painter supports the pinned Mermaid 12.2.0 vector registry and legacy
ellipse form. It keeps distinct shapes, dotted/thick lines and arrow, circle and
cross markers. Unknown shapes and image/icon assets return an error with no
output. The library never fetches assets. HTML and Markdown labels use an inert
text projection and give a warning. Author CSS and callbacks remain source data;
links are escaped `data-link` values without active navigation.

`swimlane_limits` bounds visible/input elements, connections, nesting, geometry
work and output size. A failed layout, unsupported shape, forbidden XML character
or exhausted output budget returns diagnostics with no SVG. Explicit `id_prefix`
values isolate marker IDs and adaptive styles for adjacent inline copies.
Adaptive and fixed dark/light palettes keep the existing theme hues with ink
checked against canvas and node fills.

`diagrams-svg/swimlane-layout.check` checks ownership, measured fit, minimum
11 px text, 4.5:1 contrast, unrelated overlaps, labels and real vector endpoints.
Use `swimlane-layout.palette` for the same ink shades as the painter. Layout
computes one geometry for both static rendering and motion bindings. It retains
each parallel connection's identity and excludes invisible constraints from SVG
and playback. Existing playback and canonical SVG downloads also work for this
kind through `diagrams-animated`.
