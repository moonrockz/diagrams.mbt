# architecture-svg-rendering Specification

## Purpose
Lay out architecture models and render them as readable, deterministic,
self-contained SVG with explicit ports, group boundaries and symbols.

## Requirements

### Requirement: Deterministic architecture placement

Layout SHALL place services, junctions, group boundaries, icons and measured
labels deterministically. It SHALL retain nested containment and explicit
row/column alignment and member order. Disconnected elements SHALL use
declaration order as the stable tie-breaker. Equal inputs and options SHALL
give equal geometry and SVG bytes on all four targets.

#### Scenario: Grid across groups

- **WHEN** compatible row and column alignments span services in three groups
- **THEN** the requested axes and member order hold and all nodes remain inside their declared group boundaries

#### Scenario: Disconnected services

- **WHEN** unconnected services are declared as `Z`, `A`, `M`
- **THEN** their stable placement follows declaration order rather than alphabetical or random order

### Requirement: Port and group-boundary routing

Each connection SHALL attach to its declared sides and follow a visible route
between the actual service/junction or requested group outlines. Routing SHALL
keep labels, arrowheads and parallel-edge identity. Group attachments SHALL
remain adjacent to their referenced services. Unrelated shapes, labels and
group titles SHALL not obstruct the routes.

#### Scenario: Connection between group boundaries

- **WHEN** a connection requests the bottom of one service's group and the top of another's group
- **THEN** its route meets those group outlines at the requested sides, keeps both service identities and avoids drawing the endpoints on the service boxes

#### Scenario: Parallel edges and self-connection

- **WHEN** a model has parallel edges and an edge returning to the same service
- **THEN** each has distinguishable geometry, correct ports and retained labels and markers

### Requirement: Architecture symbols and safe text

The renderer SHALL paint group/service symbols and unresolved-icon fallbacks
according to the diagram-icons contract. Labels, literal icon text and
metadata SHALL remain escaped data. An omitted icon SHALL not produce a broken
resource placeholder. Source configuration SHALL not inject executable markup
or arbitrary CSS into output.

#### Scenario: Text resembles executable markup

- **WHEN** a service label or literal icon text contains markup and event-handler text
- **THEN** output displays escaped text and contains no source-supplied executable element or attribute

### Requirement: Constraint and resource failures are explicit

Layout SHALL obey explicit node, connection, nesting, coordinate, output and
work budgets. Inconsistent hard constraints SHALL produce a constraint finding;
exhausted budgets SHALL produce a separate limit finding. Either failure SHALL
return no successful partial layout or SVG and SHALL not silently discard an
alignment, group attachment or port request.

#### Scenario: Conflicting member order

- **WHEN** two row alignments require both `A` before `B` and `B` before `A`
- **THEN** layout reports conflicting constraints with no successful SVG

#### Scenario: Routing budget exhausted

- **WHEN** routing exhausts the configured work budget
- **THEN** rendering returns a limit diagnostic that differs from invalid-model and constraint failures

### Requirement: Architecture legibility checks

A public checker SHALL detect unintended overlaps, label overflow, incorrect
containment or endpoints, text below 11 px and text contrast below 4.5:1.
Intended group containment SHALL not count as overlap. The supported corpus
SHALL pass in dark and light themes, including long labels and dense junctions.

#### Scenario: Long service label and group title

- **WHEN** a corpus model has long labels and a group title near an outgoing connection
- **THEN** layout reserves enough space and checking reports no clipping, overlap or contrast findings in either theme

### Requirement: Standalone themed architecture SVG

The SVG renderer SHALL accept architecture diagrams and return well-formed
`image/svg+xml` with title and description. It SHALL follow existing fixed and
adaptive theme behavior and ID-prefix isolation. Output SHALL have no scripts,
external references, embedded font data or network dependencies.

#### Scenario: Fixed and adaptive output

- **WHEN** the same architecture is rendered in fixed dark, fixed light and adaptive modes
- **THEN** all outputs are standalone and fixed outputs have literal colours without CSS variables or style elements

### Requirement: Existing static diagrams remain stable

Adding architecture support SHALL preserve static sequence, BPMN and swimlane
contracts and bytes for unchanged models/options except reviewed connector
changes under the connector-rendering contract. Rendering an architecture
model SHALL not require a BPMN document module, external process or UI runtime.

#### Scenario: Existing snapshot corpus

- **WHEN** existing static corpus tests run after architecture support is added
- **THEN** existing sequence, BPMN and swimlane content and semantics remain unchanged, with reviewed deterministic updates limited to connector geometry and crossing treatment on every target
