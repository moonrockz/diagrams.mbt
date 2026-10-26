# Spec delta

## Purpose

Read, preserve and print Mermaid architecture source, then convert it to a
validated architecture model with diagnostics tied to the original source.

## ADDED Requirements

### Requirement: Mermaid architecture grammar

The reader SHALL accept the Mermaid 12.2.0 `architecture-beta` grammar, including
groups, services, junctions, all port/arrow forms, labelled edges, `{group}`
endpoints, row/column alignment, quoted service icon text and title/accessibility
statements. The frozen grammar SHALL take precedence over documentation prose.

#### Scenario: Frozen documentation and grammar corpus

- **WHEN** each valid documentation example and grammar production fixture is read
- **THEN** it produces a typed AST with no syntax errors and keeps each declaration

#### Scenario: Labelled edge

- **WHEN** a source uses an edge label accepted by the frozen grammar
- **THEN** the AST and canonical output retain that label and the exact endpoint ports and arrow flags

### Requirement: Lossless architecture source and recovery

The syntax tree SHALL reproduce all source text, including malformed regions,
comments, directives, front matter, whitespace, CRLF and non-BMP characters.
Diagnostics SHALL use stable codes, severity, messages and half-open UTF-16
spans with one-based lines/columns. Reading SHALL resume at a safe statement
boundary after an error and retain later valid statements.

#### Scenario: Two malformed statements

- **WHEN** invalid port and declaration statements occur between valid service declarations
- **THEN** reading reports both errors, retains the valid declarations and reproduces the entire input

### Requirement: Canonical architecture printing

The printer SHALL preserve statement order, IDs, ownership, labels, icon values,
ports, arrow flags, group attachments, alignments and source metadata in native
architecture syntax. Printing SHALL use typed AST values. Reading printed output
SHALL give an equivalent AST, and a second print SHALL give identical bytes.

#### Scenario: A caller edits an alignment

- **WHEN** a caller changes an alignment member order in the AST and prints it
- **THEN** the printed order follows that edit and reparses without restoring stale source text

### Requirement: Reference-compatible architecture conversion

Conversion SHALL follow the frozen Mermaid 12.2.0 reference for declaration
order, ID uniqueness, membership, endpoint eligibility and alignment validation.
It SHALL preserve service identity for group-boundary endpoints and keep each
parallel edge distinct. Semantic errors SHALL identify the relevant statement
and prevent a complete successful model.

#### Scenario: Group-boundary connection

- **WHEN** two grouped services connect with `{group}` at both ends
- **THEN** the model retains both service IDs, their group-boundary attachments, ports and arrow directions

#### Scenario: Invalid group endpoint

- **WHEN** an edge uses a group ID directly where a service or junction is required
- **THEN** conversion reports an endpoint diagnostic without silently replacing it with a service

#### Scenario: Invalid alignment member

- **WHEN** an alignment names an absent element or a group instead of an eligible service/junction
- **THEN** conversion reports a diagnostic with that member and source span

### Requirement: Metadata stays data

Source metadata and renderer configuration SHALL survive source reproduction
and canonical printing. Unsupported rendering options SHALL receive warnings.
Reading and conversion SHALL not execute directives, fetch icons, invoke a
layout engine from metadata or change the caller's rendering options.

#### Scenario: Source asks for random placement

- **WHEN** front matter sets architecture `randomize` or unsupported force-layout tuning
- **THEN** the AST retains it and conversion warns while output follows explicit deterministic library options

### Requirement: Architecture dispatch and error propagation

The multi-kind Mermaid read/print API and SVG convenience operation SHALL accept
`architecture-beta`. Existing sequence and swimlane API contracts SHALL remain
unchanged. Errors at any processing stage SHALL return diagnostics with no
successful partial or empty SVG.

#### Scenario: Architecture source renders through dispatch

- **WHEN** valid architecture source reaches the general Mermaid SVG operation
- **THEN** it converts to an architecture diagram and returns standalone `image/svg+xml` output

### Requirement: Bounded portable architecture processing

Architecture reading, printing and conversion SHALL be pure and obey explicit
source, output, element, connection, alignment, nesting, diagnostic and work
limits. A limit failure SHALL have a distinct diagnostic and no complete
model/output. Equal inputs SHALL give equal syntax, diagnostics, models and
printed bytes on wasm, wasm-gc, js and native.

#### Scenario: Excessive group depth

- **WHEN** declared group ownership exceeds the configured depth
- **THEN** conversion returns a depth-limit diagnostic without unbounded traversal
