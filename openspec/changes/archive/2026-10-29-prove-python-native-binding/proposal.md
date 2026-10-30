# Proposal

## Why

Python users could use the existing Mermaid reader and SVG renderer without a
second implementation. The stable MoonBit documentation says that the native
backend cannot export a linkable library. Before we plan Python packages, we
must know if a CPython extension can call the MoonBit native C backend in the
same process. We must also know what this needs for diagnostics, lifetime,
repeatable builds and deployment.

## What Changes

- Add a feasibility spike: an unpublished module in `apps/python-native/`.
- Export one narrow C entry point from a native MoonBit package. It takes UTF-8
  source bytes and returns a versioned UTF-8 JSON result. This result contains
  the SVG text or structured diagnostics. It reuses `render_svg` from
  `moonrockz/diagrams-mermaid` without change.
- Add a small CPython extension adapter in C and a Python wrapper with an
  illustrative `render_svg(source)` function. They call the MoonBit code in the
  same process. They hold the GIL and serialize calls.
- Add a native MoonBit oracle that writes the direct output of `render_svg` for
  the shared fixtures. The Python tests compare their results with it.
- Add `scripts/python-native.mbtx` and mise tasks. They build the extension from
  a clean tree, run the Python tests, run a sanitizer build and measure repeated
  calls.
- Add a feasibility report. It records the toolchain, the linkage and runtime
  approach, the results, the limits, the deployment and ABI risks, and the next
  steps.

## Capabilities

### New Capabilities

- `python-native-binding`: Experimental in-process Python access to Mermaid SVG
  rendering through the MoonBit native backend, with structured diagnostics.

### Modified Capabilities

None.

## Out of Scope

- Wheels for more than one platform, PyPI publication and release automation.
- A stable or production Python API, and typed bindings for each diagram model.
- Raster, GIF, HTML playback and PlantUML or BPMN bindings.
- Thread-safety, free-threaded CPython and subinterpreter support. The spike
  makes no claim about them.
- A subprocess or WebAssembly fallback presented as the native result.
- Changes to the parser, the renderer or the published library modules.
- A release of any module.

## Tracking

The user approved the spike scope on 2026-10-29 in the Orca dispatch for this
workspace. One epic and one story per task group track the work in beads. The
`Bead:` lines in `tasks.md` hold the IDs.

## Impact

- New unpublished workspace member `apps/python-native/` and its registration in
  `moon.work`. It does not change the published modules.
- New task script `scripts/python-native.mbtx` and mise tasks that select a
  pinned CPython for those tasks only.
- No change to public library APIs, outputs or the release pipeline.
