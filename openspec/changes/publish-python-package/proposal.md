# Proposal

## Why

The spike `prove-python-native-binding` showed that CPython can call the
MoonBit Mermaid-to-SVG renderer in the same process. A probe also showed that
zig can cross-compile the generated C for Linux, macOS and Windows from one
host. Python users can use the library only when the project publishes wheels.
The owner approved a first PyPI release, `diagrams.mbt` 0.0.1, through trusted
publishing from `release.yml` with the environment `pypi`.

## What Changes

- Rename the Python import package to `diagrams_mbt` and its extension module
  to `diagrams_mbt._native`. The PyPI project is `diagrams.mbt`. The Python
  version (`diagrams_mbt.__version__`, first 0.0.1) is separate from the
  MoonBit module version.
- Cross-build five Limited API wheels (`cp312-abi3`) on one host with the
  pinned zig: manylinux 2.17 x86_64 and aarch64, macOS 11.0 arm64 and x86_64,
  and Windows x86_64. The build uses pinned CPython headers with verified
  digests.
- Test each wheel on a native GitHub runner with CPython 3.12 and 3.15 before
  publication. Check the Linux wheels with `auditwheel` and the metadata with
  `twine check`.
- Add a PyPI job to `release.yml`. It publishes the wheels with trusted
  publishing when a push to `main` has a Python version that PyPI does not
  have. Pull requests build and test only.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `python-native-binding`: The binding is a published Python package with
  cross-built wheels, not only an unpublished spike.

## Out of Scope

- A source distribution. A source build needs the MoonBit toolchain.
- Free-threaded (`abi3t`) wheels, musllinux, Windows arm64 and 32-bit targets.
- mimalloc and simdutf in the wheels. The cross-built runtime uses the system
  allocator and scalar UTF-8 code, which is about two times slower.
- Typed bindings for each model, renderer options, raster or other formats.
- Changes to the MoonBit release, the shared MoonBit version or mooncakes.io.

## Tracking

The owner approved this scope and the 0.0.1 PyPI publication on 2026-10-29.
One epic and one story per task group track the work in beads.

## Impact

- `apps/python-native/` (package rename, wheel metadata and builder),
  `scripts/python-native.mbtx`, `.config/mise/config.toml`.
- New reusable workflow `.github/workflows/python-wheels.yml`, called by
  `ci.yml` and `release.yml`. `ci-ok` requires it.
- `release.yml` gains a PyPI plan and publish path. The MoonBit release path
  does not change.
