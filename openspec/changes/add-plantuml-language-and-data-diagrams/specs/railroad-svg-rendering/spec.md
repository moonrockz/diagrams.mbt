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

### Requirement: Independent match and failure highlight channels

Regex and EBNF static rendering SHALL accept supplied trace highlights for
matched paths, non-matched paths, taken paths/prefixes and failure points.
Each channel SHALL have independent visibility and theme-aware style options.
Highlighting SHALL work without animation or a provider invocation. With no
requested highlights, rendering SHALL preserve unannotated output bytes.

#### Scenario: Show only failed paths

- **WHEN** non-matched highlights are enabled and matched highlights are disabled
- **THEN** only the supplied non-matched paths receive those highlights in either diagram kind

#### Scenario: Render without annotations

- **WHEN** no trace highlights are requested
- **THEN** rendering gives the ordinary unannotated SVG bytes

### Requirement: Independent failure point and taken prefix

Rendering SHALL allow a failure terminal or assertion to be highlighted without
its taken path, and a taken path without its failure point. Explicit entry/exit
boundary failures SHALL have identifiable markers. Highlights SHALL address
semantic occurrences and actual connector geometry without adding branches or
changing layout.

#### Scenario: Terminal-only rejection marker

- **WHEN** a failed attempt supplies a taken prefix and a failure terminal but only the failure-point channel is enabled
- **THEN** the terminal is highlighted while the prefix retains its ordinary style

#### Scenario: Prefix-only failure illustration

- **WHEN** only the taken-path channel is enabled
- **THEN** the supplied prefix is highlighted without marking unvisited alternatives as failed

### Requirement: Overlapping trace highlights retain evidence

Rendering SHALL retain distinct attempt memberships when matched and failed
paths share a target. Callers SHALL be able to select attempts. Simultaneously
visible classes SHALL use a documented deterministic layered style and accessible
status labels rather than overwrite one another. Keys, descriptions and input
text SHALL remain safely encoded data.

#### Scenario: Backtracking reuses a connector

- **WHEN** matched and non-matched attempts sharing one connector are shown together
- **THEN** both classifications remain identifiable, and selecting either attempt isolates its supplied path

### Requirement: Public renderer and provider integration

The renderer and PlantUML SVG convenience API SHALL accept trace values and
highlight options directly. A separate explicit entry point SHALL allow a caller
to invoke an external provider and render its validated result. Ordinary render
calls SHALL not invoke a provider. Provider failures SHALL remain diagnostics,
distinct from a completed non-match, without silent fallback.

#### Scenario: Completed non-match renders evidence

- **WHEN** an external provider returns a valid completed non-match with a failure point
- **THEN** the explicit trace-rendering entry point returns the requested annotated SVG

#### Scenario: Provider does not support the subject

- **WHEN** the supplied provider returns unsupported
- **THEN** trace rendering reports that outcome without pretending it matched, failed to match or successfully rendered the requested highlights

### Requirement: Configured highlights belong to canonical rendering

Canonical SVG SHALL include the static trace highlights explicitly supplied in
render options. Highlight configuration SHALL not change the diagram model,
source AST or canonical PlantUML text. Display scenes SHALL preserve its geometry
and configured styles, separate from transient playback and selection effects.

#### Scenario: Source writing after a highlighted render

- **WHEN** a diagram is rendered with failure highlights and its AST is then written
- **THEN** the written PlantUML is unchanged by those render options
