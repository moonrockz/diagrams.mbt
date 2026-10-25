# Spec Delta

## Purpose

Read native Mermaid swimlane source into lossless syntax and typed values,
write it canonically, and convert it to a swimlane diagram model.

## ADDED Requirements

### Requirement: Native Mermaid swimlane syntax

The library SHALL read `swimlane-beta` using the Mermaid 12.2.0 shared flowchart
grammar. It SHALL support the documented global directions `TB`, `TD`, `BT`,
`LR` and `RL`, with `TB` as the default. It SHALL retain node/edge declarations,
subgraphs, direction statements, labels, shape data, classes, styles, links,
comments, directives, front matter and accessibility fields.

#### Scenario: Documentation corpus

- **WHEN** the reader reads each frozen Mermaid 12.2.0 swimlane documentation example
- **THEN** it produces a typed AST without syntax errors and keeps every statement

#### Scenario: All documented directions

- **WHEN** sources use each documented direction or omit the direction
- **THEN** the AST records the written direction or its absence, and conversion treats `TD` as `TB` and absence as `TB`

### Requirement: Lossless swimlane CST

The swimlane CST SHALL reproduce the complete input text, including invalid
regions, comments, front matter, whitespace, quote/arrow spelling, CRLF and
non-BMP text. Syntax ranges SHALL use half-open UTF-16 offsets. Canonical
printing SHALL be separate from CST source reproduction.

#### Scenario: Labels contain syntax-like text

- **WHEN** quoted labels contain `end`, `subgraph`, arrows and brackets
- **THEN** those values remain label text and CST reproduction equals the original source

#### Scenario: Malformed source

- **WHEN** source contains an unmatched bracket and a later invalid statement
- **THEN** reproduction retains both invalid regions and all source after them

### Requirement: Recoverable diagnostics

Reading and conversion SHALL report stable codes, severity, messages and source
spans when available. Lines and columns SHALL be one-based with CRLF as one line
break. Reading SHALL recover at a valid statement boundary and retain later
valid statements. It SHALL diagnose missing group ends and SHALL NOT silently
discard unsupported or malformed syntax.

#### Scenario: Two recoverable errors

- **WHEN** two malformed statements occur between valid node and edge declarations
- **THEN** the reader reports both errors and retains the valid declarations in the AST

#### Scenario: Missing lane end

- **WHEN** a lane is opened without its closing `end`
- **THEN** reading reports the lane's source position and retains its readable contents

#### Scenario: A finding follows Unicode text

- **WHEN** an invalid token follows a non-BMP character on a CRLF-delimited line
- **THEN** its span selects the same UTF-16 slice on all four targets

### Requirement: Canonical Mermaid printing

The printer SHALL write valid native swimlane Mermaid with documented ordering,
indentation and spelling. It SHALL retain statement order, IDs, nesting, label
values, direction and non-rendered metadata. Reading printed output SHALL give
an equivalent AST, and a second canonical print SHALL give identical bytes on
all supported targets.

#### Scenario: Stable printing

- **WHEN** each valid corpus AST is printed, read and printed again
- **THEN** the ASTs are equivalent and the two canonical outputs are byte-identical

### Requirement: Reference-compatible semantic conversion

Conversion SHALL follow Mermaid 12.2.0 rules for node creation/redeclaration,
subgraph membership, repeated subgraph IDs, implicit endpoints and edge
expansion. It SHALL preserve resulting lane/node order, exact connection
identity, direction, labels, shapes and nested-group ownership. Invalid final
ownership or endpoints SHALL give diagnostics without inventing BPMN semantics.

#### Scenario: Implicit nodes

- **WHEN** an edge names nodes with no explicit declaration or lane membership
- **THEN** conversion creates those nodes in their reference-defined order and leaves their lane ownership absent

#### Scenario: Repeated lane ID

- **WHEN** two subgraph declarations reuse one lane ID
- **THEN** conversion merges the members while retaining the first completed database registration's title, direction and position as Mermaid 12.2.0 does

#### Scenario: Nested repeated group ID

- **WHEN** a nested declaration repeats its still-open outer group's ID
- **THEN** the first completed database registration supplies the stored title and direction, and normalized membership matches the pinned reference

#### Scenario: Edge expansion

- **WHEN** source contains chained edges, grouped endpoints and parallel connections
- **THEN** normalized nodes, edges and membership equal the pinned upstream reference fixture and each connection retains a distinct identity

### Requirement: Safe preservation of presentation metadata

Reading and printing SHALL retain Mermaid classes, style declarations, links,
callbacks, shape data and renderer configuration as source data. Conversion
SHALL identify renderer-only features that the library does not apply.
Callbacks and configuration SHALL NOT execute code, load resources or change
the host environment.

#### Scenario: A callback declaration

- **WHEN** source contains a Mermaid `click` callback
- **THEN** the AST and printed text retain the declaration, conversion reports its unsupported interactive behavior and no callback executes

#### Scenario: A different Mermaid layout engine

- **WHEN** front matter asks Mermaid to use an external layout engine
- **THEN** source reproduction/printing keep it and rendering identifies the unsupported option while using the caller's explicit library options

### Requirement: Mermaid kind dispatch and compatibility

The library SHALL provide a new read/print interface that dispatches supported
Mermaid diagram kinds by header. Existing sequence-specific read, print,
conversion and result types SHALL retain their contracts. The existing SVG
convenience operation SHALL dispatch sequence and swimlane source and preserve
failure diagnostics without returning empty text as successful output.

#### Scenario: Read both supported Mermaid kinds

- **WHEN** the new dispatching API receives a sequence source and a swimlane source
- **THEN** it returns the appropriate typed variant for each and their CSTs reproduce the respective inputs

#### Scenario: Existing sequence consumer

- **WHEN** an existing consumer compiles and runs its sequence-only reading and printing examples unchanged
- **THEN** the examples retain their existing types and results

#### Scenario: Unsupported Mermaid header

- **WHEN** the dispatching API receives an ordinary `flowchart` or another unsupported diagram header
- **THEN** it reports the unsupported kind and returns no model or rendered output

### Requirement: Bounded portable processing

Swimlane reading, printing and conversion SHALL be pure and bounded by explicit
source/output, node, edge, nesting and work limits. Exceeding a limit SHALL give
a distinct diagnostic and no successful complete model/output. Equal inputs
SHALL give equal ASTs, diagnostics, models and printed bytes on wasm, wasm-gc,
js and native.

#### Scenario: Excessive nesting

- **WHEN** nested subgraphs exceed the configured depth limit
- **THEN** processing returns a depth-limit finding without overflowing the host call stack

#### Scenario: A grouped edge exceeds the expansion budget

- **WHEN** grouped endpoints would expand into more connections than the configured edge limit
- **THEN** conversion reports a limit result instead of allocating or silently dropping the excess connections
