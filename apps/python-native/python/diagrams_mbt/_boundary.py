"""The private structured boundary of ``diagrams_mbt``.

``call(op, *args)`` sends one operation to the MoonBit library through
``diagrams_mbt._native.call`` and returns its value, or raises the exception
that the failure code names. Arguments and values are ``None``, ``bool``,
``int`` (signed 64-bit), ``str``, ``bytes`` and tuples of them; lists are
accepted as arguments and come back as tuples. Nesting is limited to 64 levels.

The extension releases the GIL while it waits for the runtime lock and while
MoonBit runs. One process-wide runtime lock serializes all MoonBit work, so
native calls from different threads never overlap. ``Exclusive`` guards a
mutable native object, such as a cursor, against use by two threads at once.

This module is internal. Its names can change in any release.
"""

from __future__ import annotations

import threading
from typing import Any, Dict, Type

from . import _native

__all__ = [
    "BoundaryError",
    "BusyError",
    "ClosedError",
    "Exclusive",
    "InvalidArgumentError",
    "InvalidTokenError",
    "ResourceLimitError",
    "call",
]


class BoundaryError(RuntimeError):
    """A failure that a native operation reported.

    ``code`` is the stable failure code, for example ``closed-token``, and
    ``message`` is its English description. ``str(error)`` is the message.
    """

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class InvalidTokenError(BoundaryError):
    """A token of another object kind, or one that names no native object."""


class ClosedError(BoundaryError):
    """The native object was closed."""


class BusyError(BoundaryError):
    """Another thread uses the same mutable native object at this time."""


class ResourceLimitError(BoundaryError):
    """An operation reached a declared resource limit."""


class InvalidArgumentError(BoundaryError, ValueError):
    """An argument has the wrong type or value."""


_ERRORS: Dict[str, Type[BoundaryError]] = {
    "wrong-token": InvalidTokenError,
    "invalid-token": InvalidTokenError,
    "closed-token": ClosedError,
    "busy": BusyError,
    "resource-limit": ResourceLimitError,
    "invalid-argument": InvalidArgumentError,
}


def error_for(code: str, message: str) -> BoundaryError:
    """The exception for a failure ``code``."""
    return _ERRORS.get(code, BoundaryError)(code, message)


def call(op: str, *args: Any) -> Any:
    """Run boundary operation ``op`` with ``args`` and return its value."""
    response = _native.call((op, *args))
    if response[0] == 0:
        return response[1]
    raise error_for(response[1], response[2])


class Exclusive:
    """A non-blocking guard for one mutable native object.

    ``with guard:`` enters at once, or raises ``BusyError`` when another
    thread, or the same thread from a callback, is inside the guard. It never
    waits, so it cannot deadlock with the runtime lock or the GIL.
    """

    __slots__ = ("_lock", "_what")

    def __init__(self, what: str = "object") -> None:
        self._lock = threading.Lock()
        self._what = what

    def __enter__(self) -> "Exclusive":
        if not self._lock.acquire(blocking=False):
            raise BusyError(
                "busy", f"Another call is using this {self._what} at this time."
            )
        return self

    def __exit__(self, *exc_info: object) -> None:
        self._lock.release()

    @property
    def busy(self) -> bool:
        """True while a call is inside the guard."""
        return self._lock.locked()
