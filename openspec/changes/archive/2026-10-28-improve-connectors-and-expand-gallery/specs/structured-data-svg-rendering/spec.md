# Spec Delta

## MODIFIED Requirements

### Requirement: Standalone data themes and safe text

Rendering SHALL provide complete, deterministic, script-free SVG using the
shared adaptive and fixed dark/light themes. It SHALL escape keys and values,
preserve scalar distinctions and scope resource IDs by prefix. Titles and
accessibility text SHALL describe the data view. Other diagram kinds' static SVG bytes SHALL remain unchanged except reviewed
connector changes under the connector-rendering contract.

#### Scenario: A value contains markup

- **WHEN** a key or value contains SVG, HTML or script-like text
- **THEN** it is displayed as text without active markup, requests or author code
