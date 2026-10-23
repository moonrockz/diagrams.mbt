# Spec delta: sequence-model

## Purpose

Describes a sequence diagram without a link to one diagram format, so that each
format, adapter and renderer of a sequence diagram works on the same value.

## ADDED Requirements

### Requirement: Format-independent sequence model

The library SHALL provide one sequence model that each sequence format produces.
The model SHALL hold the participants in declaration order and the events in
diagram order. Events are messages, notes, activation starts and ends,
participant creation and destruction, and frames.

#### Scenario: Participants keep their declaration order

- **WHEN** a sequence declares the participants `C`, `A` and `B` in that order
- **THEN** the model lists the participants as `C`, `A`, `B`

#### Scenario: Events keep their diagram order

- **WHEN** a sequence has a message from `A` to `B`, then a note over `B`, then a message from `B` to `A`
- **THEN** the model lists these three events in that order

### Requirement: Immutable model values

The public values of the sequence model SHALL be immutable. A function that
changes a model SHALL return a new model and SHALL NOT change its input.

#### Scenario: A change returns a new model

- **WHEN** a caller adds render properties to a participant of a model
- **THEN** the caller gets a new model with the properties, and the original model has no properties on that participant

### Requirement: Message ends and line style

Each message SHALL have a sender, a receiver, a line style that is solid or
dotted, a head value at each end and a label. The head values SHALL be able to
express every arrow form of the Mermaid 12.2.0 sequence grammar.

#### Scenario: A solid arrow

- **WHEN** a message has a solid line and a filled arrowhead at the receiver end only
- **THEN** the model gives the line style solid, no head at the sender end and a filled arrowhead at the receiver end

#### Scenario: A bidirectional dotted arrow

- **WHEN** a message has a dotted line and a filled arrowhead at both ends
- **THEN** the model gives the line style dotted and a filled arrowhead at each end

#### Scenario: A message to the same participant

- **WHEN** a message has the same participant as sender and receiver
- **THEN** the model keeps the message with that participant at both ends

### Requirement: Nested frames with sections

The model SHALL have frames of the kinds loop, alt, opt, par, critical, break
and rect. A frame SHALL have one or more sections, each with an optional label
and its own events. Frames SHALL nest.

#### Scenario: An alt frame with two sections

- **WHEN** a sequence has an alt frame with the sections "found" and "missing", each with one message
- **THEN** the model has one alt frame with two sections in that order, each with its message

#### Scenario: A loop inside an alt section

- **WHEN** a loop frame is inside the first section of an alt frame
- **THEN** the model has the loop frame as an event of that section

### Requirement: Participant kinds and groups

Each participant SHALL have a kind. The kinds SHALL include participant, actor,
boundary, control, entity, database, collections, queue, service, resource and
client. A participant SHALL have an optional box group with a label and an
optional colour.

#### Scenario: A database participant

- **WHEN** a sequence declares `Store` as a database
- **THEN** the model gives `Store` the kind database

#### Scenario: Participants in a box group

- **WHEN** a sequence puts `A` and `B` in a box group with the label "Backend"
- **THEN** the model gives `A` and `B` the same box group with the label "Backend"

### Requirement: Links on participants and messages

A participant or a message SHALL have an optional link. A link SHALL have a
scheme and a target. The library SHALL know the schemes `smithy` and `openrpc`.

#### Scenario: A participant with a Smithy link

- **WHEN** a participant links to `smithy:example.weather#Weather`
- **THEN** the model gives the participant a link with the scheme `smithy` and the target `example.weather#Weather`

#### Scenario: A message with no link

- **WHEN** a message has the label "hello" and no link
- **THEN** the model gives the message no link

### Requirement: Render properties

A participant SHALL have optional render properties: a kind, a sublabel and a
description. A message SHALL have optional render properties: a sublabel and a
description. A render property kind SHALL replace the declared kind for
rendering, and the model SHALL keep the declared kind.

#### Scenario: A resolver sets a participant kind

- **WHEN** a participant declared as participant gets the render property kind service
- **THEN** the model gives the declared kind participant and the render kind service

#### Scenario: A message sublabel

- **WHEN** a message gets the render property sublabel "GetForecastOutput"
- **THEN** the model gives the message that sublabel and keeps its label

### Requirement: Link resolution contract

A link resolver SHALL be a pure function. It SHALL take a model and a source, and
it SHALL return a model with render properties and a list of diagnostics. It
SHALL NOT change participants, events or links. A link that the source does not
contain SHALL give a warning diagnostic with the link target.

#### Scenario: A resolver finds a target

- **WHEN** a test resolver that knows the target `example.weather#Weather` resolves a model with a participant link to that target
- **THEN** the result has render properties on that participant and no diagnostics

#### Scenario: A resolver does not find a target

- **WHEN** the same test resolver resolves a model with a participant link to `example.weather#Missing`
- **THEN** the result has a warning diagnostic that names `example.weather#Missing`, and the participant has no new render properties
