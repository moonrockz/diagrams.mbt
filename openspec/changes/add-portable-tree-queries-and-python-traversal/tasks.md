# Tasks

Epic: diagrams-uzj

## 1. Prove the shared query path and serialized GIL release

Bead: diagrams-uzj.1

- [ ] 1.1 Add a minimal public portable query module, BPMN adapter and Python entry path for one exact-kind capture; verify a fresh MoonBit consumer on all four targets and Python return the same node identity and projected ID from the same source.
- [ ] 1.2 Audit the pinned runtime and allocator thread-handoff constraints, then add a bounded native-lock/GIL tracer bullet; verify different Python threads can enter serially, unrelated Python code advances during native work and lock waits, and sanitizers report no error. If thread affinity requires a dedicated owner thread, update the design explicitly before continuing.
- [ ] 1.3 Record reproducible commands, runtime findings, baseline render/query/callback timings and the proposed API mapping; verify the evidence distinguishes measured behavior from assumptions and the initial query needs no Python predicate.

## 2. Add the public query schema, typed form and compiler

Bead: diagrams-uzj.2

Depends on group 1.

- [ ] 2.1 Complete the generic core-only adapter/schema contract and immutable typed query/plan values; verify independent BPMN and non-BPMN test adapters, reusable plans, incompatible-schema failures and the generated public interface on all four targets.
- [ ] 2.2 Implement the documented version 1 grammar, name resolution and native-predicate checks; verify exact kinds/categories, wildcards, ordered child fields, absent fields, alternatives and captures, including malformed queries and explicit rejection of regex, quantifiers, directives and anchors.
- [ ] 2.3 Implement text/typed-form validation parity and compile limits; verify namespace aliases/open extension namespaces, capture scope, duplicate capture rules, predicate arities, absent-versus-empty values and UTF-16 query diagnostics after non-BMP/CRLF text.
- [ ] 2.4 Publish the language grammar, schema inventory and executable MoonBit examples; verify every documented supported example compiles and every unsupported example gives its documented diagnostic on all four targets.

## 3. Add bounded native matching, projections and batches

Bead: diagrams-uzj.3

Depends on group 2.

- [ ] 3.1 Implement explicit-stack matching and fixed native predicates; verify root preorder, pattern and child-assignment order, distinct overlapping alternatives, repeated node capture roles and exact direct-child semantics against an independent small-tree reference evaluator.
- [ ] 3.2 Add requested-field projection and immutable owner-qualified capture records; verify namespace/scalar/source distinctions, absent and unknown fields, output bounds and equal text/typed query results without per-field callbacks.
- [ ] 3.3 Add independent cursors, bounded batches and complete/stopped/failed outcomes; verify batch sizes 1/64/256 concatenate identically, budgets are cumulative and a limit after a delivered batch is not presented as completion.
- [ ] 3.4 Add adversarial/deep-tree tests and consumer guidance; verify all declared compile/execution bounds, ambiguous child assignments, 10,000-depth trees, early close, independent cursors and no host-stack overflow on all four targets.

## 4. Complete the BPMN adapter and compatibility contract

Bead: diagrams-uzj.4

Depends on group 3.

- [ ] 4.1 Complete the opt-in BPMN adapter using existing public node/field/path APIs; verify processes, choreography, conversations, DI, vendor XML, comments, PI, malformed-but-retained content and constructed values retain identity, order and optional source locations.
- [ ] 4.2 Qualify namespace-aware fields and revision ownership; verify known/extension local-name collisions, duplicate IDs, aliases, absent defaults, source changes and handle/path resolution using shared source-backed and MoonBit-constructed fixtures.
- [ ] 4.3 Publish the exact MoonBit/Python compatibility map and normalized fixture schema for every mapped operation; verify defaults, enum/optional/scalar mappings, integer widths, source units, callback controls, graph failures and unsupported surfaces have no undocumented gaps.
- [ ] 4.4 Add fresh reader-only and query-adapter consumer tests and docs; verify BPMN retains its core-only imports, tree matching does not follow reference cycles, and captured handles feed existing graph lookup/reachability/routes with their original ambiguity and limit behavior on all four targets.

## 5. Replace private transport and complete runtime synchronization

Bead: diagrams-uzj.5

Depends on group 1; query transport qualification also requires groups 3 and 4.

- [ ] 5.1 Introduce the versioned structured C boundary, C-owned result buffers and generation-checked owner/plan/cursor tokens; verify stale/wrong/closed tokens fail safely, retained views outlive local document variables and cleanup releases resources exactly once under sanitizers.
- [ ] 5.2 Replace complete SVG JSON transport while preserving the public Python rendering API; verify exact SVG/diagnostic/Unicode parity, unchanged dataclass and error behavior, and no JSON round trip for complete SVG or projected batches.
- [ ] 5.3 Apply the native lock policy to initialization, allocation, reference counts, cycle collection, registries and counters; verify detached lock waits, release-before-GIL-reacquire ordering, imports/cleanup under contention, and rejection of simultaneous advancement of one cursor with bounded deadlock tests.
- [ ] 5.4 Document boundary ownership and supported concurrency, and qualify portable bridge records plus candidate native wheels; verify Python 3.12 Limited API compatibility, all existing wheel targets, sanitizer and native-Zig integration, and unchanged subinterpreter/free-threaded restrictions.

## 6. Expose complete Python query and traversal parity

Bead: diagrams-uzj.6

Depends on groups 4 and 5.

- [ ] 6.1 Add BPMN reading, explicit resources, owning tree views, node inspection, handles and paths plus query schema/typed/text compile, projection and batches; verify each mapped operation against the shared MoonBit oracle, including absent values, source units and complete/stopped/failed outcomes.
- [ ] 6.2 Add resumable pull/push events and full tree-cursor navigation; verify subtree bounds, relative depth, unchanged position after failed moves, independent cursors and callback-free observational batches on shared fixtures.
- [ ] 6.3 Add visitor, walk, fold, reduce and pruned-reduce facades; verify implemented-handler-only dispatch, immediate Continue/SkipChildren/Stop, leave behavior, accumulator/combine order, nested extension calls, 10,000-depth traversal and original exception propagation without later callbacks.
- [ ] 6.4 Expose graph lookup, reachability and route inputs/results from the compatibility map; verify typed endpoints, external resources/nodes, edge-kind/direction defaults, route tie breaks, ambiguity and each failure/limit outcome against MoonBit.
- [ ] 6.5 Publish paired MoonBit/Python query and traversal guides and typed Python signatures; verify examples run from clean consumer installs and the final generated-interface/API inventory has no missing mapped operation.

## 7. Qualify combined parity and performance

Bead: diagrams-uzj.7

Depends on all prior groups.

- [ ] 7.1 Run the complete shared normalized corpus on wasm, wasm-gc, js and native and on all five candidate wheels with Python 3.12/3.15; verify exact results, source identities, diagnostics, pruning, graph outcomes and resource bounds agree.
- [ ] 7.2 Extend the reproducible measurement task for native oracle, public calls, no-op/field/substantive visitors, pruning, selective/match-all queries and batch sizes 1/64/256; verify equal workloads and report latency distributions, throughput, native/callback counts, conversion bytes, allocation growth, GIL-held time and native-lock wait with platform/toolchain evidence.
- [ ] 7.3 Run integrated GIL-progress, reentry, contention, ownership and sanitizer qualification and review measured baselines; verify zero Python per-candidate calls for native queries, no runtime overlap, no lock-order deadlock and no unsupported parallel-speedup claim.
- [ ] 7.4 Run mise run format, mise run check, mise run test:native-zig, the focused Python/query consumer and sanitizer tasks, candidate wheel qualification and mise exec -- openspec validate --all --strict; verify required checks pass, public interfaces are reviewed and the final compatibility map is complete.

## Workflow follow-up

- After maintainer approval, create one local epic and one story for each numbered group, add the listed dependencies and record each Bead ID before claiming work.
- Prefer one coherent implementation PR where practical; story boundaries do not require separate PRs. Keep each group's tests and documentation with its implementation.
- Archive this change in the PR that completes its last task group. After merge, close stories with PR and merge SHA, close the finished epic and sync beads successfully.
- Obtain owner approval before opening or merging release/version changes or publishing to Mooncakes/PyPI. This proposal does not authorize publication, rename the existing trusted publisher, or change historical artifacts.
