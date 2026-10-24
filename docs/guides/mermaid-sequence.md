---
title: Mermaid sequence diagrams
summary: Read Mermaid sequence text and render a standalone SVG.
order: 1
---
# Mermaid sequence diagrams

Use `moonrockz/diagrams-mermaid` to read Mermaid sequence text and render SVG.
The reader follows the sequence grammar of Mermaid 12.2.0. The SVG has the
classic archify colours, an opaque background and accessible title and
description text. It needs no script, external font or network request.

## A rendered example

```text
sequenceDiagram
    Alice->>John: Hello John, how are you?
    John-->>Alice: Great!
    Alice-)John: See you later!
```

![Alice sends a greeting, John replies, and Alice sends an asynchronous farewell.](sequence.svg)

This image is the adaptive SVG of frozen corpus example 01. It uses dark
colours by default and follows the viewer's light preference.

## Render and check diagnostics

```moonbit notest
let result = @mermaid.render_svg(source)
// Inspect result.diagnostics before using result.output.
```

`render_svg` runs reading, model conversion, layout and painting. It returns
all diagnostics. A missing sequence header gives no output. Recovered syntax
or semantic problems can still give output, so check diagnostics even when
output exists.

For canonical writing, use `read`, `print` and `to_sequence` separately. For
fixed colours, pass the converted model to `SvgRenderer::new(mode=Fixed(Light))`
or `Fixed(Dark)`. Fixed SVG uses literal presentation attributes for slide
tools. The default adaptive SVG uses embedded CSS.

The [Mermaid package guide](../../pkgs/diagrams-mermaid/README.mbt.md) has
compiled examples, syntax rules, links and diagnostic codes. The
[SVG package guide](../../pkgs/diagrams-svg/README.mbt.md) describes fixed
themes, render properties, layout geometry and legibility checks.

## Review the complete corpus

Run `mise run gallery` from the repository root. Open `_gallery/index.html` to
compare all 38 frozen examples in dark and light. The task checks the SVG
snapshots against the current renderer first. Each pair includes its Mermaid
source. Run `mise run test:svg` for browser checks of standalone SVG and theme
behaviour.
