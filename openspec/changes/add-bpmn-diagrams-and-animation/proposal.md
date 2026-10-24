# Proposal

## Why

diagrams.mbt can draw sequence diagrams, but it cannot read or draw BPMN business
processes and collaborations. Callers also need an independent BPMN document
library and animated diagrams that help readers follow interactions and inspect
possible routes.

## What Changes

- Add the independent module `moonrockz/bpmn` in this workspace. Provide a
  lossless XML CST, typed document values, diagnostics, deterministic writing,
  reference lookup and traversal. The module has no diagram dependency.
- Use BPMN 2.0.2 as the document authority. Keep processes, collaborations,
  choreography, conversations, diagram interchange and vendor extensions in the
  document model. Deliver process and collaboration diagram rendering first.
- Add `moonrockz/diagrams-bpmn` to convert a selected BPMN view to an immutable
  BPMN diagram model, with source identities and diagnostics.
- Add BPMN layout and painting to `moonrockz/diagrams-svg`. Use valid supplied
  BPMN diagram interchange geometry, or compute a deterministic layout when
  geometry is absent. Keep the standard BPMN symbols and the archify palette.
- Add pure motion plans and directed route queries, and a separate
  `moonrockz/diagrams-animated` renderer. It returns a standalone HTML artifact
  with inline SVG, playback controls and path exploration. Support both BPMN
  and the existing sequence model. Animation illustrates authored relationships;
  it does not execute BPMN conditions or business work.
- **BREAKING:** add a BPMN case to the public `Diagram` enum. Callers that match
  that enum exhaustively must add a case. Document this source change.

## Out of scope

- Choreography and conversation layout, painting and animation. Their document
  content remains readable, writable and traversable. Rendering those views
  gives an explicit unsupported-view diagnostic until a later change.
- A BPMN execution engine, token simulation, expression evaluation, task
  execution, message delivery, timer scheduling or execution-conformance claims.
- A diagram editor, hosted viewer, UI framework package or Rabbita dependency
  in a published module. Browser interaction is confined to the generated HTML.
- General XML tooling as a separate public module, XML signatures, XML C14N,
  automatic network resolution, raster/video export and a version release.

## Capabilities

### New Capabilities

- `bpmn-documents`: independent BPMN XML reading, immutable typed documents,
  source reproduction, canonical writing, diagnostics and explicit references.
- `bpmn-traversal`: deterministic containment traversal and separate graph
  queries over document identities and references.
- `bpmn-diagrams`: process/collaboration model conversion, view selection,
  layout, legibility and standalone SVG output.
- `diagram-animation`: deterministic motion plans, directed path exploration
  and standalone animated HTML for BPMN and sequence diagrams.

### Modified Capabilities

None. The existing sequence model and script-free standalone SVG contracts
continue to apply. Animated HTML has its own output contract.

## Impact

- New modules: `pkgs/bpmn`, `pkgs/diagrams-bpmn` and
  `pkgs/diagrams-animated`. Register them in `moon.work` and the version and
  publication tooling in dependency order. Publication needs a separate approval.
- Extend `pkgs/diagrams` with the BPMN diagram model and motion contracts;
  extend `pkgs/diagrams-svg` with BPMN geometry and rendering. Preserve existing
  sequence SVG bytes when callers use the existing options.
- Reuse the theme, text measurement and XML escaping where their contracts fit.
  The standalone BPMN module depends on core libraries only. Frozen OMG schema
  data and test-only reference tools retain their source and licence notices.
- Add an unpublished BPMN corpus, standalone-consumer acceptance tests, browser
  animation checks, a gallery, tested module examples and documentation.
- Keep all public library operations pure and portable across wasm, wasm-gc,
  js and native. Put clock, DOM and playback effects in the emitted browser
  runtime, and filesystem/process effects in task scripts or host adapters.
