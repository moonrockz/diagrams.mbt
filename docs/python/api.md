---
title: Python API reference
summary: The functions and values of the diagrams_mbt package.
order: 2
---
# Python API reference

All names are in the module `diagrams_mbt`. All values are immutable dataclasses.

## Functions

| Function | Result |
| --- | --- |
| `render_svg(source: str) -> Rendered` | Reads Mermaid `source` and renders it with the default SVG renderer |
| `code_point_index(source: str, utf16_offset: int) -> int` | The `str` index of a UTF-16 code-unit offset in `source` |

`render_svg` raises:

| Exception | When |
| --- | --- |
| `TypeError` | `source` is not a `str` |
| `UnicodeEncodeError` | `source` contains a lone surrogate, so it is not valid Unicode. The renderer is not called. |

It does not raise an exception for a diagram error; read `Rendered.diagnostics`.

## Values

| Type | Fields |
| --- | --- |
| `Rendered` | `output: str \| None`, `media_type: str` (`image/svg+xml`), `diagnostics: tuple[Diagnostic, ...]`, and the property `ok: bool` |
| `Diagnostic` | `code: str`, `severity: str` (`error`, `warning` or `info`), `message: str`, `span: Span \| None` |
| `Span` | `start: Position`, `end: Position` |
| `Position` | `line: int` and `column: int` (both start at 1), `offset: int` (from 0) |

Columns and offsets count UTF-16 code units.

## Constants

| Name | Value |
| --- | --- |
| `__version__` | The package version, for example `"0.0.1"` |
| `ABI_VERSION` | The version of the boundary between the extension and the MoonBit library. The extension refuses another version at import. |

## Behavior

- The extension holds the GIL during a call, so calls run one at a time.
- The package cannot load in a subinterpreter that has its own GIL; the
  import raises `ImportError`.
- An internal renderer failure (a MoonBit panic) stops the process. It is not a
  Python exception. Do not render untrusted input in a process that must not stop.
