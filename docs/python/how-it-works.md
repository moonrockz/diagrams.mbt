---
title: How the Python package works
summary: The native boundary, the zig cross-build, the tests and the PyPI release of diagrams.mbt.
order: 3
---
# How the Python package works

## From MoonBit to a wheel

```mermaid
flowchart LR
  A[MoonBit sources] -->|moonc, C backend| B[ffi.c]
  B --> C[zig cc for each target]
  R[MoonBit runtime C files] --> C
  M[mimalloc 2.1.7] --> C
  P[CPython adapter, Limited API 3.12] --> C
  C --> D[_native extension module]
  D --> W[abi3 wheel]
```

1. `moon build --target native --release` writes C for the native
   `foreign_library` package `apps/python-native/ffi`. It exports two C functions.
   Source goes in as UTF-8 bytes, and a versioned UTF-8 JSON result comes out.
2. `zig cc -target <target>` compiles that C, five MoonBit runtime files, the
   CPython adapter and mimalloc 2.1.7, the same version that the MoonBit runtime
   bundles. One Linux or macOS host builds all five wheels.
3. A small standard-library script writes each wheel with its metadata and the
   license files of the bundled components.

The Python wrapper parses the JSON result into dataclasses. It does not parse
or render a diagram itself.

## Memory and calls

- The adapter copies the source into a new MoonBit `Bytes` value and copies the
  result into a new `str`. It releases each MoonBit value one time. No Python
  object points into MoonBit memory.
- The MoonBit runtime starts one time for each process, when the module is
  imported, and stays until the process stops.
- The spike measured no leak with the macOS `leaks` tool after 4,000 renders,
  and no error with AddressSanitizer and UndefinedBehaviorSanitizer. See the
  [feasibility report](https://github.com/moonrockz/diagrams.mbt/blob/main/apps/python-native/FEASIBILITY.md).

## Tests

Each pull request builds the wheels with zig on Linux. Then it installs each
wheel on a native runner and runs the tests with CPython 3.12 and 3.15:
Linux x86_64 and arm64, macOS arm64 and Intel, and Windows x86_64. The tests
compare the output and the diagnostics with the direct output of a native
MoonBit program. `auditwheel` checks the Linux tags and `twine check` checks
the metadata.

To build the wheels on your machine (Linux or macOS):

```shell
mise run python-native:wheels
```

The wheels go to `_build/python-native/dist/`.

## Releases

The Python version is `__version__` in
`apps/python-native/python/diagrams_mbt/__init__.py`. It is separate from the
version of the MoonBit modules. When a change of that version merges to `main`,
the Release workflow builds and tests the wheels, and uploads them to PyPI with
trusted publishing. It uploads nothing when PyPI already has the version.

## Limits

- Windows wheels use the MinGW ABI with the Universal CRT. MoonBit supports
  only MSVC on Windows, so the Windows tests are the main evidence for this
  target. The Windows module also exports some MoonBit runtime symbols; this
  causes no conflict on Windows.
- There is no free-threaded (`abi3t`), musllinux, 32-bit or Windows arm64 wheel.
- The UTF-8 conversion uses the scalar code of the MoonBit runtime, not
  simdutf. The measured render time is the same, because the conversion runs
  only at the boundary.
