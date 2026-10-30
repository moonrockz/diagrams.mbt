"""In-process Mermaid-to-SVG rendering through the MoonBit native backend.

This package is a feasibility spike, not a stable API. ``render_svg`` calls the
MoonBit ``render_svg`` function of ``moonrockz/diagrams-mermaid`` in this
process through the extension module ``_diagrams_native``. The extension holds
the GIL during a call. The spike makes no claim about threads, free-threaded
CPython or subinterpreters.

Diagnostic positions are the MoonBit values: lines and columns start at 1,
and columns and offsets count UTF-16 code units. Use ``code_point_index`` to
convert an offset to an index into the Python string.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Optional, Tuple

from . import _diagrams_native

__all__ = [
    "ABI_VERSION",
    "Diagnostic",
    "Position",
    "Rendered",
    "Span",
    "code_point_index",
    "render_svg",
]

ABI_VERSION: int = _diagrams_native.ABI_VERSION


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
    data = json.loads(_diagrams_native.render_svg_json(source))
    if data.get("format") != ABI_VERSION:
        raise RuntimeError(f"unexpected result format {data.get('format')!r}")
    return Rendered(
        output=data["output"],
        media_type=data["media_type"],
        diagnostics=tuple(_diagnostic(d) for d in data["diagnostics"]),
    )


def code_point_index(source: str, utf16_offset: int) -> int:
    """Convert a UTF-16 code-unit offset in ``source`` to a str index."""
    units = 0
    for index, char in enumerate(source):
        if units >= utf16_offset:
            return index
        units += 2 if ord(char) > 0xFFFF else 1
    return len(source)


def _position(data: dict) -> Position:
    return Position(data["line"], data["column"], data["offset"])


def _diagnostic(data: dict) -> Diagnostic:
    span = data["span"]
    return Diagnostic(
        code=data["code"],
        severity=data["severity"],
        message=data["message"],
        span=None
        if span is None
        else Span(_position(span["start"]), _position(span["end"])),
    )
