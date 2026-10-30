"""Tests of the private structured boundary (``_native.call``, ``_boundary``).

The ``echo`` operation returns its arguments, so these tests check the C
encoder and decoder in both directions without domain code.
"""

from __future__ import annotations

import threading
import unittest

from diagrams_mbt import _boundary, _native

INT64_MIN = -(2**63)
INT64_MAX = 2**63 - 1


def nested(depth: int) -> tuple:
    value: tuple = (None,)
    for _ in range(depth - 1):
        value = (value,)
    return value


class CodecTest(unittest.TestCase):
    def test_scalar_values_round_trip(self) -> None:
        values = (
            None,
            True,
            False,
            0,
            -1,
            INT64_MIN,
            INT64_MAX,
            "",
            "café 漢字 \U0001F680 \U0001D518",
            b"",
            b"\x00\xff",
        )
        echoed = _boundary.call("echo", *values)
        self.assertEqual(echoed, values)
        for sent, back in zip(values, echoed):
            self.assertIs(type(back), type(sent))

    def test_lists_become_tuples(self) -> None:
        self.assertEqual(
            _boundary.call("echo", [1, [2, ()], []]), ((1, (2, ()), ()),)
        )

    def test_nesting_up_to_the_limit_round_trips(self) -> None:
        self.assertEqual(_native.RECORD_MAX_DEPTH, 64)
        # The response (status, (args...)) wraps the value in two levels, so
        # a value of 62 levels gives a response of exactly 64.
        value = nested(62)
        self.assertEqual(_boundary.call("echo", value), (value,))
        # A request of 64 levels (the tuple and 63 more) is accepted; only
        # the deeper echoed response is refused.
        with self.assertRaisesRegex(RuntimeError, "nested too deeply"):
            _boundary.call("echo", nested(63))

    def test_deeper_nesting_is_refused_before_the_call(self) -> None:
        before = _native._runtime_info()["calls"]
        with self.assertRaises(ValueError):
            _boundary.call("echo", nested(64))
        cyclic: list = []
        cyclic.append(cyclic)
        with self.assertRaises(ValueError):
            _boundary.call("echo", cyclic)
        self.assertEqual(_native._runtime_info()["calls"], before)

    def test_out_of_range_int_raises_overflow_error(self) -> None:
        for value in (INT64_MAX + 1, INT64_MIN - 1, 2**200):
            with self.subTest(value=value), self.assertRaises(OverflowError):
                _boundary.call("echo", value)

    def test_unsupported_values_raise_type_error(self) -> None:
        for value in (1.5, {"a": 1}, object(), bytearray(b"x")):
            with self.subTest(value=value), self.assertRaises(TypeError):
                _boundary.call("echo", value)
        with self.assertRaises(TypeError):
            _native.call(["echo"])

    def test_lone_surrogate_raises_unicode_encode_error(self) -> None:
        with self.assertRaises(UnicodeEncodeError):
            _boundary.call("echo", "\ud800")

    def test_large_values_round_trip(self) -> None:
        text = "x\U0001F680" * 200_000
        blob = bytes(range(256)) * 4_000
        self.assertEqual(_boundary.call("echo", text, blob), (text, blob))


class ErrorMappingTest(unittest.TestCase):
    def test_failures_raise_by_code(self) -> None:
        with self.assertRaises(_boundary.BoundaryError) as caught:
            _boundary.call("no-such-op")
        self.assertEqual(caught.exception.code, "unknown-op")
        self.assertIsInstance(caught.exception, RuntimeError)
        with self.assertRaises(_boundary.InvalidArgumentError) as caught:
            _boundary.call("render_svg", "not bytes")
        self.assertIsInstance(caught.exception, ValueError)
        self.assertEqual(caught.exception.code, "invalid-argument")

    def test_codes_map_to_documented_classes(self) -> None:
        expected = {
            "wrong-token": _boundary.InvalidTokenError,
            "invalid-token": _boundary.InvalidTokenError,
            "closed-token": _boundary.ClosedError,
            "busy": _boundary.BusyError,
            "resource-limit": _boundary.ResourceLimitError,
            "invalid-argument": _boundary.InvalidArgumentError,
            "other": _boundary.BoundaryError,
        }
        for code, cls in expected.items():
            error = _boundary.error_for(code, "message")
            self.assertIs(type(error), cls)
            self.assertEqual((error.code, str(error)), (code, "message"))

    def test_raw_response_shape(self) -> None:
        self.assertEqual(_native.call(("abi_version",)), (0, 2))
        failure = _native.call(("no-such-op",))
        self.assertEqual(failure[:2], (1, "unknown-op"))

    def test_live_objects_are_name_count_pairs(self) -> None:
        for name, count in _boundary.call("live_objects"):
            self.assertIsInstance(name, str)
            self.assertIsInstance(count, int)


class ExclusiveTest(unittest.TestCase):
    def test_second_entry_is_busy_and_never_waits(self) -> None:
        guard = _boundary.Exclusive("cursor")
        with guard:
            self.assertTrue(guard.busy)
            # The same thread (for example a callback) is refused too.
            with self.assertRaises(_boundary.BusyError):
                with guard:
                    pass
            errors: list[BaseException] = []

            def other() -> None:
                try:
                    with guard:
                        pass
                except _boundary.BusyError as error:
                    errors.append(error)

            thread = threading.Thread(target=other)
            thread.start()
            thread.join(timeout=10)
            self.assertFalse(thread.is_alive())
            self.assertEqual(len(errors), 1)
            self.assertEqual(errors[0].code, "busy")
        self.assertFalse(guard.busy)
        with guard:
            pass

    def test_exception_inside_releases_the_guard(self) -> None:
        guard = _boundary.Exclusive()
        with self.assertRaises(KeyError):
            with guard:
                raise KeyError("x")
        self.assertFalse(guard.busy)


if __name__ == "__main__":
    unittest.main()
