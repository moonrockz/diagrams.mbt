# Spec delta

## ADDED Requirements

### Requirement: Explicit participant symbol painting

The sequence renderer SHALL paint each explicit participant icon according to
the diagram-icons contract. It SHALL preserve the participant label, semantic
kind colour family, optional sublabel and link metadata. Symbol bounds SHALL
take part in header width, creation-row, lifeline and legibility calculations.

#### Scenario: Annotated participants in both themes

- **WHEN** a sequence contains UML, cloud and technology annotators with aliases
- **THEN** each displays its catalog symbol and alias without overlap in dark, light and adaptive output

#### Scenario: Annotated participant creation

- **WHEN** an annotated participant is created during an interaction
- **THEN** its creation-row header contains the symbol and label and its lifeline starts at the correct row

### Requirement: Typed exception fragment painting

The renderer SHALL draw try frames with visible try, catch and finally section
roles, catch labels, dividers and nested events. It SHALL not render a finally
section as an alternative catch branch or imply an evaluated exception outcome.
All sections SHALL remain visible in static output.

#### Scenario: Nested exception frame

- **WHEN** a try frame with two catches and finally appears inside a loop
- **THEN** SVG shows the enclosing loop, all exception sections, their labels and their events without overlap

### Requirement: Sequence rendering compatibility without new values

An existing sequence with no explicit icon references or new exception fragment
values SHALL retain its prior static SVG bytes for equal theme/options. Adding
icon assets SHALL not emit unused definitions or change layout for these models.

#### Scenario: Existing sequence snapshots

- **WHEN** the existing Mermaid sequence corpus is rendered on all four targets
- **THEN** its fixed dark, fixed light and adaptive snapshots remain byte-identical
