# Proposal

## Why

Python can render Mermaid SVG through the native MoonBit implementation, but it cannot use the public document traversal APIs. A portable query language and matching traversal interfaces can let MoonBit and Python consumers inspect the same immutable trees without a Python callback for every node or field.

## What Changes

- Add a public, portable MoonBit query compiler, typed query representation and bounded evaluator. The syntax uses Tree-sitter-style node patterns, fields, alternatives, captures and native predicates. Python uses this same compiler and evaluator.
- Add a query adapter for the existing BPMN document tree. Retain its namespace-aware names, complete document content, order, revision identity and optional source locations. Keep the independent BPMN module free of diagram and host dependencies.
- Expose the existing BPMN read-only inspection, visitor, walk, fold, reduction, event, cursor and graph-query capabilities in Python. Publish an explicit mapping to the public MoonBit operations, including defaults, control decisions, failures and limits.
- Add reusable compiled queries, requested-field projection and bounded result batches to both public consumer APIs. Keep immediate visitor pruning and stop behavior distinct from observational batches.
- Replace whole-result SVG JSON transport with direct output buffers and structured result metadata. Retain the current Python SVG API and its output and diagnostic behavior.
- Release the GIL during native rendering, query execution and traversal advancement, and while waiting for a separate runtime lock. Keep MoonBit calls serialized. Run user callbacks outside the runtime lock through resumable traversal.
- Qualify semantic parity on all four MoonBit targets and the existing five-wheel Python matrix. Add reproducible latency, boundary, allocation, callback and contention measurements.

Compatibility means equal capabilities and observable behavior for this scope, with language-appropriate names and values. It does not mean exposing compiler-generated symbols or copying MoonBit object layouts into Python. The query language is a MoonBit library feature, not a Python-only facade.

## Capabilities

### New Capabilities

- `tree-query-language`: Public portable query schemas, compilation, native predicates, deterministic matching, captures, projections, batches and resource limits.

### Modified Capabilities

- `bpmn-traversal`: Add the shared query adapter and a public consumer compatibility map over the existing complete BPMN traversal and graph surface.
- `python-native-binding`: Add query and traversal parity, direct result transport, explicit runtime synchronization, GIL release and callback-safe resumable execution.

## Scope and Non-goals

The first complete domain adapter is the existing BPMN document tree. The query core is adapter-based and must also pass a small non-BPMN tree fixture. Other diagram-model and parser-AST adapters are follow-up work; this proposal does not claim those surfaces already have a common tree contract.

Out of scope: binding every public model constructor, adding non-BPMN readers or raster/animation APIs to Python, changing rendering or BPMN semantics, following graph references implicitly in a tree query, a Tree-sitter parser/runtime dependency, full Tree-sitter query compatibility, arbitrary executable query predicates, concurrent MoonBit runtime execution, free-threaded Python, subinterpreters, and a new release without separate owner approval. Raw BPMN reading and explicit resource inputs needed to exercise traversal are in scope; a full Python BPMN construction/writer binding is not.

## Tracking

Planning only. After approval, create one repository-local epic and one story per numbered task group. Record dependencies and Bead IDs in tasks.md. Archive in the last implementation PR; close and sync stories only after merge with the PR and merge SHA.

## Impact

- Proposed new workspace module `pkgs/diagrams-query`, with a core-only generic package and an opt-in BPMN adapter package. Register and version it through the existing workspace/version tasks.
- Existing seams: `pkgs/bpmn/tree_model.mbt`, `events.mbt`, `visitor.mbt`, `cursor.mbt`, `graph_query.mbt` and generated public interfaces.
- Native host: `apps/python-native/{bridge,ffi,oracle,python/adapter,python/diagrams_mbt,python/tests}`. The private boundary version changes; existing public Python rendering remains compatible.
- Qualification: `scripts/python-native.mbtx`, `scripts/python-wheels.mbtx`, unpublished acceptance suites, Python documentation and cross-language fixtures. Existing CI/release gates remain applicable.
- No engine implementation, dependency change, version bump, release or publication is performed by this proposal.
