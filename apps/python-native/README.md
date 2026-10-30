# Python package diagrams.mbt

This module builds the PyPI package `diagrams.mbt` (import `diagrams_mbt`). The
package calls the existing Mermaid-to-SVG code in the Python process through the
MoonBit native C backend. The MoonBit module itself is not published. The
OpenSpec changes `prove-python-native-binding` (spike) and
`publish-python-package` (wheels and PyPI) describe it. See
[the feasibility report](FEASIBILITY.md) and the
[Python docs](../../docs/python/getting-started.md).

## Layout

| Path | Contents |
| --- | --- |
| `bridge/` | Portable MoonBit package. It renders with `@mermaid.render_svg` and writes the versioned JSON result. It builds and tests on all four targets. |
| `ffi/` | Native `foreign_library` package. It exports `diagrams_py_abi_version` and `diagrams_py_render_svg`. |
| `oracle/` | Native executable. It writes the direct `render_svg` output of each fixture for comparison. |
| `fixtures/` | Shared Mermaid inputs: valid, invalid, empty, unsupported and non-BMP text. |
| `python/adapter/native.c` | The CPython extension adapter (Limited API 3.12). |
| `python/diagrams_mbt/` | The Python package with `render_svg(source)` and `__version__`. |
| `python/build_wheel.py` | The standard-library wheel builder. |
| `python/README.md` | The PyPI project description. |
| `python/THIRD-PARTY-NOTICES.md` | The licenses of the components in each wheel. |
| `python/tests/` | `unittest` tests that the tasks run. |
| `python/measure.py` | Bounded repeated-call measurements. |

## Commands

The tasks use the pinned MoonBit toolchain, zig and CPython 3.12.16 and 3.15.2
through mise. Run them from the repository root.

```shell
mise run clean
mise run test:python-native            # build, write the oracle, test with 3.12 and 3.15
mise run test:python-native-sanitize   # ASan + UBSan build from generated C, same tests
mise run python-native:measure         # repeated calls, allocator counts, macOS leaks
mise run python-native:build           # build only
mise run python-native:wheels          # cross-build the five wheels with zig
```

`python-native:wheels` writes the wheels to `_build/python-native/dist/`. It
downloads pinned CPython headers and mimalloc 2.1.7 and checks their SHA-256
digests.

The extension goes to `_build/python-native/default/diagrams_mbt/`. To try
it:

```shell
PYTHONPATH=_build/python-native/default mise exec python@3.15.2 -- python -P -c '
import diagrams_mbt
r = diagrams_mbt.render_svg("flowchart TD\n  A --> B\n")
print(r.ok, len(r.output), r.diagnostics)
r = diagrams_mbt.render_svg("flowchart TD\n  A[ --> B\n")
print(r.ok, r.diagnostics[0])
'
```

The host tasks (`test:python-native`, `test:python-native-sanitize` and
`python-native:measure`) are verified on macOS arm64 only. The wheels are tested
in CI on Linux, macOS and Windows.
