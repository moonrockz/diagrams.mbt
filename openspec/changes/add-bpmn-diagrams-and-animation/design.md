# Design

## Context

See `proposal.md` for the motivation and scope. The current library has an
immutable sequence model, a public `Diagram::Sequence` case, a `Renderer` trait
and a standalone SVG renderer. The public SVG geometry is specific to sequence
columns, lifelines, messages and frames. Theme tokens, measured text widths and
XML escaping are already available. There is no BPMN reader, general graph
layout, motion plan or browser playback renderer.

The following sources informed this design:

- [OMG BPMN 2.0.2](https://www.omg.org/spec/BPMN/2.0.2/) and its normative
  BPMN20, Semantic, BPMNDI, DI and DC schemas. Use their namespace URIs and
  metamodel as authority. The PDF sections 9.5 and 11 distinguish conversation
  views and choreography from process orchestration.
- The local `moonrockz/smithy` syntax and traversal packages. They separate
  lossless CST, typed AST, source diagnostics and reference-aware semantic
  values. Their walk, fold, visitor, events and cursor agree on source order.
- The local `moonrockz/moon-lander/pkgs/openrpc` reader/writer. It distinguishes
  source reproduction from canonical writing, keeps absent fields and
  extensions, takes explicit reference resources and bounds processing.
- Archify 3.2 `references/viewer-runtime.md`. Its motion follows authored edges
  on a separate overlay; route queries use directed relationships. Still mode,
  reduced motion, printing and canonical export preserve the static diagram.
- [bpmn-moddle](https://github.com/bpmn-io/bpmn-moddle), an independent BPMN XML
  reader/writer suitable for test-only semantic comparison. It does not replace
  a lossless MoonBit source model.

## Goals / Non-Goals

**Goals:** keep document handling independent, retain the BPMN distinctions that
rendering and future adapters need, and reuse one geometry result for static
painting and animation. Keep every public operation deterministic and portable.

**Non-Goals:** see the proposal. In particular, animation and structural routes
do not implement BPMN execution semantics. The generated HTML is a renderer
output; published MoonBit modules do not depend on a UI framework or browser.

## Decisions

### D1. Stage rendering without narrowing document interchange

**Owner:** on 2026-10-24 the owner agreed to process/collaboration rendering
first, with choreography and conversation supported by the document design and
their rendering deferred. Motion follows the archify exploration approach.

**Call:** the document model covers the normative BPMN semantic families and
diagram interchange. Choreography activities, participant bands, conversations,
conversation links and their references have typed document representations.
They are not converted to generic tasks for drawing. Conversion returns
`bpmn/unsupported-view` for those view kinds in this change.

This keeps read/write/traversal useful for whole BPMN documents and avoids a
second parser when another view renderer is added. An opaque representation for
all non-process content was considered; it would defer useful independent-module
APIs and make later typed traversal harder. Opaque XML remains available for
vendor content and unknown standard-namespace elements.

### D2. Module direction follows existing format adapters

**Call:** use these module boundaries:

| Module | Responsibility | Direct domain dependencies |
| --- | --- | --- |
| `moonrockz/bpmn` | XML CST, typed BPMN document, writer, diagnostics, validation, references and traversal | MoonBit core only |
| `moonrockz/diagrams` | Format-independent sequence and BPMN diagram values, renderer contract, motion and route values | MoonBit core only |
| `moonrockz/diagrams-svg` | Kind-specific geometry and static painting, shared theme/text/escaping, render-scene bindings | diagrams, existing metrics |
| `moonrockz/diagrams-bpmn` | BPMN view selection, document-to-diagram conversion and SVG convenience API | bpmn, diagrams, diagrams-svg |
| `moonrockz/diagrams-animated` | Motion projection and standalone HTML rendering from a diagram | diagrams, diagrams-svg |

`bpmn` has its own diagnostic and source-location values. The adapter maps them
to diagram diagnostics without losing code, severity or span. This small
duplication prevents a dependency from the standalone document library to the
diagram library. The diagram model holds its own visual BPMN values, not XML
CST handles or the source library's types. Existing Mermaid module dependencies
stay as they are.

Putting XML values directly in `diagrams` was rejected because it couples every
diagram consumer to a format reader. Putting SVG in `bpmn` would prevent a
reader-only installation. A separate UI application is unnecessary: the animated
renderer produces a string using the same `Renderer` result contract.

### D3. Own the source and lower it in explicit stages

**Call:** `read(text, source_id?, limits?)` returns an owned CST, an optional
typed document, a source map and ordered diagnostics. Its internal pipeline is
XML tokenization, lossless CST construction, namespace resolution and typed
lowering. Malformed regions remain error nodes; synchronization at a recoverable
tag boundary permits more than one finding. An XML syntax error prevents a
successful complete typed document. A semantic reference error can coexist with
a typed document and is checked before rendering the affected view.

Spans are half-open UTF-16 ranges. Lines and columns start at one; CRLF counts
as one line break. CST reproduction returns the original string, including
error text. Model values do not carry mutable pointers into token storage.
Source maps are optional and separate, so constructed documents need no fake
source. Traversal handles include an owning immutable document revision key,
derived from the source/resource identity or constructed document value. Validate
the owning revision as well as the node index; do not rely on a hash match alone
or a process-global allocation counter.

Use an explicit element stack for XML reading and writing. Reject DTD/entity
declarations; support the five predefined XML entities and numeric character
references. Neither namespace URIs nor schema locations cause I/O. The API takes
decoded text; file decoding belongs to a host adapter. Accept UTF-8-compatible
XML declarations and report a conflicting encoding declaration.

A conventional DOM parser was considered, but it loses quote spelling, comments
or malformed regions and cannot meet source-reproduction requirements.

### D4. Freeze the normative schema and derive the type inventory

**Call:** freeze the five OMG XSD files with URL, SHA-256 digest and notices in
the unpublished test corpus. A MoonBit task script derives checked-in type/field
metadata and repetitive typed model code from those fixed inputs. It handles the
schema features those files use: named types, derivation, substitution groups,
sequences/choices, occurrence bounds and attribute value kinds. A tool-only XML
reader can assist this task; it does not become a `bpmn` runtime dependency.

Expose immutable typed variants and accessors, exact decimal values for DI,
optional values that keep absence, and read-only child collections. Keep
containment order. Reference values retain their spelling plus resolved expanded
identity where available. Generated metadata drives structural lowering and
writer field dispatch; hand-written checks cover BPMN semantic restrictions.
The corpus records a coverage entry for each normative element and attribute so
missing standard types cannot silently become vendor extensions.

The reader keeps unknown namespace content as immutable XML nodes with expanded
names, attributes, mixed children and namespace bindings. Unknown elements in a
standard namespace also get an unsupported-element finding. Do not promise that
vendor-specific semantics or every BPMN execution constraint are validated.

Hand-writing every schema field was considered; deriving the repetitive parts
reduces omission and gives the schema-coverage test an independent inventory.
This is a fixed-input generator, not a general public XML Schema processor.

### D5. Canonical writing preserves values and namespace meaning

**Call:** provide canonical compact and two-space pretty formats. Use a stable
namespace policy and attribute ordering by namespace URI and local name; keep
element/mixed-content order. Do not add defaults, new IDs, DI, or reordered
process elements. Preserve exact decimal value tokens and absent fields.
Canonical here means this library's deterministic format, not XML C14N.

Known QName-valued fields can be rewritten only with matching namespace
declarations. Foreign content retains all in-scope bindings needed by its opaque
values, including prefixes whose use is not known to the library. Keep them in
the preserved subtree scope so a canonical parent prefix cannot rebind them.
Pretty writing must not insert semantic whitespace into mixed content.

Reject invalid constructed names, forbidden characters and conflicting bindings
with a structured error. Writer equality laws compare document meaning with
source maps and lexical prefix aliases excluded. CST reproduction remains the
only API that promises identical original text.

### D6. Validate and resolve over supplied resources

**Call:** keep syntax, structural and reference validation as distinct stages.
Build an ID index per document and namespace-aware indexes for imported values.
Preserve duplicate occurrences so lookup can return ambiguity. Check required
fields, containment/target kinds, duplicate IDs, dangling endpoints, boundary
attachments and sequence-flow scope. An import resolver accepts an immutable
resource set; it has no implicit filesystem or HTTP fallback.

Tree traversal never resolves references. Graph operations use the explicit
indexes and chosen edge kinds. A malformed or ambiguous selected endpoint blocks
its diagram conversion. An unrelated unresolved import remains a diagnostic and
does not prevent rendering a self-contained selected process.

Default document limits are 16,777,216 UTF-16 code units each for source and
output, 1,000,000 nodes, 4,096 open elements, 1,048,576 code units for one
attribute/text token and 256 diagnostics. Callers can supply different bounds.
Every stage checks size arithmetic and limit exhaustion before allocation.

### D7. Reuse the moonrockz traversal contract

**Call:** add a read-only `NodeRef` with category/kind, named field access,
children, identity, source location and path. Provide `walk`, `fold`, `reduce`,
pruned reduction, `accept` with default visitor methods, pull `EventReader`,
push events and `TreeCursor`. Their normalized event order is the common
acceptance law. Enter decisions are continue, skip-children and stop; skipping
still leaves the node, and stop emits no later leave events.

Use per-call explicit stacks. References are leaves in containment traversal.
Separate graph queries select sequence flow, message flow, association, general
reference or containment edges and direction. Reachability includes its start
identity and each reachable identity once. Breadth-first search returns one
shortest route; adjacency follows source/model order for deterministic ties.
Return typed unreachable, ambiguous, invalid-reference and limit outcomes.

A single recursive visitor was considered; it cannot provide depth safety or the
existing event/cursor styles without different behavior between interfaces.

### D8. Convert a selected view to a dedicated diagram model

**Call:** accept selectors for a process, collaboration or diagram/plane ID.
For automatic selection, consider planes, then collaborations, then processes;
stop at the first nonempty tier and require exactly one candidate. This avoids
counting a plane and its own referenced process as two competing views. Check
the selected view's kind and report deferred kinds explicitly. A BPMN diagram keeps semantic
kind, identity, pool/lane/subprocess ownership, event/task/gateway markers,
typed connection kinds and endpoints, labels, optional links/render properties,
and optional selected DI geometry. Keep the source ID alongside any generated
render ID. Missing IDs use a deterministic source/model containment path for
visual identity; do not write that generated identity back to XML.

Use a `Bpmn` case in the public `Diagram` enum. The core model is a diagram
projection; document editing still uses `bpmn`. Convert all process and
collaboration graphical constructs, including black-box pools, collapsed and
expanded subprocesses, nested lanes, data artifacts and annotations. Preserve
distinct BPMN line and endpoint rules. Do not copy vendor XML into SVG.

A generic flowchart node/edge model was considered, but would erase event
definitions, boundary attachment, pool ownership and gateway/task markers.
Adding the public enum case is a source compatibility change for exhaustive
matches; document it before a separately approved version release.

### D9. Use complete DI or compute one complete layout

**Call:** define `PreferDi`, `RequireDi` and `Automatic` policies. A selected
complete valid plane supplies shape/label bounds and edge waypoints. Apply only
a common viewport translation. Report imported legibility problems without
moving author geometry. Missing or incomplete DI under `PreferDi` produces a
warning and automatic layout for the whole selected view. Invalid supplied
coordinates fail under either DI policy. `Automatic` deliberately ignores DI.

Implement BPMN geometry separately from the current sequence geometry. Reuse
only genuinely common text, rectangle, path, theme and escaping helpers. For
automatic layout, process each containment scope, condense strongly connected
components, rank its acyclic graph in source order, allocate measured node/label
sizes to lane bands and route orthogonal connections around unrelated shapes.
Place return edges in reserved channels. Handle parallel edges with separate
ports and route message flows across pool boundaries. Place boundary events
after their attached activity. Pack disconnected components deterministically.

Layout has explicit node, edge and search budgets. If routing cannot satisfy its
limits, return a layout-limit finding rather than incomplete success. Start
with 10,000 visible nodes and 50,000 connections as configurable input bounds.
The corpus establishes practical layouts; this is not a promise of an optimal
embedding or zero line crossings for arbitrary graphs.

The checker understands intended containment, attached events and edge endpoints.
It checks labels, unrelated overlaps, minimum text size, contrast and node/edge
attachment. BPMN symbol shapes and markers follow the standard; archify supplies
colour families and motion accents. Arbitrary recolouring cannot replace BPMN
notation. Static output remains script-free and has no external resources.

### D10. Separate motion semantics from the playback clock

**Call:** `diagrams/animation` defines immutable element/occurrence identities,
directed exploration graphs, motion steps, finite scenarios and sampled state.
Sampling takes elapsed integer milliseconds. Progress is represented by bounded
integer numerator/denominator values; browser interpolation does not define the
library's logical state. Validate positive finite durations, a maximum of 100,000
steps and total duration within JavaScript's exact integer range.

BPMN animation binds sequence and message flows to their routed paths. Sequence
animation identifies each message occurrence by its containment path, not just
its participant pair. Keep the frame tree: caller scenarios choose alternative
sections and bounded repetitions; concurrent groups are explicit. Default live
flow highlights authored connections illustratively. It is labelled as such and
does not turn alternative branches into one asserted execution.

Sequence exploration uses occurrence/control structure, not a participant graph
that would turn `A -> B -> A` into an infinite trace. BPMN exploration uses the
selected view's structural connections. Default queries include sequence flows;
message flows are opt-in and associations are excluded. Queries are scoped to
visible/expanded containment, with no invented transitions into a collapsed
subprocess. Each query is bounded by 10,000 nodes and 50,000 edges by default.

Token simulation was considered and deferred. Inclusive joins, event races,
correlation, cancellation and expression evaluation need a separate execution
contract. A structural route is useful without asserting those semantics.

### D11. Render-scene bindings keep static exports stable

**Call:** add a pure scene operation alongside ordinary SVG rendering. It
returns canonical SVG plus display SVG and bindings from source occurrence IDs
to display paths/shapes. The display copy can carry the IDs needed for playback;
the ordinary static API keeps its existing sequence bytes. Both copies come
from the same measured geometry and theme. Test that instrumentation does not
change geometry, notation or labels.

The animated renderer emits a self-contained HTML document with that scene, a
validated motion plan and a small inline browser runtime. Runtime sources live
as renderer assets and are embedded reproducibly by a MoonBit task. No UI
framework is imported. A clock and DOM are used only after the generated artifact
is opened in a browser. Animation uses an overlay along the bound path and does
not rewrite the canonical SVG.

Start still. Provide accessible play/pause, restart, step, seek, speed, route and
reach controls. Scope selectors and IDs to one viewer. Reduced motion disables
continuous movement, hidden pages suspend work, and print CSS shows the complete
static diagram. No storage or network service is needed. The SVG download uses
the stored canonical bytes, so it excludes overlays and retains the exact static
contract. Export does not clear the active viewer state.

Encode embedded JSON safely for script context, including `<`, `&` and line
separators. Put source labels into text nodes, never executable markup. Foreign
extensions are document data and cannot contribute scripts, styles or URLs to
the runtime. Treat every plan identity and binding as untrusted until validated.

Putting scripts into normal SVG was rejected because it breaks the accepted
standalone-SVG contract and Markdown/slide use. Depending on archify at runtime
would require another tool and an undocumented schema conversion. Reuse its
interaction ideas and palette with the existing attribution instead.

### D12. Verify independent documents and shared rendering separately

**Call:** freeze licensed OMG examples plus project-authored negative and edge
fixtures. Keep source URL, licence and digest for every imported input. Include
processes, collaborations, choreography, conversations, vendor extensions,
multiple/partial/no DI, invalid XML, Unicode and cyclic flow graphs. A checked-in
coverage manifest maps standard graphical symbols and schema fields to tests.

Use a pinned test-only bpmn-moddle version to compare decoded core identities,
containment, references and DI against independently generated fixtures.
Normalize namespace aliases and library metadata explicitly. Source reproduction
and malformed-input recovery use their own laws; the reference reader does not
prove those properties. Check normative schema constraints independently where
the corpus provides expected valid/invalid cases.

Run document round-trip and traversal laws, route/motion sampling tests and SVG
snapshots on all four targets. A fresh consumer imports only `bpmn` and verifies
no renderer/UI dependency. Browser tests cover offline playback, real path motion,
keyboard controls, route changes, reduced motion, visibility suspension, print,
theme isolation and exact canonical SVG export for both diagram kinds. Extend
the existing browser qualification path through MoonBit task entry points; do
not add an unrelated platform matrix.

Add `mise run test:animation` to the existing Site build job after `test:site`.
Reuse its locked Playwright version and Chromium cache. Browser input is the
checked-in HTML/SVG snapshots of the current commit; the four-target test jobs
independently compare those bytes with current renderer output. The animation
task does not compile the workspace or rebuild the site. Existing `ci-ok` gates
both the snapshot comparisons and browser qualification. Local and release
qualification run the same animation task for the candidate being reviewed.

## Risks / Trade-offs

- Full BPMN document coverage is larger than its first renderer. The frozen
  schema inventory and a small complete first path reveal omissions early;
  later task groups fill the typed families before claiming full document support.
- Opaque extension values can contain namespace-sensitive text. Keep their
  bindings rather than attempting to normalize unknown embedded languages.
- Auto layout can be expensive for dense cyclic graphs. Scope it, bound searches,
  provide a supplied-DI mode and report limits without dropping elements.
- Imported DI can be illegible. Preserve it and report findings; callers can
  deliberately choose automatic layout.
- Readers may interpret moving highlights as proof of execution. Label playback
  as illustrative and routes as structural; preserve condition labels.
- Shared SVG refactoring can change existing output. Keep sequence snapshot
  bytes as a gate and add scene instrumentation through a separate output path.

## Migration Plan

Implement one task group per PR after design approval and bead creation. The
first PR proves a small end-to-end document, static render and motion sample;
subsequent groups complete the contracts before the change is archived. Keep
incomplete APIs documented as such until their group lands. Add modules at the
root version, but do not publish or change the release version in this change.

Existing callers keep sequence behavior. Callers with exhaustive `Diagram`
matches add the `Bpmn` case. Register new modules in version checks and the
publication list, update docs and gallery, then obtain owner gallery review.
The final implementation PR archives this change. Close beads only after each
PR merges, close the epic after all children close, and sync the tracker.
