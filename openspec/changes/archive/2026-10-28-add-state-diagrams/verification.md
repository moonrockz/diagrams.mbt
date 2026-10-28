# State acceptance evidence

The implementation uses Mermaid 12.2.0 and PlantUML 1.2026.9. The references
project upstream state databases and Java entities/links independently of the
MoonBit readers. Portable acceptance tests consume committed fixtures.

| Requirement group | Acceptance evidence |
| --- | --- |
| Immutable state values, ownership, concurrent regions, roles, IDs, copied input and bounded validation | `pkgs/diagrams/state/model_test.mbt`, executable state model guide and fresh model consumer |
| Native Mermaid grammar, losslessness, UTF-16 recovery, canonical edits, scope, inert presentation and processing limits | `tests/state-mermaid-acceptance/`, dedicated state reader/printer/converter packages and fresh reader consumer |
| Independent Mermaid profile | 53 original/canonical sources, all 22 documentation examples, 49 grammar bindings and 64 digest-bound frozen inputs under `tests/corpus/mermaid-states/` |
| Native PlantUML state grammar, aliases, hierarchy, concurrent scope, history, boundary roles, descriptions, notes, recovery, edits, limits and resource refusals | `tests/plantuml-state-acceptance/`, dedicated state package and fresh reader consumer |
| UML envelope family discrimination and existing native contracts | Existing PlantUML package and activity acceptance suites plus state dispatch regressions |
| Independent PlantUML profile | Frozen documentation/source/license/digest inventories and Java entity/link projection under `tests/corpus/plantuml-state/` and `tests/plantuml-state-reference/`; all 45 documentation examples accounted for |
| Deterministic hierarchical layout, roles, actual boundary attachments, mixed separator orientation, collapsed display endpoints, safe themes, geometry and limits | `pkgs/diagrams-svg/state_test.mbt`, both full state corpus rendering tests, public `state-layout` geometry/check/separators and shared connector inspection |
| Final styled connectors, bridge/mask parity and canonical scene paths | Shared connector tests, state SVG tests, fresh player consumer and stored Chromium qualification |
| Finite catalogs/scenarios, repeated/concurrent occurrences, visits, reverse/unheaded routes, visible scope and bounded queries | `pkgs/diagrams/animation/state_test.mbt`, executable animation guide and `pkgs/diagrams-animated/state_test.mbt` |
| Offline accessible controls, hostile source encoding, reduced motion, page hiding, print and exact SVG export without viewer mutation | `apps/site/scripts/state-test.ts`, stored state gallery and hostile source artifacts; shared existing animation/browser regressions |
| Six distinct sources with source, adaptive/light/dark SVG and players | `tests/state-gallery-acceptance/`, `site/examples/states/`, checked gallery manifest and artifact generator |
| Gallery source controls, all theme downloads, version paths, narrow/no-script browsing and stable prior routes | Gallery qualifier and root/next site browser tests |
| Existing output stability | All 208 existing gallery source/static SVG files compare byte-for-byte with the v0.3.0 base; reviewed shared player HTML updates retain static downloads |
| Dependency boundaries and all four targets | `mise run test:state-consumer`; model, dedicated Mermaid/PlantUML and renderer/player cases each run on wasm, wasm-gc, js and native |

The final frozen-code `mise run check` passed 888 tests on wasm, wasm-gc and
JavaScript, 899 tests on native, 23 task scripts, lint, validation and builds.
Fresh local consumers passed all 16 case/target combinations.

The full repository gate is `mise run check`. Stored visual/player qualification
uses `mise run test:svg`, `mise run test:animation`, `mise run test:state` and
`mise run gallery -- --existing-output --site-assets --qualify`. Site acceptance
uses build, link and browser checks at root and next. Strict OpenSpec validation
runs after archival. The final implementation/release PR carries these results.

Release 0.4.0 uses the existing GitHub Actions Release workflow. The owner
approved implementation, merge and publication. Postmerge tracker closure
records the PR and merge SHA, then pulls/pushes beads. Publication verification
checks all seven modules, the matching tag/release SHA, site asset contents,
fresh published state consumers and deployed versioned docs before goal closure.
