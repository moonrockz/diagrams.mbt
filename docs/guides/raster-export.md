# Raster export

The optional `moonrockz/diagrams-raster` module converts diagrams.mbt-generated
SVG to PNG and JPEG bytes and exports source-bound playback as animated GIF.
The same pure conversion path runs on wasm, wasm-gc, JavaScript and native.
It requires no browser, external converter, remote service or UI framework.

Use the existing SVG renderer to obtain a complete canonical SVG, then call
`@raster.rasterize(svg)`. PNG is the default. Read `result.image` only after
checking diagnostics. A successful image contains immutable encoded bytes,
media type, format and actual dimensions. Failure has no image payload.
Existing text renderer APIs and original SVG/source bytes remain unchanged.

```moonbit
let result = @raster.rasterize(
  canonical_svg,
  options=@raster.StillOptions::new(size=Width(1200), theme=Light),
)
```

`RasterSize` supports original dimensions, positive finite scale, output width,
output height and a fitting box. The renderer preserves viewBox aspect ratio and
shows the complete diagram. An explicit width or height is exact. Only the
derived axis rounds up. Integral generated bounds use overflow-safe integer
ratios, and a fitting box is a maximum, not a cropping rectangle.

PNG defaults to alpha. JPEG requires an explicit opaque background and quality
from 1 through 100:

```moonbit
let result = @raster.rasterize(
  canonical_svg,
  options=@raster.StillOptions::new(
    format=Jpeg(quality=85),
    size=Fit(1200, 800),
    background=@raster.Rgba::white(),
    theme=Light,
  ),
)
```

Background options replace only the generated top-level background rectangle.
Nested icon, mask and foreground backgrounds remain intact. Adaptive SVG uses
the explicit export theme. Fixed diagram colors retain their supplied values.
Viewport zoom, pan, fullscreen and transient live highlights are absent from a
canonical still export.

## Fonts and supported input

The generated-SVG profile includes sequence, ZenUML, architecture, BPMN,
swimlane, flowchart, regex, EBNF, JSON, YAML and state diagrams. It preserves text
outlines, supplied static font faces, icons, curves, markers, transforms,
clipping and crossing masks. General third-party SVG is outside this contract.
Unsupported elements, styles, resources and required glyphs produce diagnostics.

The licensed default profile uses Noto Sans Mono regular/bold and Noto Sans
Symbols 2, with documented aliases for the SVG writer's monospaced stack. It
covers the current gallery label characters and a broader declared
Latin/Greek/Cyrillic, punctuation, arrow, control-picture and symbol subset.
It never discovers a host font or fetches one.

Supply other supported faces with `FontFace::new(family, bytes, weight=400,
italic=false)` and `FontSet::new`. The static TrueType glyf profile validates
table bounds, cmap references, glyph buffers and compound cycles before parsing.
It supports horizontal kern format 0. A missing family/style or glyph,
unsupported variable/CFF/color glyph profile or text requiring complex shaping
returns a diagnostic instead of a partial label. Format-4 signed wrap mappings
are normalized to equivalent positive format-12 mappings before outlining or
subsetting. Cmap expansion is capped at 1,200,000 mappings before expansion;
subtable copies share a four-times-cmap byte budget, and all font table copies
share the source-unit budget. Aggregate label glyphs are checked before outlines
are allocated.

Build tools can call `fonts.subset_for_svg(svg)` and embed the returned font
bytes in a standalone artifact. The method retains required compound glyphs,
checks supported label coverage and preserves rendered pixels. Font data and
models stay immutable. Exact source revisions, licenses, subset ranges and
hashes are recorded under `pkgs/diagrams-raster/fonts/`.

## Bounds and diagnostics

`RasterLimits` controls source units, XML nodes, dimensions, pixels, label
glyphs, encoded bytes, frames and cumulative animation pixels. The default
limits are 16 Mi UTF-16 source units, 200,000 XML nodes/attributes, 16,384 pixels
per dimension, 16 Mi pixels per image, 100,000 label glyphs, 32 Mi encoded bytes,
300 frames and 64 Mi cumulative animation pixels. Source and font bytes share
an explicit bounded profile; XML depth is at most 256.

Option validation precedes default font loading. Overflow-safe checks reject
excessive dimensions and work. Invalid options, malformed SVG/fonts, missing
resources, unavailable glyphs and exhausted budgets return identified
diagnostics with no successful image. File writing belongs to the caller's
host adapter.

Equal source, fonts and options produce equal encoded bytes on all four targets.
JPEG uses a pinned fixed-point DCT basis, avoiding platform cosine differences.
Independent Chromium decoding checks the stored public PNG, JPEG and GIF
fixtures. The portable snapshot suites compare encoded bytes across targets.

See the [module guide](../../pkgs/diagrams-raster/README.mbt.md) for checked API
examples and the exact font profile. Run `mise run test:raster-consumer` for an
isolated public consumer. `mise run validate:raster-fonts` verifies the licensed
subsets and generated font embedding against committed originals.

## Animated GIF

`export_gif(scene, plan)` samples the source-bound plan and the final scene
paths. Repeated, concurrent and reversed occurrences retain their own timing;
node visits highlight their bound shapes. The inputs stay immutable.
`GifOptions` selects size, theme, opaque background, frame rate, interval and
`Once`, `Forever` or `Repeat` looping. GIF uses a fixed 3/3/2 RGB palette and
has no alpha. Delays round to centiseconds. The exact interval endpoint is
included as a final frame and held for one sample period.

The versioned `gif_export_data` and `export_gif_data` protocol carries the same
scene/plan for an offline worker. It validates source identity, geometry,
schedules and limits. Its fingerprint detects accidental mismatch, not hostile
forgery. Bindings, steps and groups share the XML-node budget; repeated metadata
shares the source-unit budget. Zero-duration and empty schedules are diagnostics. Endpoint-inclusive frame
counts are checked against cumulative pixels and the minimum encoded byte
budget before any timestamp array is allocated, including with custom limits.
See the checked module examples for interval and loop options.

Standalone players embed a compressed worker and validated font subsets. PNG,
JPEG and GIF downloads use the portable library in that worker. They capture
submitted options and the selected plan without changing live playback or
viewport state. Cancel terminates the worker. SVG remains available when raster
validation fails. Worker, Blob and DecompressionStream support are required for
browser raster downloads; static SVG remains usable with scripts disabled.

Generated adapters and standalone HTML retain the converter and default-font
license notices offline. The original source texts are stored with the browser
adapter, and the raster module retains its JPEG adaptation and font records.
