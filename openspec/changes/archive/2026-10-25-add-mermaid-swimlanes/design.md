# Design

## Context

See `proposal.md` for the motivation. Main now supports sequence and BPMN
diagram values, static SVG scenes, motion catalogs, bounded structural route
queries and offline HTML playback. The Mermaid module still reads sequences
only. Its public `ast.Diagram` is a sequence statement structure, and its public
CST kinds are sequence-specific. Changing those types into a union would break
existing readers even when they never use swimlanes.

BPMN layout already has measured lane bands, iterative cycle condensation,
orthogonal routing, outline ports, legibility checks and resource bounds. Its
geometry and ownership types are BPMN-specific. Animation likewise has explicit
sequence/BPMN cases in catalog building, route planning, scene binding and the
browser data projection. A new kind must extend each of those boundaries.

Primary sources are pinned to `mermaid@12.2.0`:

- [Swimlane syntax](https://github.com/mermaid-js/mermaid/blob/mermaid%4012.2.0/packages/mermaid/src/docs/syntax/swimlanes.md).
- [Shared flowchart grammar](https://github.com/mermaid-js/mermaid/blob/mermaid%4012.2.0/packages/mermaid/src/diagrams/flowchart/parser/flow.jison).
- [Swimlane entry point](https://github.com/mermaid-js/mermaid/blob/mermaid%4012.2.0/packages/mermaid/src/diagrams/swimlanes/swimlanesDiagram.ts), which reuses the flowchart parser and database.
- [Flowchart database](https://github.com/mermaid-js/mermaid/blob/mermaid%4012.2.0/packages/mermaid/src/diagrams/flowchart/flowDb.ts), including subgraph merge and member deduplication rules.

The upstream diagram starts with `swimlane-beta`, defaults to `TB` and treats
top-level subgraphs as lanes. It uses the complete flowchart node/edge grammar.
Its theme and layout defaults belong to Mermaid's renderer; this library keeps
its own theme and deterministic layout contracts.

## Goals / Non-Goals

**Goals:** read native source without losing syntax, keep responsibility and
connection identity explicit, draw readable lanes and reuse existing playback
controls. Preserve the existing sequence APIs and static output for both older
diagram kinds.

**Non-Goals:** see the proposal. In particular, adding this header does not
enable plain flowcharts, BPMN conversion, external assets or arbitrary author
code. Rendering matches source meaning and notation, not Mermaid pixel positions.

## Decisions

### D1. Use the native header and a fixed compatibility profile

**Call:** use Mermaid 12.2.0, matching the current sequence corpus version. Freeze
the documentation examples, shared grammar and relevant semantic/shape coverage
fixtures with source, licence, digest and resolved upstream commit. The beta
name is part of the accepted syntax; do not invent `swimlaneDiagram`.

The reader accepts the shared grammar under `swimlane-beta`, including modern
shape data, quoted/Markdown labels, grouped/chained edges, edge IDs, classes,
styles, click metadata, local directions and accessibility statements. Unknown
future syntax is retained in the CST and diagnosed. Undocumented direction
tokens accepted by the shared grammar stay representable in the AST, but only
the five documented spellings convert to supported global directions.

Using ordinary `flowchart` plus a custom lane convention was considered. It
would miss the native format and conflate a visual subgraph with responsibility.
Supporting every flowchart header is a later change over the same syntax work.

### D2. Preserve the sequence API and add explicit kind dispatch

**Call:** retain `read`, `print`, `to_sequence`, `ReadResult` and the existing
sequence AST/CST types. Add `read_diagram` and `print_diagram` using a new parsed
diagram union with `Sequence` and `Swimlane` cases. Its read result contains the
matching CST variant, optional AST and diagnostics. Add `to_swimlane` for the
typed swimlane AST. The new printer has an explicit diagnostic/limit result.

Place swimlane syntax, CST, AST, printer and conversion in separate packages
inside `diagrams-mermaid`, with a small dispatch package. Reuse source-position
helpers, not the sequence statement parser. Detect the header after bounded
front matter/comments while preserving full-source offsets. Unsupported headers
give a specific finding and no model.

Route the existing `render_svg(source)` convenience operation through this new
dispatch. Preserve diagnostics from every stage and propagate a failed renderer
result as no output. Do not copy the current empty-string fallback into the new
path. Existing valid sequence inputs keep their SVG bytes and existing sequence
reader examples compile unchanged.

Replacing `ast.Diagram` with a union was considered and rejected because its
public fields and constructors already mean a sequence. Adding a union alongside
it gives general callers a clear entry point with a smaller migration surface.

### D3. Separate source spelling from semantic normalization

**Call:** use an explicit-stack lexer/parser that understands the grammar's label,
shape-data, comment and edge states. Statement boundaries must not split quoted
labels, Markdown strings, shape data or style values. Recover at a known outer
statement boundary after errors. Keep every token and malformed region in the
owned CST and use existing UTF-16 location conventions.

The AST keeps ordered declarations, direction spelling/absence, IDs, group
boundaries, labels and label kind, shape data, link forms and metadata statements.
Equality ignores source locations and incidental whitespace/quote spelling. The
printer reads typed fields, so edits do not reuse stale statement text. Print
one declaration per line with two-space group indentation, stable escaping and
unchanged statement order. Shape-data blocks can span lines when the native
lexer requires block YAML. Front matter/directives remain data.

Use pinned `moonbit-community/yaml@0.0.8` as an iterative event preflight for
shape-data YAML. It computes expanded alias weight and logical depth with checked
budgets before pinned `moonbitstack/moonyaml@0.1.1` resolves values. This separates
resource checks from the dependency's recursive value operations, including flat
source with deep alias chains. Both dependencies stay inside the Mermaid module.
The adapter accepts the JSON-schema values used by the pinned Mermaid
parser and applies explicit depth, alias and work budgets. Its `metadata_depth`
setting supports 1 through 256 and defaults to 256, an explicit safety profile
for the dependency's recursive operations. Unsupported settings fail before
processing. Its positive `metadata_work` budget defaults to one million units
and remains subject to the overall work budget. These metadata settings are
separate from the configurable diagram-group depth. It retains raw source
in the CST and typed values in the AST; no YAML tag executes code or loads a
resource. Follow the native lexer's shape-data boundaries; preserve and diagnose
forms it refuses rather than enabling another syntax profile. Canonical nested
values use a block form that the pinned lexer accepts. The test-only Mermaid
oracle qualifies scalar blocks, anchors,
aliases, duplicate keys, nested values and canonical printing. The core swimlane
model stays independent of this parser dependency.

Semantic conversion runs separately. Mirror the pinned database's implicit node,
redeclared label/shape, membership, group merge and edge-expansion rules. For a
repeated subgraph ID, merge members into the first completed database
registration, preserving its title, final local direction and position. A nested
repeat can complete before its outer declaration. Use upstream fixtures for
nested/repeated member cases instead of guessing ownership from textual opening
order. Explicit and generated edge IDs follow the pinned database's expansion
and collision rules, including the single explicit-ID slot in a grouped edge.
Absent group IDs get deterministic database-compatible keys.

Bound source/output to 16 Mi UTF-16 units, nodes to 10,000, edges after expansion
to 50,000, nesting to 256, work to one million units and diagnostics to 256 by
default. Allow explicit limits. Check expansion products before allocation.
Report incomplete/limit results distinctly; no implicit filesystem or network.

### D4. Add a dedicated swimlane model

**Call:** add `diagrams/swimlane` and `Diagram::Swimlane`. The model holds a view
ID; global direction; ordered lanes, groups, nodes and connections; and title,
accessibility and optional generic links/render properties. Values and collection
accessors are immutable. The model imports neither a Mermaid nor a BPMN module.

Lanes have IDs, labels and optional local direction. Nested groups keep parent,
effective lane, local direction and expanded/collapsed state. A node keeps its
effective lane and group path, shape, decoded label/kind and shape metadata.
Nodes without a lane remain unowned. Each connection has stable identity,
source/target, label and label kind, line style, marker at each end, minimum-length hint and
flow direction. Endpoints can be visible nodes, groups or lanes.

Normalize shape aliases to a pinned shape identity while the AST keeps spelling.
Retain asset-dependent shape metadata; its renderer reports unsupported assets.
Keep invisible edges as layout constraints. Normalize one-sided endpoint markers
as directed toward that end, two-sided markers as bidirectional, and no markers
as undirected. This is an explicit structural playback policy, not an execution
claim. Preserve the actual marker shapes independently of that policy.

Validate constructed values for ambiguous IDs, missing endpoints and ownership
cycles. Legal Mermaid redeclarations are normalized before model validation.
A generic flowchart model remains possible later, but this change keeps lane
ownership mandatory as a concept rather than losing it in BPMN task types.

### D5. Keep layout kind-specific and reuse small geometry routines

**Call:** add `diagrams-svg/swimlane-layout` with its own geometry and checker.
Reuse text measurement, colours, numeric formatting and XML primitives. Extract
rank/routing helpers from BPMN only where they can take neutral shapes, ports,
obstacles and bounds. Preserve BPMN's public packages through wrappers and
require old static snapshots to stay byte-identical. Do not route a swimlane by
constructing a fake BPMN document or translating its nodes to BPMN activity kinds.

Compute geometry in canonical top-to-bottom coordinates, with source-order
lane bands across the flow. Lay out nested scopes bottom-up; reserve measured
lane-title bands and labels; preserve empty lanes and pack an unowned region
separately. Condense cycles for ranking and reserve channels for return/self
edges. Keep disconnected nodes in source order. Respect explicit supported local
directions within their scope, independent of cross-lane connection endpoints.

Transform positions for `LR`, `RL` and `BT`, then recompute outline ports and
routes in final coordinates so text is never mirrored. Reverse only the flow
axis: lane order stays left-to-right or top-to-bottom across it. Use bounded
orthogonal routing around shapes, labels and header text, distinct ports for
parallel edges and explicit clipping at each vector shape's outline. Subgraph
or lane endpoints attach to their own boundaries. Crossings are permitted where
necessary; unintended intersections with labels/shapes are findings.

Collapsed groups reserve their label/boundary and expose no visible descendants.
Cross-boundary connections can use the nearest collapsed ancestor as a display
anchor while keeping their original semantic endpoints. Their visual occurrence
can be played; a hidden semantic endpoint remains outside route-query scope.
Only a source-declared group endpoint creates a graph endpoint at that group.
Do not use containment as a connection. The checker understands intended nested
boundaries and checks fit, contrast, minimum text size, containment, route and
endpoint attachment. Use the current layout node/edge/work limits; exhaustion
returns a typed error and no apparently complete geometry.

### D6. Paint built-in vectors with the existing theme policy

**Call:** freeze a shape coverage manifest from the pinned upstream registry and
cover every built-in vector shape, including aliases and modern shape-data
forms. Paint its notation and markers with the shared archify colour families.
Text measurement includes decoded multiline labels and a safe text projection
for Markdown/HTML labels. Preserve unsupported formatting in the AST and warn
when the rendered label uses that text projection. Do not insert author HTML.

Image/icon nodes and unknown shapes fail rendering explicitly. CSS, callback
and Mermaid theme/layout declarations remain readable/printable metadata;
conversion warns when their renderer-specific behavior is not applied. Library
theme/layout options are explicit inputs. Link declarations can become escaped
link metadata, with no automatic navigation or remote fetch.

Add the swimlane case to `SvgRenderer` and its scene operation. Normal SVG remains
script-free, with local markers, title/description, adaptive/fixed themes and
ID-prefix isolation. Shape and lane selection metadata are escaped. Canonical
static output is deterministic on all four targets.

### D7. Extend catalogs and carry traversal direction into playback

**Call:** add swimlane catalog/node/occurrence/connection cases to the current
animation model and scene projection. Preserve existing BPMN/sequence fields
and constructors. Add typed optional swimlane source values rather than storing
them in BPMN fields. Catalogs bind each visible connection to the path produced
by its geometry, including parallel edges and self-loops.

Directed connections supply one forward arc; bidirectional connections supply
both oriented arcs referencing one underlying connection. Headless connections
are available only through an explicit undirected edge kind. Invisible edges
are excluded. Every route retains the orientation used on each arc. Add a
direction-aware motion step while keeping existing forward `Motion::Step`
behavior. Sample/serialize reverse motion explicitly, and make the browser
interpolate backwards along that same path without changing its markers.

Add swimlane edge kinds to appropriate default route selection; keep unheaded
edges opt-in. Hidden group descendants use the existing outside-view result.
Lane membership, visual order and labels never add arcs. Existing budget,
shortest-route, tie-break, reachability, mismatch and finite-scenario contracts
continue to apply. Finite scenarios can repeat one connection explicitly.

Extend the current HTML renderer and small embedded runtime for new typed
bindings, orientation and selectors. Preserve still startup, keyboard controls,
reduced motion, hidden-page suspension, offline operation and exact canonical
SVG downloads. Runtime changes can change old HTML bytes; regenerate those
snapshots deliberately while keeping old static SVG bytes and tested playback
semantics. No new viewer, UI framework or storage service is needed.

### D8. Use reference semantics and independent geometry assertions

**Call:** freeze the native documentation examples plus upstream-derived and
project-authored edge fixtures. Cover all directions, empty/unowned lanes,
nesting, repeated IDs, implicit nodes, node/edge shape forms, Unicode, malformed
source, expanded endpoints, collapsed groups, self/parallel/back edges and limits.
Record source/licence/digests and keep CRLF fixtures stable across git platforms.

Use a test-only `mermaid@12.2.0` installation in a pinned locked reference harness.
Read real native swimlane source in its browser-compatible environment and
normalize its database into nodes, edges, ownership and direction fixtures.
Keep semantic configuration fixed and explicit. Do not make the production
library invoke JavaScript or Mermaid. Source reproduction, recovery and our
layout policies have their own laws and are not inferred from reference pixels.

Run CST/AST/model/print, geometry, route and timeline tests on wasm, wasm-gc, js
and native. Extend existing SVG/animation browser harnesses with current-commit
snapshots, reusing the installed Chromium and existing Site build gate. Browser
checks inspect actual header clearance, outline endpoints, motion direction,
themes, safe labels, reduced motion and static export. Do not recompile the
workspace just to open stored qualification snapshots.

## Risks / Trade-offs

- Native syntax is beta. Pin the compatibility profile and require a deliberate
  corpus/grammar update to change it.
- Shared flowchart grammar is larger than the swimlane documentation examples.
  Use a grammar/shape coverage manifest and normalized upstream fixtures rather
  than claiming completeness from a few happy-path diagrams.
- Lane directions and cyclic handoffs complicate routing. Separate local scopes,
  reserve header/return channels and keep explicit search limits.
- Undirected and bidirectional connections can animate incorrectly if orientation
  is lost. Keep orientation in route steps and test actual reversed path motion.
- Extracting layout helpers can affect BPMN output. Preserve its public wrappers
  and old static snapshots, and qualify both prior diagram kinds.

## Migration Plan

After review, create one epic and one bead per task group. Start with a thin
native source-to-SVG-to-animation path, then complete syntax, semantic conversion,
layout, painting and shared playback in order. Each group owns its examples and
tests. Do not replace existing sequence reader types.

Document new `Diagram`/animation variants for callers with exhaustive matches.
The shared runtime can require controlled HTML snapshot updates; ordinary SVG
snapshots stay fixed. No public module or release version is added here. The
last implementation PR records gallery approval and archives this change.
Close/sync beads only under the repository's post-merge landing rules.
