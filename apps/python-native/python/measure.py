"""Bounded repeated-call measurements of the diagrams_mbt Python binding.

Usage: python -P measure.py --fixtures DIR [--batches N] [--calls N]
       [--max-growth-per-call X] [--report] [--warm N] [--cold N]
       [--workload NAME]...

Each batch makes the given number of mixed calls: every fixture in turn and
one refused lone-surrogate call for each fixture. After each batch it prints a
JSON line with the time per call, the Python allocated block count, the
resident set size and, on macOS, the malloc zone statistics of the process.

With --max-growth-per-call, the script fails when the Python block count or
the malloc block count grows by more than X blocks per call between the first
and the last batch. One leaked object per call gives a growth of about 1.

These numbers are observations, not proof of leak freedom. With the default
build MoonBit memory comes from mimalloc, which the malloc zone statistics do
not include. Use the system-allocator build to count MoonBit blocks.

With --report, the script then measures each workload of ``WORKLOADS`` and
prints one JSON line for each:

- ``cold``: the first call in each of --cold fresh processes, and the import;
- ``warm``: --warm repeated calls in this process;
- for each warm call, from the extension's lock instrumentation: the time in
  the runtime lock (``native``), the wait for it (``lock_wait``), the C codec
  time with the GIL held (``c_codec``), the rest of the public call in Python
  (``python``) and all time with the GIL held (``gil_held``), plus the
  request and response record bytes;
- allocation growth (Python blocks, malloc zone, resident size) over the
  warm calls, and the platform, interpreter and allocator.

Distributions are in microseconds: min, p50, p90, p99, max and mean. A
``contention`` row runs the warm calls from two threads at the same time. The
runtime lock serializes them, so it reports the lock wait; it is not a
parallel-speedup measurement. Workloads that will exist later (queries,
visitors, batches) add an entry to ``WORKLOADS`` with the same row format.
"""

from __future__ import annotations

import argparse
import array
import ctypes
import ctypes.util
import gc
import json
import os
import pathlib
import platform
import statistics
import subprocess
import sys
import threading
import time
from typing import Callable, Dict, List

import diagrams_mbt
from diagrams_mbt import _native


class _MallocStatistics(ctypes.Structure):
    _fields_ = [
        ("blocks_in_use", ctypes.c_uint),
        ("size_in_use", ctypes.c_size_t),
        ("max_size_in_use", ctypes.c_size_t),
        ("size_allocated", ctypes.c_size_t),
    ]


class _RusageInfoV0(ctypes.Structure):
    _fields_ = [("uuid", ctypes.c_uint8 * 16)] + [
        (name, ctypes.c_uint64)
        for name in [
            "user_time",
            "system_time",
            "pkg_idle_wkups",
            "interrupt_wkups",
            "pageins",
            "wired_size",
            "resident_size",
            "phys_footprint",
            "proc_start_abstime",
            "proc_exit_abstime",
        ]
    ]


def _libc():
    return ctypes.CDLL(ctypes.util.find_library("c"))


def malloc_stats() -> dict | None:
    if sys.platform != "darwin":
        return None
    stats = _MallocStatistics()
    _libc().malloc_zone_statistics(None, ctypes.byref(stats))
    return {"blocks": stats.blocks_in_use, "bytes": stats.size_in_use}


def memory() -> dict:
    if sys.platform == "darwin":
        info = _RusageInfoV0()
        libproc = ctypes.CDLL(ctypes.util.find_library("proc"))
        if libproc.proc_pid_rusage(os.getpid(), 0, ctypes.byref(info)) == 0:
            return {
                "rss": info.resident_size,
                "footprint": info.phys_footprint,
            }
    statm = pathlib.Path("/proc/self/statm")
    if statm.exists():
        pages = int(statm.read_text().split()[1])
        return {"rss": pages * os.sysconf("SC_PAGE_SIZE")}
    return {}


# A workload is a factory: given the fixture directory it returns a function
# that makes one public call. The functions must give equal work on each call.
Workload = Callable[[pathlib.Path], Callable[[], object]]


def _render_fixture(name: str) -> Workload:
    def factory(fixtures: pathlib.Path) -> Callable[[], object]:
        source = (fixtures / f"{name}.mmd").read_bytes().decode("utf-8")
        return lambda: diagrams_mbt.render_svg(source)

    return factory


def _render_large(fixtures: pathlib.Path) -> Callable[[], object]:
    del fixtures
    source = "flowchart TD\n" + "".join(
        f"  N{i} --> N{i + 1}\n" for i in range(300)
    )
    return lambda: diagrams_mbt.render_svg(source)


def _boundary_noop(fixtures: pathlib.Path) -> Callable[[], object]:
    del fixtures
    from diagrams_mbt import _boundary

    return lambda: _boundary.call("echo")


WORKLOADS: Dict[str, Workload] = {
    "boundary-noop": _boundary_noop,
    "render-flowchart": _render_fixture("flowchart-valid"),
    "render-invalid": _render_fixture("flowchart-invalid"),
    "render-non-bmp": _render_fixture("unicode-non-bmp"),
    "render-large-flowchart": _render_large,
}


def distribution(samples_ns: List[float]) -> dict:
    if not samples_ns:
        return {}
    ordered = sorted(samples_ns)

    def pct(p: float) -> float:
        index = min(len(ordered) - 1, max(0, round(p / 100 * (len(ordered) - 1))))
        return round(ordered[index] / 1000, 1)

    return {
        "min": pct(0),
        "p50": pct(50),
        "p90": pct(90),
        "p99": pct(99),
        "max": pct(100),
        "mean": round(statistics.fmean(ordered) / 1000, 1),
    }


_STAT_KEYS = ("held_ns", "wait_ns", "gil_ns", "bytes_in", "bytes_out", "entries")


def _stats() -> dict:
    s = _native._lock_stats()
    return {k: s[k] for k in _STAT_KEYS}


def measure_warm(call: Callable[[], object], count: int) -> dict:
    call()  # the first call of this workload in this process is not warm
    gc.collect()
    blocks = sys.getallocatedblocks()
    before_memory, before_malloc = memory(), malloc_stats()
    # array("d") stores samples without one Python object per sample, so the
    # block growth shows the calls, not the measurement.
    rows: Dict[str, array.array] = {
        k: array.array("d", bytes(8 * count))
        for k in ("public", "native", "lock_wait", "c_codec", "python", "gil_held")
    }
    bytes_in = bytes_out = entries = 0
    for i in range(count):
        a = _stats()
        t0 = time.perf_counter_ns()
        call()
        t1 = time.perf_counter_ns()
        b = _stats()
        public = t1 - t0
        native = b["held_ns"] - a["held_ns"]
        wait = b["wait_ns"] - a["wait_ns"]
        codec = b["gil_ns"] - a["gil_ns"]
        rows["public"][i] = public
        rows["native"][i] = native
        rows["lock_wait"][i] = wait
        rows["c_codec"][i] = codec
        rows["python"][i] = max(0, public - native - wait - codec)
        rows["gil_held"][i] = max(0, public - native - wait)
        bytes_in += b["bytes_in"] - a["bytes_in"]
        bytes_out += b["bytes_out"] - a["bytes_out"]
        entries += b["entries"] - a["entries"]
    gc.collect()
    after_memory, after_malloc = memory(), malloc_stats()
    # Absolute deltas over the warm calls. A small fixed offset (the first
    # samples, interned values) is normal; the growth batches above give the
    # per-call rate over many more calls.
    growth = {"py_blocks": sys.getallocatedblocks() - blocks}
    if before_malloc and after_malloc:
        growth["malloc_blocks"] = after_malloc["blocks"] - before_malloc["blocks"]
    if "rss" in before_memory and "rss" in after_memory:
        growth["rss_bytes"] = after_memory["rss"] - before_memory["rss"]
    return {
        "calls": count,
        "native_entries_per_call": entries / count,
        "request_bytes_per_call": bytes_in / count,
        "response_bytes_per_call": bytes_out / count,
        "us": {k: distribution(list(v)) for k, v in rows.items()},
        "growth": growth,
    }


_COLD_SCRIPT = """
import json, pathlib, sys, time
t0 = time.perf_counter_ns()
import diagrams_mbt
t1 = time.perf_counter_ns()
from measure import WORKLOADS
call = WORKLOADS[sys.argv[1]](pathlib.Path(sys.argv[2]))
t2 = time.perf_counter_ns()
call()
t3 = time.perf_counter_ns()
print(json.dumps({"import_ns": t1 - t0, "first_ns": t3 - t2}))
"""


def measure_cold(name: str, fixtures: pathlib.Path, runs: int) -> dict:
    imports: List[float] = []
    firsts: List[float] = []
    env = dict(os.environ)
    here = str(pathlib.Path(__file__).resolve().parent)
    env["PYTHONPATH"] = os.pathsep.join(
        [p for p in [env.get("PYTHONPATH"), here] if p]
    )
    for _ in range(runs):
        out = subprocess.run(
            [sys.executable, "-B", "-P", "-c", _COLD_SCRIPT, name, str(fixtures)],
            env=env,
            capture_output=True,
            text=True,
            check=True,
            timeout=300,
        ).stdout
        row = json.loads(out.strip().splitlines()[-1])
        imports.append(row["import_ns"])
        firsts.append(row["first_ns"])
    return {"runs": runs, "import_us": distribution(imports), "first_call_us": distribution(firsts)}


def measure_contention(call: Callable[[], object], count: int) -> dict:
    """Two threads make ``count`` calls each at the same time."""
    a = _native._lock_stats()
    barrier = threading.Barrier(2)

    def body() -> None:
        barrier.wait()
        for _ in range(count):
            call()

    threads = [threading.Thread(target=body) for _ in range(2)]
    t0 = time.perf_counter_ns()
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    elapsed = time.perf_counter_ns() - t0
    b = _native._lock_stats()
    calls = 2 * count
    return {
        "threads": 2,
        "calls": calls,
        "calls_per_s": round(calls / (elapsed / 1e9), 1),
        "contended_fraction": round((b["contended"] - a["contended"]) / calls, 3),
        "lock_wait_us_per_call": round((b["wait_ns"] - a["wait_ns"]) / calls / 1000, 1),
        "native_us_per_call": round((b["held_ns"] - a["held_ns"]) / calls / 1000, 1),
        "max_inside": b["max_inside"],
    }


def environment() -> dict:
    info = _native._runtime_info()
    return {
        "platform": platform.platform(),
        "machine": platform.machine(),
        "python": platform.python_version(),
        "implementation": platform.python_implementation(),
        "allocator": info["allocator"],
        "abi_version": info["abi_version"],
        "module": pathlib.Path(_native.__file__).name,
    }


def report(fixtures: pathlib.Path, names: List[str], warm: int, cold: int) -> None:
    print(json.dumps({"environment": environment()}), flush=True)
    for name in names:
        call = WORKLOADS[name](fixtures)
        row = {"workload": name, "warm": measure_warm(call, warm)}
        if cold > 0:
            row["cold"] = measure_cold(name, fixtures, cold)
        row["contention"] = measure_contention(call, max(1, warm // 4))
        print(json.dumps(row), flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixtures", required=True)
    parser.add_argument("--batches", type=int, default=5)
    parser.add_argument("--calls", type=int, default=2000)
    parser.add_argument("--max-growth-per-call", type=float)
    parser.add_argument("--report", action="store_true")
    parser.add_argument("--warm", type=int, default=400)
    parser.add_argument("--cold", type=int, default=5)
    parser.add_argument("--workload", action="append", choices=sorted(WORKLOADS))
    args = parser.parse_args()

    fixtures = sorted(pathlib.Path(args.fixtures).glob("*.mmd"))
    sources = [p.read_bytes().decode("utf-8") for p in fixtures]
    first = [diagrams_mbt.render_svg(s) for s in sources]

    # array("d") stores floats without one Python object per sample.
    per_fixture = {p.stem: array.array("d") for p in fixtures}
    rows = []
    calls = 0
    for batch in range(args.batches + 1):
        start = time.perf_counter()
        made = 0
        # Batch 0 only takes the baseline.
        while batch > 0 and made < args.calls:
            index = made % len(sources)
            t0 = time.perf_counter()
            result = diagrams_mbt.render_svg(sources[index])
            per_fixture[fixtures[index].stem].append(time.perf_counter() - t0)
            if result != first[index]:
                print(f"mismatch for {fixtures[index].name}", file=sys.stderr)
                return 1
            try:
                diagrams_mbt.render_svg("\ud800")
            except UnicodeEncodeError:
                pass
            made += 1
        elapsed = time.perf_counter() - start
        calls += made
        # Refused calls leave cyclic garbage (exceptions and tracebacks).
        # Collect it, so the block counts show only live objects.
        gc.collect()
        row = {
            "batch": batch,
            "calls": calls,
            "us_per_call": round(elapsed / made * 1e6, 1) if made else None,
            "py_blocks": sys.getallocatedblocks(),
            "memory": memory(),
            "malloc": malloc_stats(),
            "runtime": _native._runtime_info(),
        }
        rows.append(row)
        print(json.dumps(row), flush=True)

    summary = {
        name: {
            "calls": len(times),
            "median_us": round(statistics.median(times) * 1e6, 1),
            "min_us": round(min(times) * 1e6, 1),
        }
        for name, times in per_fixture.items()
        if times
    }
    print(json.dumps({"per_fixture": summary}), flush=True)

    if args.max_growth_per_call is not None and len(rows) > 2:
        first_row, last_row = rows[1], rows[-1]
        span = last_row["calls"] - first_row["calls"]
        growth = {
            "py_blocks": (last_row["py_blocks"] - first_row["py_blocks"]) / span
        }
        if last_row["malloc"] is not None:
            growth["malloc_blocks"] = (
                last_row["malloc"]["blocks"] - first_row["malloc"]["blocks"]
            ) / span
        print(json.dumps({"growth_per_call": growth}), flush=True)
        if any(g > args.max_growth_per_call for g in growth.values()):
            print("growth per call exceeds the limit", file=sys.stderr)
            return 1
    if args.report:
        report(
            pathlib.Path(args.fixtures),
            args.workload or list(WORKLOADS),
            args.warm,
            args.cold,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
