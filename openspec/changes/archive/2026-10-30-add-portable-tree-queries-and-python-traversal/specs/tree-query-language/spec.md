# Spec Delta

## Purpose

Let MoonBit and other language consumers select and project immutable tree values through one portable, bounded query language and evaluator.

## ADDED Requirements

### Requirement: Public portable query core

The query compiler, typed query representation, evaluator and tree-adapter contract SHALL be public MoonBit APIs. They SHALL give equal normalized results on wasm, wasm-gc, js and native. The generic core SHALL require only core libraries and SHALL NOT import Python, a renderer, host I/O or a specific document model.

#### Scenario: A MoonBit consumer has no Python dependency

- **WHEN** a fresh MoonBit consumer compiles and executes a query over a supplied tree adapter
- **THEN** it can inspect captures and failures on all four targets without a Python runtime or native extension

#### Scenario: The core supports more than one tree schema

- **WHEN** the same core evaluates the BPMN adapter and a small independent test-tree adapter
- **THEN** each uses its declared kinds, fields and scalar values without domain-specific conditions in the evaluator

### Requirement: Versioned structural query language

Version 1 SHALL support exact kinds, categories, wildcards, ordered direct-child patterns, named child fields, absent child fields, alternatives, named captures and documented native predicates. Candidate roots SHALL be searched through containment descendants. Unsupported Tree-sitter features SHALL give a compile diagnostic, not partial interpretation.

#### Scenario: Capture a typed child

- **WHEN** a query names a process with a user-task child in its declared flow-element field
- **THEN** it captures only matching direct-child relationships in the declared order
- **AND** nodes deeper inside a subprocess do not match that direct-child constraint

#### Scenario: Unsupported syntax is explicit

- **WHEN** version 1 receives a quantifier, adjacency anchor, directive or regular-expression predicate
- **THEN** compilation gives a stable unsupported-feature code and the query-source span
- **AND** no executable plan is returned

### Requirement: Native predicates and namespace identity

Attribute equality, inequality, existence, absence and membership predicates, and scalar-text equality SHALL execute inside the shared evaluator. Missing attributes SHALL differ from empty values. Names SHALL resolve by the supplied schema and namespace bindings. Unknown names, predicates and capture references SHALL fail compilation. Queries SHALL NOT execute host callbacks or external code.

#### Scenario: Prefix spelling does not change the result

- **WHEN** two namespace maps bind different query prefixes to the same namespace URI
- **THEN** equivalent queries select the same nodes and attributes

#### Scenario: Missing and empty attributes

- **WHEN** one node lacks a name and another has an explicitly empty name
- **THEN** the existence and equality predicates distinguish them identically on all targets

#### Scenario: A predicate cannot call Python

- **WHEN** a query names an unregistered predicate
- **THEN** compilation fails without invoking a Python function, filesystem or network operation

### Requirement: Shared query compilation paths

Text compilation and public typed query construction SHALL use the same schema checks, limits and evaluation rules. Compiled plans SHALL be immutable and reusable with independent execution cursors. A plan SHALL identify its language and adapter-schema versions and reject an incompatible schema without searching it.

#### Scenario: Text and typed forms agree

- **WHEN** a MoonBit consumer constructs the typed form of a query and compiles its text form
- **THEN** both return the same ordered matches, captures and failures on the same tree

#### Scenario: Cursors do not share position

- **WHEN** two cursors execute one compiled plan over one immutable tree
- **THEN** advancing, stopping or closing one does not change the other

### Requirement: Deterministic matches and capture identity

Matches SHALL retain pattern index, capture names, node identities and optional locations. Order SHALL be candidate-root preorder, source pattern order and lexicographic child-position order. Equivalent matches from different pattern indices SHALL remain distinct. Capturing the same node twice SHALL retain both named captures. Compilation SHALL reject duplicate capture names within one alternative.

#### Scenario: Overlapping alternatives are retained

- **WHEN** two source patterns match the same node
- **THEN** both matches are returned in source pattern order with their distinct pattern indices

#### Scenario: A node has two capture roles

- **WHEN** one successful pattern captures a node in two distinct roles
- **THEN** both roles identify the same underlying node and revision

### Requirement: Projection without repeated property calls

Consumers SHALL request capture handles and a declared set of node fields in one operation. Projection SHALL preserve strings, scalar tags, absent values and source-location units. A field absent on a node SHALL be absent data; an unknown projection field SHALL be an input failure. Projected snapshots SHALL remain valid while the result owner is retained.

#### Scenario: Collect IDs and names

- **WHEN** a query requests identity, ID and name for each captured activity
- **THEN** each returned row contains those values without a property callback for each field
- **AND** field selection does not change matching or capture order

### Requirement: Bounded execution and truthful completion

Compilation and execution SHALL have explicit source, pattern, depth, work, pending-match, capture, result and output limits. Limit failures SHALL identify the exhausted bound. A batch cursor SHALL distinguish data, complete, stopped and failed states. Previously delivered batches SHALL not imply completeness. Work and result budgets SHALL be cumulative across batches.

#### Scenario: Batch size does not change meaning

- **WHEN** a query executes with batch sizes 1, 64 and 256 under equal sufficient limits
- **THEN** concatenating each complete run gives the same ordered matches and projections

#### Scenario: A bound is reached after a batch

- **WHEN** a cursor exhausts its work budget after delivering one batch
- **THEN** its terminal state is a limit failure and not complete or an empty successful result
- **AND** requesting another batch does not reset the work budget

### Requirement: Query diagnostics and malformed input

Compile diagnostics SHALL contain stable codes, severity, message and half-open UTF-16 query-source offsets with one-based lines and columns. CRLF SHALL count as one line break. Invalid or unsupported patterns SHALL not execute. Supported matching SHALL use bounded explicit stacks rather than host-stack recursion.

#### Scenario: Invalid query follows a non-BMP character

- **WHEN** malformed query text contains a non-BMP character before the error
- **THEN** all MoonBit targets and Python identify the same UTF-16 source slice

#### Scenario: Deep but permitted trees

- **WHEN** a valid tree has 10,000 nested nodes and the configured bounds permit the query
- **THEN** matching terminates without a host-stack overflow and agrees across targets

### Requirement: Tree matching does not infer graph traversal

Structural patterns SHALL follow only adapter-declared containment. IDs, reference attributes, diagram coordinates and labels SHALL NOT create implicit child or descendant edges. Graph reachability and routes SHALL remain explicit operations with their own edge kinds and failures.

#### Scenario: A reference cycle is harmless to containment matching

- **WHEN** two contained tasks reference each other through sequence flows
- **THEN** a tree query visits the containment candidates without following those flows or repeating candidates because of the cycle
