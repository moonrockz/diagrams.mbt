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


**BPMN document**:
The typed definitions, processes, collaborations, choreography, conversations,
diagram interchange and extensions from one BPMN source.

**BPMN view**:
One selected process, collaboration or diagram plane for rendering. A document
can retain several views, including kinds whose rendering is deferred.

**Diagram interchange**:
The authored shapes, bounds, labels and connection waypoints of a BPMN view.

**Message occurrence**:
One authored sequence message at a particular position within nested frames.
Repeated participants do not make occurrences identical.

**Structural route**:
A bounded path over selected drawn connections with an explicit traversal
orientation for each connection. Conditions and event
triggers do not establish whether a business process can follow that path.
_Avoid_: execution path

**Illustrative flow**:
A repeating visual explanation of authored connections, with no execution claim.
_Avoid_: token simulation

**Explicit scenario**:
A finite authored choice of occurrences, order, repetitions, concurrent groups
and durations.

**Canonical SVG**:
The complete static SVG without motion, selection effects or viewer controls.
A display scene preserves its geometry and adds separate motion bindings.


**Swimlane**:
A responsibility diagram with ordered lanes, steps and explicit connections.
It describes ownership and interactions without asserting process execution.

**Lane**:
A named responsibility band. A top-level group in native Mermaid swimlane syntax
is a lane; a group inside it remains a nested group.

**Unowned step**:
A step outside every responsibility lane. Its ownership is absent rather than
assigned to a generated actor.

**Connection occurrence**:
One authored, identifiable connection. Parallel connections have different
occurrences even when they share endpoints.

**Traversal orientation**:
The direction in which a structural route uses a connection's drawn path.
Reversing traversal does not move or replace its endpoint markers.

**Display anchor**:
The visible outline used for an endpoint hidden by a collapsed group or lane.
It does not replace the endpoint's identity in structural route queries.
