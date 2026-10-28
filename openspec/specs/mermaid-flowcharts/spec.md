# mermaid-flowcharts Specification

## Purpose
Read, print and convert native Mermaid flowcharts with source fidelity and
explicit compatibility against the repository's pinned Mermaid baseline.

## Requirements

### Requirement: Native flowchart grammar

The library SHALL read the Mermaid 12.2.0 flowchart grammar, including
`flowchart`, `graph`, header aliases, directions, nodes, shapes, edge chains,
grouped endpoints, subgraphs, labels, metadata and accessibility statements.
The frozen grammar SHALL resolve disagreements with documentation. Header
layout aliases SHALL retain their meaning as presentation requests.

#### Scenario: Header and direction coverage

- **WHEN** the corpus exercises each accepted header and `TB`, `TD`, `BT`, `LR` and `RL`
- **THEN** each source has a typed flowchart AST and the effective direction matches the pinned reference

#### Scenario: Complete syntax coverage

- **WHEN** the frozen documentation and grammar-production fixtures are read
- **THEN** every accepted production has a passing case and every upstream refusal has a recorded reason

### Requirement: Lossless syntax and recoverable findings

The syntax tree SHALL reproduce every source code unit within the source
limit, including invalid regions, front matter, directives, comments, CRLF and
non-BMP text. Diagnostics SHALL have stable codes, severity, messages and
half-open UTF-16 spans with one-based lines and columns. Reading SHALL recover
at valid statement boundaries and retain later readable statements.

#### Scenario: Two errors after Unicode text

- **WHEN** a CRLF source contains an emoji and two malformed statements between valid edges
- **THEN** the tree reproduces the source, both findings identify the original UTF-16 slices and later valid edges remain in the AST

### Requirement: Typed canonical printing

Canonical printing SHALL derive Mermaid text from typed AST values and retain
statement order, identities, nesting, labels and non-rendered metadata. Reading
the result SHALL give an equivalent AST apart from locations and trivia.
Printing again SHALL give identical bytes. Invalid or unrepresentable ASTs
SHALL return diagnostics without stale or partial output.

#### Scenario: Edit a label before printing

- **WHEN** a caller changes a parsed node label, prints the AST and reads it again
- **THEN** the new AST contains the changed label and a second print equals the first

### Requirement: Reference-compatible graph conversion

Conversion SHALL follow the pinned flowchart rules for implicit nodes,
redeclarations, node and edge order, anonymous and repeated subgraphs,
membership, local direction and edge expansion. It SHALL retain distinct
connection IDs and both endpoint markers. All subgraphs SHALL remain groups
without lane ownership. Invalid normalized structure SHALL give diagnostics.

#### Scenario: Grouped edge expansion

- **WHEN** a source uses grouped endpoints, a chained edge and two explicit parallel edges
- **THEN** the normalized node order, edge identities and endpoints equal the pinned independent reference

#### Scenario: Repeated and nested groups

- **WHEN** repeated subgraph IDs and implicit nodes occur inside nested subgraphs
- **THEN** labels, membership, direction and registration order match the pinned flowchart reference without creating lanes

### Requirement: Presentation data remains explicit

The AST and printer SHALL retain classes, styles, callbacks, links, shape
metadata and renderer configuration. Conversion SHALL preserve supported
links and shape values and report unapplied presentation behavior. Source
callbacks, configuration and asset URLs SHALL NOT execute, fetch resources or
change caller options. Unknown and asset-dependent shapes SHALL retain their
identity for explicit rendering diagnostics.

#### Scenario: A callback and an image

- **WHEN** source declares a click callback and a remote image shape
- **THEN** reading and printing retain both, conversion identifies unsupported behavior and no script or network request occurs

### Requirement: Bounded portable flowchart syntax

Reading, printing and conversion SHALL be pure and deterministic on all four
supported targets. Explicit source, output, nesting, metadata, node, edge,
diagnostic and work limits SHALL apply before unbounded expansion. Exhaustion
SHALL give a distinct limit result with no successful complete model or output.

#### Scenario: Grouped endpoints exceed the edge budget

- **WHEN** a grouped edge would expand past the supplied edge limit
- **THEN** conversion reports exhaustion before allocating the excess edges

### Requirement: Independently qualified Mermaid profile

The flowchart corpus SHALL freeze the pinned documentation, grammar, database
and shape sources with provenance, licenses, digests and coverage manifests.
Expected acceptance and normalized graph values SHALL come from pinned
upstream Mermaid, independently of the MoonBit converter. Normal acceptance
tests SHALL use committed fixtures without an upstream runtime or network.

#### Scenario: Qualification checks canonical output

- **WHEN** the reference check reads each source and its MoonBit canonical output
- **THEN** both have the expected upstream acceptance and normalized graph values, and all four MoonBit targets agree with the stored fixtures
