# sequence-svg-rendering Specification

## Purpose
Renders a sequence model as one standalone SVG file in the visual style of
archify, with output that is easy to read on the web, in Markdown and in slides.

## Requirements

### Requirement: Renderer contract

A renderer SHALL take a diagram and give output text, its media type and
diagnostics. A renderer that does not support the kind of the diagram SHALL give
an error diagnostic and no output.

#### Scenario: The SVG renderer renders a sequence

- **WHEN** the SVG renderer renders a sequence model
- **THEN** the result has SVG text, the media type `image/svg+xml` and no error diagnostics

### Requirement: Standalone SVG

The SVG SHALL be one well-formed XML document. It SHALL NOT contain scripts,
external references, font data or links to other files. It SHALL have a
`<title>` and a `<desc>` from the diagram title and the accessibility fields.

#### Scenario: No external references

- **WHEN** the renderer renders each corpus diagram
- **THEN** no SVG has a `<script>` element, an `@import` rule, a `url(` value that is not a local `#` reference, or an `href` to another file

#### Scenario: Accessibility text

- **WHEN** a diagram has the accessibility title "Login flow"
- **THEN** the SVG has a `<title>` element with the text "Login flow"

### Requirement: Deterministic output

Rendering SHALL be a pure function of the model, the theme and the options. The
same inputs SHALL give the same bytes on all supported targets.

#### Scenario: The same bytes on each target

- **WHEN** the snapshot tests render each corpus diagram on wasm, wasm-gc, js and native
- **THEN** each target gives the same SVG bytes as the stored snapshot

### Requirement: Adaptive theme mode

In the adaptive mode, the SVG SHALL use the dark theme by default and the light
theme when the viewer prefers light. A `data-theme` attribute of `dark` or
`light` on the root element SHALL override the viewer preference.

#### Scenario: The viewer prefers light

- **WHEN** a browser that prefers light shows an adaptive SVG
- **THEN** the SVG uses the light background colour of the theme

#### Scenario: The root element forces dark

- **WHEN** the root element of an adaptive SVG has `data-theme="dark"` and the viewer prefers light
- **THEN** the SVG uses the dark background colour of the theme

### Requirement: Fixed theme mode

In the fixed mode, the SVG SHALL use literal colour values in presentation
attributes. It SHALL NOT use CSS variables, `@media` rules or a `<style>`
element. The caller SHALL select dark or light.

#### Scenario: A fixed light SVG

- **WHEN** the renderer renders a diagram in the fixed light mode
- **THEN** the SVG has no `<style>` element and no `var(` text, and its background has the literal light background colour

### Requirement: Archify visual style

The default theme SHALL use the colour tokens, rounded participant boxes, dashed
lifelines, arrowhead markers and label chips of archify's classic preset. Each
participant kind SHALL map to a colour family. A participant with no specific
kind SHALL get the next family in a fixed cycle.

#### Scenario: Kinds get their colour families

- **WHEN** a diagram has a database participant and a queue participant
- **THEN** the database box uses the database colour family and the queue box uses the message bus colour family

#### Scenario: Plain participants get different colours

- **WHEN** a diagram has three participants with no specific kind
- **THEN** the three boxes use three different colour families

#### Scenario: Reply messages are dashed

- **WHEN** a diagram has a dotted message
- **THEN** the SVG draws the message line dashed in the reply colour

#### Scenario: Two diagrams share an inline page

- **WHEN** a page contains two rendered diagrams with different arrowheads or palettes
- **THEN** each diagram uses its own marker shapes, colours and adaptive CSS

#### Scenario: Repeated inline copies have separate overrides

- **WHEN** a caller gives two copies of the same diagram distinct `id_prefix` values
- **THEN** each copy has its own generated IDs and can use a separate root theme override

#### Scenario: A reversed half-arrow keeps its side

- **WHEN** a sender half-arrow or a right-to-left receiver half-arrow has `upper=true`
- **THEN** the arrowhead is above the message line, also on a self-message return leg

### Requirement: Coloured text and author colours

Lines, boxes and fills SHALL use the theme accent colours as they are. Coloured
text SHALL use a text shade of the same hue that has a contrast ratio of at least
4.5:1. A colour that the author writes for a box group or a rect frame SHALL show
as a translucent tint over the theme background.

#### Scenario: A light-theme label in a low-contrast accent

- **WHEN** a message label in the light theme has the colour of an accent whose contrast is below 4.5:1
- **THEN** the label text uses a darker shade of the same hue with a contrast of at least 4.5:1, and the message line keeps the accent colour

#### Scenario: A rect frame with an author colour

- **WHEN** a diagram has `rect rgb(191, 223, 255)` around a message, in the dark theme
- **THEN** the frame is a translucent tint of that colour, and the legibility check gives no findings for the message label

#### Scenario: A colour that the renderer cannot read

- **WHEN** a diagram has a box group with the colour `notacolour`
- **THEN** the renderer gives a warning diagnostic and uses the theme colour for the box group

### Requirement: Complete rendering of the model

The renderer SHALL draw every model element: participants, box groups,
lifelines, messages with each head value, self-messages, notes, activations,
nested frames with section labels and dividers, creation, destruction, the
title and autonumber values.

#### Scenario: A self-message

- **WHEN** a diagram has a message from `A` to `A`
- **THEN** the SVG draws a loop that starts and ends on the lifeline of `A`, with its label

#### Scenario: Autonumber with a start, a step and off

- **WHEN** a diagram has `autonumber 10 5`, two messages, `autonumber off` and one message
- **THEN** the SVG shows 10 and 15 on the first two messages and no number on the third

#### Scenario: Autonumber

- **WHEN** a diagram has autonumber on and three messages
- **THEN** the SVG shows the numbers 1, 2 and 3 on the three messages in order

#### Scenario: A participant that is created and destroyed

- **WHEN** a diagram creates `B` after its first message and destroys `B` before its last message
- **THEN** the box of `B` is at the row of its creation and its lifeline ends at the row of its destruction with a cross

### Requirement: Render properties in the output

The renderer SHALL use render properties when they are present. A render kind
SHALL select the colour family. A sublabel SHALL show under the participant
label or under the message label. A message label that names its `smithy`
link target, with `/` or `#`, SHALL show as the text after the `/` or `#`.

#### Scenario: A participant sublabel

- **WHEN** a participant has the render sublabel "v2026-01-01"
- **THEN** the SVG shows "v2026-01-01" under the participant label

#### Scenario: A shape ID label shows its short name

- **WHEN** a message has the label `example.weather/City$name` and a `smithy` link to `example.weather#City$name`
- **THEN** the SVG shows the label `City$name`

#### Scenario: Link attributes

- **WHEN** a participant has the link `smithy:example.weather#Weather`
- **THEN** the participant group in the SVG has a `data-link` attribute with the value `smithy:example.weather#Weather`

### Requirement: Legibility

The layout SHALL obey these rules: no label overlaps another label, a
participant box or a line that it does not belong to; each label fits inside its
box or chip; no text is smaller than 11 px; each text colour has a contrast ratio
of at least 4.5:1 against the colour behind it in each theme.

#### Scenario: The corpus passes the legibility check

- **WHEN** the legibility check runs on the layout of each corpus diagram in each theme
- **THEN** the check gives no findings

#### Scenario: Long labels make wider gaps

- **WHEN** a message between two neighbouring participants has a label of 60 characters
- **THEN** the gap between their lifelines is wide enough for the label, and the legibility check gives no findings

#### Scenario: The check finds a low-contrast theme

- **WHEN** the legibility check runs with a theme whose text colour is equal to its background colour
- **THEN** the check gives a contrast finding for each text element

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
values SHALL retain its prior static SVG bytes for equal theme/options except for
reviewed connector changes under the connector-rendering contract. Adding
icon assets SHALL not emit unused definitions or change layout for these models.

#### Scenario: Existing sequence snapshots

- **WHEN** the existing Mermaid sequence corpus is rendered on all four targets
- **THEN** its fixed dark, fixed light and adaptive snapshots preserve existing content, with deterministic reviewed updates only for connector geometry and crossing treatment
