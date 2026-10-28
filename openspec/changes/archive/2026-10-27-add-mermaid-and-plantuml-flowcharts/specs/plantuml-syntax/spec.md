# Spec Delta

## MODIFIED Requirements

### Requirement: Native diagram dispatch

The library SHALL read one native regex, EBNF, JSON, YAML or activity block and
return its typed kind. Activity blocks SHALL use `@startuml` and `@enduml`.
Raw body reading SHALL require an explicit kind and, for activities, dialect.
Wrong closing markers, other diagram kinds, extra blocks and trailing
non-trivia SHALL produce diagnostics rather than partial success.

#### Scenario: Dispatch each supported block

- **WHEN** a complete `@startregex`, `@startebnf`, `@startjson` or `@startyaml` block is read
- **THEN** the result identifies its kind and retains its matching closing marker

#### Scenario: Two diagrams in one source

- **WHEN** a source contains two complete blocks
- **THEN** reading diagnoses unsupported multiple blocks instead of rendering only the first

#### Scenario: Dispatch both activity dialects

- **WHEN** modern and legacy activity blocks are read separately
- **THEN** each result identifies an activity document and its dialect and supports printing and flowchart conversion

#### Scenario: Another UML family

- **WHEN** a complete `@startuml` block contains a class or sequence diagram
- **THEN** reading reports an unsupported diagram and returns no activity model or SVG

#### Scenario: Existing body-only callers

- **WHEN** an existing caller supplies a regex, EBNF, JSON or YAML body with its explicit kind
- **THEN** its reading, canonical writing and conversion results retain their existing contracts

### Requirement: Published compatibility profile

The library SHALL publish a versioned feature and refusal inventory for regex,
EBNF, JSON, YAML and both activity dialects. The baseline SHALL remain PlantUML
`1.2026.9`. The inventory SHALL separate native acceptance, literal-data
handling, library safety refusals and unsupported presentation features.
Portable results SHALL agree on all four targets.

#### Scenario: A documented example is refused upstream

- **WHEN** a frozen documentation example fails in the pinned reference
- **THEN** its fixture records that refusal and reason instead of claiming supported syntax or omitting the example

#### Scenario: Activity coverage is separate

- **WHEN** a reader inspects the compatibility inventory
- **THEN** modern activity, legacy activity and the four existing native block kinds have separately checkable coverage and refusal records
