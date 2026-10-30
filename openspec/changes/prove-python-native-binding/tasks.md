# Tasks

## 1. Prove an in-process tracer from Python to render_svg

Bead: diagrams-wf3.1

- [x] 1.1 Verify the pinned toolchain output for a native `foreign_library` package: record the archive, the C backend steps, `moonbit_init` and the exported symbols.
- [x] 1.2 Add the unpublished `apps/python-native` module with a portable bridge package and a native `ffi` package that exports the versioned bytes-in, bytes-out entry point; verify the bridge on all four targets.
- [x] 1.3 Add the Limited API C adapter, the Python wrapper and the `scripts/python-native.mbtx` build; verify that `import diagrams_native` renders one valid flowchart in the same process.

## 2. Add diagnostics, Unicode and parity with the direct output

Bead: diagrams-wf3.2

Depends on group 1.

- [x] 2.1 Add the native oracle and shared fixtures for valid, invalid, empty and non-BMP input; verify that Python output and diagnostics equal the oracle files.
- [x] 2.2 Refuse text that is not valid Unicode before the call, check the boundary version at import, and state the units of diagnostic positions; verify each case with a test.
- [x] 2.3 Add the `test:python-native` mise task; verify that it builds from a clean tree and exits nonzero when a test fails.

## 3. Check lifetime, sanitizers and repeated calls

Bead: diagrams-wf3.3

Depends on group 2.

- [x] 3.1 Document and test initialization, ownership of each buffer and the serialized GIL policy; verify that a second import does not initialize the runtime again.
- [x] 3.2 Build the extension with AddressSanitizer and UndefinedBehaviorSanitizer from the generated C and runtime sources; verify that repeated mixed calls report no error.
- [x] 3.3 Measure bounded repeated calls with allocator, RSS and leak tools where available; record the method, the numbers and the limits.
- [x] 3.4 Load the same abi3 extension in two pinned CPython versions; record the Limited API result.

## 4. Report the feasibility result

Bead: diagrams-wf3.4

Depends on group 3.

- [x] 4.1 Write the feasibility report with toolchain, linkage, results, limits, deployment and ABI risks, and next steps; verify each claim against a command, a test or a primary source.
- [x] 4.2 Run `mise run format`, `mise run check`, `mise run test:python-native` and `mise exec -- openspec validate --all --strict`; verify that all pass.

## Workflow follow-up

- Archive this change in the final task-group pull request. Close the stories and
  the epic only after the merge, with the pull request and the merge SHA, then sync beads.
