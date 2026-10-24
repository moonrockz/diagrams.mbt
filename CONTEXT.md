# diagrams.mbt language

**Diagram kind**:
A family of diagrams with the same concepts, such as sequence diagrams or
flowcharts. Each kind has its own model.

**Diagram format**:
A textual or file notation for a diagram, such as Mermaid, PlantUML, Draw.io or
Graphviz DOT.

**Diagram model**:
A typed, immutable value that describes a diagram of one kind without depending
on one diagram format. A sequence model has participants and ordered events.

**Link**:
A scheme and target that identify the item a participant or message represents,
such as a Smithy shape or an OpenRPC method.

**Render properties**:
Optional presentation information about a participant or message, such as its
kind, sublabel and description, kept separately from its link.

**Source reproduction**:
Returning the same source text that was read, including whitespace and member
order.
_Avoid_: canonical writing

**Canonical writing**:
Producing deterministic text from a diagram model under a documented ordering and
spelling policy.
_Avoid_: source reproduction
