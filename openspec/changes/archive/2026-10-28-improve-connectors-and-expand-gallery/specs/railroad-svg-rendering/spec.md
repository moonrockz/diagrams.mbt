# Spec Delta

## MODIFIED Requirements

### Requirement: Standalone themed output

Rendering SHALL return complete, deterministic, script-free SVG with adaptive
and fixed dark/light modes, title and accessibility text. Labels SHALL be safe
text. Resource IDs SHALL be scoped by an explicit prefix so inline copies
remain independent. Existing SVG output for other kinds SHALL remain unchanged except reviewed
connector changes under the connector-rendering contract.

#### Scenario: Inline copies in different themes

- **WHEN** two copies use different ID prefixes and fixed dark/light modes
- **THEN** neither copy changes the other's markers, colours or selected element identities
