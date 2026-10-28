# Spec Delta

## ADDED Requirements

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
