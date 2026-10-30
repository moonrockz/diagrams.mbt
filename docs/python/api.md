---
title: Python API reference
summary: The functions and values of the diagrams_mbt package.
order: 2
---
# Python API reference

All names on this page are in the module `diagrams_mbt`. All values are
immutable dataclasses. The submodules `diagrams_mbt.bpmn` and
`diagrams_mbt.query` have their own guides; see [Modules](#modules).

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

## Modules

| Module | Contents | Guide |
| --- | --- | --- |
| `diagrams_mbt` | `render_svg`, `code_point_index` and the values on this page | This page |
| `diagrams_mbt.bpmn` | BPMN reading, document trees, node views, handles and paths, events, cursors, `walk`, `fold`, `reduce`, visitors and graph queries | [BPMN traversal](traversal.md) |
| `diagrams_mbt.query` | Query schema, text and typed compilation, plans, cursors, batches and projected captures | [Tree queries](query.md) |

The [compatibility map](compatibility.md) lists each public MoonBit operation
and the Python operation that calls it, with defaults, controls, failures and
limits. A test checks the map against the generated MoonBit interfaces.

Failures of native objects use exception classes from
`diagrams_mbt._boundary`: `ClosedError` (a closed object), `InvalidTokenError`
(a token of another kind or an unknown token), `BusyError` (two threads use one
cursor or reader at the same time) and `ResourceLimitError`. All are
`RuntimeError` subclasses; `InvalidArgumentError` is also a `ValueError`.

## Behavior

- The extension releases the GIL while MoonBit runs and while a call waits
  for the process-wide runtime lock. That lock lets only one MoonBit call run
  at a time, so other Python threads continue but MoonBit work does not run in
  parallel. See [Threads and concurrency](concurrency.md).
- The package cannot load in a subinterpreter that has its own GIL; the
  import raises `ImportError`. There is no free-threaded wheel.
- An internal renderer failure (a MoonBit panic) stops the process. It is not a
  Python exception. Do not render untrusted input in a process that must not stop.
