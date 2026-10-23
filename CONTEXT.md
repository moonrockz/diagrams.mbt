# diagrams.mbt language

**Diagram format**:
A textual or file notation for a diagram, such as Mermaid, PlantUML, Draw.io or
Graphviz DOT.

**Diagram model**:
A typed, immutable value that describes the nodes, edges and labels of a diagram
without a link to one diagram format.

**Source reproduction**:
Returning the same source text that was read, including whitespace and member
order.
_Avoid_: canonical writing

**Canonical writing**:
Producing deterministic text from a diagram model under a documented ordering and
spelling policy.
_Avoid_: source reproduction
