# Spec Delta

## MODIFIED Requirements

### Requirement: Explicit layout limits and existing output stability

Layout, checking and SVG writing SHALL obey explicit node, edge, depth, work,
dimension and output limits. Exhaustion SHALL return a distinct diagnostic
without partial successful output. Existing diagram models and public layout
contracts SHALL remain unchanged. Static SVG bytes SHALL remain unchanged except
reviewed connector changes under the connector-rendering contract.

#### Scenario: Routing budget exhausted

- **WHEN** routing consumes its supplied work budget
- **THEN** rendering returns a layout-limit error and no partial SVG

#### Scenario: Existing static corpus

- **WHEN** existing sequence, BPMN, swimlane, architecture, railroad and data-tree snapshots run
- **THEN** their content and semantics remain unchanged on all four targets, with reviewed deterministic updates limited to connector geometry and crossing treatment
