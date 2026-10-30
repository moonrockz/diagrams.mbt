"""Bounded repeated-call measurements for the Python native-binding spike.

Usage: python -P measure.py --fixtures DIR [--batches N] [--calls N]
       [--max-growth-per-call X]

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
import statistics
import sys
import time

import diagrams_native
from diagrams_native import _diagrams_native


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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixtures", required=True)
    parser.add_argument("--batches", type=int, default=5)
    parser.add_argument("--calls", type=int, default=2000)
    parser.add_argument("--max-growth-per-call", type=float)
    args = parser.parse_args()

    fixtures = sorted(pathlib.Path(args.fixtures).glob("*.mmd"))
    sources = [p.read_bytes().decode("utf-8") for p in fixtures]
    first = [diagrams_native.render_svg(s) for s in sources]

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
            result = diagrams_native.render_svg(sources[index])
            per_fixture[fixtures[index].stem].append(time.perf_counter() - t0)
            if result != first[index]:
                print(f"mismatch for {fixtures[index].name}", file=sys.stderr)
                return 1
            try:
                diagrams_native.render_svg("\ud800")
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
            "runtime": _diagrams_native._runtime_info(),
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
    return 0


if __name__ == "__main__":
    sys.exit(main())
