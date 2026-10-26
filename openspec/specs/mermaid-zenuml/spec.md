# mermaid-zenuml Specification

## Purpose
Read and print Mermaid ZenUML source and convert its interactions to the shared
sequence model with explicit diagnostics and portable results.

## Requirements

### Requirement: Frozen ZenUML compatibility profile

The reader SHALL accept `zenuml` with the syntax families documented in Mermaid
12.2.0: participants, aliases, annotators, sync/async messages, creation, all
documented return forms, nested calls, comments, loops, alternatives, optional
and parallel fragments, and try/catch/finally. Semantic behavior SHALL follow
the frozen plugin 1.0.1 and core 3.47.9 reference. Other extensions SHALL be
retained and diagnosed as unsupported.

#### Scenario: Documentation corpus

- **WHEN** each complete Mermaid 12.2.0 ZenUML documentation example is read and converted
- **THEN** it gives an AST and sequence model without syntax or unsupported-feature errors

#### Scenario: An extension outside the profile

- **WHEN** source uses a statement outside the declared compatibility profile
- **THEN** reading retains its text and reports the unsupported statement rather than silently dropping it

### Requirement: Lossless syntax and recoverable diagnostics

The syntax tree SHALL reproduce every source unit, including comments,
whitespace, CRLF and malformed regions. Diagnostics SHALL have stable codes,
severity, messages and half-open UTF-16 spans with one-based lines and columns.
Reading SHALL recover at a safe statement boundary and retain later valid
statements. Missing braces SHALL identify their opening statement.

#### Scenario: Non-BMP text before an error

- **WHEN** a malformed statement follows non-BMP text on a CRLF-delimited line
- **THEN** reproduction equals the input and the finding selects the same UTF-16 slice on each target

#### Scenario: Missing closing brace

- **WHEN** a call body has no closing brace
- **THEN** reading diagnoses the opening call and retains its readable body

### Requirement: Typed source and canonical printing

The AST SHALL keep statement order, aliases, annotator identity, labels, call
nesting, expressions, comments and fragment boundaries. Canonical printing SHALL
use typed fields and produce equivalent native ZenUML. Reading and printing the
result again SHALL give the same AST meaning and canonical bytes.

#### Scenario: Edited alias and nested call

- **WHEN** a caller edits an alias and a nested call label in an AST and prints it
- **THEN** the output contains the edited values and reparses to the edited meaning without stale source text

### Requirement: Ordered call and return conversion

Conversion SHALL preserve participant and event order and follow the frozen
reference for explicit/implicit callers, call nesting, activations, creation,
assignment replies, `return`, and annotated replies. Expressions SHALL remain
descriptive text. Invalid return targets SHALL give diagnostics without invented
participants or edges.

#### Scenario: Nested synchronous calls

- **WHEN** a caller invokes `A`, whose body invokes `B` and returns a result
- **THEN** the model keeps the caller-to-A and A-to-B order, scoped activations and the reference-defined return targets

#### Scenario: Asynchronous message

- **WHEN** source sends `A->B: notify` without a nested synchronous call
- **THEN** the model contains that async message without inventing a synchronous activation scope

#### Scenario: Assignment and explicit reply

- **WHEN** corpus fixtures use typed/untyped assignments, `return`, `@return` and `@reply`
- **THEN** converted message direction, labels and activation boundaries match the frozen reference fixtures

### Requirement: Fragment and attached comment conversion

Conversion SHALL retain nested loop, alternative, optional, parallel and
exception fragment structure. Try, catch and finally sections SHALL retain
distinct roles and order. Comments attached to messages/fragments SHALL become
notes at their reference-defined location. Comment markup SHALL remain safe
text; conversion SHALL not evaluate conditions or exception outcomes.

#### Scenario: Exception sections

- **WHEN** source contains a try body, two catch bodies and a finally body
- **THEN** the model retains all four ordered bodies with distinct roles and catch labels

#### Scenario: Attached comment

- **WHEN** a comment precedes a message in the frozen reference's attached-comment position
- **THEN** the model includes the comment note before that message and preserves its text

### Requirement: Annotator identity survives conversion

Conversion SHALL retain each participant annotator as an explicit icon reference
with the pinned registry's case and alias rules. A known UML kind SHALL retain
its semantic kind as well as its symbol. A provider or technology annotator
SHALL retain its own identity without becoming a generic service symbol.
Unknown annotators SHALL remain identifiable and give a warning.

#### Scenario: Different database systems

- **WHEN** participants use `@Database`, `@PostgreSQL` and `@MongoDB`
- **THEN** their model icon references retain three distinct declared identities for rendering

### Requirement: Mermaid dispatch preserves existing APIs

The multi-kind read/print and SVG convenience APIs SHALL accept `zenuml` and
return the corresponding syntax or rendered sequence. The sequence-specific
read, print and conversion APIs SHALL retain their types and behavior.
Errors from reading, conversion or rendering SHALL propagate with no successful
empty or partial output.

#### Scenario: Dispatch a ZenUML diagram

- **WHEN** the general Mermaid API reads a source with a `zenuml` header
- **THEN** it selects ZenUML syntax and its source-to-SVG path uses the shared sequence renderer

#### Scenario: Existing consumer

- **WHEN** existing sequence and swimlane examples compile and run unchanged
- **THEN** their public operation results and static SVG bytes remain unchanged

### Requirement: Bounded portable ZenUML processing

Reading, printing and conversion SHALL be pure and obey explicit source, output,
participant, event, nesting, diagnostic and work limits. A limit failure SHALL
have a distinct diagnostic and no complete model/output. Equal inputs SHALL
give equal syntax, diagnostics, models and printed bytes on wasm, wasm-gc, js
and native.

#### Scenario: Deep call nesting

- **WHEN** call nesting exceeds the configured depth
- **THEN** processing returns a depth-limit diagnostic without overflowing the host stack
