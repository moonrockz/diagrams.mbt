# Python package diagrams.mbt

This module builds the PyPI package `diagrams.mbt` (import `diagrams_mbt`). The
package calls the existing Mermaid-to-SVG code in the Python process through the
MoonBit native C backend. The MoonBit module itself is not published. The
OpenSpec changes `prove-python-native-binding` (spike),
`publish-python-package` (wheels and PyPI) and
`add-portable-tree-queries-and-python-traversal` (structured boundary,
runtime lock, traversal and queries) describe it. See
[the feasibility report](FEASIBILITY.md) and the
[Python docs](../../docs/python/getting-started.md).

## Layout

| Path | Contents |
| --- | --- |
| `bridge/` | Portable MoonBit package. It decodes request records, runs the operation (`render_svg` and later traversal and query operations) and encodes the response record. Native objects are generation-checked registry tokens. It builds and tests on all four targets. |
| `ffi/` | Native `foreign_library` package. It exports `diagrams_py_abi_version` and `diagrams_py_call`. |
| `oracle/` | Native executable. It writes the direct `render_svg` output of each fixture for comparison. |
| `fixtures/` | Shared Mermaid inputs: valid, invalid, empty, unsupported and non-BMP text. |
| `python/adapter/native.c` | The CPython extension adapter (Limited API 3.12): the record codec, the runtime lock and the GIL release. |
| `python/diagrams_mbt/` | The Python package with `render_svg(source)` and `__version__`. `_boundary.py` holds the private `call`, its exception classes and the `Exclusive` busy guard. |
| `python/build_wheel.py` | The standard-library wheel builder. |
| `python/README.md` | The PyPI project description. |
| `python/THIRD-PARTY-NOTICES.md` | The licenses of the components in each wheel. |
| `python/tests/` | `unittest` tests that the tasks run. `test_runtime_*.py` test the boundary codec and the threads. |
| `python/measure.py`, `python/measure_bpmn.py` | Bounded repeated-call measurements and a latency, lock-wait, GIL and callback report for each render, query, event and visitor workload. Results: [MEASUREMENTS.md](MEASUREMENTS.md). |

## Commands

The tasks use the pinned MoonBit toolchain, zig and CPython 3.12.16 and 3.15.2
through mise. Run them from the repository root.

```shell
mise run clean
mise run test:python-native            # build, write the oracle, test with 3.12 and 3.15
mise run test:python-native-sanitize   # ASan + UBSan build from generated C, same tests
mise run python-native:measure         # repeated calls, allocator counts, latency report, macOS leaks
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

## Concurrency

The adapter releases the GIL while MoonBit runs and while a thread waits for
the process-wide runtime lock. That lock serializes all MoonBit work. The
adapter releases it before it takes the GIL again, and it runs no Python code
while it holds it. Builds must define `DIAGRAMS_PY_MIMALLOC` (1 for the
mimalloc runtime, 0 for the system allocator); with mimalloc the adapter
installs a deferred-free callback that collects cycles only on the thread that
holds the runtime lock. See [docs/python/concurrency.md](../../docs/python/concurrency.md)
and the [feasibility report](FEASIBILITY.md#runtime-thread-handoff).
