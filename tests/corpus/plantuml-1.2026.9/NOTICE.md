# PlantUML reference notice

This directory holds test inputs and normalized reference results for
PlantUML 1.2026.9 (commit `18d0aae311a4f1eb3723bb4b0ad939185e22f166`).

- The files under `fixtures/` with a `doc-` prefix are examples from the
  PlantUML documentation pages that `manifest.json` lists. PlantUML and its
  documentation are by the PlantUML project; see <https://plantuml.com>.
- `reference.json` records what the pinned PlantUML JAR does with each
  fixture. The JAR is test-only reference tooling. It is downloaded by
  `mise run plantuml-corpus:reference`, verified against the digest in
  `manifest.json`, and is not part of this repository or of any published
  module. PlantUML is distributed under the GPL and other licenses; see
  <https://plantuml.com/download>.
- No PlantUML source code is copied into this repository. The MoonBit readers
  and renderers are original implementations.
