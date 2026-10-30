# Tasks

## 1. Package the binding as diagrams_mbt and build wheels

Bead: diagrams-6va.1

- [x] 1.1 Rename the import package to `diagrams_mbt` and the extension to `diagrams_mbt._native`, add `__version__` 0.0.1 and `py.typed`; verify the existing tests and tasks.
- [x] 1.2 Add a dependency-free wheel builder with PyPI metadata, license and RECORD; verify `twine check` and an install with pip.

## 2. Cross-build the wheels with zig

Bead: diagrams-6va.2

Depends on group 1.

- [x] 2.1 Fetch pinned CPython 3.12 headers for each target and verify their SHA-256 digests; verify that a wrong digest fails the task.
- [x] 2.2 Compile the generated C, the five runtime files and the adapter with zig for the five targets and link the extension modules; verify the macOS minimum version, the glibc symbol versions and the Windows imports.
- [x] 2.3 Add the `python-native:wheels` task; verify the Linux wheels in Docker with `auditwheel` and the tests, and the macOS wheels on this host.

## 3. Test the wheels in CI

Bead: diagrams-6va.3

Depends on group 2.

- [x] 3.1 Add the reusable `python-wheels.yml` workflow: build on Linux, then install and test each wheel on its native runner with CPython 3.12 and 3.15.
- [x] 3.2 Call it from `ci.yml`, require it in `ci-ok`, and verify a green pull request run.

## 4. Publish to PyPI with trusted publishing

Bead: diagrams-6va.4

Depends on group 3.

- [x] 4.1 Add the PyPI plan (version on main, not on PyPI) with tests, and the `pypi` job in `release.yml` with `id-token: write`.
- [x] 4.2 Update the README, the feasibility report and the guides; run `mise run format`, `mise run check` and `mise exec -- openspec validate --all --strict`.
- [x] 4.3 After the merge, verify that PyPI has `diagrams.mbt` 0.0.1 with five wheels and that a fresh install renders a diagram.

## Workflow follow-up

- Archive this change and `prove-python-native-binding` in the pull request. Close the beads after the merge with the pull request and the merge SHA.
