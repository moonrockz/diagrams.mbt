# moonrockz/diagrams

Diagramming for MoonBit. The library will support formats such as Mermaid,
PlantUML, Draw.io and Graphviz DOT.

Each diagram kind has one model that does not depend on a format. All formats of
that kind read into it and write from it. The packages are:

| Package | Contents |
| --- | --- |
| `moonrockz/diagrams` | `Diagnostic`, `Severity`, `Span` and `Position`, which all modules use |
| `moonrockz/diagrams/sequence` | The `Sequence` model: participants, messages and their order |
| `moonrockz/diagrams/render` | The `Renderer` trait, the `Diagram` enum and the `Rendered` result |

`moonrockz/diagrams-mermaid` reads Mermaid into these models, and
`moonrockz/diagrams-svg` renders them as SVG. Requirements come as OpenSpec
changes in `openspec/changes/`.
