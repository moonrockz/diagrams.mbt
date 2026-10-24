# diagrams.mbt acceptance tests

This module is not published. It holds acceptance tests that use more than one
module of the workspace, for example a Mermaid source rendered to SVG.

Run the tests with `mise run test`.

Run `mise run gallery` and open `_gallery/index.html` to review all corpus
diagrams in dark and light, with their source. The task verifies the current
renderer against the stored SVG snapshots before it writes the gallery.

The acceptance snapshots keep each of the 38 frozen Mermaid diagrams as
adaptive, fixed dark and fixed light SVG. `mise run test:svg` checks those files
and the SVG package's edge-case snapshots in Chromium, including XML validity,
standalone references, adaptive overrides and rendered text contrast.
