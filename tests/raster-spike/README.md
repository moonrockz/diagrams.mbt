# Portable raster qualification

The spike selects published `Milky2018/svg@0.6.0` for CPU rendering,
`Milky2018/xml@0.6.1` for bounded generated-SVG normalization,
`mizchi/font@0.7.4` for explicit TrueType outlines,
`mizchi/image@0.4.3` for PNG, an integer JPEG adaptation, and
`walkzzz/image@0.5.0` for animated GIF. Nothing in this path uses a browser,
external converter, host font lookup or remote service.

[evidence.json](evidence.json) records exact archive checksums, licenses,
source digests, dimensions and output hashes. Four target runs produced 43
outputs each: normalized SVG, PNG and JPEG for 14 fixtures, plus one two-frame
GIF. Every corresponding byte sequence matches across wasm, wasm-gc, JavaScript
and native. Pillow 11.3.0 independently decoded every image. The GIF has distinct
371 × 288 frames and 100/200 millisecond delays. Chromium 156.0.8078.4, through
pinned Playwright 1.64.1, independently decoded its frames with WebCodecs.
`ImageDecoder` requires a secure context, including a loopback HTTP origin.

The fixtures use actual checked emitter output for sequence, ZenUML,
architecture, BPMN, swimlane, flowchart, regex, EBNF, JSON, YAML and state. Extra
fixtures exercise adaptive styles, connector crossing masks, a clipped radial
gradient and a transformed provider icon with a luminance mask. The icon
fixture retains original emitted symbol definitions and attribution text.

The browser reference uses the same supplied regular/bold fonts as the software
path. Canonical SVG versus normalized SVG has channel mean absolute error
0–0.434 on a 0–255 scale. Normalized SVG in Chromium versus CPU PNG has error
0.015–0.465. These comparisons accompany decoded dimensions and direct inspection
of labels, arrowheads, icons, gradients, rotated bars, clipping and crossings.
They do not grant a broad error allowance for missing content.

## Resolved candidate gaps

- `mizchi/svg@0.2.3` cannot render the emitted profile directly. It omits path
  gradient fills, ignores rotated rectangle geometry, overwrites alpha through
  its convenience image setter, ignores the alpha component of rgba colors,
  and reverses end markers that use `auto-start-reverse`. It remains a transitive
  font path type dependency, rather than the selected raster renderer.
- `Milky2018/svg@0.6.0` covers those geometry and paint cases. One emitted icon
  mask uses `feFlood` followed by `feBlend`. The normalizer expands that exact
  filter profile to its equivalent white viewport rectangle and original shape.
  An unqualified filter produces a diagnostic.
- Text and `tspan` become paths from explicit regular/bold fonts and fallback
  faces. The normalizer preserves baseline positions and anchors. Required
  glyph absence fails conversion. JSON's emitted U+2611 checkbox required the
  licensed Noto Sans Symbols 2 fallback.
- The published font dependency graph needs modern published overrides for
  zlib, pixelmatch, image, x and async. Older transitive manifests are rejected
  by the pinned compiler. Exact successful versions are in the evidence file.
- `walkzzz/image@0.5.0` PNG emits invalid chunk CRCs, so it is excluded from PNG.
  Its JPEG API lacks quality and its GIF encoder fixes the loop extension to
  infinite. Production must validate GIF frame budgets and adapt that binary
  extension to the requested loop option.
- `mizchi/image@0.4.3` JPEG computes its DCT cosine basis through platform math.
  An isolated probe found one-ULP native/JS differences at three basis entries.
  That produces different JPEG bytes despite equal input pixels. The adapted
  encoder retains the published baseline JPEG structure and tables but uses
  exact integer RGB conversion and a pinned 14-bit integer DCT basis.

## Reproduce the portable fixture

From the repository root, run each target, redirecting encoded outputs to local
files because the fixture writes base64 image data:

```sh
mise exec -- moon run tests/raster-spike/cmd --target wasm
mise exec -- moon run tests/raster-spike/cmd --target wasm-gc
mise exec -- moon run tests/raster-spike/cmd --target js
mise exec -- moon run tests/raster-spike/cmd --target native
```

The command's source contains the qualified input bytes and font bytes. It is an
unpublished acceptance fixture. Production adoption still requires the bounded
public API, supplied font style selection, invalid input diagnostics, JPEG opaque
composition, output budgets, GIF sampling, browser integration and fresh consumers.
Those are tracked by groups 2–7 of `refresh-site-and-diagram-viewers`.

## Upstream sources and licenses

[Milky2018/svg](https://github.com/Milky2018/svg),
[Milky2018/xml](https://github.com/moonbit-community/xml-mbt),
[mizchi/font](https://github.com/mizchi/font),
[mizchi/image](https://github.com/mizchi/image-mbt), and the JPEG adaptation use
Apache-2.0. [walkzzz/image](https://github.com/toadium/stb-image) uses MIT.
The complete registry dependency record is in `evidence.json`.

Font originals and exact source provenance are in
`pkgs/diagrams-raster/fonts/`. They come from notofonts/noto-fonts commit
`ffebf8c1ee449e544955a7e813c54f9b73848eac` under SIL OFL-1.1.
