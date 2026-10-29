# diagram-animation Specification

## Purpose
Help readers follow BPMN and sequence interactions with deterministic motion,
explicit route exploration and portable standalone HTML artifacts.

## Requirements

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

Routes SHALL identify their structural relation and visible scope. They SHALL
not assert feasible execution or evaluate conditions, event triggers, gateway
synchronization, regex matches or grammar acceptance. Connection steps SHALL
follow drawn paths; data relations without connectors SHALL use node visits.
Hidden detail SHALL require another view or an outside-view result, with no
invented connections.

#### Scenario: An exclusive gateway has two conditions

- **WHEN** a reader explores either outgoing branch
- **THEN** the viewer retains the condition labels and identifies the result as structural rather than reporting a condition as true

#### Scenario: A collapsed subprocess hides detail

- **WHEN** an endpoint is inside a subprocess whose inner view is not selected
- **THEN** the viewer requests the inner view or reports the endpoint outside the selected view instead of fabricating a connection

#### Scenario: A regex branch has a lookaround

- **WHEN** a reader explores a branch next to a lookaround constraint
- **THEN** the viewer retains the constraint description without claiming that any input matches

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

### Requirement: Swimlane motion catalog and bindings

The shared animation API SHALL accept swimlane diagrams and retain node/group,
lane and connection identities in its catalog and scene bindings. Each visible
connection occurrence SHALL bind to its actual rendered path. Parallel edges
SHALL remain independently selectable. Invisible layout constraints SHALL be
excluded from playback and route graphs.

#### Scenario: Animate a cross-lane handoff

- **WHEN** a caller plays a connection from Customer to Support
- **THEN** motion follows that connection's routed path between the actual endpoint outlines

#### Scenario: Select one parallel edge

- **WHEN** two labelled handoffs connect the same endpoints and one ID is selected
- **THEN** only that connection's occurrence is highlighted or played

#### Scenario: Invisible edge

- **WHEN** an invisible connection is present in the layout model
- **THEN** it creates no playable occurrence or route through the animation graph

### Requirement: Swimlane route direction

Swimlane routes SHALL follow directed arrow semantics, support both directions
of bidirectional connections and obey explicit reverse queries. Unheaded
connections SHALL participate only when undirected exploration is explicitly
enabled. A resolved route SHALL retain each connection's traversal direction,
and playback SHALL follow that direction without changing its markers.

#### Scenario: Right-to-left layout is not a reversed edge

- **WHEN** an `RL` diagram contains `A --> B` and the reader selects `A` then `B`
- **THEN** a forward route exists and its motion follows `A` to `B` even though it travels left

#### Scenario: Bidirectional return

- **WHEN** a bidirectional connection joins `A` and `B` and the route starts at `B`
- **THEN** playback travels from `B` to `A` along the same connection with its markers intact

#### Scenario: Unheaded connector is opt-in

- **WHEN** `A --- B` is the only connection and undirected exploration is disabled
- **THEN** directed route search reports no route
- **AND** enabling undirected exploration permits either traversal direction without claiming a directed business flow

### Requirement: Swimlane scope and structural exploration

Swimlane route/reachability queries SHALL keep the existing deterministic bounds
and result distinctions. They SHALL use explicit connections, not lane
membership or position. Collapsed group descendants SHALL be outside the visible
query scope. Route output SHALL remain structural and SHALL not evaluate labels
as conditions or reinterpret a diamond as a BPMN gateway.

#### Scenario: A shared lane is not an edge

- **WHEN** two nodes share one lane but have no connecting path
- **THEN** route search reports them as disconnected

#### Scenario: Collapsed group

- **WHEN** a requested endpoint is hidden inside a collapsed group
- **THEN** the query reports it outside the current view rather than inventing a route through that group

### Requirement: Shared standalone playback for swimlanes

The animated renderer SHALL provide the existing offline playback, route/reach,
keyboard, reduced-motion, visibility and static-export behavior for swimlanes.
Export SHALL give the canonical static swimlane SVG without transient overlays.
Existing sequence/BPMN playback behavior SHALL remain unchanged; shared-runtime
byte changes SHALL be covered by updated deterministic HTML snapshots.

#### Scenario: Export while playing

- **WHEN** a selected swimlane route is playing and the reader downloads SVG
- **THEN** the download equals the direct static render and the viewer keeps its playback position and selection

#### Scenario: Existing diagram playback

- **WHEN** existing sequence and BPMN browser qualification runs with the extended runtime
- **THEN** playback controls, route semantics, safe labels and canonical static downloads still pass their contracts

### Requirement: Pattern grammar and data catalogs

The shared catalog and scene APIs SHALL accept regex, EBNF and structured-data
models. They SHALL retain occurrence identities, semantic roles and source/view
bindings. Connection occurrences SHALL bind to real paths; value occurrences
SHALL bind to their visible nodes or rows. Equal labels SHALL not merge targets.

#### Scenario: Equal terminals in two branches

- **WHEN** a caller selects one of two equally labelled terminal occurrences
- **THEN** only that occurrence and its selected connectors are inspected or played

### Requirement: First-class node visits

Pure plans SHALL support timed visits to visible nodes or rows without a
connection path. Visits SHALL sample deterministically from explicit elapsed
time and obey the existing duration and plan-size bounds. Wrong target kinds,
missing targets and source mismatches SHALL produce diagnostics. Existing
connection-step and orientation behavior SHALL remain unchanged.

#### Scenario: Seek during a scalar visit

- **WHEN** a finite plan visits an inline scalar row and is sampled halfway through its duration
- **THEN** the same row and visit progress are active on all four targets without a fake path

### Requirement: Bounded railroad exploration

Railroad route and reachability queries SHALL use the displayed expression
topology, with explicit connector direction and bounded repetition handling.
Assertions and exclusions SHALL retain constraint roles. Rule references SHALL
be inspectable targets and SHALL not create invisible route edges or recursively
expand definitions.

#### Scenario: Explore a repeated alternative

- **WHEN** a reader selects a branch and return connector in a repeated expression
- **THEN** playback follows the chosen drawn paths and terminates under the supplied finite scenario

#### Scenario: A reference names another rule

- **WHEN** a reader inspects an EBNF reference with no drawn inter-rule connection
- **THEN** its target can be identified without inventing an animated connection or a parser call

### Requirement: Typed hierarchy exploration

Data queries SHALL identify their relation as containment and provide bounded
ancestor, descendant and parent/child route results. They SHALL preserve member
and array occurrence order. Route plans SHALL combine explicit row visits with
steps on connectors that exist. Literal references, equal values and adjacent
rows SHALL not create extra relations.

#### Scenario: Parent and inline member

- **WHEN** a selected parent/child relation ends at an inline scalar row
- **THEN** the viewer visits that row without drawing a connector absent from the static view

#### Scenario: A search limit is reached

- **WHEN** a hierarchy query exhausts its budget
- **THEN** it reports exhaustion separately from an unreachable or outside-view endpoint

### Requirement: Finite language and data illustrations

Default illustrations SHALL use deterministic source or hierarchy order and
bounded occurrence sets. They SHALL not expand unbounded repeats or recursive
references. Explicit scenarios SHALL preserve chosen occurrences, repetitions,
durations and concurrent groups. Neither mode SHALL compute or verify input
acceptance. Supplied provider outcomes SHALL be distinguished from structural
query results.

#### Scenario: An unbounded repetition

- **WHEN** a pattern with an unbounded quantifier receives its default illustration
- **THEN** the finite plan illustrates its structure without allocating an unbounded timeline

### Requirement: Shared offline playback for new kinds

The standalone player SHALL support the new kinds and node visits through the
existing controls, reduced-motion, hidden-page, print and offline contracts.
Static export SHALL equal the direct canonical SVG and preserve viewer state.
Existing sequence, BPMN and swimlane playback SHALL remain compatible; shared
runtime byte changes SHALL have deterministic updated HTML snapshots.

#### Scenario: Export during a row visit

- **WHEN** a reader exports SVG while a row visit is playing
- **THEN** the bytes equal the direct static render and playback keeps its position and selection

#### Scenario: Open all four source kinds offline

- **WHEN** generated regex, EBNF, JSON and YAML players open with network access blocked
- **THEN** controls, selection, path steps and row visits work with no request or console error

### Requirement: Supplied trace highlights survive playback and export

Configured static match/failure highlights SHALL remain separate from playback
and selection overlays. Export SHALL equal direct static rendering with the
same trace and style options. Playback and export SHALL not invoke a trace
provider or compute acceptance. Displayed supplied outcomes SHALL identify
their external origin.

#### Scenario: Export a failure-highlighted grammar while playing

- **WHEN** a grammar has configured failure-terminal highlights and the reader exports SVG during playback
- **THEN** export retains those configured highlights, excludes transient progress, and preserves viewer position and selection
- **AND** the provider is not invoked again

### Requirement: Architecture catalog and scene bindings

The animation API SHALL accept architecture diagrams and retain service,
junction, group and connection identities. Each connection occurrence SHALL
bind to its actual rendered path. Parallel edges SHALL remain selectable
independently. Group-boundary attachment SHALL not replace authored service
endpoints with group IDs in the route graph.

#### Scenario: Connection between grouped services

- **WHEN** playback selects an edge attached to the groups beside two services
- **THEN** motion follows the rendered group-boundary path while the catalog retains the two service identities

### Requirement: Architecture direction and structural queries

Architecture route and reachability queries SHALL follow arrowhead direction.
Bidirectional edges SHALL permit both directions; unheaded edges SHALL require
explicit undirected exploration. Results SHALL retain traversal direction.
Junctions SHALL be graph endpoints; containment, alignment and proximity SHALL
not create edges. Queries SHALL retain existing deterministic bounds and result
distinctions.

#### Scenario: Bidirectional return route

- **WHEN** a route traverses a bidirectional edge in the reverse of its stored endpoint order
- **THEN** playback follows the resolved traversal direction with the original markers intact

#### Scenario: Unheaded edge

- **WHEN** two services have only an unheaded edge and undirected exploration is disabled
- **THEN** directed search reports no route
- **AND** enabling undirected exploration permits traversal in either direction

#### Scenario: Aligned services have no connection

- **WHEN** services share a group and alignment but no connecting path
- **THEN** reachability reports them as disconnected

### Requirement: Shared standalone architecture playback

Architecture HTML SHALL provide existing offline playback, explicit scenarios,
route/reachability controls, keyboard access, reduced-motion, visibility and
static-export behavior. It SHALL start still. Playback SHALL describe authored
connections without asserting execution or deployment outcomes. Equal inputs
SHALL produce identical HTML bytes on all four targets.

#### Scenario: Open architecture playback offline

- **WHEN** an architecture artifact opens with network requests blocked
- **THEN** symbols, controls and routes work without network requests or console errors

#### Scenario: Canonical export during playback

- **WHEN** a reader downloads SVG while an architecture route is playing
- **THEN** it equals a direct static render and the player retains selection and logical playback position

### Requirement: ZenUML sequence projection and exception scenarios

Converted ZenUML SHALL use the shared sequence catalog, occurrence ordering and
scene bindings. Explicit scenarios SHALL identify selected exception sections
and retain finally as a distinct role. Unselected sections SHALL remain visible
without playback. The player SHALL not evaluate exceptions or infer which
section executes from labels.

#### Scenario: Explicit catch and finally selection

- **WHEN** a caller supplies a scenario selecting one catch section and a finally section
- **THEN** playback follows those selected occurrences in supplied order without selecting another catch or claiming an exception was evaluated

### Requirement: Existing playback and new symbols remain intact

Extending shared playback SHALL preserve sequence/BPMN/swimlane behavior.
Annotated participant symbols SHALL remain in canonical/display SVG, still
states, print output and static download. Shared HTML byte changes SHALL remain
deterministic and satisfy the existing browser contracts.

#### Scenario: Annotated sequence export

- **WHEN** an annotated ZenUML sequence is paused, stepped, printed and exported
- **THEN** its symbols remain present and downloaded SVG equals the direct static output

#### Scenario: Existing player qualification

- **WHEN** existing sequence, BPMN and swimlane browser suites run with the extended runtime
- **THEN** controls, route semantics, safe labels and canonical downloads continue to pass

### Requirement: Flowchart catalog and scene bindings

The shared animation API SHALL accept flowcharts from both source formats and
retain visible node, group, lane, note, region and connection identities.
Playable connections SHALL bind to actual rendered paths. Separate equal-label
nodes and parallel edges SHALL remain independently selectable. Isolated
visible nodes SHALL support timed visits without fabricated paths. Invisible
constraints and note attachments SHALL NOT become playable route edges.

#### Scenario: Select a repeated action

- **WHEN** a caller selects the second of two equal-label action occurrences
- **THEN** only that action is visited or highlighted and its own incident paths remain identifiable

#### Scenario: Select a parallel connection

- **WHEN** two labelled edges share endpoints and one is played
- **THEN** motion follows only that edge's drawn route and retains its markers

### Requirement: Flowchart route direction and scope

Route and reachability queries SHALL use actual connection direction, preserve
resolved traversal direction and permit unheaded connections only through
explicit undirected exploration. Group or lane membership SHALL NOT create
edges. Hidden descendants SHALL be outside the visible query scope. Queries
SHALL terminate on cycles and distinguish unreachable, outside-view, invalid
and exhausted results under explicit limits.

#### Scenario: Right-to-left edge

- **WHEN** an `RL` diagram has `A --> B` and a forward query starts at `A`
- **THEN** it reaches `B` and playback moves from `A` to `B` even though that path travels left

#### Scenario: Bidirectional and unheaded connections

- **WHEN** a query traverses a bidirectional edge in reverse or requests an unheaded edge
- **THEN** the first retains its reverse traversal and the second is available only when undirected exploration is enabled

#### Scenario: Hidden endpoint and exhausted search

- **WHEN** one query targets a collapsed descendant and another consumes its work budget
- **THEN** the first reports outside-view and the second reports exhaustion rather than unreachable

### Requirement: Finite flowchart illustrations and explicit scenarios

Default illustrations SHALL use deterministic ordered finite occurrence sets.
They SHALL NOT unfold loops or recursively expand regions without a bound.
Explicit scenarios SHALL retain chosen branch connections, repeated
occurrences, durations, node visits and concurrent groups. Invalid identities,
durations, source bindings and excessive plan sizes SHALL return diagnostics.
Plan construction and sampling SHALL remain pure and portable.

#### Scenario: Loop played twice

- **WHEN** a scenario names the same loop-return edge twice
- **THEN** playback retains both occurrences and stops at the supplied finite end

#### Scenario: Explicit parallel group

- **WHEN** a scenario places two fork branches in one concurrent group
- **THEN** both animate in that group before the next scenario group without inferring synchronization

### Requirement: Flowchart exploration remains structural

Playback and queries SHALL identify results as structural illustration or a
caller-supplied scenario. They SHALL retain condition, branch, loop and join
labels without evaluating expressions, selecting feasible branches, executing
actions or asserting fork synchronization. PlantUML control roles SHALL remain
inspectable without turning the player into an execution engine.

#### Scenario: A join has a specification

- **WHEN** a reader explores a fork and join with condition and join-specification text
- **THEN** the viewer retains that text and reports a structural path without claiming that any condition or synchronization succeeded

### Requirement: Shared offline flowchart playback

Flowchart HTML SHALL provide existing play, pause, restart, step, seek, speed,
route and reachability controls with keyboard access and state feedback. It
SHALL start still and respect reduced motion, hidden-page and print behavior.
Artifacts SHALL work offline, encode source content as data and give identical
bytes for equal inputs on all four targets. No source-supplied code SHALL run.

#### Scenario: Open all dialects offline

- **WHEN** Mermaid and modern/legacy PlantUML flowchart players open with network blocked
- **THEN** diagrams, inspection, scenarios, controls and routes work without requests or console errors

#### Scenario: Reduced motion and visibility

- **WHEN** reduced motion is enabled or a playing page becomes hidden
- **THEN** continuous animation stops, explicit step inspection remains available and print output contains the complete static diagram

### Requirement: Canonical flowchart export and playback compatibility

SVG download SHALL equal direct static rendering for the same flowchart and
options and SHALL exclude transient route, selection and progress overlays.
Export SHALL preserve viewer position and selection. Existing diagram
playback contracts SHALL remain unchanged. Shared runtime byte changes SHALL
have deterministic updated HTML snapshots and pass existing browser checks.

#### Scenario: Export during a loop step

- **WHEN** a reader downloads SVG while a repeated loop connection is playing
- **THEN** download bytes equal direct static SVG and playback retains its occurrence, progress and selection

#### Scenario: Existing player qualification

- **WHEN** sequence, BPMN, swimlane, architecture, railroad and data-tree players are qualified after the extension
- **THEN** their controls, route semantics, source escaping and canonical exports still satisfy existing contracts

### Requirement: Playback follows styled connectors

Playback bindings SHALL use the final path for the selected connector options,
including smooth curves, rounded corners and crossing bridges. Forward and
reverse motion SHALL follow that path in the resolved direction. Progress,
selection and trace overlays SHALL retain crossing separation and underpass
masks. Styling SHALL NOT change occurrences, graph connectivity or query results.

#### Scenario: Play a curved bridge forward and backward

- **WHEN** a reader plays a curved connection with a bridge and then explores it in reverse
- **THEN** the motion follows the visible curve and bridge in the correct direction in both cases
- **AND** the route retains its original semantic endpoints and occurrence identity

#### Scenario: Highlight the underpass

- **WHEN** a selected or playing connection passes beneath another connection's bridge
- **THEN** its overlay preserves the underpass and does not paint over the bridge as a new joined crossing

#### Scenario: A crossing is not a graph vertex

- **WHEN** two disconnected routes cross and the reader requests reachability between them
- **THEN** the crossing adds no reachable endpoint regardless of connector style

### Requirement: Canonical export retains connector options

Static downloads SHALL equal direct SVG rendering for the same diagram,
connector options and configured trace highlights. Export SHALL preserve viewer
position, selection and speed and exclude transient playback overlays. Every
supported diagram kind SHALL retain offline, keyboard, reduced-motion,
hidden-page and print behavior with the new path styles.

#### Scenario: Download while a bridge is playing

- **WHEN** a reader downloads SVG during curved-bridge playback
- **THEN** the bytes equal direct static rendering, including the bridge and local mask definitions
- **AND** the current occurrence, position, selection and speed do not change

#### Scenario: Styled players without a network

- **WHEN** qualified players for every diagram kind open with network requests blocked
- **THEN** style-specific motion and canonical downloads work without requests or console errors
- **AND** reduced motion, keyboard stepping, page hiding and print retain their existing contracts

### Requirement: State catalog and scene bindings

The shared animation API SHALL accept state diagrams from both readers and
direct model construction. Catalogs SHALL retain visible state, region,
pseudostate, note and transition identities. Playable transitions SHALL bind to
their real final paths and masks. Isolated states SHALL support node visits.
Description lines, ownership and note attachments SHALL NOT become route edges.

#### Scenario: Select one parallel transition

- **WHEN** two transitions have the same endpoints and one occurrence is selected
- **THEN** inspection and motion identify only that transition and follow its own rendered path

#### Scenario: Visit a disconnected state

- **WHEN** a caller supplies a timed visit for a visible state without transitions
- **THEN** the player highlights that state without adding an invisible connection

### Requirement: State route direction and scope

Routes and reachability SHALL follow explicit transitions and retain resolved
traversal direction. Reverse queries SHALL follow the same real path in reverse.
Unheaded relations SHALL require opt-in undirected exploration. Hierarchy,
concurrency and history SHALL NOT imply transitions. Queries SHALL terminate on
cycles and distinguish invalid, outside-view, unreachable and exhausted results.

#### Scenario: Regions do not imply reachability

- **WHEN** states share a composite or concurrent region but have no transition path
- **THEN** search reports them disconnected without inventing entry, exit or synchronization steps

#### Scenario: Collapsed and exhausted queries

- **WHEN** one query targets a hidden child and another exhausts its work bound
- **THEN** the first reports outside-view and the second reports exhaustion rather than unreachable

### Requirement: Finite state illustrations and scenarios

Default illustrations SHALL use deterministic finite occurrence sets without
unfolding cycles. Explicit scenarios SHALL retain selected transitions, repeated
occurrences, node visits, durations and caller-selected concurrent groups.
Invalid identities, source mismatches, durations and excessive plan sizes SHALL
give diagnostics. Plan construction and sampling SHALL remain pure on all four
targets.

#### Scenario: Repeat a self-transition

- **WHEN** a scenario names one self-transition twice followed by a state visit
- **THEN** both distinct playback occurrences follow the loop and the finite scenario ends after the visit

#### Scenario: Illustrate concurrent regions

- **WHEN** a caller groups two region transitions concurrently
- **THEN** both animate with the supplied timing without asserting an active state configuration or fork/join synchronization

### Requirement: State playback remains descriptive

Playback and query results SHALL identify structural illustration or a supplied
scenario. Event, guard, action, entry/do/exit and internal behavior descriptions
SHALL remain inspectable data. The player SHALL NOT schedule events, evaluate
guards, execute actions, restore history, select feasible branches or claim
state-machine execution or UML semantic validation.

#### Scenario: Explore a guarded history transition

- **WHEN** a reader explores a transition labelled with an event, guard and action to deep history
- **THEN** the viewer preserves those descriptions and the history target without evaluating the guard or selecting a restored state

### Requirement: Shared offline state playback

Standalone state HTML SHALL provide the existing play, pause, restart, step,
seek, speed, inspection, route and reachability controls with keyboard access
and feedback. It SHALL start still, respect reduced motion and page visibility,
and print the complete static diagram. It SHALL work offline, encode source
content as data and have equal bytes on all four targets.

#### Scenario: Offline hostile labels

- **WHEN** players from both formats open with network blocked and labels containing a script terminator
- **THEN** controls and routes work without requests or console errors and labels cannot execute code

#### Scenario: Reduced motion and print

- **WHEN** reduced motion is enabled, the page becomes hidden or the user prints
- **THEN** continuous animation stops as required, explicit stepping remains available and print contains the complete static diagram without viewer overlays

### Requirement: Canonical state export and connector parity

State SVG download SHALL equal direct static rendering for the same model,
theme and connector options. Motion and selection SHALL retain final curves,
bridges and underpass masks. Export SHALL exclude transient overlays and
preserve position, occurrence, selection and speed. Existing diagram/player
contracts SHALL remain unchanged; shared HTML changes SHALL have reviewed
portable snapshots and browser qualification.

#### Scenario: Export during a curved return

- **WHEN** a reader downloads SVG while a repeated curved transition with a bridge is played in reverse
- **THEN** the download equals direct static SVG, crossing separation remains correct and the viewer retains its state

#### Scenario: Existing player regression

- **WHEN** all existing diagram player suites run after state integration
- **THEN** their controls, bindings, scope, escaping, motion paths and canonical downloads still pass

### Requirement: Player raster downloads

The shared offline player SHALL offer canonical PNG and JPEG downloads and
animated GIF export through the diagram-raster-export contract. PNG SHALL be
the default still format. The export controls SHALL have public styling hooks
and preserve the existing canonical SVG download.

#### Scenario: Save a still or animation

- **WHEN** a reader selects PNG, JPEG or animated GIF
- **THEN** export uses the selected format and validated options with accessible feedback
- **AND** the live player's position, speed, route, zoom and pan remain unchanged

### Requirement: Themed player presentation

The shared offline player SHALL use the site's Smithy-aligned light and dark
palette with an explicit system option. It SHALL provide a clear heading,
prominent diagram stage, primary playback action, timeline with position and
duration, and grouped exploration controls. Fixed-theme diagram colors SHALL
remain independent from the surrounding player theme.

#### Scenario: Open a player in either theme

- **WHEN** a reader opens a player in light, dark or system mode
- **THEN** its controls, surfaces, focus states and timeline use the selected shell palette
- **AND** the SVG remains readable in its supplied fixed or adaptive theme

#### Scenario: Narrow player layout

- **WHEN** a reader opens a player at 360 CSS pixels
- **THEN** the diagram, playback, position, speed, scope and exploration controls remain usable without horizontal page overflow

### Requirement: Player theme preference

When opened from the site, a player SHALL honor the site's stored theme
preference when storage is available. Standalone use or blocked storage SHALL
fall back to the system preference. A host's explicit viewer theme SHALL take
precedence over stored and system preferences.

#### Scenario: Site preference and blocked storage

- **WHEN** the site has a stored dark preference or the browser blocks storage
- **THEN** the player uses dark or falls back to the system without a script error
- **AND** an explicit host theme overrides either result

### Requirement: Player viewport controls

The animation stage SHALL follow the diagram-viewer-controls contract. Zoom,
pan, fit and fullscreen SHALL move the complete diagram and its transient
overlays together. Viewport actions SHALL preserve position, speed, occurrence,
selected route and playback state.

#### Scenario: Inspect during playback

- **WHEN** a reader zooms, pans or enters fullscreen during playback
- **THEN** highlighted connections and tokens remain aligned with the diagram
- **AND** viewport actions do not restart or seek the animation

#### Scenario: Download while enlarged

- **WHEN** a reader downloads SVG after zooming and selecting a route
- **THEN** the download equals canonical static rendering
- **AND** no viewport transform, UI control or transient overlay appears in the download

### Requirement: Player styling contract

The shared player SHALL document stable root and part hooks for its header,
stage, playback bar, timeline, status and exploration panel. Hosts SHALL be able
to override namespaced CSS custom properties per viewer for palette, typography,
spacing and radii without editing the runtime or losing accessible controls.

#### Scenario: Custom player skin

- **WHEN** a host applies documented palette, font, spacing and radius hooks
- **THEN** the player and viewport toolbar use those values inline and expanded
- **AND** playback, seeking, keyboard use and exploration still work

### Requirement: Player presentation compatibility

Player presentation changes SHALL retain offline use, safe label encoding,
equal output bytes on all four targets, reduced-motion behavior and inactive-page
handling. Printing SHALL show the complete static diagram. The default SHALL
remain paused and semantic scope text SHALL remain visible.

#### Scenario: Offline and reduced motion

- **WHEN** a player opens with network blocked and reduced motion enabled
- **THEN** the themed controls and explicit stepping work with no remote request
- **AND** no continuous animation starts

#### Scenario: Existing family regression

- **WHEN** existing player suites run after the presentation change
- **THEN** all diagram families retain motion bindings, route bounds, scope labels, safe hostile labels and canonical downloads
