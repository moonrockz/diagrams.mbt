---
title: Python quick start
summary: Install diagrams.mbt from PyPI and render Mermaid source to SVG in Python.
order: 1
---
# Python quick start

The PyPI package [`diagrams.mbt`](https://pypi.org/project/diagrams.mbt/) renders
Mermaid source to standalone SVG in your Python process. It uses the same MoonBit
reader and renderer as the MoonBit packages, compiled to native code. It needs no
browser, no Node.js and no subprocess.

> The package is experimental (0.0.x). Its API can change in any release.

## Install

```shell
pip install diagrams.mbt
```

The import name is `diagrams_mbt`. One wheel for each platform serves CPython
3.12 and every later version (Limited API, `abi3`).

| Platform | Wheel tag |
| --- | --- |
| Linux x86_64, glibc 2.17 or later | `manylinux_2_17_x86_64` |
| Linux aarch64, glibc 2.17 or later | `manylinux_2_17_aarch64` |
| macOS 11 or later, Apple silicon | `macosx_11_0_arm64` |
| macOS 11 or later, Intel | `macosx_11_0_x86_64` |
| Windows x86_64 | `win_amd64` |

There is no source distribution, and free-threaded CPython builds are not
supported. On another platform, `pip` finds no wheel and stops.

## Render a diagram

```python
import diagrams_mbt

result = diagrams_mbt.render_svg("""
flowchart TD
  A[Start] --> B{Ready?}
  B -->|Yes| C[Render]
  B -->|No| D[Wait]
""")

if result.ok:
    with open("diagram.svg", "w", encoding="utf-8") as f:
        f.write(result.output)
```

`render_svg` accepts flowchart and graph, sequence, state, ZenUML,
`architecture-beta` and `swimlane-beta` diagrams. The output is the same SVG that
the MoonBit `render_svg` function writes with the default renderer.

## Read the diagnostics

`render_svg` does not raise an exception for a diagram error. It returns the
diagnostics:

```python
result = diagrams_mbt.render_svg("flowchart TD\n  A[ --> B\n")
print(result.ok)        # False
print(result.output)    # None
d = result.diagnostics[0]
print(d.severity, d.code, d.message)
# error flowchart/syntax Invalid flowchart statement
print(d.span.start.line, d.span.start.column)
# 2 3
```

A valid diagram can also have warnings. `result.ok` is `True` when there is
output and no diagnostic has the severity `error`.

Columns and offsets count UTF-16 code units. A character above U+FFFF, for
example an emoji, counts as two. Use `code_point_index` to get a Python index:

```python
start = diagrams_mbt.code_point_index(source, d.span.start.offset)
end = diagrams_mbt.code_point_index(source, d.span.end.offset)
print(source[start:end])
```

## Threads

You can call `render_svg` from any thread. The extension releases the GIL while
the MoonBit code runs, so other Python threads continue. MoonBit calls run one
at a time. See [Threads and concurrency](concurrency.md).

## Next

- [API reference](api.md)
- [How the package works](how-it-works.md)
- [Threads and concurrency](concurrency.md)
