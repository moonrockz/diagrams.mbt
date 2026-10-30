# Python native-binding spike

This unpublished module is a feasibility spike for the OpenSpec change
`prove-python-native-binding`. It shows that CPython can call the existing
Mermaid-to-SVG code in the same process through the MoonBit native C backend.
It is not a stable Python API and is not published. See
[the feasibility report](FEASIBILITY.md) for the results and the limits.

## Layout

| Path | Contents |
| --- | --- |
| `bridge/` | Portable MoonBit package. It renders with `@mermaid.render_svg` and writes the versioned JSON result. It builds and tests on all four targets. |
| `ffi/` | Native `foreign_library` package. It exports `diagrams_py_abi_version` and `diagrams_py_render_svg`. |
| `oracle/` | Native executable. It writes the direct `render_svg` output of each fixture for comparison. |
| `fixtures/` | Shared Mermaid inputs: valid, invalid, empty, unsupported and non-BMP text. |
| `python/adapter/diagrams_native.c` | The CPython extension adapter (Limited API 3.12). |
| `python/diagrams_native/` | The Python wrapper with `render_svg(source)`. |
| `python/tests/` | `unittest` tests that the tasks run. |
| `python/measure.py` | Bounded repeated-call measurements. |

## Commands

The tasks use the pinned MoonBit toolchain and CPython 3.12.16 and 3.15.2
through mise. Run them from the repository root.

```shell
mise run clean
mise run test:python-native            # build, write the oracle, test with 3.12 and 3.15
mise run test:python-native-sanitize   # ASan + UBSan build from generated C, same tests
mise run python-native:measure         # repeated calls, allocator counts, macOS leaks
mise run python-native:build           # build only
```

The extension goes to `_build/python-native/default/diagrams_native/`. To try
it:

```shell
PYTHONPATH=_build/python-native/default mise exec python@3.15.2 -- python -P -c '
import diagrams_native
r = diagrams_native.render_svg("flowchart TD\n  A --> B\n")
print(r.ok, len(r.output), r.diagnostics)
r = diagrams_native.render_svg("flowchart TD\n  A[ --> B\n")
print(r.ok, r.diagnostics[0])
'
```

Only macOS arm64 is verified. The task script has Linux link arguments, but
they are not tested.
