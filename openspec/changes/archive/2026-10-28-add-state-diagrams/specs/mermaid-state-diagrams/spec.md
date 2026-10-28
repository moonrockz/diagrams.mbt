## Purpose

Read, print and convert native Mermaid state diagrams with source fidelity and
explicit compatibility against the repository's pinned Mermaid version.

## ADDED Requirements

### Requirement: Native Mermaid state grammar

The reader SHALL accept the Mermaid 12.2.0 state grammar for `stateDiagram` and
`stateDiagram-v2`, declarations, aliases, descriptions, implicit states,
transitions, initial/final forms, composites, concurrent regions, choice,
fork/join, notes, directions and metadata. Frozen grammar and reference behavior
SHALL resolve documentation disagreements; upstream refusals SHALL be explicit.

#### Scenario: Both state headers

- **WHEN** equivalent sources use the legacy and v2 headers
- **THEN** each produces a typed state AST, retains its header and converts with its pinned source semantics

#### Scenario: Nested concurrent states

- **WHEN** a source has a composite with concurrent regions and nested states
- **THEN** the AST retains each region, separator, declaration and transition in source order

### Requirement: Lossless state source and diagnostics

The source tree SHALL reproduce every code unit within the source limit,
including comments, directives, front matter, invalid regions, CRLF and non-BMP
text. Diagnostics SHALL have stable codes, severity and half-open UTF-16 spans
with one-based lines and columns. Recovery SHALL respect quotes, notes and
nesting and retain later readable statements without claiming a complete model.

#### Scenario: Bad statement after Unicode

- **WHEN** CRLF source has an emoji, a malformed transition and a later valid declaration
- **THEN** the tree reproduces the source, the finding selects its original UTF-16 slice and recovery retains the valid declaration

### Requirement: Typed canonical state printing

Printing SHALL derive source from typed AST values, preserving the header,
declaration order, nesting, identities, labels and retained metadata. Read of
canonical output SHALL recover an equivalent AST apart from trivia and spans.
Repeated printing SHALL give identical bytes. Invalid or unrepresentable typed
values SHALL return diagnostics without stale source or partial success.

#### Scenario: Edit a transition label

- **WHEN** a caller edits a typed transition label, prints, reads and prints again
- **THEN** the read AST contains the edit and both canonical outputs have equal bytes

### Requirement: Reference-compatible state conversion

Conversion SHALL follow pinned rules for aliases, implicit declarations,
redeclarations, description accumulation, nesting, concurrent regions and scoped
initial/final identities. It SHALL preserve ordered parallel transitions,
self-loops, notes and pseudostate roles. Cross-composite references SHALL follow
recorded upstream acceptance or refusal rather than generic flowchart rules.

#### Scenario: Scope-sensitive transition

- **WHEN** a fixture connects internal states across composite boundaries
- **THEN** conversion matches the pinned acceptance and normalized topology or reports the documented refusal without moving endpoints

### Requirement: Inert state presentation data

Classes, styles, directives, renderer requests, links and accessibility metadata
SHALL remain retained data. Conversion SHALL report unapplied behavior. Source
configuration SHALL NOT override caller options, execute code or fetch assets.
Labels SHALL remain text under the shared escaping and link policy.

#### Scenario: Style and hostile label

- **WHEN** source contains a class definition and a markup-like state label
- **THEN** printing retains the data, conversion reports unapplied styling and rendering cannot execute the label

### Requirement: Bounded portable state syntax

Reading, printing and conversion SHALL be pure and deterministic on all four
targets. Explicit source, output, depth, state, region, transition, diagnostic
and work limits SHALL apply before excess expansion or allocation. Exhaustion
SHALL be distinct from invalid syntax and SHALL yield no successful complete
model or printed output.

#### Scenario: Excessive region nesting

- **WHEN** source exceeds the configured nesting limit
- **THEN** processing returns a depth-limit diagnostic before stack overflow or a successful partial model

### Requirement: Independently qualified Mermaid state profile

The corpus SHALL freeze pinned documentation, grammar and semantic sources
with provenance, licenses, digests and a feature/refusal inventory. Acceptance
and normalized hierarchy/transition expectations SHALL come from upstream,
independently of MoonBit conversion. Normal portable tests SHALL use committed
fixtures without a JavaScript runtime or network.

#### Scenario: Source and canonical output qualification

- **WHEN** every frozen example and feature fixture is checked against Mermaid 12.2.0
- **THEN** source and canonical output have the expected acceptance and normalized meaning, every documented construct is accounted for and all four MoonBit targets agree
