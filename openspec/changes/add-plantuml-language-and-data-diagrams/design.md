# Design

## Context

See [proposal.md](proposal.md) for the motivation and scope.

The current `Diagram` union has sequence, BPMN and swimlane cases. Each has a
format-independent model. `diagrams-mermaid` demonstrates lossless CST/AST
reading, canonical writing, conversion and an SVG convenience call.
`diagrams-svg` owns measured geometry, legibility and canonical/display scenes.
`diagrams/animation` owns pure catalogs, queries and plans; `diagrams-animated`
owns the offline HTML boundary. Current motion occurrences describe connections,
and the scene has path bindings plus inspectable node bindings.

The site has a build-time Mermaid fence pass in `apps/site/content/mermaid.mbt`.
The workspace already has four-target CI, stored oracle fixtures, SVG/player
browser qualification and a gallery. These are the integration points.

## Goals / Non-Goals

**Goals:**

- Add the four requested source types without making Java a library dependency.
- Retain pattern, grammar and data meaning in immutable domain values.
- Reuse themes, text metrics, safe output, scenes and controls while keeping
  railroad layout separate from structured-data layout.
- Give every acceptance criterion a portable fixture, geometry check or browser
  check in the existing verification paths.

**Non-Goals:**

- A common parser for all PlantUML languages or a general-purpose regex/YAML engine.
- A generic graph model that removes operators, scalar types or member order.
- A second player, UI framework or independent release pipeline.

## Decisions

### D1. Four source types with existing feature parity

**Owner:** Start with PlantUML regex, EBNF, JSON and YAML diagrams and give them
the same treatment as the existing diagram kinds.

**Owner:** Expose independently controlled match/failure highlighting in the
renderer and a public trait for external matching/parsing engines. Implement
the renderer extension and hook; do not bundle those engines.

**Call:** Parity includes lossless reading, typed values, canonical writing,
diagnostics, pure constructed-model APIs, themed SVG, structural exploration,
offline playback, static export, tested guides and a review gallery. As with
BPMN playback, illustration does not execute the source language. The new
provider contract accepts evidence from an external engine; built-in regex
matching or EBNF input execution would need a separate change.

### D2. Pin native behavior before completing the readers

**Call:** Use PlantUML `1.2026.9`, commit
`18d0aae311a4f1eb3723bb4b0ad939185e22f166`, as the initial reference. Freeze
documentation inputs, parser/command feature inventories, accepted examples,
literal-data cases and expected refusals with provenance and digests.

The first slice must prove a restricted host-side reference driver for all four
kinds. Use parser/data inspection where it is available and rendered semantic
labels/topology for remaining cases. Record that distinction in the fixture
schema; rendered acceptance alone must not be labelled a complete AST oracle.
Compare semantic normalization and acceptance, not upstream pixel positions.

Pin the JAR digest and exact JDK in mise for that host task. Keep Java, upstream
source and their notices in the test/reference boundary. Write original MoonBit
readers and painters; do not copy the Java implementation into published code.
Reference runs use controlled fixtures and restrict external resource access.

An unpinned public server was rejected because it can change and receive private
source. A Java rendering wrapper was rejected because all library targets must
work without a process, network or external renderer.

### D3. One new format module and three model cases

**Call:** Add `pkgs/diagrams-plantuml`, with `cst`, `ast`, envelope scanning,
kind-specific readers/printers and conversion packages. Its public parsed union
has regex, EBNF, JSON and YAML cases. `read` accepts one native block;
`read_body` requires an explicit kind. `print` writes a native block and
`print_body` writes only its body. `render_svg` composes reading, conversion and
the existing renderer, accumulating diagnostics and preserving failure.

Add `regex`, `ebnf` and `data-tree` packages to `diagrams`, and `Regex`, `Ebnf`
and `DataTree` cases to the shared diagram union. Regex and EBNF keep separate
expression types. JSON and YAML are source formats for one structured-data
diagram kind. This follows the current distinction between a kind and a format.

Add `railroad-trace` beside those model packages. It depends on regex/EBNF values
and common diagnostics, not the format reader, renderer or animation package.

Separate published modules for every source type were rejected: these are format
adapters and visual models, not new general-purpose language runtimes. A single
untyped graph was rejected because it cannot retain the necessary distinctions.

### D4. Separate lexical source from semantic values

**Call:** A lossless scanner partitions the original source and returns an owned
CST, including malformed regions. The envelope and body scanners use their own
quote/comment states. No global comment or directive stripping runs over bodies.
Diagnostics use source UTF-16 offsets and stable exported code inventories.

Typed ASTs retain all accepted statements and metadata, not just the rendered
portion. Canonical writing reads typed values, not cached source text. Logical
round-trip comparison excludes locations and trivia placement. An unrepresentable
constructed value gives a writer diagnostic rather than stale source output.

Use explicit positive source, output, depth, node, work and diagnostic budgets.
Check depth before recursive work or use iterative stacks/flat arenas. Counts
and repetitions remain symbolic; they do not allocate repeated copies.

Keep title, notes, style blocks, skin settings and highlight selectors as typed
metadata under the documented profile. Library themes and explicit options own
painting. Unapplied presentation settings give findings. Includes, executable
preprocessing and unsupported diagram blocks prevent model conversion; they
never cause implicit I/O. Multi-block files get an explicit diagnostic.

### D5. Pattern and grammar models retain operators

**Call:** Regex values distinguish atoms, classes, sequences, choices, groups,
repetition and zero-width constraints. EBNF values distinguish rules, references,
terminals, special sequences, sequences, choices, optional terms, repetition,
empty terms and exclusions. Keep bounds, names, polarity, notes and source
bindings. Immutable constructors copy input arrays.

Use view-scoped occurrence identities based on ordered ownership paths or
explicit caller IDs, never labels alone. Validate constructed ownership,
references, duplicate definitions, bounds and budgets before rendering.
Recursive rule references are allowed; containment cycles are invalid.
Unresolved or ambiguous names remain renderable nonterminals with warnings and
no fabricated definition target. This preserves native examples that use names
as placeholders. An explicit target ID that names no rule is an invalid
constructed model. A resolved reference can identify its definition for
inspection without becoming an invisible route.

Shared railroad fragment helpers operate on measured geometry; they do not
replace the two public semantic expression types.

### D6. Ordered data and the native YAML policy

**Call:** The data model has ordered object members, indexed arrays and typed
scalars. Preserve decimal number lexemes, including large integers and signed
zero, instead of converting through floating point. Duplicate names and repeated
values have separate occurrence IDs. Source bindings and view highlights are
separate from values.

The JSON AST retains all member occurrences. If a pinned adapter projection
shadows a member, retain the full AST and document that projection with a
diagnostic. Fixtures determine the exact duplicate-key behavior for each native
format; the core model can represent every occurrence without a map overwrite.

The pinned YAML adapter converts scalars to strings. Its parser supports selected
indentation, list, quoting, flow-list and block-text forms, rather than full YAML
schema resolution. Preserve that native policy. Do not reuse the Mermaid YAML
metadata resolver as if its scalar or alias rules were identical. Freeze cases
for tabs, comments, colons/commas in quotes, empty values, multiline text, duplicate
names and constructs recognized lexically but refused by the pinned parser.
Anchor/tag-looking text has no expanded reference semantics.

Canonical YAML writing selects representable native forms and verifies their
logical values. A new value that the native profile cannot express gives an
explicit writer error. Raw-source fallback was rejected because it would hide
typed edits. General YAML support can later add an explicit profile without
silently changing this one.

### D7. Two geometry implementations with shared output contracts

**Call:** Add `railroad-layout` and `data-tree-layout` packages inside
`diagrams-svg`. Reuse existing text measurement, themes, escaping and neutral
geometry helpers. Do not route expressions through BPMN or swimlane semantics.

Railroad layout uses fragment baselines and entry/exit ports. It composes sequence,
choice, bypass and repeat geometry, stacks EBNF rules in order, and shows
constraints with distinct markers or annotations. Excluded terms and lookarounds
must not become ordinary accepting branches. Rule references stay compact.
Width wrapping uses explicit continuation geometry and never cuts a token's
meaning or silently omits text.

Data layout uses measured container boxes, keyed/indexed rows and connections to
nested values. Empty containers and scalar roots are visible. Each row has
inspectable bounds even when it has no separate drawn connector. Resolve semantic
highlights to occurrences; quoted path separators stay within their segments.

Both implementations expose geometry and legibility checks, obey bounds and
return no partial successful SVG after an error. Canonical SVG is script-free.
Display scenes use the same geometry with explicitly prefixed IDs. Apply the
shared contrast policy to highlights as well as ordinary labels.

### D8. Node visits are a separate motion target

**Call:** Add a typed visit operation to pure plans and timed node/row occurrences
to catalogs. Preserve existing connection steps and reversed-path interpolation.
Visits bind to visible regions; connection steps bind to real SVG paths. Do not
create zero-length paths or invisible arrows to fit rows into a connection API.

Railroad graphs project displayed structural connectors and retain constraint
roles. Recursive references do not add unrendered graph arcs. Data graphs expose
typed containment relations. A hierarchy route becomes ordered row visits plus
connector steps only where a connector is drawn. Equal keys/values, scalar text
and row adjacency create no additional relation. Existing swimlane containment
rules remain unchanged.

Default illustration is finite and source-ordered, or pre-order for data. It can
repeat as an illustration but never expands an unbounded regex repeat or recursive
grammar. Explicit scenarios preserve chosen repetitions and concurrent groups.
The viewer calls computed routes structural or hierarchy results. A separately
supplied match/parse outcome identifies its external source and is not presented
as a conclusion of route search.

Extend the existing runtime and scene payload with explicit target kinds. Reject
wrong target/source combinations and stale scene bindings. Node visits obey the
same positive duration, sampling, seeking, reduced-motion, visibility and print
rules as connection steps. Export continues to return direct canonical SVG bytes.
Configured static trace highlights belong to that canonical render. Current
playback/selection effects stay separate from them.

### D9. Site and package integration stay at existing boundaries

**Call:** Add a native PlantUML fence pass in `apps/site/content` for `plantuml`
and `puml` fences. It renders the four supported native envelopes at build time
with per-diagram ID prefixes and file/block diagnostics. Ordinary `json`, `yaml`,
`regex` and `ebnf` code fences stay code. They are not guessed to be diagrams.

Register the module in the workspace, shared-version checks, tested guides and
publication order after `diagrams-svg`. Extend the publication-list assertions.
No publishing command or version release is part of this change.

### D10. Reuse the verification categories

**Call:** Add portable acceptance fixtures under the unpublished tests module.
Regular CI validates corpus digests, feature/refusal coverage and normalized
oracle fixtures, then exercises the new packages through the existing four-target
test/build matrix. Extend the current SVG/player/site browser harnesses and gallery
rather than adding duplicate compilation or another platform matrix.

The host-only reference task runs before merging parser/profile changes and on
the final candidate. Its report records source/fixture/tool digests and actual
normalization coverage; corpus validation rejects stale reports for the inputs
they certify. Java is needed for that qualification, not every portable test.
Use existing generated artifacts for browser checks when their inputs agree.

Keep old static SVG snapshots unchanged. Regenerate old HTML snapshots only for
an intentional shared-runtime/schema change, with existing controls and export
contracts still qualified. Finish with a gallery for all four source kinds,
dark/light modes, long text, nested branches/collections and finite scenarios.

### D11. External trace providers and static renderer highlights

**Call:** The core hook has this public shape, with immutable request/result
values and no bundled matching implementation:

```text
pub(open) trait RailroadTraceProvider {
  fn trace(Self, TraceRequest) -> TraceResult
}
```

The request carries a typed regex model or EBNF grammar, the input text, view
identity and explicit input/attempt/step/depth/work limits. EBNF requests name a
start-rule identity. Providers use the library's public semantic occurrence and
connector identities, not SVG IDs or label matching. A provider supporting only
one subject kind returns an explicit unsupported result for the other.

Results separate a completed matched result, a completed non-match, unsupported
syntax/kind, exhausted limits and provider errors. Finite trace attempts have
their own IDs, ordered path/visit occurrences, traversal orientation and optional
input spans. Preserve repetition and backtracking attempts even when they reuse
an occurrence. Failure points can identify a terminal, assertion or explicit
entry/exit boundary, with optional UTF-16 input position and diagnostic text.
Exhaustion and unsupported features are not evidence of a non-match.

Export semantic occurrence/connector lookup so an implementor can map an engine's
events to trace targets before any SVG or animation exists. Validate returned
kind/model/view identity, target roles, step continuity where specified, span
bounds and trace budgets. Do not re-run matching to verify a provider's claims.
Provider computation honors a cooperative budget; host adapters own any harder
timeout or I/O boundary. The library enforces its own trace-validation and
rendering limits regardless of provider implementation.

Expose a per-render highlight request for four independent channels: matched
paths, non-matched paths, the taken path/prefix, and failure points. Each has
separate visibility and theme-aware style options. A caller can show only the
failure terminal, only the prefix, or any combination. Never infer that an
unvisited alternative failed. Keep input strings and provider descriptions as
escaped data. The request is separate from the immutable diagram and source AST.

Keep distinct attempt memberships when the same connector is present in both a
matched and a failed attempt. The caller can select attempts; if both are shown,
use a documented deterministic layered style and accessible status labels rather
than last-write-wins replacement. Static highlights do not move nodes or paths.
With no highlight request, rendering retains the ordinary unannotated output bytes.

The SVG renderer and PlantUML SVG convenience entry point accept validated trace
values/highlight options directly. Provide an explicit opt-in orchestration entry
point that invokes a supplied provider, validates its result and renders the
trace. Keep the existing `Renderer::render` contract and ordinary render calls
free of implicit engine execution. Engines requiring asynchronous work or I/O
can run in an external host adapter and pass completed trace values instead.
Provider failure yields a typed diagnostic rather than a fabricated no-match
or a silent unhighlighted success in the trace-rendering entry point.

Canonical SVG includes the highlights explicitly requested at render time.
Scenes use the same geometry, trace configuration and styles. Animation overlays
do not overwrite the configured evidence, and static export equals a direct
render with the same trace options. No engine is invoked by playback or export.

Test both subject kinds using small fake providers in consumer/test packages.
They demonstrate the external trait contract; they are not production regex or
EBNF matching engines. Cover full match, failure after a consumed prefix,
terminal-only highlighting, assertion/end boundaries, repeated/backtracked
attempts, overlapping statuses, empty/unvisited alternatives, wrong-model traces,
invalid spans and unsupported/exhausted/error outcomes on all four targets.

## Risks / Trade-offs

- Four grammars broaden the work. Mitigation: prove all four thin paths first,
  then complete native readers and static families before full exploration.
- Native YAML differs from general YAML expectations. Mitigation: publish scalar
  and refusal policies and compare difficult cases with the pinned implementation.
- A rendered oracle cannot prove every AST field. Mitigation: label its coverage,
  inspect native semantic values where available, and add direct typed invariants.
- Node visits change shared scene/plan types. Mitigation: preserve existing step
  constructors, compile consumer examples and qualify all old players.
- Recursive grammar and deep data can exhaust resources. Mitigation: symbolic
  references/counts, bounded stacks and explicit errors at every processing stage.
- Upstream code has separate notices. Mitigation: keep reference materials in
  test tooling, retain provenance and write original production implementations.
- External engines have different semantics and resource behavior. Mitigation:
  retain provider provenance and explicit outcomes, validate traces, require
  cooperative limits and keep engine execution outside ordinary rendering.

## Migration Plan

1. The owner approved this scope and requested Claude implementation and landing.
   Epic `diagrams-9sy` has one story per numbered task group, recorded in tasks.md.
   The first group proves
   the reference, external provider hook and four end-to-end
   paths; groups 2-4 complete readers/models; groups 5-6 complete static output;
   group 7 completes motion; group 8 completes integration and qualification.
2. Document new diagram/occurrence/motion cases and any scene/catalog constructor
   changes in the first API-bearing PR. Keep existing public entry points usable.
3. Follow the normal task/PR workflow. Archive this change with the last group,
   then close and sync its beads after the corresponding merges.
4. A future owner-approved release publishes the new module with the shared
   version. Until then the existing released versions remain unchanged.
5. Dispatch to a Claude Orca workspace with full implementation/landing ownership.
   Prefer one complete PR; split only when correctness or review needs it, not
   once per task group. Use at most three agents total, counting the planning
   agent and Claude lead. No further merge approval is needed after the declared
   checks and concrete owner gallery review pass. Do not use admin bypass or
   publish a release without separate authorization.

## Open Questions

No owner decision blocks this plan. The first slice fixes the exact reference
driver inspection hooks, JDK patch pin and snapshot normalization schema. These
are test-tool choices and must not reduce the declared feature profile or remove
native examples from coverage.
