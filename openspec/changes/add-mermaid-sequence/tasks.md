# Tasks: add-mermaid-sequence

Epic: `diagrams-67z`. The owner approved the design on 2026-10-23.

Each numbered group is one beads story. Claim one story, implement and verify
it, then tick its tasks and close that story. Each story carries its own tests
and documentation. Run `mise run format`, `mise run check` and
`mise exec -- openspec validate --all --strict` before closing a story.

## 1. Prove a thin path from Mermaid text to SVG

Bead: `diagrams-67z.1`.

- [x] 1.1 Create `pkgs/diagrams-mermaid`, `pkgs/diagrams-svg` and the unpublished `tests` module, register them in `moon.work` with the root version, and verify that `mise run validate` passes.
- [x] 1.2 Add `moonbit-community/metrics` to `diagrams-svg`, and verify that a measure call builds and passes a test on wasm, wasm-gc, js and native.
- [x] 1.3 Add the minimum `sequence` model, `render` trait and `Diagram` enum to `moonrockz/diagrams`, and verify them with unit tests.
- [x] 1.4 Read `sequenceDiagram` with two participants and one `->>` message into a CST, AST and model; verify CST reproduction, printing and conversion in tests.
- [x] 1.5 Lay out and render that diagram as adaptive SVG with the archify classic tokens; verify a stored snapshot, identical bytes on all four targets, and a passing legibility check.
- [x] 1.6 Write the first README section of each new module with a runnable example, and verify that the example runs in `mise run test`.

## 2. Read the complete Mermaid sequence syntax

Bead: `diagrams-67z.2`.
Depends on: `diagrams-67z.1`.

- [x] 2.1 Freeze the Mermaid 12.2.0 sequence documentation examples in `tests` with source, licence and SHA-256 digest, and verify the digests in a test.
- [x] 2.2 Complete the lexer and the lossless CST for every statement, arrow form, comment and directive of the grammar; verify CST reproduction for the corpus, CRLF sources and non-BMP text.
- [x] 2.3 Add error recovery and the diagnostic codes with UTF-16 spans; verify one test for each code, the two-errors case and the missing-`end` case.
- [x] 2.4 Document each diagnostic code in the `diagrams-mermaid` README, and verify that a test lists the same codes as the README.

## 3. Type the AST and print canonical Mermaid

Bead: `diagrams-67z.3`.
Depends on: `diagrams-67z.2`.

- [x] 3.1 Complete the typed AST for every statement, with the exact arrow spelling, and verify that each corpus diagram lowers with no error diagnostics.
- [x] 3.2 Implement the canonical printer and document its order and spelling rules; verify the read-print-read law and print stability for the corpus on all four targets.

## 4. Complete the sequence model and the Mermaid conversion

Bead: `diagrams-67z.4`.
Depends on: `diagrams-67z.3`.

- [ ] 4.1 Complete the model: head values, frames with sections, notes, activations, creation, destruction, box groups, title, accessibility fields, autonumber, links and render properties; verify immutability and each model scenario in tests.
- [ ] 4.2 Convert the AST to the model with implicit participants, the activation shorthand and semantic diagnostics; verify each conversion scenario.
- [ ] 4.3 Make links from `link` and `links` statements and from shape ID labels; verify the four link scenarios and the Smithy shape ID grammar edge cases.
- [ ] 4.4 Add the fixture script that runs `moonbit-community/mermaid` on the corpus, write the fixtures, and verify that the model matches them for participants, messages and frames.
- [ ] 4.5 Add the link resolution contract with a test resolver, and verify the found and not-found scenarios.

## 5. Lay out every sequence element

Bead: `diagrams-67z.5`.
Depends on: `diagrams-67z.4`.

- [ ] 5.1 Lay out columns and rows with gaps from measured label widths; verify the long-label scenario and the spacing rules in tests.
- [ ] 5.2 Lay out self-messages, notes, nested activations, nested frames with sections, box groups, creation and destruction; verify the geometry of each with focused tests.
- [ ] 5.3 Implement the public legibility check for overlap, fit, text size and contrast with alpha composition; verify that it finds each kind of problem in a broken layout and finds nothing in the corpus.

## 6. Paint the complete archify look

Bead: `diagrams-67z.6`.
Depends on: `diagrams-67z.5`.

- [ ] 6.1 Implement the XML writer with attribute and text escaping, and verify well-formed output and escaping of `<`, `&`, `"` and control characters.
- [ ] 6.2 Paint every element with the archify classic tokens, kind colour families, the colour cycle, message colours and arrowhead markers for each head value; verify the style scenarios and the snapshots of the corpus.
- [ ] 6.3 Compute the text shades of the accents and paint author colours as tints; verify the stored shade values, the three colour scenarios and a contrast test for each shade.
- [ ] 6.4 Implement the adaptive and fixed theme modes; verify the fixed-mode scenario by text checks and the adaptive scenarios in a Playwright check with light and dark preference.
- [ ] 6.5 Use render properties in the output and write the `data-` attributes for IDs and links; verify the sublabel and link-attribute scenarios.
- [ ] 6.6 Verify the standalone-SVG scenarios for every corpus diagram, and credit archify in the `diagrams-svg` README.

## 7. Review the result and document it

Bead: `diagrams-67z.7`.
Depends on: `diagrams-67z.6`.

- [ ] 7.1 Add the `mise run gallery` task that writes `_gallery/index.html` with each corpus diagram in dark and light, add `_gallery/` to `.gitignore`, and verify that the task runs.
- [ ] 7.2 Add `diagrams-mermaid` and `diagrams-svg` to `scripts/publish.mbtx` in dependency order, and verify the task script tests.
- [ ] 7.3 Add the terms "diagram kind", "link" and "render properties" to `CONTEXT.md`, update `docs/design/overview.md` for one model per diagram kind, and add a docs page with a rendered example; verify `mise run build:site` and `mise run check:site`.
- [ ] 7.4 Ask the owner to review the gallery, and record the result in the pull request.

## Workflow follow-up

- Archive the change in the pull request that lands the last group.
- After the merge, close the beads and the epic, then run `bd dolt pull` and `bd dolt push`.
