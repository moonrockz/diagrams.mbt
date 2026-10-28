## ADDED Requirements

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
