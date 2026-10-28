# Spec Delta

## MODIFIED Requirements

### Requirement: Sequence rendering compatibility without new values

An existing sequence with no explicit icon references or new exception fragment
values SHALL retain its prior static SVG bytes for equal theme/options except for
reviewed connector changes under the connector-rendering contract. Adding
icon assets SHALL not emit unused definitions or change layout for these models.

#### Scenario: Existing sequence snapshots

- **WHEN** the existing Mermaid sequence corpus is rendered on all four targets
- **THEN** its fixed dark, fixed light and adaptive snapshots preserve existing content, with deterministic reviewed updates only for connector geometry and crossing treatment
