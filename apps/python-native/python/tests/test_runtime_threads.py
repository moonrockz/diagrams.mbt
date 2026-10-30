"""Thread tests of the serialized runtime lock and the GIL release.

The extension keeps lock instrumentation in C atomics. ``_native._lock_stats()``
reads it with the GIL held and without the runtime lock:

- ``inside``: threads inside the runtime lock now (0 or 1);
- ``max_inside``: the largest value of ``inside`` since the process started;
- ``waiting``: threads that wait for the runtime lock now (detached);
- ``entries``: lock acquisitions; ``contended``: acquisitions that waited;
- ``deferred_*``: calls of the guarded mimalloc deferred-free callback.

A Python thread that reads ``inside == 1`` runs Python code while another
thread holds the runtime lock. The lock is only held while the holder is
detached from Python, so such a reading proves that native work releases the
GIL. Every wait has a deadline, so a deadlock fails a test instead of hanging.
"""

from __future__ import annotations

import gc
import os
import subprocess
import sys
import textwrap
import threading
import time
import unittest

import diagrams_mbt
from diagrams_mbt import _boundary, _native

DEADLINE = float(os.environ.get("DIAGRAMS_NATIVE_THREAD_DEADLINE", "60"))
ROUNDS = int(os.environ.get("DIAGRAMS_NATIVE_THREAD_ROUNDS", "3"))

# A flowchart that takes tens of milliseconds to render (about 40 ms on an
# Apple M-series host with mimalloc), below the renderer's layout limits.
LONG_SOURCE = "flowchart TD\n" + "".join(f"  N{i} --> N{i + 1}\n" for i in range(300))
SMALL_SOURCE = "flowchart TD\n  A --> B\n"
# A few milliseconds of native work: enough contention, short waits.
MEDIUM_SOURCE = "flowchart TD\n" + "".join(f"  N{i} --> N{i + 1}\n" for i in range(40))


def child_env() -> dict[str, str]:
    """The environment of a Python child process, with the sanitizer preload.

    macOS removes ``DYLD_INSERT_LIBRARIES`` from the environment after it is
    used, so the sanitizer task also sets ``DIAGRAMS_NATIVE_PRELOAD``.
    """
    env = dict(os.environ)
    preload = env.get("DIAGRAMS_NATIVE_PRELOAD")
    if preload:
        name, _, value = preload.partition("=")
        env[name] = value
    return env


def stats() -> dict:
    return _native._lock_stats()


def join_all(test: unittest.TestCase, threads: list[threading.Thread]) -> None:
    end = time.monotonic() + DEADLINE
    for thread in threads:
        thread.join(timeout=max(0.0, end - time.monotonic()))
        test.assertFalse(thread.is_alive(), f"{thread.name} passed the deadline")


class Worker(threading.Thread):
    """Runs ``body`` and keeps its exception for the test thread."""

    def __init__(self, name: str, body) -> None:
        super().__init__(name=name, daemon=True)
        self.body = body
        self.error: BaseException | None = None

    def run(self) -> None:
        try:
            self.body()
        except BaseException as error:  # noqa: BLE001 - reported by check()
            self.error = error

    def check(self, test: unittest.TestCase) -> None:
        if self.error is not None:
            raise AssertionError(f"{self.name} failed") from self.error


class SerializedEntryTest(unittest.TestCase):
    def test_different_threads_enter_one_at_a_time(self) -> None:
        expected = diagrams_mbt.render_svg(SMALL_SOURCE)
        long_expected = diagrams_mbt.render_svg(LONG_SOURCE)
        before = stats()
        idents: set[int] = set()
        mismatches: list[str] = []

        def body() -> None:
            idents.add(threading.get_ident())
            for i in range(20):
                src, want = (
                    (LONG_SOURCE, long_expected) if i % 10 == 0 else (SMALL_SOURCE, expected)
                )
                if diagrams_mbt.render_svg(src) != want:
                    mismatches.append(threading.current_thread().name)

        workers = [Worker(f"render-{i}", body) for i in range(8)]
        for w in workers:
            w.start()
        join_all(self, workers)
        for w in workers:
            w.check(self)
        after = stats()
        self.assertEqual(mismatches, [])
        self.assertEqual(len(idents), 8)
        self.assertEqual(after["max_inside"], 1)
        self.assertEqual(after["inside"], 0)
        self.assertEqual(after["waiting"], 0)
        self.assertGreaterEqual(after["entries"] - before["entries"], 160)
        # Eight threads with long renders must have met at the lock.
        self.assertGreater(after["contended"], before["contended"])


class GilReleaseTest(unittest.TestCase):
    def test_heartbeat_progresses_during_one_native_call(self) -> None:
        """Python ticks happen strictly inside one call while it is native."""
        diagrams_mbt.render_svg(LONG_SOURCE)  # warm up
        best = 0
        for _ in range(ROUNDS * 2):
            ticks: list[int] = []
            started = threading.Event()
            stop = threading.Event()

            def heartbeat() -> None:
                started.set()
                while not stop.is_set():
                    if stats()["inside"] == 1:
                        ticks.append(time.perf_counter_ns())

            beat = Worker("heartbeat", heartbeat)
            beat.start()
            self.assertTrue(started.wait(DEADLINE))
            t0 = time.perf_counter_ns()
            rendered = diagrams_mbt.render_svg(LONG_SOURCE)
            t1 = time.perf_counter_ns()
            stop.set()
            join_all(self, [beat])
            beat.check(self)
            self.assertTrue(rendered.ok)
            # Only this call takes the runtime lock, so a tick that saw
            # `inside == 1` within [t0, t1] ran during its native work.
            during = [t for t in ticks if t0 < t < t1]
            best = max(best, len(during))
            if best >= 10:
                break
        self.assertGreaterEqual(best, 10, "the heartbeat made no progress during native work")

    def test_third_thread_runs_while_a_caller_waits_for_the_lock(self) -> None:
        """A works in native code, B waits for the lock, C runs Python."""
        for _ in range(ROUNDS):
            stop = threading.Event()

            def native_loop() -> None:
                while not stop.is_set():
                    diagrams_mbt.render_svg(LONG_SOURCE)

            a = Worker("A", native_loop)
            b = Worker("B", native_loop)
            a.start()
            b.start()
            proven = False
            end = time.monotonic() + DEADLINE
            try:
                while not proven and time.monotonic() < end:
                    first = stats()
                    if first["inside"] != 1 or first["waiting"] < 1:
                        continue
                    # C does Python work while the same holder and waiter stay.
                    work = sum(i * i for i in range(2000))
                    second = stats()
                    proven = (
                        work > 0
                        and second["inside"] == 1
                        and second["waiting"] >= 1
                        and second["entries"] == first["entries"]
                    )
            finally:
                stop.set()
            join_all(self, [a, b])
            a.check(self)
            b.check(self)
            self.assertTrue(proven, "C never ran while A held the lock and B waited")
            self.assertEqual(stats()["max_inside"], 1)


class DeadlockTest(unittest.TestCase):
    def test_mixed_load_finishes_within_the_deadline(self) -> None:
        """Native calls, lock reads, GIL-heavy Python and GC finish together."""
        old_interval = sys.getswitchinterval()
        sys.setswitchinterval(1e-5)
        try:
            for _ in range(ROUNDS):
                py_lock = threading.Lock()
                shared: list[int] = []

                def renders() -> None:
                    for i in range(15):
                        source = LONG_SOURCE if i % 5 == 0 else SMALL_SOURCE
                        # Hold a Python lock across a native call: the native
                        # call must never need it, so no lock-order cycle.
                        with py_lock:
                            shared.append(len(diagrams_mbt.render_svg(source).output))

                def info() -> None:
                    for _ in range(50):
                        _native._runtime_info()
                        _boundary.call("echo", (1, "x", b"y"))

                def python_only() -> None:
                    for _ in range(50):
                        with py_lock:
                            shared.append(sum(range(500)))
                        gc.collect(0)

                workers = [Worker(f"render-{i}", renders) for i in range(4)]
                workers += [Worker(f"info-{i}", info) for i in range(2)]
                workers += [Worker(f"py-{i}", python_only) for i in range(2)]
                for w in workers:
                    w.start()
                join_all(self, workers)
                for w in workers:
                    w.check(self)
                self.assertEqual(len(shared), 4 * 15 + 2 * 50)
        finally:
            sys.setswitchinterval(old_interval)
        self.assertEqual(stats()["max_inside"], 1)


class Finalized:
    """An object whose finalizer calls the extension, like a native owner.

    The finalizer takes no Python lock: the collector can run it on a thread
    that already holds one. ``list.append`` is atomic with the GIL.
    """

    closed: list[str] = []

    def __init__(self) -> None:
        self.cycle = self

    def __del__(self) -> None:
        Finalized.closed.append(_boundary.call("echo", "close")[0])


class CleanupTest(unittest.TestCase):
    def test_finalizers_call_native_code_under_contention(self) -> None:
        gc.collect()
        Finalized.closed = []
        created: list[int] = []
        old_threshold = gc.get_threshold()
        # Frequent collections run finalizers at many points, also while
        # other threads hold the runtime lock.
        gc.set_threshold(10, 2, 2)
        stop = threading.Event()

        def contention() -> None:
            while not stop.is_set():
                diagrams_mbt.render_svg(MEDIUM_SOURCE)

        # The lock is not fair: each finalizer can wait for a whole render.
        def make_garbage() -> None:
            for _ in range(150):
                Finalized()
                created.append(1)

        busy = [Worker(f"busy-{i}", contention) for i in range(2)]
        makers = [Worker(f"garbage-{i}", make_garbage) for i in range(4)]
        try:
            for w in busy + makers:
                w.start()
            join_all(self, makers)
        finally:
            stop.set()
            gc.set_threshold(*old_threshold)
        join_all(self, busy)
        for w in busy + makers:
            w.check(self)
        gc.collect()
        self.assertEqual(len(created), 600)
        self.assertEqual(Finalized.closed, ["close"] * 600)
        self.assertEqual(stats()["max_inside"], 1)

    def test_many_short_lived_threads_exit_while_another_renders(self) -> None:
        """Thread exit runs mimalloc's deferred-free callback off the lock."""
        before = stats()
        expected = diagrams_mbt.render_svg(SMALL_SOURCE)
        stop = threading.Event()
        bad: list[str] = []

        def renderer() -> None:
            while not stop.is_set():
                diagrams_mbt.render_svg(LONG_SOURCE)

        def short_lived() -> None:
            if diagrams_mbt.render_svg(SMALL_SOURCE) != expected:
                bad.append(threading.current_thread().name)

        steady = Worker("steady", renderer)
        steady.start()
        count = 0
        try:
            for batch in range(10):
                group = [Worker(f"short-{batch}-{i}", short_lived) for i in range(20)]
                for w in group:
                    w.start()
                join_all(self, group)
                for w in group:
                    w.check(self)
                count += len(group)
        finally:
            stop.set()
            join_all(self, [steady])
        steady.check(self)
        self.assertEqual(bad, [])
        after = stats()
        self.assertEqual(after["max_inside"], 1)
        if after["allocator"] == "mimalloc":
            # Each exiting thread that allocated from mimalloc calls the
            # callback with force set and without the runtime lock. The guard
            # skips it; allocation slow paths under the lock still reach it.
            skipped = after["deferred_skipped"] - before["deferred_skipped"]
            self.assertGreaterEqual(skipped, count)
            self.assertGreater(after["deferred_locked"], before["deferred_locked"])
        else:
            self.assertEqual(after["deferred_skipped"], 0)
            self.assertEqual(after["deferred_locked"], 0)


class ImportTest(unittest.TestCase):
    def test_concurrent_imports_initialize_the_runtime_once(self) -> None:
        script = textwrap.dedent(
            """
            import importlib, sys, threading
            barrier = threading.Barrier(8)
            modules, errors = [], []
            def first_import():
                try:
                    barrier.wait(30)
                    modules.append(importlib.import_module("diagrams_mbt"))
                except BaseException as error:
                    errors.append(error)
            threads = [threading.Thread(target=first_import) for _ in range(8)]
            for t in threads: t.start()
            for t in threads: t.join(60)
            assert not errors, errors
            assert len({id(m) for m in modules}) == 1
            import diagrams_mbt
            native = diagrams_mbt._native
            stop = threading.Event()
            def busy():
                src = "flowchart TD\\n" + "".join(f"  N{i} --> N{i+1}\\n" for i in range(300))
                while not stop.is_set():
                    diagrams_mbt.render_svg(src)
            worker = threading.Thread(target=busy)
            worker.start()
            # A new module object runs the exec slot again while another
            # thread holds the runtime lock.
            for _ in range(5):
                sys.modules.pop("diagrams_mbt._native")
                again = importlib.import_module("diagrams_mbt._native")
                assert again is not native
                assert again._runtime_info()["init_count"] == 1
            stop.set()
            worker.join(60)
            assert not worker.is_alive()
            assert native._lock_stats()["max_inside"] == 1
            print("ok", native._runtime_info()["init_count"])
            """
        )
        completed = subprocess.run(
            [sys.executable, "-c", script],
            env=child_env(),
            capture_output=True,
            text=True,
            timeout=DEADLINE * 2,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout.strip(), "ok 1")


class BusyCursorTest(unittest.TestCase):
    def test_same_object_is_busy_while_independent_objects_work(self) -> None:
        shared = _boundary.Exclusive("cursor")
        independent = _boundary.Exclusive("cursor")
        inside = threading.Event()
        release = threading.Event()

        def hold() -> None:
            with shared:
                inside.set()
                diagrams_mbt.render_svg(LONG_SOURCE)
                release.wait(DEADLINE)

        holder = Worker("holder", hold)
        holder.start()
        try:
            self.assertTrue(inside.wait(DEADLINE))
            with self.assertRaises(_boundary.BusyError) as caught:
                with shared:
                    pass
            self.assertEqual(caught.exception.code, "busy")
            with independent:
                self.assertTrue(diagrams_mbt.render_svg(SMALL_SOURCE).ok)
        finally:
            release.set()
            join_all(self, [holder])
        holder.check(self)
        with shared:
            pass


if __name__ == "__main__":
    unittest.main()
