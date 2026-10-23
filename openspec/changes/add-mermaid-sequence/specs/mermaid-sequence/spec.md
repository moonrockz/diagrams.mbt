# Spec delta: mermaid-sequence

## Purpose

Reads, checks, prints and converts Mermaid sequence diagrams, with exact source
reproduction and diagnostics that point to the source.

## ADDED Requirements

### Requirement: Supported Mermaid syntax

The reader SHALL accept the complete sequence-diagram grammar of Mermaid 12.2.0,
including every statement and every message arrow. When the grammar and the
Mermaid documentation do not agree, the reader SHALL follow the grammar.

#### Scenario: Every documented example reads without errors

- **WHEN** the reader reads each sequence example of the frozen Mermaid 12.2.0 documentation corpus
- **THEN** each read gives an AST and no error diagnostics

#### Scenario: Every arrow form reads

- **WHEN** the reader reads one message for each arrow form of the Mermaid 12.2.0 grammar
- **THEN** each message is in the AST with its exact arrow spelling

### Requirement: Source reproduction

The reader SHALL give a lossless syntax tree. The text of the tree SHALL be
equal to the source, including whitespace, comments, directives, line endings
and text with errors.

#### Scenario: A source with comments and CRLF line endings

- **WHEN** the reader reads a source with `%%` comments, a `%%{init}%%` directive and CRLF line endings
- **THEN** the text of the syntax tree is equal to the source

#### Scenario: A source with an error

- **WHEN** the reader reads a source that has an unknown statement on line 3
- **THEN** the text of the syntax tree is equal to the source

### Requirement: Diagnostics with source positions

Each diagnostic SHALL have a stable code, a severity, a message and a span. The
span SHALL give UTF-16 offsets, and lines and columns that start at 1. The
values SHALL be the same on all supported targets.

#### Scenario: An unknown statement

- **WHEN** the reader reads a source with the text `frobnicate A` at the start of line 3
- **THEN** the reader gives an error diagnostic with the code `mermaid/unknown-statement` and a span that starts at line 3, column 1

#### Scenario: A position after non-BMP text

- **WHEN** an error follows an emoji on the same line
- **THEN** the column of the error counts the emoji as two UTF-16 code units

### Requirement: Error recovery

After a syntax error, the reader SHALL continue at the next statement and SHALL
report each later error. The AST SHALL contain each statement that has no error.
The reader SHALL NOT drop a statement without a diagnostic.

#### Scenario: Two bad statements between good ones

- **WHEN** a source has a good message, a bad statement, a good message, a bad statement and a good message
- **THEN** the reader gives two error diagnostics and an AST with the three good messages

#### Scenario: A missing frame end

- **WHEN** a source opens a loop frame and has no `end`
- **THEN** the reader gives an error diagnostic at the loop keyword, and the AST has the loop with the statements that follow it

### Requirement: Canonical printing

The printer SHALL write canonical Mermaid text from an AST. The canonical form
SHALL use a documented order and spelling. Reading the printed text SHALL give
an AST that is equal to the printed AST. Printing SHALL give the same text on
all supported targets.

#### Scenario: Printing is stable

- **WHEN** the printer prints the AST of each corpus diagram, and the reader reads the result
- **THEN** the new AST is equal to the first AST, and printing it again gives the same text

#### Scenario: Printing keeps the arrow spelling

- **WHEN** the printer prints a message read from `A-)B: ping`
- **THEN** the printed message uses the arrow `-)`

### Requirement: Conversion to the sequence model

The library SHALL convert an AST to the sequence model. The conversion SHALL keep
participant order, event order, frames, notes, activations, creation,
destruction, box groups, the title, the accessibility fields and each autonumber
statement. A participant that is not declared SHALL be added at its first use, as
Mermaid does.

#### Scenario: An implicit participant

- **WHEN** a source declares `A` and then has the message `A->>B: hi`
- **THEN** the model has the participants `A` and `B` in that order

#### Scenario: The activation shorthand

- **WHEN** a source has `A->>+B: call` and then `B-->>-A: done`
- **THEN** the model has an activation start for `B` after the first message and an activation end for `B` after the second message

### Requirement: Semantic diagnostics

The conversion SHALL report problems that the grammar allows but the meaning
does not. These SHALL include a deactivation of a participant that is not
active, an event for a participant after its destruction, and a second
declaration of a participant with a different kind. As in Mermaid, a `destroy`
statement comes before the message that destroys the participant, and the
destruction takes effect after that message.

#### Scenario: A deactivation without an activation

- **WHEN** a source has `deactivate B` and `B` is not active
- **THEN** the conversion gives an error diagnostic with the code `mermaid/inactive-deactivation` and the span of the statement

#### Scenario: The destroying message is valid

- **WHEN** a source has `destroy B` and then the message `A-xB: stop`
- **THEN** the conversion gives no diagnostic, and the model has the message and then the destruction of `B`

#### Scenario: An event after the destruction

- **WHEN** a source has `destroy B`, the message `A-xB: stop` and then the message `A->>B: again`
- **THEN** the conversion gives an error diagnostic with the code `mermaid/destroyed-participant` and the span of the second message

### Requirement: Links from Mermaid syntax

The conversion SHALL make a participant link from a `link` or `links` statement
whose URL uses a known link scheme. It SHALL make a message link when the whole
message label is a Smithy shape ID. Any other URL or label SHALL stay as it is.

#### Scenario: A participant link statement

- **WHEN** a source has `link W: shape @ smithy:example.weather#Weather`
- **THEN** the participant `W` has a link with the scheme `smithy` and the target `example.weather#Weather`

#### Scenario: A shape ID label

- **WHEN** a source has the message `C->>W: example.weather#GetForecast`
- **THEN** the message has a link with the scheme `smithy` and the target `example.weather#GetForecast`, and the label `example.weather#GetForecast`

#### Scenario: A label that only looks like a shape ID

- **WHEN** a source has the message `C->>W: see #42`
- **THEN** the message has no link and the label `see #42`

#### Scenario: A web link stays a Mermaid link

- **WHEN** a source has `link W: docs @ https://example.com/w`
- **THEN** the participant `W` has no model link, and the AST keeps the Mermaid link

### Requirement: Pure and deterministic processing

Reading, printing and conversion SHALL be pure. They SHALL NOT read files, the
network, the clock or the environment. The same input SHALL give the same
output on all supported targets.

#### Scenario: The same result on each target

- **WHEN** the corpus tests run on wasm, wasm-gc, js and native
- **THEN** each target gives the same syntax trees, ASTs, diagnostics and printed text
