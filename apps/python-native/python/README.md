# diagrams.mbt for Python

`diagrams.mbt` renders Mermaid diagrams to standalone SVG in your Python
process. It uses the [diagrams.mbt](https://github.com/moonrockz/diagrams.mbt)
MoonBit renderer, compiled to native code. It needs no browser, no Node.js and
no subprocess.

> **Experimental (0.0.x).** The API can change in any release.

## Install

```shell
pip install diagrams.mbt
```

Wheels are available for CPython 3.12 and later on:

| Platform | Wheel tag |
| --- | --- |
| Linux x86_64, glibc 2.17 or later | `manylinux_2_17_x86_64` |
| Linux aarch64, glibc 2.17 or later | `manylinux_2_17_aarch64` |
| macOS 11 or later, Apple silicon | `macosx_11_0_arm64` |
| macOS 11 or later, Intel | `macosx_11_0_x86_64` |
| Windows x86_64 | `win_amd64` |

Free-threaded CPython builds are not supported.

## Render a diagram

```python
import diagrams_mbt

result = diagrams_mbt.render_svg("""
flowchart TD
  A[Start] --> B{Ready?}
  B -->|Yes| C[Render]
""")

if result.ok:
    with open("diagram.svg", "w", encoding="utf-8") as f:
        f.write(result.output)
```

`render_svg` returns a `Rendered` value with `output` (the SVG text or `None`),
`media_type` and `diagnostics`. It does not raise an exception for a diagram
error:

```python
result = diagrams_mbt.render_svg("flowchart TD\n  A[ --> B\n")
print(result.ok)               # False
for d in result.diagnostics:
    print(d.severity, d.code, d.message, d.span)
```

Supported Mermaid diagrams: flowchart and graph, sequence, state, ZenUML,
`architecture-beta` and `swimlane-beta`.

## Notes

- Diagnostic columns and offsets count UTF-16 code units. Use
  `diagrams_mbt.code_point_index(source, offset)` to get a Python string index.
- The extension releases the GIL while MoonBit runs. One process-wide runtime
  lock lets only one MoonBit call run at a time, so other Python threads
  continue, but MoonBit work does not run in parallel.
- An internal renderer failure (a MoonBit panic) stops the process. Do not
  render untrusted input in a process that must not stop.

See the [Python documentation](https://moonrockz.github.io/diagrams.mbt/docs/python/)
for details. The package is licensed under Apache-2.0. Bundled third-party
components keep their own licenses; see the files in the `licenses` directory
of the installed distribution.
