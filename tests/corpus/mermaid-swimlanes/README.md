# Native Mermaid swimlane compatibility corpus

The frozen primary sources and their licences are recorded in `provenance.json`.
`SHA256SUMS` covers every corpus input. The thirteen upstream documentation
examples, complete shared-grammar production manifest, shape-alias manifest and
project-authored cases are checked by the native reader and canonical printer.

`reference.json` captures the locked Mermaid 12.2.0 database semantics. The test-only
browser adapter loads modules on loopback and refuses external requests. It parses
both frozen sources and the MoonBit canonical output; the three native refusals
under `extensions/` must remain refused. This oracle is independent of MoonBit
semantic normalization, geometry and SVG assertions.

Run `mise run validate:swimlane-corpus` for the deterministic digest and generated
embedding check. To intentionally update frozen cases, record provenance, update
`SHA256SUMS`, and run `mise run swimlane-corpus:reference`. When adding a case,
bootstrap the raw reference with `mise exec -- moonx scripts/swimlane-reference.mbtx
--bootstrap`, regenerate the embedding, then update the acceptance canonical
snapshot. Finally run the reference task with `--check`; bootstrap alone does not
qualify canonical compatibility. Commit the source, digests, generated embedding,
reference data and canonical snapshot together.

Metadata remains typed, including nonfinite scalars. The bounded pure YAML adapter
uses the pinned Apache-2.0 MoonYAML resolver and MIT event parser listed in
provenance. WHATWG entity data carries its own licence, also packaged inside the
published Mermaid module as `NOTICE-WHATWG`.
