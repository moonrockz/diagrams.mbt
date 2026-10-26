# Design

## Context

See `proposal.md` for the motivation and scope. Current Mermaid dispatch has
`Sequence` and `Swimlane` AST/CST cases. The legacy `read`, `print` and
`to_sequence` operations are sequence-specific. `render_svg` already dispatches,
converts, collects diagnostics and refuses output after errors.

The shared render diagram has sequence, BPMN and swimlane cases. Sequence values
already express calls, returns through line/head values, notes, activations,
creation and nested frames. Participant kind selects a colour family. There is
no independent participant icon reference or typed exception frame. SVG layout,
motion catalogs and scene bindings have explicit cases for each diagram kind.

The existing corpus stores provenance, licences, digests and generated MoonBit
text for tests that cannot read files. The swimlane reference uses a locked,
test-only Mermaid browser adapter. Reuse this pattern for independent expected
syntax and semantics. Do not use our own converter to generate expected models.

Primary sources:

- [ZenUML documentation at Mermaid 12.2.0](https://github.com/mermaid-js/mermaid/blob/mermaid%4012.2.0/packages/mermaid/src/docs/syntax/zenuml.md).
- [Architecture documentation at Mermaid 12.2.0](https://github.com/mermaid-js/mermaid/blob/mermaid%4012.2.0/packages/mermaid/src/docs/syntax/architecture.md).
- [Architecture grammar](https://github.com/mermaid-js/mermaid/blob/mermaid%4012.2.0/packages/parser/src/language/architecture/architecture.langium).
- [ZenUML plugin dependency](https://github.com/mermaid-js/mermaid/blob/mermaid%4012.2.0/packages/mermaid-zenuml/package.json).
- [ZenUML lexer and parser](https://github.com/mermaid-js/zenuml-core/tree/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/g4).
- [ZenUML icon registry](https://github.com/mermaid-js/zenuml-core/blob/e3f93e0eb65d23fa3520e8691a5bca883853aa4b/src/components/DiagramFrame/Tutorial/LazyIcons.ts).

## Goals / Non-Goals

**Goals:** retain native source, produce typed shared models, draw all supported
symbols offline, and keep output deterministic on all four backends. Use source
identity for playback and use geometry only for placement.

**Non-Goals:** see the proposal. In particular, parsing a complete expression
retains its text and does not run it. Layout and icon support do not import
Mermaid, React, the browser DOM or a font-based icon system into library code.

## Decisions

### D1. Freeze separate syntax and semantic references

**Call:** architecture follows Mermaid 12.2.0, including labelled edges, quoted
service icon text and `align row`/`align column` found in its grammar. Freeze the
grammar's imported terminals and relevant database validation as well as examples.
The grammar takes precedence over prose when they differ.

ZenUML uses the Mermaid 12.2.0 documentation profile and the separately pinned
plugin `@mermaid-js/mermaid-zenuml@1.0.1` with `@zenuml/core@3.47.9`, commit
`e3f93e0eb65d23fa3520e8691a5bca883853aa4b`. The plugin permits a range of core
versions, so the plugin version alone is insufficient. Commit an exact test lock.
The reader supports all documentation examples and the syntax families named
in the ZenUML spec. Other core grammar extensions remain losslessly retained
and diagnosed. Do not claim full upstream editor-tolerance grammar support.

Freeze an exhaustive manifest of participant icon keys from that commit's
`LazyIcons.ts`, plus alias-to-asset mappings. Inspection found 523 keys. This
registry is wider than the upstream static SVG registry, so the smaller SVG map
must not define our coverage. Record provider asset terms separately from the
engine's MIT licence. Keep source paths, digests, attribution and normalized
asset digests in the manifest.

Using a moving upstream version would make acceptance change without repository
changes. Using the sequence grammar for ZenUML would lose call nesting and returns.

### D2. Extend dispatch without changing the sequence-only entry points

**Call:** add `Zenuml` and `Architecture` AST/CST cases to `read_diagram` and
`print_diagram`. Add `to_zenuml_sequence` and `to_architecture` conversions with
optional model values and diagnostics. Preserve the legacy sequence operations
and result types. Use the existing header preprocessing rules and full-source
UTF-16 positions. The bare `zenuml` header selects the new reader.

Add separate `zenuml-*` and `architecture-*` syntax, CST, AST, printer and
conversion packages inside `diagrams-mermaid`. Reuse source-position helpers and
bounded metadata preprocessing. Do not route these languages through the
sequence line parser. Parse braces, strings, parentheses and comments with
explicit state and stacks; recover at the next safe statement boundary.

The dispatch API currently accepts a swimlane-named limits type. Preserve that
parameter and its meaning for existing callers. Add optional per-kind limits
for the new readers/printers rather than renaming the existing public type.
Document the defaults and stable `zenuml/*` and `architecture/*` diagnostic codes.

Replacing the old sequence AST with a union would break unrelated consumers.
Separate format readers also prevent one grammar's recovery rules from damaging
the other format.

### D3. Convert ZenUML through an explicit call stack

**Call:** retain declaration order, aliases, annotator spelling and source spans
in the ZenUML AST. Keep calls, async messages, creation, assignments, returns,
comments and fragments as typed statements. Canonical printing uses those fields,
not saved statement text. Normalize only spelling and indentation, not meaning.

Conversion tracks the current caller and nested call stack. An implicit starter
uses the reference-defined starter identity and actor appearance, with collision
checks. Synchronous calls emit messages and balanced activation events around
their bodies. Async messages do not create a synchronous call scope. Map `new`
and each return form to reference-compatible ordered creation/message/activation
events. An assignment result remains a label, never an evaluated value. Diagnose
a return with no valid target instead of inventing one.

Use existing loop, alt, opt, par and break frames where they express the source.
Add a `Try` frame and section roles `Plain`, `Try`, `Catch`, `Finally`; the default
role is `Plain` for existing constructors. Keep catch labels and final sections
typed. Do not turn a finally section into an alternative. Comments attached to
messages/fragments become notes at the reference-defined location; other comments
stay in syntax. Preserve Markdown source as safe text in this first profile.

A source-to-source rewrite into `sequenceDiagram` was considered. It cannot keep
ZenUML source, call scopes and annotator identity reliably. A second renderer
would duplicate the existing sequence layout and animation work.

### D4. Keep icon identity independent of semantic kind

**Call:** add a small immutable icon reference in `diagrams/icons`, with namespace
and key, and an optional participant icon field whose constructor default is
absent. Preserve the declared ZenUML annotator separately in its AST. Map known
UML semantic kinds when applicable, but do not map every cloud icon to a new
participant kind. Render-property kind overrides keep their existing colour
semantics and do not erase an explicit icon.

Put normalized vector data in `diagrams-svg/icons`. Include the full pinned
ZenUML registry and the five architecture defaults `cloud`, `database`, `disk`,
`internet`, `server`. Match the reference's case rules and aliases. Distinct
names can share an asset only where the pinned registry does so. Reuse geometry
where useful without merging namespaces or declared identities.

Convert approved fixed assets to a bounded typed vector representation at
development time. Include needed paths, groups, transforms, paints and local
definitions; reject executable elements and external references. Preserve
provider colours; add a suitable backing plate when needed in dark/light themes.
The renderer reads compiled values and embeds only referenced definitions,
deduplicated within an output and isolated by its ID prefix. No runtime SVG
parser, filesystem lookup or source-provided markup enters the writer.

Reserve measured icon space beside the participant label. Account for aliases,
sublabels, creation rows and lifeline anchors. The normal participant's old
geometry stays unchanged when its explicit icon is absent. Unknown names render
a generic labelled symbol and a stable warning naming the unresolved key.
Known registry keys cannot use this fallback as a substitute for implemented art.

An enum case for each provider symbol would couple core semantics to a changing
asset catalog. An icon font or remote URL would violate offline portable output.

### D5. Use an independent architecture model and constraint layout

**Call:** add `diagrams/architecture` with immutable ordered groups, services,
junctions, connections, alignments and accessibility. An endpoint holds the
authored service/junction ID, side and optional group-boundary attachment. Keep
the referenced service ID when a connection attaches to its containing group.
Give each connection a stable ordinal ID, including parallel edges. Validate
IDs, ownership, endpoints and alignments before geometry.

Add `Diagram::Architecture` and `diagrams-svg/architecture-layout`. Reuse shared
measurement, theme and XML writer code. Use an explicit deterministic ordering
and checked geometry/work budgets. Solve ordered row/column equality and spacing
constraints with group containment, then route orthogonal paths to declared
ports. Detect inconsistent hard constraints and return diagnostics with no SVG.
Do not silently discard an alignment or move an edge to a different side.
Disconnected elements use declaration order. Cycles and self-connections use
bounded routing rather than unbounded topological traversal.

Author Mermaid layout settings remain source data and receive warnings for
unsupported options. Caller-supplied library limits and deterministic spacing
options control output. No random seed or force-layout runtime is needed.

Reusing a swimlane model would give groups responsibility semantics and lose
explicit ports. Importing Mermaid's force engine would add a JavaScript-only
runtime and conflict with deterministic four-target output.

### D6. Reuse the animation contract with explicit direction

**Call:** ZenUML remains `Diagram::Sequence` after conversion. Extend sequence
frame projection for typed exception sections and retain participant icons in
canonical/display SVG and export. Scenario playback selects explicit exception
sections and does not infer that an exception occurred or that finally ran.

Add architecture catalog and node-binding cases. A connection occurrence binds
to its actual SVG path, with its authored identities and traversal direction.
Group-boundary attachment changes the path, not the service endpoint identity.
Junctions are real selectable graph endpoints. Group membership, row/column
alignment and proximity never create graph edges.

Headed edges define forward reachability; two heads allow both directions.
Unheaded edges require explicit undirected exploration. Reverse queries retain
traversal direction for playback. Reuse existing bounds, controls, reduced
motion, offline behavior and canonical static download.

An architecture-only player would duplicate controls and export behavior.
Treating each line as directed would invent a dependency the author did not draw.

## Risks / Trade-offs

- The complete annotator catalog increases asset size. Mitigate with a generated
  manifest, shared asset deduplication, used-symbol output and measured module/
  artifact sizes. Do not shrink coverage to the smaller upstream SVG map.
- Provider assets have their own distribution terms. Record and satisfy those
  terms in the asset inventory before importing the catalog. The first task
  group qualifies representative UML, cloud and technology assets end to end.
- Native ZenUML starter/return behavior is context-sensitive. Freeze independent
  semantic fixtures for nested calls, assignments and early returns before
  extending the converter beyond the first thin path.
- Architecture constraints can conflict. Distinguish invalid models, conflicting
  constraints and exhausted budgets. Include each case in acceptance tests.
- Public enum additions require consumer updates. Keep constructor defaults and
  legacy examples, document each new case and verify generated interfaces.

## Migration plan

Land story-sized groups after approval, each with its acceptance path. The first
group is a compatibility and rendering spike followed by one thin source-to-SVG
path per header. Create the epic and story beads only after approval. Record
dependencies in both tasks and beads.

Run frozen corpus, static snapshots and browser qualification for each affected
boundary. Existing sequence/BPMN/swimlane static bytes must stay unchanged for
old inputs/options. Shared HTML runtime changes need deterministic snapshot
updates and behavior qualification. Document exhaustive matches for parsed/CST,
render diagram, frame/section and animation enums in the module guides.

The last implementation PR archives this change and syncs accepted specs. Close
its beads only after merge, then close the finished epic and sync the tracker.
Rollback uses ordinary commits before publication; this proposal changes no
release policy or version.
