# Tasks

The owner approved the scope and requested Claude implementation and landing.
Epic: `diagrams-9sy`. Each numbered group has one story and the dependencies
below. Each group lands its own tests, tested examples and compatibility notes.
Tick tasks in their PRs; close beads only after the corresponding merge.

Prefer one complete implementation PR, including archival. Split only when
correctness or review needs it; a task group does not require a separate PR.
Use at most three agents total: this planner, the Claude lead and at most one
additional agent. Reuse that helper rather than spawning further agents.

Before each PR run `mise run format`, `mise run check` and
`mise exec -- openspec validate --all --strict`. Use
`MISE_ACTIVATE_AGGRESSIVE=1` for nested pinned-tool commands. Rendering/runtime
groups also run `mise run test:svg` and `mise run test:animation`. Keep reference
qualification reports bound to their actual source, fixture and tool digests.

## 1. Prove four native sources through SVG and playback

Bead: diagrams-9sy.1.

- [x] 1.1 Pin PlantUML 1.2026.9 source/JAR identities, notices and digests plus an exact test-only JDK; build the restricted host reference task and freeze one regex, EBNF, JSON and YAML example, verifying accepted/refused cases and recording which normalized fields come from parser inspection versus rendered output.
- [x] 1.2 Add `diagrams-plantuml`, minimal CST/AST/read/print/conversion paths and the three immutable model/diagram cases; register workspace, shared versions and publication order without publishing, and verify four-target source reproduction, typed round trips, constructor immutability and publication-list tests.
- [x] 1.3 Draw minimal railroad and data geometry through the shared SVG renderer; verify a canonical SVG snapshot for each of the four source fixtures and unchanged existing static snapshots.
- [x] 1.4 Add initial catalogs, actual path bindings and a pure timed node-visit target; emit one player per fixture and verify sampling plus real browser play/pause for a path step and an inline scalar visit.
- [x] 1.5 Document the tracer's exact coverage, errors for unsupported syntax and public enum/scene migration with compiled module examples; verify all four guides/examples build and that no production module needs Java, a server or a UI framework.
- [x] 1.6 Add immutable source-bound trace values and the public `RailroadTraceProvider` trait with typed Regex/EBNF requests, input/start-rule/limits and distinct result outcomes; verify separate consumer stub implementations supply success/failure traces, can reject unsupported kinds and need no bundled matcher/parser.

## 2. Complete regex reading, writing and model semantics

Bead: diagrams-9sy.2.
Depends on: group 1.

- [x] 2.1 Freeze the regex feature/refusal inventory from pinned commands, token kinds and documentation examples; verify complete fixture coverage and reproducible native acceptance/semantic normalization through the host reference task.
- [x] 2.2 Complete regex CST/AST and model conversion for atoms, escapes, classes, groups, anchors, lookarounds, alternatives and all pinned quantifier forms; verify typed distinctions, names/modifiers/bounds and independently selectable equal-text occurrences on all four targets.
- [x] 2.3 Complete typed canonical writing, state-aware recovery and explicit limits; verify changed-AST output, read-print-read equality, stable canonical bytes, two-error recovery, Unicode/CRLF spans and symbolic large repeats without stack or allocation expansion.
- [x] 2.4 Publish the regex profile, diagnostic inventory, constraint semantics and constructed-model examples; verify missing/invalid model identities, bounds and containment cycles plus compiled examples and explicit refusals instead of literal fallback.

## 3. Complete EBNF reading, writing and model semantics

Bead: diagrams-9sy.3.
Depends on: group 1.

- [x] 3.1 Freeze the EBNF feature/refusal inventory and documentation cases, including counts, special sequences, restrictions, empty rules and notes; verify reference normalization and explicit classification of removed or refused drawing commands.
- [x] 3.2 Complete ordered rules, Unicode names, terminals, references, sequence/choice/grouping, optional/repeated terms and exclusions in CST/AST/model conversion; verify operator precedence, note ownership and bounded recursive references on all targets.
- [x] 3.3 Complete canonical writing, recovery and grammar validation; verify typed round trips, modified terminals, unresolved/ambiguous references, invalid counts, two errors in separate rules and depth/work/output failures without partial success.
- [x] 3.4 Document rule identity, recursive references and exclusion/constraint behavior through compiled constructed/read examples; verify diagnostics identify the actual reference occurrence and do not turn excluded terms into ordinary alternatives.

## 4. Complete JSON and native YAML data paths

Bead: diagrams-9sy.4.
Depends on: group 1.

- [x] 4.1 Freeze both data profiles and native acceptance/refusal/scalar fixtures, including duplicate-key projection, quotes, comments, empty values, multiline text, tabs and nested collections; verify normalized results and source/tool digest coverage through the reference task.
- [x] 4.2 Complete JSON CST/AST, ordered data conversion and canonical writing without a lossy map or floating-point intermediary; verify duplicate members, exact large/signed-zero numbers, scalar roots, Unicode escapes, malformed literals and stable typed round trips on all four targets.
- [x] 4.3 Complete the pinned native YAML reader/converter/writer with its string-scalar policy; verify quote/colon/comma boundaries, multiline values, indentation/list forms, literal anchor/tag-looking data, explicit refusals and unrepresentable edited-value errors without source fallback.
- [x] 4.4 Complete titles, notes, retained style metadata and typed highlight selectors; verify keys containing separators, array indices, repeated occurrences, unresolved/ambiguous targets, inert presentation data and errors for includes/executable preprocessing.
- [x] 4.5 Complete immutable data-model validation and document format projection, limits and diagnostics with compiled examples; verify caller array mutation, invalid roots/parents, containment cycles, depth/work/output exhaustion and distinct identities for repeated values.

## 5. Complete railroad layout and static qualification

Bead: diagrams-9sy.5.
Depends on: groups 2 and 3.

- [x] 5.1 Complete measured railroad fragments, ordered rule placement, choice/bypass/return paths and bounded width continuation; verify nested expressions, empty terms, long labels and loop attachment without label collisions.
- [x] 5.2 Paint all pattern/grammar semantic roles, bounds, notes and reference targets with shared themes and safe text; verify assertions/exclusions stay constraints, recursion is not inlined, and adaptive/fixed dark/light snapshots agree across targets.
- [x] 5.3 Expose railroad geometry/legibility checks and exact scene paths; verify deliberately broken attachment, padding and contrast, independent inline prefixes, explicit exhaustion and no partial successful SVG.
- [x] 5.4 Extend existing SVG browser qualification and compiled renderer examples; verify actual curve/bypass/loop paths, headers/labels, offline output, canonical/display geometry equality and unchanged old sequence/BPMN/swimlane static bytes.
- [x] 5.5 Expose independent static highlight channels and styles for matched, non-matched, taken-prefix and failure-point targets through direct renderer/convenience APIs and an explicit provider driver; verify both subject kinds, terminal-only/prefix-only use, overlapping attempts, neutral unvisited branches, stale/invalid trace rejection, unsupported/exhausted/error distinctions, unchanged geometry and unannotated bytes, plus external-provider consumer examples on all four targets and dark/light browsers.

## 6. Complete data layout and static qualification

Bead: diagrams-9sy.6.
Depends on: group 4.

- [x] 6.1 Complete ordered container/row placement and child routing for nested mixed collections, scalar roots and empty containers; verify exact decimal labels, array positions, long text wrapping, row bounds and correct connector attachment.
- [x] 6.2 Apply shared themes, scalar distinctions, semantic highlights, accessibility and scoped IDs; verify escaped hostile labels/metadata, independent repeated rows, contrast and adaptive/fixed dark/light snapshots across targets.
- [x] 6.3 Expose bounded data geometry/legibility and row/connector bindings; verify invalid constructed geometry, explicit depth/work/output failure and node visits for inline values without fake or zero-length paths.
- [x] 6.4 Extend the existing SVG harness and compiled examples for both source formats; verify standalone XML, actual row/connector geometry, canonical/display identity, no resource fetches and unchanged old static SVGs.

## 7. Complete structural playback and exploration

Bead: diagrams-9sy.7.
Depends on: groups 5 and 6.

- [x] 7.1 Complete catalogs, typed path/visit bindings and public target validation for all three models; verify repeated occurrence identity, source/view mismatch, invalid target kinds and pure cross-target sampling with existing connection steps unchanged.
- [x] 7.2 Complete railroad route/reach queries and finite explicit/default illustrations; verify selected branch/bypass/return direction, symbolic unbounded repeats, bounded cycles, reference inspection without invisible arcs and descriptive constraints without computed match/parse claims, while keeping externally supplied outcomes distinguishable.
- [x] 7.3 Complete typed containment queries and hierarchy plans that combine row visits with actual connector steps; verify ancestor/descendant order, inline scalar targets, repeated names/values, absence of implicit reference links and distinct unreachable/outside-view/limit results.
- [x] 7.4 Extend the existing embedded player for visit targets and relation-aware controls; verify actual path motion, scalar-region highlights, play/pause/restart/step/seek/speed, keyboard operation, reduced motion, hidden-page suspension and print output for all four source kinds.
- [x] 7.5 Qualify canonical export and document finite illustrative semantics with compiled examples; verify export bytes while playing either target kind, unchanged selection/position, safe offline HTML and old player behavior with deliberately regenerated runtime-dependent HTML snapshots only.
- [x] 7.6 Preserve configured static trace highlights in animated scenes and canonical exports; verify direct-render byte equality with the same trace/style options, independent transient overlays, external-outcome labels and zero provider calls during ordinary rendering, playback, selection or export.

## 8. Integrate docs, review output and qualify the candidate

Bead: diagrams-9sy.8.
Depends on: group 7.

- [x] 8.1 Add build-time `plantuml`/`puml` fence rendering through the native library with scoped IDs and file/block diagnostics; verify all four source types, adjacent copies, failure propagation and unchanged ordinary JSON/YAML/regex/EBNF code fences in site tests.
- [x] 8.2 Extend the gallery and stored site assets with native sources, dark/light SVGs and players for all four types, including constraints, recursive references, nested data, explicit scenarios and independent successful/failed/prefix/terminal trace highlights for both regex and EBNF; verify deterministic generation, asset parity and every gallery link.
- [x] 8.3 Update module navigation, glossary, architecture and user guides to the tested APIs and compatibility/refusal policy; verify compiled examples, fresh consumers that keep model/rendering and Java-free production boundaries, plus `build:site`, `check:site` and `test:site`.
- [x] 8.4 Run final native reference, portable corpus, full four-target, SVG and animation checks on the actual candidate; verify report/source digests and all existing CI categories without adding duplicate build or platform matrices.
- [x] 8.5 Obtain owner gallery review before landing, record supported profiles, migration notes and real validation in the final PR, and verify that all completed groups' tasks are checked before archival.

## Workflow follow-up

- Archive this change in the PR that lands the last task group and update its links.
- After each merge, close its completed beads with the PR and merge SHA.
- Close the epic only after every child closes, then verify `bd dolt pull` and push.
- The Claude workspace owns implementation and normal merging after checks and
  the concrete gallery review pass. Do not ask for duplicate merge approval or
  use admin bypass. Report any required owner gallery review with actual artifacts.
- A version release and publication need separate owner approval.
