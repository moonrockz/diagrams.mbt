# state-svg-rendering Specification

## Purpose
Lay out state models and draw readable standalone SVG with explicit hierarchy,
stable geometry, shared connector styling and inspection/playback bindings.

## Requirements

### Requirement: Deterministic hierarchical state layout

Layout SHALL support four global directions, source-supported local hints,
nested and empty composites, concurrent region separators, disconnected states,
cycles, self-loops and parallel transitions. It SHALL retain source-order ties,
state containment, readable headings/descriptions and distinct transition labels.
Layout SHALL NOT change ownership or semantic endpoints to simplify drawing.

#### Scenario: Nested composite with parallel transitions

- **WHEN** a composite contains concurrent regions, a self-loop and two labelled transitions with equal endpoints
- **THEN** regions remain contained and separated, each transition has its own readable path and layout terminates in all four directions

### Requirement: Typed state and pseudostate painting

Rendering SHALL distinguish ordinary/composite states, initial/final symbols,
choice, fork/join, shallow/deep history and supported boundary symbols. It SHALL
retain multiline descriptions, stereotypes, notes and transition markers/styles.
Unknown or unsupported symbols SHALL return explicit diagnostics and no SVG
rather than substitute ordinary boxes or fetch assets.

#### Scenario: Symbol coverage

- **WHEN** the supported symbol corpus is rendered in fixed light and dark themes
- **THEN** every role has a distinct checked shape, readable labels and a stable source binding

### Requirement: State transition connector parity

State transitions SHALL use the accepted connector contract for elbow, rounded
and curved lines, default bridge hops, plain-crossing opt-out, distributed
attachments and marker approaches. Paths SHALL attach to actual outlines or
explicit boundary points. Region borders, shared pseudostates and true endpoints
SHALL NOT become bridge crossings or new graph edges.

#### Scenario: Curved crossing beside a composite

- **WHEN** two unrelated transitions cross near a composite with curved bridge options
- **THEN** the paths and underpass remain distinct without touching labels or borders, while a shared fork endpoint remains visibly joined

### Requirement: Public state geometry and legibility checks

Public inspection SHALL expose immutable state/region bounds, text, semantic and
display endpoints, original routes and final styled paths/masks. A bounded checker
SHALL detect unintended containment, attachment, label, route and viewport
violations, text below 11 px and contrast below 4.5:1. Declared containment,
boundary attachments and underpasses SHALL remain intentional relationships.

#### Scenario: Long descriptions near a bridge

- **WHEN** checked geometry contains a bridge that enters an unrelated description
- **THEN** the checker identifies the transition and collision instead of exempting the bridge from checking

### Requirement: Collapsed state scope

Caller-selected collapsed composites SHALL hide descendant geometry and attach
crossing display routes to the composite outline while retaining semantic child
endpoints. Hidden descendants SHALL be outside visible inspection/query scope.
Collapsing SHALL NOT rewrite the source model or create region-membership edges.

#### Scenario: Collapse a transition target's owner

- **WHEN** a transition targets a child of a collapsed composite
- **THEN** its display path ends at the composite boundary, its semantic target remains the child and hidden detail is outside the view

### Requirement: Standalone themed state SVG

The shared renderer SHALL accept state diagrams and return deterministic,
well-formed, script-free `image/svg+xml` on all four targets. Output SHALL be
self-contained, with adaptive and fixed themes, title/accessibility metadata,
safe text/links and caller prefix isolation. Existing diagram contracts and
static SVG bytes SHALL remain unchanged.

#### Scenario: Two inline state diagrams

- **WHEN** copies use separate prefixes and markup-like labels
- **THEN** definitions and masks stay isolated in both themes and labels display as text without external requests

### Requirement: State scene bindings and limits

Scenes SHALL bind visible states, regions, pseudostates, notes and transitions
to stable identities. Playable transitions SHALL use their final drawn paths
and masks. Isolated visible states SHALL allow visits without invented paths.
Explicit size, depth, work, dimension and output limits SHALL return distinct
exhaustion diagnostics without successful partial SVG.

#### Scenario: Isolated state and exhausted layout

- **WHEN** an isolated state is inspected and a separate render exceeds its work budget
- **THEN** the state has a visit binding with no fabricated edge and the exhausted render returns no SVG with a limit finding
