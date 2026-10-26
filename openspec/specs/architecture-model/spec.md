# architecture-model Specification

## Purpose
Represent architecture groups, resources and explicit connections independently
of Mermaid source, SVG coordinates or process execution semantics.

## Requirements

### Requirement: Immutable ordered architecture values

The library SHALL provide immutable architecture values for groups, services,
junctions, connections and alignments, with diagram identity, title and
accessibility fields. Construction SHALL copy mutable input collections.
Transformations SHALL return new values without changing their inputs.
The model SHALL not depend on source-format or rendering modules.

#### Scenario: Caller changes its input

- **WHEN** a caller constructs an architecture from a service array and later changes that array
- **THEN** the architecture retains its original services and declaration order

### Requirement: Group and node identity

Groups, services and junctions SHALL have stable IDs and declaration order.
Each SHALL have at most one parent group. Groups and services SHALL retain
labels and optional icon references; services SHALL also support literal icon
text. Junctions SHALL remain explicit connection points. Unowned nodes SHALL
remain unowned rather than entering an invented group.

#### Scenario: Nested groups and a junction

- **WHEN** a group contains a child group with a service and junction
- **THEN** each value retains its own identity and immediate parent and the junction does not become a service

### Requirement: Explicit connection endpoints and direction

Each connection SHALL have a stable ID, declaration order, optional label and
two endpoints. Each endpoint SHALL keep its service/junction ID, top/bottom/
left/right port and optional group-boundary attachment. Arrowheads at either
end SHALL be independent. Parallel edges SHALL remain distinct and SHALL not
inherit direction from screen placement or declaration order.

#### Scenario: Group attachment retains service identity

- **WHEN** an endpoint attaches to the parent group's boundary beside service `S`
- **THEN** the model retains `S`, its port and the attachment separately, rather than replacing `S` with a group ID

#### Scenario: Parallel connections

- **WHEN** two differently labelled edges have equal endpoints
- **THEN** both retain separate IDs, labels and arrowhead values

### Requirement: Ordered row and column constraints

The model SHALL retain explicit row/column alignments with ordered eligible
service/junction members. Row members SHALL share a horizontal axis and keep
left-to-right order; column members SHALL share a vertical axis and keep
top-to-bottom order. Alignment SHALL not create a connection or change an edge's
endpoint direction.

#### Scenario: Cross-group alignment

- **WHEN** an alignment includes services in separate groups
- **THEN** the model keeps that constraint and its member order independently of group membership

### Requirement: Architecture validation

Validation SHALL detect duplicate or ambiguous IDs, missing endpoints, invalid
parents, ownership cycles, ineligible group attachments, invalid ports and
invalid alignment membership. Findings SHALL have stable codes and identify
affected elements. Validation SHALL terminate within explicit limits and SHALL
not repair invalid values by changing ownership or creating endpoints.

#### Scenario: Ownership cycle

- **WHEN** a constructed group makes its descendant its parent
- **THEN** validation reports the cycle without infinite traversal

#### Scenario: Group attachment without a parent

- **WHEN** an ungrouped service endpoint requests a group-boundary attachment
- **THEN** validation identifies that endpoint as invalid without inventing a group
