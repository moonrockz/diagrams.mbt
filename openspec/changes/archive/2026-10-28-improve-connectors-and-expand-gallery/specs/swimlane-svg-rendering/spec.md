# Spec Delta

## MODIFIED Requirements

### Requirement: Existing diagram output remains stable

Swimlane support SHALL preserve existing sequence and BPMN static rendering
behavior and SVG bytes for unchanged inputs/options except reviewed connector
changes under the connector-rendering contract. Shared geometry refactoring SHALL
not change their public layout contracts or require a BPMN document module to
render a swimlane model.

#### Scenario: Existing snapshot corpus

- **WHEN** existing sequence/BPMN static corpus tests run after swimlane support is added
- **THEN** their content and semantics remain unchanged on all four targets, with reviewed deterministic updates limited to connector geometry and crossing treatment
