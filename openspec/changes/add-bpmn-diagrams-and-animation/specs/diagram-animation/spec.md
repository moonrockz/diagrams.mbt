# Spec Delta

## Purpose

Help readers follow BPMN and sequence interactions with deterministic motion,
explicit route exploration and portable standalone HTML artifacts.

## ADDED Requirements

### Requirement: Pure motion plans

The library SHALL construct and sample immutable motion plans from a diagram,
explicit options and an explicit elapsed time. Plans SHALL identify their source
diagram and target elements. Equal inputs SHALL give equal plans and sampled
states on all four targets. Planning and sampling SHALL not read a clock, DOM,
network, environment or mutable global state.

#### Scenario: Sampling is reproducible

- **WHEN** a plan is sampled at 0, 250 and 1000 milliseconds on each target
- **THEN** each target gives the same active identities, order and progress at each sample

#### Scenario: A plan is used with another view

- **WHEN** a caller supplies a plan whose source diagram identity differs from the rendered view
- **THEN** rendering reports a plan-mismatch error without animating unrelated elements

### Requirement: Motion follows authored connections

Motion SHALL follow the actual rendered path of each selected connection in its
declared direction. It SHALL preserve underlying BPMN symbols, sequence line
styles, labels and arrowheads. Motion SHALL use an overlay so that stopping or
removing it leaves a complete readable static diagram.

#### Scenario: A routed BPMN message

- **WHEN** a selected message flow has four waypoints
- **THEN** its moving highlight follows that routed connection in sender-to-receiver order

#### Scenario: A self-message

- **WHEN** a sequence self-message is animated
- **THEN** the highlight follows its loop path and returns to the same participant

### Requirement: Authored flow and explicit scenario playback

The renderer SHALL offer a repeating illustrative flow mode and finite playback
of a caller-supplied scenario. A scenario SHALL name connection occurrences and
their order, duration and optional concurrent group. Invalid identities, invalid
durations and excessive plan sizes SHALL give diagnostics. An illustrative loop
SHALL NOT be presented as a BPMN process execution.

#### Scenario: Concurrent messages

- **WHEN** a supplied scenario places two messages in the same concurrent group
- **THEN** playback highlights both in that group and then advances to the next group

#### Scenario: Repeated occurrence of a flow

- **WHEN** a finite scenario names one connection twice
- **THEN** playback preserves both occurrences and finishes after the second

#### Scenario: Expressions remain descriptive

- **WHEN** a flow plan is made for a process with a gateway expression and a timer event
- **THEN** the plan retains their descriptions without evaluating the expression, scheduling a timer or reporting an execution outcome

### Requirement: Sequence occurrence order

Sequence animation SHALL preserve message occurrence identity and authored order,
including self-messages and nested frames. Scenario selection SHALL keep the
chosen alternative sections and explicit loop repetitions. Unselected sections
SHALL remain visible but SHALL NOT be animated as part of the selected scenario.
Repeated participants SHALL NOT imply an unbounded interaction cycle.

#### Scenario: Choose an alternative

- **WHEN** a supplied sequence scenario selects the `missing` section of an alt frame
- **THEN** playback includes that section's messages and excludes messages in the `found` section

#### Scenario: Participants exchange messages twice

- **WHEN** messages are `A -> B`, `B -> A` and `A -> B` in that order
- **THEN** finite playback visits the three distinct occurrences once in that order

### Requirement: Directed route and reachability exploration

Readers SHALL be able to select endpoints, inspect one directed shortest route,
and inspect upstream or downstream reachability over selected connection kinds.
Queries SHALL use authored identities and direction, obey explicit bounds and
terminate on cycles. Sequence flows and message flows SHALL remain distinct;
annotations and associations SHALL be excluded from control-flow routes.

#### Scenario: Select a BPMN route

- **WHEN** a reader selects connected tasks `A` and `C` with sequence-flow exploration enabled
- **THEN** the viewer highlights one deterministic shortest route and can play that route

#### Scenario: Message flow is opt-in

- **WHEN** the only connection to another pool is a message flow and the query includes only sequence flows
- **THEN** the viewer reports no route under the selected kinds
- **AND** including message flows permits that structural connection to be explored

#### Scenario: Search exceeds a bound

- **WHEN** a route query exhausts its search limit
- **THEN** the viewer reports that limit separately from an unreachable result

### Requirement: Structural paths do not imply feasible execution

Route output SHALL identify itself as a path over drawn connections. It SHALL
state that conditions, event triggers and gateway synchronization are not
evaluated. It SHALL NOT describe a path as a proven feasible business execution.
Collapsed subprocesses SHALL not expose invented internal routes.

#### Scenario: An exclusive gateway has two conditions

- **WHEN** a reader explores either outgoing branch
- **THEN** the viewer retains the condition labels and identifies the result as structural rather than reporting a condition as true

#### Scenario: A collapsed subprocess hides detail

- **WHEN** an endpoint is inside a subprocess whose inner view is not selected
- **THEN** the viewer requests the inner view or reports the endpoint outside the selected view instead of fabricating a connection

### Requirement: Standalone animated HTML

The animated renderer SHALL return one `text/html` artifact with its inline SVG,
styles, runtime and motion data. It SHALL work offline without external scripts,
fonts, services or UI frameworks. Equal models and options SHALL give identical
HTML bytes on all four targets. Source labels and metadata SHALL be encoded as
data and SHALL not execute as HTML or JavaScript.

#### Scenario: Open the artifact offline

- **WHEN** a browser opens the generated artifact with all network requests blocked
- **THEN** its diagram, playback and route controls work without a request or console error

#### Scenario: A label contains a script terminator

- **WHEN** a source label contains `</script>` and markup with an event-handler attribute
- **THEN** the viewer displays the label as text and executes no source-supplied code

### Requirement: Playback controls

The viewer SHALL provide keyboard-operable play, pause, restart, step, speed and
seek controls with accessible names and current-state feedback. It SHALL start
still. Seeking or changing speed SHALL keep the current logical position.
Selecting a route SHALL replace the active exploration overlay without changing
the underlying document, layout or canonical diagram.

#### Scenario: Pause and seek

- **WHEN** a reader pauses, seeks to the middle of a finite plan and advances one step
- **THEN** the display shows that position and the next step without starting continuous playback

#### Scenario: A route replaces another route

- **WHEN** a reader selects a second route during playback
- **THEN** only the new route overlay remains and the base diagram has unchanged geometry

### Requirement: Reduced motion and inactive pages

The viewer SHALL respect reduced-motion preference and SHALL stop animated work
while the page is hidden. Reduced-motion mode SHALL keep the full static diagram
and allow explicit step inspection without continuous movement. Printing SHALL
show a complete static diagram without controls or transient overlays.

#### Scenario: Reduced motion is enabled

- **WHEN** the browser opens the artifact with reduced motion enabled
- **THEN** no continuous motion starts and the reader can inspect individual steps

#### Scenario: The page is hidden

- **WHEN** an actively playing page becomes hidden
- **THEN** its animation loop stops until it becomes visible and its playback state permits resumption

### Requirement: Canonical static export is isolated

The viewer SHALL provide the complete standalone SVG for download. This export
SHALL satisfy the static renderer contract and SHALL exclude scripts, controls,
motion overlays and route/selection state. Exporting SHALL preserve the viewer's
current selection and logical playback position.

#### Scenario: Export a highlighted route

- **WHEN** a reader downloads SVG while a selected route is playing
- **THEN** the downloaded SVG is byte-identical to a direct static render with the same model, theme and options
- **AND** the viewer retains its selection and playback position
