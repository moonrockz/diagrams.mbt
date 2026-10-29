# Spec Delta

## MODIFIED Requirements

### Requirement: Distributed automatic attachments

Automatic attachments SHALL use shape-aware candidate locations and usable
perimeter spans, with corner and marker padding. Multiple box-side attachments
SHALL spread evenly across the usable straight span. Diamond points SHALL take
preference over generic side fractions when feasible. Routing SHALL consider
other clear sides before crowding an anchor. Explicit ports and direction hints
SHALL remain in force. True junctions and grammar joins SHALL retain shared points.

#### Scenario: Multiple attachments on one component side

- **WHEN** two or more independently identified connections use one automatically routed box side
- **THEN** their attachments spread evenly across its usable straight span with corner and marker padding
- **AND** each keeps its actual outline attachment, source identity and semantic endpoints

#### Scenario: Use clear top and bottom approaches

- **WHEN** an automatically routed return edge or crowded bundle has a clearer top or bottom approach
- **THEN** the router uses that available side to reduce clutter while retaining readable marked terminal corridors
- **AND** explicitly authored ports and edge direction hints remain in force

#### Scenario: Multiple diamond connections

- **WHEN** independent connections can use distinct clear diamond points without violating authored constraints or marker clearance
- **THEN** routing prefers those points before generic positions on sloping edges
- **AND** it does not merge independent terminal segments into a false junction

## ADDED Requirements

### Requirement: Shape-aware automatic anchors

Automatic endpoints SHALL consider the actual outline, shape size, route
direction and marker dimensions. Diamond and choice shapes SHALL prefer their
four points. Boxes SHALL prefer clear straight-side spans and rounded shapes
SHALL use readable perimeter approaches. Preferences SHALL NOT override explicit
ports, authored sides, boundary targets or supplied geometry.

#### Scenario: Diamond in each flow direction

- **WHEN** an unconstrained diamond or BPMN gateway has a clear single connection in TB, BT, LR or RL direction
- **THEN** its endpoint is the appropriate point and its terminal segment approaches that point along the corresponding axis
- **AND** the arrowhead remains outside the shape interior with its required approach distance

#### Scenario: A non-square diamond

- **WHEN** a diamond's width or height changes to fit its label
- **THEN** its preferred anchors follow its actual four points rather than a fixed square or stale box fraction

#### Scenario: Other outlines and explicit geometry

- **WHEN** boxes, circles, rounded boxes or explicit ports are routed
- **THEN** endpoints meet the real outline with readable approaches
- **AND** explicit ports and default supplied BPMN waypoints retain their authored positions

### Requirement: Route-aware attachment selection

Automatic routing SHALL evaluate feasible source and target anchors together
with route direction, bends, length, clearance and incident-edge congestion.
Candidate evaluation SHALL be deterministic and bounded. If preferred anchors
conflict, routing SHALL use a clear alternative or report a routing finding,
without silently drawing through protected content.

#### Scenario: Clear route versus a crowded point

- **WHEN** a preferred point would overlap another independent marked terminal corridor
- **THEN** routing selects another feasible point, side or nearby outline location while retaining marker and label clearance

#### Scenario: Self-loops and parallel connections

- **WHEN** a shape has a self-loop and repeated source-to-target connections
- **THEN** every connection retains its identity and readable terminal geometry without false joins or hidden arrowheads

#### Scenario: Stable ties and exhausted budget

- **WHEN** equivalent candidates tie or candidate work reaches its limit
- **THEN** stable source identities resolve ties identically on all four targets, or a distinct limit diagnostic returns no partial successful output

### Requirement: Anchor geometry across outputs

Chosen anchors SHALL be reflected in public route and final path geometry,
static SVG, playback overlays and raster/animated exports. Source models SHALL
remain unchanged. Qualified connector-only output changes SHALL be reviewed;
unrelated geometry and content SHALL remain stable.

#### Scenario: Inspect and export a routed decision

- **WHEN** a reader inspects a diamond's final connector, plays it and exports SVG, PNG or GIF
- **THEN** every output uses the same outline endpoint and path, including selected connector styles and masks
- **AND** source syntax, semantic endpoints and connection identity are unchanged

