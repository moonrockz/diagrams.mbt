# plantuml-activity Specification

## Purpose
Read modern and legacy PlantUML activity diagrams into typed source values and
a shared flowchart model without a PlantUML runtime dependency.

## Requirements

### Requirement: Modern activity syntax

The reader SHALL support the PlantUML 1.2026.9 modern activity profile for
actions, start/stop/end, conditionals, switch/case, repeat/backward/break,
while/endwhile, fork/join/merge, split, detach/kill, connectors, label/goto,
partitions, groups, lanes, notes and arrow labels. Nested constructs and
multiline labels SHALL retain their structure. Pinned upstream refusals SHALL
remain explicit in the compatibility inventory.

#### Scenario: Nested branch and loop

- **WHEN** a repeat loop contains an if/elseif/else and a backward action
- **THEN** the AST keeps the loop, ordered branches, condition and return-path action separately

#### Scenario: Parallel and split forms

- **WHEN** sources use `end fork`, `end merge` and `end split`
- **THEN** the AST distinguishes the three constructs and keeps their branch order and labels

### Requirement: Legacy activity syntax

The reader SHALL support the PlantUML 1.2026.9 legacy activity profile for
`(*)`, `(*top)`, quoted actions, aliases, implicit previous activities,
directional and labelled arrows, nested conditionals, synchronization bars,
partitions and notes. Reused aliases and implicit endpoints SHALL follow
pinned legacy identity rules rather than modern action-occurrence rules.

#### Scenario: Reuse an activity alias

- **WHEN** a legacy source declares an action `as A` and later connects `A` to another action
- **THEN** conversion reuses the first action identity rather than adding a second occurrence

#### Scenario: Implicit source and synchronization

- **WHEN** a legacy arrow omits its source and two paths meet at a named synchronization bar
- **THEN** its source and the shared bar identity match the pinned reference

### Requirement: Activity dialect selection

Reading SHALL identify modern or legacy activity syntax from supported
statements within one `@startuml` block. Explicit body reading SHALL allow a
caller to select the activity dialect. Unsupported UML families, ambiguous
bodies and unsupported mixed dialects SHALL receive stable diagnostics without
a successful activity model. Comments, strings and metadata SHALL NOT trigger
kind detection.

#### Scenario: A sequence block is not an activity

- **WHEN** a block has `Alice -> Bob: start` and no activity declarations
- **THEN** dispatch reports an unsupported diagram rather than interpreting its label as an activity keyword

#### Scenario: A keyword in a note

- **WHEN** a legacy action note contains the text `start` and `fork`
- **THEN** the reader retains the legacy dialect and note text

### Requirement: Lossless activity source and findings

Reading SHALL reproduce the complete source within its source limit, including
comments, CRLF, non-BMP text and invalid statements. Findings SHALL use stable
codes, severities and half-open UTF-16 source spans with one-based locations.
Recovery SHALL respect multiline actions, quotes, notes and block nesting,
retain later valid statements and diagnose unmatched control delimiters.

#### Scenario: A missing endif and a later bad statement

- **WHEN** source has an open conditional and a later invalid statement after a multiline action
- **THEN** findings locate both faults, the valid action remains in the partial AST and the source tree reproduces all input

### Requirement: Canonical activity printing

Printing SHALL write a complete block or explicit body from typed AST values,
preserve its dialect and logical structure, and obey the output limit. Reading
the output SHALL give an equivalent AST apart from trivia and locations.
Repeated printing SHALL be stable. Invalid typed values SHALL return explicit
diagnostics without stale source or partial successful output.

#### Scenario: Change an action in each dialect

- **WHEN** a caller edits an action label in modern and legacy ASTs and prints each
- **THEN** each output contains the edit, reads in the same dialect and has stable repeated canonical bytes

### Requirement: Structured activity conversion

Conversion SHALL produce explicit flowchart topology for sequential actions,
branching, loop returns and exits, forks, joins, merges and splits. It SHALL
retain ordered regions, branch labels, join specifications and distinct final
forms. Implicit control nodes and edges SHALL have deterministic identities
and source bindings. Guards and join expressions SHALL remain descriptive.

#### Scenario: Break exits a loop

- **WHEN** a modern loop branch uses `break` and another branch continues
- **THEN** the break path reaches the loop exit, the continuation reaches the loop test and neither evaluates the condition

#### Scenario: Terminated branch has no continuation

- **WHEN** one conditional branch uses `stop`, `end`, `kill` or `detach`
- **THEN** its termination kind and visible topology match the pinned reference and no fabricated fall-through edge joins it to the next action

#### Scenario: Label and goto

- **WHEN** a pinned-accepted source jumps to a declared label
- **THEN** conversion keeps that structural connection and source binding without executing it

### Requirement: Activity scopes and notes

Conversion SHALL retain partition/group nesting and explicit lane order,
aliases and ownership. Notes SHALL retain their text, placement and attachments
without becoming executable actions or route edges. Repeated equal action
labels SHALL follow the selected dialect's identity rules.

#### Scenario: Change lanes inside a partition

- **WHEN** actions within one partition switch lanes using pipe declarations
- **THEN** each action keeps its effective lane, the partition path and its declared sequence connection

### Requirement: Presentation and preprocessing boundaries

Titles, notes, colors, stereotypes and styles SHALL remain typed or retained
source data. Conversion SHALL diagnose unapplied presentation settings.
Includes, executable preprocessing, external assets and other unsupported
directives SHALL receive explicit refusals and SHALL perform no I/O or code
execution. Supported plain and multiline text SHALL remain readable.

#### Scenario: External include and styled action

- **WHEN** source requests an include and declares a colored action
- **THEN** the tree keeps both, the include receives an error and any unapplied color receives a presentation finding without a file or network read

### Requirement: Bounded portable activity processing

Reading, printing and conversion SHALL be pure and bounded by explicit source,
output, depth, node, edge, diagnostic and work limits. Limit exhaustion SHALL
have a distinct diagnostic and no successful complete model or output. Equal
inputs and options SHALL give equal values and bytes on wasm, wasm-gc, js and
native.

#### Scenario: Nested branches exceed the depth limit

- **WHEN** a source exceeds the configured branch nesting limit
- **THEN** processing reports depth exhaustion before stack overflow or partial successful rendering

### Requirement: Independent activity compatibility corpus

The corpus SHALL freeze modern and legacy documentation and relevant upstream
sources with provenance, licenses, digests and a feature inventory. Pinned
PlantUML acceptance and activity topology evidence SHALL be independent of
MoonBit conversion. The inventory SHALL distinguish supported semantics,
upstream refusals, library refusals and unapplied presentation. Normal tests
SHALL use committed fixtures without Java, Graphviz or network access.

#### Scenario: Every documented feature is accounted for

- **WHEN** the corpus is qualified against PlantUML 1.2026.9
- **THEN** every frozen modern and legacy example has an acceptance/refusal record, every supported control feature has independent topology evidence and canonical output has the same acceptance and meaning
