# Native Mermaid flowchart compatibility corpus

The baseline is Mermaid 12.2.0, commit
`1fb7869866dd619168d840291c9c54b4f129758b`. `provenance.json` records primary
sources and licenses. `SHA256SUMS` covers the frozen inputs and oracle values.

All 114 Mermaid examples in the pinned flowchart documentation are present
under `docs/`. Shared grammar-production, shape and semantic cases extend those
examples. The independent browser adapter records 148 accepted fixtures and
three explicit upstream metadata refusals. Node, connection and group ordering,
labels, vector shapes, ownership, local directions, edge IDs, marker forms,
styles and minimum-length hints are tested against these fixtures.

Upstream creates temporary vertices when an edge names a group. The reference
projection records those IDs as group endpoints rather than duplicate model
nodes. It does not change an endpoint to a child node. Mermaid shape aliases are
normalized separately by the shared model registry. Canonical printing is
qualified by reading both the original source and canonical text with the pinned
upstream parser and comparing normalized graph values.

Run `mise run flowchart-mermaid-corpus:reference -- --check` to qualify source
and canonical output. It uses the existing locked `tests/swimlane-reference`
Mermaid dependency and the site's locked Playwright Chromium. Requests are
restricted to its loopback module server. JavaScript is a test dependency only.

Run `mise run validate:flowchart-mermaid-corpus` for offline digest, documentation
coverage, grammar-manifest, source/reference binding and portable embedding
checks. After an intentional corpus change, refresh the digests and reference,
then run `mise run flowchart-mermaid-corpus:generate`. Normal MoonBit tests read
committed fixtures and need neither a browser nor network access. Commit source,
manifest, digests, reference, embedding and canonical snapshots together.
