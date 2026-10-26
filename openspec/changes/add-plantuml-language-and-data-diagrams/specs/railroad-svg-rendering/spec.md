# Spec Delta

## Purpose

Draw readable regex and EBNF railroad diagrams with deterministic geometry,
clear semantic markers and the shared standalone SVG contract.

## ADDED Requirements

### Requirement: Measured railroad geometry

Layout SHALL measure labels and place entry/exit points, ordered fragments,
alternatives, optional bypasses and repeat loops. It SHALL preserve rule order
and connector direction. Long labels and width constraints SHALL produce
readable geometry or an explicit limit diagnostic without silent truncation.

#### Scenario: Nested repetition and alternatives

- **WHEN** a pattern has a repeated choice inside a sequence
- **THEN** the repeat loop encloses that choice and connectors do not cross its labels

#### Scenario: Multiple EBNF rules

- **WHEN** a grammar has several rules
- **THEN** each has a labelled entry and exit and remains in source order

### Requirement: Constraints and references stay distinct

SVG SHALL distinguish literals, character classes, rule references, assertions,
special sequences and exclusions. It SHALL show repetition bounds and modifiers.
It SHALL not paint an assertion or excluded term as an ordinary consuming
alternative. A reference SHALL not inline a recursive definition.

#### Scenario: A rule excludes another term

- **WHEN** an EBNF rule contains an exclusion
- **THEN** the excluded term is shown as a labelled constraint rather than a second accepted route

#### Scenario: Inspect a recursive reference

- **WHEN** a rule refers to itself
- **THEN** the SVG contains one reference occurrence and a stable target identity without an expanded copy

### Requirement: Standalone themed output

Rendering SHALL return complete, deterministic, script-free SVG with adaptive
and fixed dark/light modes, title and accessibility text. Labels SHALL be safe
text. Resource IDs SHALL be scoped by an explicit prefix so inline copies
remain independent. Existing SVG output for other kinds SHALL remain unchanged.

#### Scenario: Inline copies in different themes

- **WHEN** two copies use different ID prefixes and fixed dark/light modes
- **THEN** neither copy changes the other's markers, colours or selected element identities

### Requirement: Geometry and legibility validation

The public geometry and legibility APIs SHALL report invalid attachment,
label/connector collision, insufficient padding and contrast problems.
Layout SHALL obey explicit depth, node, work and output limits. Failed layout
SHALL return diagnostics without a partial successful SVG.

#### Scenario: Broken return loop

- **WHEN** supplied test geometry places a return path through a terminal label
- **THEN** legibility validation identifies the collision and affected occurrence

### Requirement: Canonical geometry and display bindings

A display scene SHALL share the canonical SVG's measured geometry. Each
playable connector SHALL bind to its actual path and each inspectable semantic
occurrence SHALL have a scoped binding. Display instrumentation SHALL not
change canonical bytes or add semantic branches.

#### Scenario: Play the bypass of an optional term

- **WHEN** a caller selects the bypass connector
- **THEN** its binding follows the drawn bypass and does not animate the term's consuming connector
