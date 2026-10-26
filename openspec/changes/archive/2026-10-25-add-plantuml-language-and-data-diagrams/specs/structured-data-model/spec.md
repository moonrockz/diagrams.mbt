# Spec Delta

## Purpose

Represent the ordered hierarchy and visible values of structured-data diagrams
without depending on JSON, YAML or a particular renderer.

## ADDED Requirements

### Requirement: Immutable ordered data values

The library SHALL expose an immutable structured-data diagram with objects,
arrays, strings, exact numbers, booleans and null. Objects SHALL use ordered
member occurrences rather than an unordered name map. Empty containers and
scalar roots SHALL have explicit values. The shared renderer SHALL accept
constructed models without a format reader.

#### Scenario: An object with repeated names

- **WHEN** a constructed object has two members named `item`
- **THEN** both members retain their order, values and separate identities

#### Scenario: Empty and scalar roots

- **WHEN** a model contains an empty object, an empty array or a root scalar
- **THEN** each is a distinct renderable value rather than absent content

### Requirement: Scalar identity and precision

Data scalars SHALL distinguish text, number, boolean and null. Numbers SHALL
retain valid decimal lexemes without a machine floating-point conversion.
Format adapters SHALL document their scalar projection and duplicate-member
policy while retaining the complete source AST.

#### Scenario: Text that resembles another type

- **WHEN** one value is the string `true` and another is the boolean true
- **THEN** their model kinds remain distinct even if their displayed text is similar

#### Scenario: A large JSON number

- **WHEN** a supported JSON number exceeds exact binary floating-point precision
- **THEN** conversion and rendering retain its complete decimal spelling

### Requirement: Hierarchy occurrence identity

Every value and member occurrence SHALL have a stable identity within its view.
Member names and scalar text alone SHALL not define identity. Parent/child
relations and array positions SHALL remain explicit. A model SHALL retain
source bindings when conversion provides them.

#### Scenario: Repeated array values

- **WHEN** an array contains the same scalar twice
- **THEN** callers can select and visit either position independently

### Requirement: View highlights do not change data

Titles, accessibility text, links, render properties and highlight targets SHALL
be separate from data values. Resolving a view highlight SHALL preserve quoted
path segments and occurrence distinctions. An unresolved or ambiguous selector
SHALL produce a diagnostic rather than silently select an unrelated row.

#### Scenario: Highlight a repeated member

- **WHEN** a name-only selector cannot distinguish two member occurrences
- **THEN** resolution reports the ambiguity or uses an explicit documented all-matches selector
- **AND** an occurrence-specific selector can choose one member without changing either value

### Requirement: Bounded structural validation

Validation SHALL check identities, roots, containment, scalar lexemes and
explicit node, depth and work limits. It SHALL reject containment cycles and
invalid constructed values. It SHALL not interpret scalar text as a reference,
execute constructors or expand source aliases.

#### Scenario: A scalar resembles a reference

- **WHEN** a value is the text `*customer`
- **THEN** it remains one scalar and creates no relation to another node

#### Scenario: Invalid parent relation

- **WHEN** constructed values form a containment cycle or refer to an absent child
- **THEN** validation reports the affected identity without unbounded traversal
