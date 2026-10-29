# Spec Delta

## MODIFIED Requirements

### Requirement: Standalone themed state SVG

The shared renderer SHALL accept state diagrams and return deterministic,
well-formed, script-free `image/svg+xml` on all four targets. Output SHALL be
self-contained, with adaptive and fixed themes, title/accessibility metadata,
safe text/links and caller prefix isolation. Existing diagram contracts and static SVG bytes SHALL remain unchanged except
reviewed connector geometry updates under the connector-rendering contract.

#### Scenario: Two inline state diagrams

- **WHEN** copies use separate prefixes and markup-like labels
- **THEN** definitions and masks stay isolated in both themes and labels display as text without external requests

