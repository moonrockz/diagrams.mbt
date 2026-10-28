# plantuml-state-diagrams Specification

## Purpose
Read and convert native PlantUML state diagrams into typed source values and a
shared state model without a PlantUML rendering or execution dependency.

## Requirements

### Requirement: Native PlantUML state syntax

The reader SHALL support the PlantUML 1.2026.9 state profile for declarations,
quoted aliases, descriptions, transitions, arrow hints, initial/final symbols,
composites, concurrent separators, choice, fork/join, shallow/deep history,
entry/exit points, pins, expansion symbols, notes and metadata. All frozen
documentation forms SHALL have an acceptance or explicit refusal record.

#### Scenario: Composite and concurrent declarations

- **WHEN** sources use nested states and both `--` and `||` concurrent separators
- **THEN** the AST retains nesting, region order, orientation, aliases and transition labels

#### Scenario: Boundary symbols

- **WHEN** a supported source declares entry/exit points, pins and expansion inputs/outputs
- **THEN** their distinct source roles survive conversion and are not replaced by ordinary states

### Requirement: PlantUML state identity and scope

Conversion SHALL follow pinned alias, qualified-name, implicit-state,
redeclaration and scoped initial/final rules. Cross-boundary transitions SHALL
retain their real semantic endpoints. History references SHALL preserve target
scope and shallow/deep roles without inferring restored states. Parallel edges
and self-transitions SHALL retain separate identities and source bindings.

#### Scenario: Scoped deep-history target

- **WHEN** a transition targets a composite's deep-history reference
- **THEN** the model retains that composite and deep-history identity without choosing one of its descendants

#### Scenario: Cross-composite transition

- **WHEN** upstream accepts a transition from a child in one composite to a child in another
- **THEN** conversion keeps both child endpoints and their ownership paths

### Requirement: Descriptions and behavior remain data

State description lines, stereotypes and event/guard/action labels SHALL retain
their source order and text. Entry, do, exit and internal-event descriptions
SHALL remain descriptive data. Conversion SHALL NOT evaluate guards, execute
actions or turn internal description lines into external transitions.

#### Scenario: Entry and internal event descriptions

- **WHEN** a state has an entry description and an internal-event description
- **THEN** inspection retains both lines and route queries gain no edges from them

### Requirement: Lossless state reading and recovery

The source tree SHALL reproduce every code unit within its source limit,
including comments, invalid syntax, multiline notes, CRLF and non-BMP text.
Findings SHALL use stable codes, severity and half-open UTF-16 spans with
one-based locations. Recovery SHALL preserve later valid statements while
respecting quoted text, notes and composite boundaries.

#### Scenario: Error between valid state statements

- **WHEN** an invalid transition follows a multiline note and precedes a valid state
- **THEN** the tree reproduces the source, the finding locates the error and the later state remains readable without a successful complete conversion

### Requirement: Canonical PlantUML state printing

Printing SHALL derive a complete state block or explicit state body from typed
values. Read of canonical output SHALL preserve logical structure apart from
trivia and spans; repeated printing SHALL be stable. Typed edits SHALL appear
in output. Invalid values and output/work exhaustion SHALL produce diagnostics
without stale source or successful partial output.

#### Scenario: Edit an alias and its references

- **WHEN** a caller consistently edits a state alias and its transition references before printing
- **THEN** canonical output reads with the edited identity and a second print has equal bytes

### Requirement: Inert presentation and explicit resource refusals

Titles, notes, colors, stereotypes, styles and presentation commands SHALL be
retained as typed or source data, with findings for unapplied behavior. Includes,
executable preprocessing and external assets SHALL receive explicit errors and
perform no I/O. Unsupported symbols SHALL retain identity and produce a
rendering diagnostic rather than a replacement rectangle.

#### Scenario: Include request and styled transition

- **WHEN** a source includes an external file request and a styled transition
- **THEN** the tree retains both, the request is refused, unapplied presentation is identified and no resource is read

### Requirement: Bounded portable PlantUML state processing

Reading, printing and conversion SHALL be pure and bounded by explicit source,
output, nesting, state, region, transition, diagnostic and work limits. Invalid
input and limit exhaustion SHALL remain distinct without successful complete
output. Equal inputs SHALL give equal values and bytes on all four targets.

#### Scenario: Excessive transition count

- **WHEN** conversion would exceed its transition limit
- **THEN** it reports exhaustion before allocating excess transitions or rendering partial success

### Requirement: Independent PlantUML state qualification

The corpus SHALL freeze documentation and relevant upstream sources with
provenance, licenses, digests and a feature inventory. Expected acceptance and
state hierarchy/transition evidence SHALL come from pinned PlantUML independently
of MoonBit conversion. Normal tests SHALL use committed fixtures without Java,
Graphviz or network access.

#### Scenario: Qualify every documented form

- **WHEN** the frozen state examples and canonical output are checked against PlantUML 1.2026.9
- **THEN** each has an acceptance or refusal record, supported structure has independent topology evidence and all four MoonBit targets agree
