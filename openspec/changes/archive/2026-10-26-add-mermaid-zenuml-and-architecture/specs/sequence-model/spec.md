# Spec delta

## MODIFIED Requirements

### Requirement: Nested frames with sections

The model SHALL have frames of the kinds loop, alt, opt, par, critical, break,
rect and try. A frame SHALL have one or more sections, each with an optional
label and its own events. Frames SHALL nest. A section SHALL have an explicit
role of plain, try, catch or finally, with plain as the default for existing
construction. Try frames SHALL retain ordered try/catch/finally sections without
converting finally into an alternative.

#### Scenario: An alt frame with two sections

- **WHEN** a sequence has an alt frame with the sections "found" and "missing", each with one message
- **THEN** the model has one alt frame with two sections in that order, each with its message

#### Scenario: A loop inside an alt section

- **WHEN** a loop frame is inside the first section of an alt frame
- **THEN** the model has the loop frame as an event of that section

#### Scenario: Typed exception sections

- **WHEN** a sequence represents try, two catches and finally
- **THEN** it has a try frame with four ordered sections whose roles are try, catch, catch and finally, with the catch labels preserved

#### Scenario: Existing section construction

- **WHEN** a caller constructs a section with the existing constructor arguments
- **THEN** its role is plain and its label and events retain their existing values

## ADDED Requirements

### Requirement: Participant icon references

A participant SHALL have an optional immutable namespaced icon reference
independent of its declared kind, label, group, links and render properties.
The default SHALL be absent. A transformation of render properties SHALL
preserve this reference unless it explicitly changes the icon. Symbol selection
SHALL not overwrite semantic participant kind.

#### Scenario: Cloud symbol on a service

- **WHEN** a service participant has an EC2 icon reference and receives a new render sublabel
- **THEN** its declared service kind, EC2 reference, label and link remain unchanged

#### Scenario: Existing participant construction

- **WHEN** a caller constructs a participant with the existing constructor arguments
- **THEN** it has no explicit icon reference and retains its previous values
