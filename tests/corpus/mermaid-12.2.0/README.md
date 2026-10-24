# Mermaid 12.2.0 sequence diagram examples

This folder holds every sequence diagram example of the Mermaid 12.2.0
documentation, frozen for the tests of `moonrockz/diagrams-mermaid`.

| Item | Value |
| --- | --- |
| Repository | <https://github.com/mermaid-js/mermaid> |
| Tag | `mermaid@12.2.0` |
| Commit | `1fb7869866dd619168d840291c9c54b4f129758b` |
| Source file | `packages/mermaid/src/docs/syntax/sequenceDiagram.md` |
| Source SHA-256 | `dad8b72c3c8e7281d54e4e905cc64061785834140beada5c7b7ad33a2c5277e0` |
| Grammar | `packages/mermaid/src/diagrams/sequence/parser/sequenceDiagram.jison`, SHA-256 `f3f21ae48e3c334fc259e3f78ac60ef70cf930ac6df2dd3c43f2b0de6f2b24db` |
| Licence | MIT, see `LICENSE` (copied from the same commit) |

## How the examples were taken

Each fenced block with the info string `mermaid` or `mermaid-example` whose
text starts with `sequenceDiagram` (after optional front matter and
directives) is one example. A block that has the same text as an earlier block
is not copied again. The examples are numbered in document order, from
`examples/01.mmd` to `examples/38.mmd`. Each file has the exact text of its
block, including the indentation and the final line break.

`SHA256SUMS` has the SHA-256 digest of each file, in the format of
`shasum -a 256`.

## How the tests use them

`mise run validate:corpus` checks each digest and checks that
`tests/corpus/examples.generated.mbt` contains the same text. That file embeds
the examples, because tests on the wasm targets cannot read files. Run
`mise run corpus:generate` after you change this folder. A test in
`tests/corpus` also computes each digest again from the embedded text.

Do not edit the example files. To move to a later Mermaid release, add a new
folder for that release.
