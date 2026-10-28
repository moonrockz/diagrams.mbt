# Frozen Mermaid state profile

Baseline `mermaid@12.2.0`, commit
`1fb7869866dd619168d840291c9c54b4f129758b`. All 22 state documentation diagrams
are extracted byte-for-byte from `upstream/stateDiagram.md`. Grammar,
`stateDb.ts`, `dataFetcher.ts` and the upstream MIT notice are frozen alongside
the independently authored Apache-2.0 feature fixtures.

`reference.json` comes from the pinned Mermaid database, independently of the
MoonBit converter. It records accepted/refused sources, ordered states, region
ownership, roles, transitions and note attachments. Generated divider IDs are
normalized by their owning composite and occurrence; initial/final IDs are
normalized by region and role. HTML entities are decoded as text. Hostile-label
sanitization differs deliberately: native values retain raw text and SVG escapes
it. Floating notes are retained natively although upstream omits their drawing.

`feature-inventory.json` separates native support, inert presentation, literal
data, library refusals and upstream refusals. Every source has a profile record.
`documentation-coverage.json` accounts for every frozen documented diagram.
`grammar-coverage.json` binds grammar production lines to checked fixtures.
`SHA256SUMS` binds frozen inputs and reference evidence.

Run `mise run state-mermaid-corpus:reference -- --check` for independent original
and canonical source qualification with locked test-only Mermaid/Chromium.
Run `mise run validate:state-mermaid-corpus` for offline digest, source-binding,
coverage and portable embedding checks. Normal four-target MoonBit tests need
no upstream JavaScript, browser or network. The reference adapter rejects
external network requests. These tools do not add a published dependency.
