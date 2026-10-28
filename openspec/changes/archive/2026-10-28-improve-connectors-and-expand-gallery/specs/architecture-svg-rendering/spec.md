# Spec Delta

## MODIFIED Requirements

### Requirement: Existing static diagrams remain stable

Adding architecture support SHALL preserve static sequence, BPMN and swimlane
contracts and bytes for unchanged models/options except reviewed connector
changes under the connector-rendering contract. Rendering an architecture
model SHALL not require a BPMN document module, external process or UI runtime.

#### Scenario: Existing snapshot corpus

- **WHEN** existing static corpus tests run after architecture support is added
- **THEN** existing sequence, BPMN and swimlane content and semantics remain unchanged, with reviewed deterministic updates limited to connector geometry and crossing treatment on every target
