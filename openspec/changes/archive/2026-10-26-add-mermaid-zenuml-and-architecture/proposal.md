# Proposal

## Why

Users need to read and render Mermaid's ZenUML interactions and architecture
diagrams with the same portable library used for sequences, BPMN and swimlanes.
Participant annotators must produce visible symbols, including the cloud and
technology symbols that identify the systems in an interaction.

## What Changes

- Add `zenuml` reading, lossless syntax, a typed AST, canonical printing and
  conversion to the shared sequence model. Support the documented messages,
  nested calls, returns, creation, comments and control fragments.
- Render the complete participant icon registry of the pinned ZenUML reference,
  including UML, cloud, application and technology annotators. Preserve annotator
  identity separately from participant kind. Carry the symbols into offline
  playback and static export.
- Add `architecture-beta` reading, lossless syntax, canonical printing and
  conversion. Cover groups, services, junctions, ports, edge labels, arrows,
  group-boundary connections, row/column alignment and accessibility fields.
- Add an immutable architecture model, bounded deterministic layout and standalone
  SVG with built-in architecture icons. Add architecture playback and structural
  route exploration through the existing animation contracts.
- Extend the existing Mermaid dispatch API and SVG convenience operation to both
  headers. Preserve sequence-specific APIs and existing static output for inputs
  that do not use the new model fields or fragment kinds.
- **BREAKING:** add public parsed-diagram, diagram and animation enum cases, and
  sequence fragment cases needed for ZenUML. Document exhaustive-match migration.

## Out of scope

- Headerless standalone ZenUML, C4, general cloud deployment modelling, additional
  diagram languages, or conversion between architecture and BPMN/swimlanes.
- Executing conditions, calls, exceptions or infrastructure. Playback describes
  the authored diagram and explicit scenarios.
- Mermaid pixel matching, runtime JavaScript parser dependencies, UI packages,
  network icon lookup, arbitrary source-supplied SVG or new icon packs supplied
  by callers. Unknown icon names receive explicit diagnostics and a visible
  labelled fallback.
- A release or publication.

## Capabilities

### New Capabilities

- `mermaid-zenuml`: native Mermaid ZenUML syntax, printing, diagnostics and
  sequence conversion under a frozen compatibility profile.
- `diagram-icons`: immutable icon references, complete pinned annotator coverage
  and portable inline vector rendering with explicit unknown-icon behavior.
- `mermaid-architecture`: Mermaid architecture syntax, printing, diagnostics and
  conversion under the Mermaid 12.2.0 grammar.
- `architecture-model`: ordered groups, services, junctions, explicit endpoint
  ports, connections, alignment and validation independent of source format.
- `architecture-svg-rendering`: bounded layout, port routing, icon painting,
  legibility and standalone themed architecture SVG.

### Modified Capabilities

- `sequence-model`: participant icon references and typed exception fragments.
- `sequence-svg-rendering`: participant symbols and exception-fragment painting.
- `diagram-animation`: architecture catalogs, route queries and offline playback,
  plus preservation of ZenUML symbols and sequence fragment structure.

## Impact

- Add packages inside `pkgs/diagrams`, `pkgs/diagrams-mermaid` and
  `pkgs/diagrams-svg`; extend `pkgs/diagrams-animated`. Keep the core models free
  of syntax, DOM and icon-file dependencies. No new published module is required.
- Use Mermaid 12.2.0 for architecture and documentation examples. Freeze
  `@mermaid-js/mermaid-zenuml@1.0.1` with `@zenuml/core@3.47.9` as the separate
  ZenUML semantic reference. Upstream JavaScript is test-only.
- Package normalized vector assets with source, digest, licence and attribution
  records. Embed only used symbols in each output. Do not import the upstream UI.
- Extend the frozen corpora, four-target acceptance tests, gallery, module guides
  and existing browser qualification. Keep automation in MoonBit task scripts.
- Create a beads epic and one story per task group after maintainer approval, as
  required by `CONTRIBUTING.md`.
