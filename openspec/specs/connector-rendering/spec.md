# connector-rendering Specification

## Purpose
Draw readable connection paths with clear arrow approaches, selectable line
styles and visible crossing separation without changing diagram meaning.

## Requirements

### Requirement: Shared connector style options

The SVG renderer SHALL provide typed elbow, rounded-elbow and smooth-curve
options. An omitted style SHALL retain the diagram family's natural style.
Crossing bridges SHALL be enabled by default, with an explicit plain-crossing
option. Options SHALL apply to visible connectors in every supported diagram
kind, subject to the supplied-geometry policy, without changing source models.

#### Scenario: Select each line style

- **WHEN** the same automatically laid out graph is rendered in all three explicit styles
- **THEN** elbow paths have sharp turns, rounded elbows have curved corners, and smooth curves have continuous tangent directions at their internal joins
- **AND** connection identities, semantic endpoints, labels and arrowhead meanings remain equal

#### Scenario: Omit connector options

- **WHEN** an automatic diagram with an unrelated line crossing is rendered without connector options
- **THEN** it uses its family's natural line style and shows a crossing bridge

#### Scenario: Disable bridges

- **WHEN** the same diagram is rendered with plain crossings
- **THEN** its crossings have no bridges or underpass masks and its graph remains unchanged

### Requirement: Readable endpoint approaches

Automatically routed connections SHALL reserve a straight approach at each
marked endpoint that fits the marker, stroke and selected curve transition.
The approach SHALL meet the correct outline and side without a turn inside
the reserved distance. The renderer SHALL expose a documented minimum approach
option. Invalid values SHALL give diagnostics and no successful output.

#### Scenario: Bend close to an arrowhead

- **WHEN** routing a short return edge would put its final turn inside the required marker approach
- **THEN** automatic layout reserves more space or changes its route while keeping the actual endpoint and arrow direction

#### Scenario: Markers at both ends

- **WHEN** a connection has markers at both ends in each flow direction
- **THEN** both approaches meet the configured minimum and their markers do not collide with bends

#### Scenario: Invalid approach option

- **WHEN** a caller supplies a negative or non-finite approach distance
- **THEN** rendering reports an invalid-option diagnostic and returns no successful partial SVG

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

### Requirement: Visible crossing bridges

Bridge mode SHALL separate transverse interior crossings between unrelated
visible connections with a small rounded-arch hop and a clear underpass. Crossing ownership
SHALL be deterministic from stable connection order. Bridges SHALL retain
connection colours, dash styles and identity and remain visible over any local
background in fixed and adaptive themes.

#### Scenario: Two unrelated connections cross

- **WHEN** two independently identified paths cross in their interiors
- **THEN** exactly one receives a continuous rounded-arch bridge hop and the other has a clear underpass
- **AND** changing theme does not reveal a solid background-colour patch

#### Scenario: Dashed and coloured paths

- **WHEN** dashed and differently coloured connections cross
- **THEN** each retains its style through the crossing treatment and remains independently inspectable

### Requirement: Junctions and crossings remain distinct

Crossing treatment SHALL NOT add graph connectivity. Shared endpoints, declared
junctions, branch splits, joins, shared trunks and endpoint contacts SHALL NOT
receive crossing bridges. Lifelines, pool borders, lane borders and shape outlines
SHALL NOT be treated as unrelated connectors. Collinear overlap SHALL be handled
separately from a transverse crossing.

#### Scenario: A declared junction

- **WHEN** three architecture connections meet at one declared junction
- **THEN** the junction remains visibly joined and has no bridge

#### Scenario: Railroad branch and hierarchy fan-out

- **WHEN** railroad alternatives or data-tree child connections share a semantic branch point
- **THEN** that branch point remains joined and playback retains its original routes

#### Scenario: Crossing a lifeline

- **WHEN** a sequence message passes intermediate participant lifelines
- **THEN** those contacts do not receive crossing bridges

#### Scenario: Overlapping segments

- **WHEN** unrelated automatically routed connections would overlap along a segment
- **THEN** routing separates them or returns an explicit routing finding rather than disguising the overlap as one bridge

### Requirement: Safe curves and bridge placement

Styled paths SHALL retain endpoint attachment and label clearance. Curves and
bridges SHALL stay inside the viewport and avoid unrelated shapes, labels,
markers, nearby bends and other bridges. Dense crossings SHALL use safe reduced
bridge sizes or revised automatic routes. An unresolved conflict SHALL give a
distinct diagnostic without a successful misleading path.

#### Scenario: A curve near a label

- **WHEN** smoothing the routed corners would put a curve through an unrelated label
- **THEN** rendering adjusts the curve or route to preserve clearance, or returns a routing conflict

#### Scenario: Closely spaced crossings

- **WHEN** a path crosses several neighbours near a bend or arrow approach
- **THEN** its bridges remain separate and readable without entering the reserved marker approach

### Requirement: Public final path geometry

Public geometry and scene inspection SHALL expose the final styled path,
including curve and bridge segments, with stable connection identity. Checking
SHALL use this geometry and accept declared underpasses without accepting real
shape or label collisions. Original route points SHALL remain available as
route data. Rendering SHALL not mutate those points or source AST values.

#### Scenario: Inspect a curved bridged route

- **WHEN** a caller inspects an automatically laid out curved connection with a bridge
- **THEN** the final path matches its SVG path, and its original route points and semantic endpoints remain inspectable

#### Scenario: Detect an actual collision

- **WHEN** constructed final geometry puts a bridge into a label
- **THEN** the checker identifies the collision and affected connection instead of exempting all bridge geometry

### Requirement: Bounded deterministic connector processing

Routing, curve construction, crossing detection, bridge construction and final
path checking SHALL obey explicit work, segment, crossing and output limits.
Exhaustion SHALL have a distinct limit diagnostic and no successful partial
output. Equal models and options SHALL give identical path geometry and SVG
bytes on wasm, wasm-gc, js and native.

#### Scenario: Dense graph exhausts its crossing budget

- **WHEN** crossing processing reaches its configured limit
- **THEN** rendering returns a connector-limit diagnostic instead of silently omitting remaining bridges

#### Scenario: Portable output

- **WHEN** the same curve and crossing fixtures run on all four targets
- **THEN** final path geometry, crossing ownership and SVG bytes are identical

### Requirement: Scoped standalone crossing definitions

Bridge definitions and underpass masks SHALL be local, generated SVG resources.
They SHALL follow explicit prefix isolation and retain the active fixed or
adaptive theme. Different connector options SHALL not cause resource identity
collisions between otherwise equal inline diagrams. No external resource or
source-supplied executable content SHALL be needed.

#### Scenario: Inline copies use different connector styles

- **WHEN** two copies of one graph use different styles or crossing modes and separate explicit prefixes
- **THEN** each copy resolves only its own bridge and mask definitions in either theme
- **AND** automatic resource identities also distinguish different connector options

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
