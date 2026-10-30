"""In-process Mermaid-to-SVG rendering through the MoonBit native backend.

This package is experimental (0.0.x); its API can change. ``render_svg`` calls the
MoonBit ``render_svg`` function of ``moonrockz/diagrams-mermaid`` in this
process through the extension module ``diagrams_mbt._native``. Calls from any
thread are safe: the extension releases the GIL while MoonBit runs and while it
waits for its process-wide runtime lock, and that lock lets only one MoonBit
call run at a time. Free-threaded CPython and subinterpreters are not
supported. See ``docs/python/concurrency.md``.

Diagnostic positions are the MoonBit values: lines and columns start at 1,
and columns and offsets count UTF-16 code units. Use ``code_point_index`` to
convert an offset to an index into the Python string.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Tuple

from . import _boundary, _native

__version__ = "0.0.1"

__all__ = [
    "ABI_VERSION",
    "Diagnostic",
    "Position",
    "Rendered",
    "Span",
    "code_point_index",
    "render_svg",
]

ABI_VERSION: int = _native.ABI_VERSION


@dataclass(frozen=True)
class Position:
    line: int
    column: int
    offset: int


@dataclass(frozen=True)
class Span:
    start: Position
    end: Position


@dataclass(frozen=True)
class Diagnostic:
    code: str
    severity: str
    message: str
    span: Optional[Span]


@dataclass(frozen=True)
class Rendered:
    output: Optional[str]
    media_type: str
    diagnostics: Tuple[Diagnostic, ...]

    @property
    def ok(self) -> bool:
        """True when there is output and no error diagnostic."""
        return self.output is not None and not any(
            d.severity == "error" for d in self.diagnostics
        )


def render_svg(source: str) -> Rendered:
    """Render Mermaid ``source`` to standalone SVG with the default renderer.

    Diagnostics are returned, not raised. A string that is not valid Unicode,
    for example one with a lone surrogate, raises ``UnicodeEncodeError``
    before the renderer is called.
    """
    if not isinstance(source, str):
        raise TypeError("source must be str")
    # A lone surrogate raises UnicodeEncodeError here, before the renderer.
    media_type, output, diagnostics = _boundary.call(
        "render_svg", source.encode("utf-8")
    )
    return Rendered(
        output=output,
        media_type=media_type,
        diagnostics=tuple(_diagnostic(d) for d in diagnostics),
    )


def code_point_index(source: str, utf16_offset: int) -> int:
    """Convert a UTF-16 code-unit offset in ``source`` to a str index."""
    units = 0
    for index, char in enumerate(source):
        if units >= utf16_offset:
            return index
        units += 2 if ord(char) > 0xFFFF else 1
    return len(source)


def _position(record: tuple) -> Position:
    line, column, offset = record
    return Position(line, column, offset)


def _diagnostic(record: tuple) -> Diagnostic:
    code, severity, message, span = record
    return Diagnostic(
        code=code,
        severity=severity,
        message=message,
        span=None if span is None else Span(_position(span[0]), _position(span[1])),
    )
