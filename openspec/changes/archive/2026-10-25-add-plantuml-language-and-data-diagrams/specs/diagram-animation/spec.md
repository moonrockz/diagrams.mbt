# Spec Delta

## ADDED Requirements

### Requirement: Pattern grammar and data catalogs

The shared catalog and scene APIs SHALL accept regex, EBNF and structured-data
models. They SHALL retain occurrence identities, semantic roles and source/view
bindings. Connection occurrences SHALL bind to real paths; value occurrences
SHALL bind to their visible nodes or rows. Equal labels SHALL not merge targets.

#### Scenario: Equal terminals in two branches

- **WHEN** a caller selects one of two equally labelled terminal occurrences
- **THEN** only that occurrence and its selected connectors are inspected or played

### Requirement: First-class node visits

Pure plans SHALL support timed visits to visible nodes or rows without a
connection path. Visits SHALL sample deterministically from explicit elapsed
time and obey the existing duration and plan-size bounds. Wrong target kinds,
missing targets and source mismatches SHALL produce diagnostics. Existing
connection-step and orientation behavior SHALL remain unchanged.

#### Scenario: Seek during a scalar visit

- **WHEN** a finite plan visits an inline scalar row and is sampled halfway through its duration
- **THEN** the same row and visit progress are active on all four targets without a fake path

### Requirement: Bounded railroad exploration

Railroad route and reachability queries SHALL use the displayed expression
topology, with explicit connector direction and bounded repetition handling.
Assertions and exclusions SHALL retain constraint roles. Rule references SHALL
be inspectable targets and SHALL not create invisible route edges or recursively
expand definitions.

#### Scenario: Explore a repeated alternative

- **WHEN** a reader selects a branch and return connector in a repeated expression
- **THEN** playback follows the chosen drawn paths and terminates under the supplied finite scenario

#### Scenario: A reference names another rule

- **WHEN** a reader inspects an EBNF reference with no drawn inter-rule connection
- **THEN** its target can be identified without inventing an animated connection or a parser call

### Requirement: Typed hierarchy exploration

Data queries SHALL identify their relation as containment and provide bounded
ancestor, descendant and parent/child route results. They SHALL preserve member
and array occurrence order. Route plans SHALL combine explicit row visits with
steps on connectors that exist. Literal references, equal values and adjacent
rows SHALL not create extra relations.

#### Scenario: Parent and inline member

- **WHEN** a selected parent/child relation ends at an inline scalar row
- **THEN** the viewer visits that row without drawing a connector absent from the static view

#### Scenario: A search limit is reached

- **WHEN** a hierarchy query exhausts its budget
- **THEN** it reports exhaustion separately from an unreachable or outside-view endpoint

### Requirement: Finite language and data illustrations

Default illustrations SHALL use deterministic source or hierarchy order and
bounded occurrence sets. They SHALL not expand unbounded repeats or recursive
references. Explicit scenarios SHALL preserve chosen occurrences, repetitions,
durations and concurrent groups. Neither mode SHALL compute or verify input
acceptance. Supplied provider outcomes SHALL be distinguished from structural
query results.

#### Scenario: An unbounded repetition

- **WHEN** a pattern with an unbounded quantifier receives its default illustration
- **THEN** the finite plan illustrates its structure without allocating an unbounded timeline

### Requirement: Shared offline playback for new kinds

The standalone player SHALL support the new kinds and node visits through the
existing controls, reduced-motion, hidden-page, print and offline contracts.
Static export SHALL equal the direct canonical SVG and preserve viewer state.
Existing sequence, BPMN and swimlane playback SHALL remain compatible; shared
runtime byte changes SHALL have deterministic updated HTML snapshots.

#### Scenario: Export during a row visit

- **WHEN** a reader exports SVG while a row visit is playing
- **THEN** the bytes equal the direct static render and playback keeps its position and selection

#### Scenario: Open all four source kinds offline

- **WHEN** generated regex, EBNF, JSON and YAML players open with network access blocked
- **THEN** controls, selection, path steps and row visits work with no request or console error

### Requirement: Supplied trace highlights survive playback and export

Configured static match/failure highlights SHALL remain separate from playback
and selection overlays. Export SHALL equal direct static rendering with the
same trace and style options. Playback and export SHALL not invoke a trace
provider or compute acceptance. Displayed supplied outcomes SHALL identify
their external origin.

#### Scenario: Export a failure-highlighted grammar while playing

- **WHEN** a grammar has configured failure-terminal highlights and the reader exports SVG during playback
- **THEN** export retains those configured highlights, excludes transient progress, and preserves viewer position and selection
- **AND** the provider is not invoked again

## MODIFIED Requirements

### Requirement: Structural paths do not imply feasible execution

Routes SHALL identify their structural relation and visible scope. They SHALL
not assert feasible execution or evaluate conditions, event triggers, gateway
synchronization, regex matches or grammar acceptance. Connection steps SHALL
follow drawn paths; data relations without connectors SHALL use node visits.
Hidden detail SHALL require another view or an outside-view result, with no
invented connections.

#### Scenario: An exclusive gateway has two conditions

- **WHEN** a reader explores either outgoing branch
- **THEN** the viewer retains the condition labels and identifies the result as structural rather than reporting a condition as true

#### Scenario: A collapsed subprocess hides detail

- **WHEN** an endpoint is inside a subprocess whose inner view is not selected
- **THEN** the viewer requests the inner view or reports the endpoint outside the selected view instead of fabricating a connection

#### Scenario: A regex branch has a lookaround

- **WHEN** a reader explores a branch next to a lookaround constraint
- **THEN** the viewer retains the constraint description without claiming that any input matches
