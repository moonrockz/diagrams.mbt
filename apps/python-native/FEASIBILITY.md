# Feasibility report: Python in-process binding over the MoonBit native backend

Change: `prove-python-native-binding`. Date: 2026-10-29. Host: macOS 26.6.2,
arm64, Apple clang 21.0.0. The change `publish-python-package` later renamed the
package to `diagrams_mbt` and the extension to `diagrams_mbt._native`; this
report uses the current names. See [Cross-build update](#cross-build-update).

## Result

**Feasible, with conditions.** CPython 3.12 and 3.15 call the existing
`@mermaid.render_svg` in the same process through code that the MoonBit C
backend generates. One Limited API extension file (`.abi3.so`) loads in both
versions. For each of the 10 fixtures, the output and the diagnostics equal the
direct output of a native MoonBit program. The AddressSanitizer and
UndefinedBehaviorSanitizer build reports no error. After an ownership fix, the
`leaks` tool reports 0 leaks after 4,000 renders.

The conditions are in [Limits](#limits) and [Risks](#deployment-and-abi-risks).
The most important ones: a MoonBit panic stops the Python process, the
calling convention of exported functions is not documented, and only macOS
arm64 was verified.

## Toolchain

| Item | Value |
| --- | --- |
| MoonBit | `moon 0.1.20261021`, `moonc v0.10.17+093cb8f9c` (pinned in `.config/mise/config.toml`) |
| CPython | 3.12.16 and 3.15.2, the latest patch releases of the oldest Limited API target and of the newest stable line (mise), selected by the spike tasks only |
| C compiler | Apple clang 21.0.0, arm64 |

## Linkage and runtime approach

The stable MoonBit pages say: "The native backend does not currently support
exporting a `foreign_library` package as a linkable library artifact, including
shared libraries such as a `.dll` or `.so`." ([FFI][ffi], [package][pkg])

The pinned toolchain gives this, as a probe module and this spike show:

- A native package with `pkgtype(kind: "foreign_library")` builds into a
  **static archive** (`ffi.a`). There is no shared library and no `main`.
- In release mode, `moonc link-core` writes C (the C backend, `ffi.c`, 50 MB,
  925,111 lines for this spike). Then `cc -c` compiles it, and `libtool -static`
  puts it into the archive with mimalloc (`libmoonbitrun.o`), the runtime
  objects and simdutf. Debug mode uses the new native backend, which writes an
  object file directly. The spike uses release mode only.
- Each `#export_name` function becomes a plain C wrapper with that name. The
  generated C also defines `void moonbit_init(void)`. It calls
  `moonbit_runtime_init(0, 0)`, sets the layout table and initializes the
  top-level values. The pinned `moonbit.h` declares `moonbit_init` for hosts of
  a compiled library, and calls itself a "very unstable API".
- The bundled mimalloc does not define `malloc` or `free`. It does not replace
  the allocator of the Python process.

Thus the documented gap is a **shared** library. A CPython extension is a
shared library that we link ourselves, so the static archive is sufficient.
No compiler flag or patch of generated code was necessary. Two link paths work:

1. **Archive (default build).** Link the adapter object and `ffi.a` with
   `-bundle -undefined dynamic_lookup` and export only
   `PyInit__native`. The module imports only `libSystem`.
2. **Generated C and runtime sources (sanitizer and system-allocator builds).**
   Compile `ffi.c` and five runtime files (`runtime.c`, `env.c`, `utf.c`,
   `stdio.c`, `backtrace.c`) with our own flags, and link the precompiled
   simdutf objects. This path depends on file names in `_build` and in the
   toolchain, so it is only for diagnostics.

The build task checks that each linked module exports only its initialization
function and imports no process, socket or thread-creation function (`fork`,
`posix_spawn`, `exec*`, `system`, `popen`, `socket`, `connect`,
`pthread_create`). The module cannot start a child process.

## Boundary, ownership and initialization

- **Boundary.** (Spike state, boundary version 1. Version 2 replaced the
  render export with `diagrams_py_call`, which takes and returns binary
  records; see [Runtime thread handoff](#runtime-thread-handoff).) Two exports:
  `int32_t diagrams_py_abi_version(void)` and
  `moonbit_bytes_t diagrams_py_render_svg(moonbit_bytes_t)`. UTF-8 source goes
  in, and UTF-8 JSON (format 1: media type, output, diagnostics) comes out.
  The FFI page gives `Bytes` a stable mapping to `uint8_t*`. Python does not
  see MoonBit structs, enums, strings or mangled names. The adapter refuses
  another boundary version with `ImportError` (tested with a build that
  expects version 0).
- **Ownership — finding.** The FFI page says that MoonBit "uses an owned
  calling convention" by default, but it describes `extern "C"` imports. It
  does not state the convention for `#export_name` functions. A C probe on the
  pinned compiler shows that the export **borrows** its `Bytes` argument: the
  reference count is 2, not 1, after the call when the caller holds one extra
  reference. The first adapter followed the owned convention and leaked each
  input: `leaks` reported 4,005 leaks (307,808 bytes) after 4,000 renders. The
  adapter now releases the input and the result, each one time. A change of
  the convention would show as a double free in the sanitizer build or as
  growth in the measurement task.
- **Copies.** The Python `str` owns its UTF-8 buffer. The adapter copies it
  into a new MoonBit `Bytes` and copies the result into a new `str`. No Python
  object points into MoonBit memory after a call. Text with a lone surrogate
  raises `UnicodeEncodeError` before MoonBit is called (tested with a call
  counter).
- **Initialization.** The module exec slot calls `moonbit_init` one time for
  each process. A second import makes a new module object but does not
  initialize the runtime again (tested). MoonBit has no shutdown function, so
  the runtime and its top-level values stay until the process stops.
- **Concurrency.** (Spike state; see [Runtime thread handoff](#runtime-thread-handoff)
  for the current design.) The adapter held the GIL during a render, so calls
  were serialized. The runtime has process-global state, for example the cycle
  collector buffer. The module declares
  `Py_MOD_MULTIPLE_INTERPRETERS_NOT_SUPPORTED`; an isolated 3.15 subinterpreter
  gets `ImportError` (tested). The source sets `Py_MOD_GIL_USED` only when the
  headers define `Py_mod_gil`; the 3.12 Limited API headers do not, so the
  current build has no such slot. We make no claim about threads,
  free-threaded builds or subinterpreters.
- **Diagnostics.** Each diagnostic has code, severity, message and an optional
  span. Lines and columns start at 1. **Columns and offsets count UTF-16 code
  units**, as MoonBit strings do. `diagrams_mbt.code_point_index` converts an
  offset to a Python index (tested with an emoji before the error).

## Results

| Check | Command | Result |
| --- | --- | --- |
| Bridge package on wasm, wasm-gc, js and native | `mise run check` | 4 tests pass on each target |
| Parity, behavior and lifetime tests, CPython 3.12.16 | `mise run test:python-native` | 13 pass, 1 skipped (subinterpreter test needs 3.14) |
| Same tests, CPython 3.15.2, same `.abi3.so` | `mise run test:python-native` | 14 pass |
| ASan + UBSan, 200 mixed rounds (2,000 renders and 2,000 refused calls) per interpreter | `mise run test:python-native-sanitize` | No sanitizer report; tests pass on 3.12 and 3.15 |
| `leaks --atExit`, system-allocator build | `mise run python-native:measure` | 0 leaks at baseline, 0 leaks after 4,000 renders |
| Growth per call, batches 1 to 5 (8,000 calls) | `mise run python-native:measure` | Python blocks 0.0105; malloc blocks 0.000125 (system allocator) |

The fixtures are valid flowchart, sequence and state diagrams, invalid
flowchart, sequence and Unicode sources, an unsupported `pie` diagram, empty
input, whitespace only, and labels with U+1F680, U+1D518, U+10348, CJK and
`café`. Valid output can also have a warning (`flowchart/plain-text-label`).

Bounded measurements (CPython 3.12.16, 5 batches of 2,000 mixed calls, each
call also makes one refused call):

| Build | µs per mixed call | RSS after batch 1 → 5 | Median, valid flowchart | Median, invalid input |
| --- | --- | --- | --- | --- |
| Archive, mimalloc | 255–267 | 38.7 MB → 39.2 MB | 1,406 µs | 15–17 µs |
| Sources, system allocator | 503–514 | 37.6 MB → 38.1 MB | 2,967 µs | 24–27 µs |

The import of the extension, with `moonbit_init`, took 0.7 ms on CPython
3.15.2 with a warm file cache (`-X importtime`); a first cold import took 4.5 ms. The default module is 9.4 MB (7.8 MB with `strip -x`).

## Limits

- The tasks test CPython 3.12.16 and 3.15.2. CPython recommends tests with
  each supported minor version; 3.13 and 3.14 are not in the task matrix.
- Only macOS arm64 was verified. The task has Linux link arguments
  (`-shared -Wl,--exclude-libs,ALL`), but nobody ran them. Windows was not tried.
- LeakSanitizer is not available on this platform: ASan prints "detect_leaks is
  not supported on this platform". The leak evidence is from the macOS `leaks`
  tool and malloc zone counts on the system-allocator build. The default build
  uses mimalloc, which these counts do not see; for it we only have RSS, which
  does not prove that there is no leak.
- The sanitizer runtime does not instrument the precompiled `simdutf.o`,
  `moonbit_simdutf.o` or `libmoonbitrun.o`, nor CPython itself.
- Ten fixtures do not cover the renderer. The spike tests the boundary, not
  the renderer. Large inputs, limits and other diagram families were not tested.
- Only the default renderer options are exposed. Options would need a new
  boundary version.
- A MoonBit panic calls `abort()` (`backtrace.c`). It stops the Python process,
  and the adapter cannot catch it. The fixtures did not cause a panic.

## Deployment and ABI risks

| Risk | Note |
| --- | --- |
| Unstable runtime interface | The adapter uses `moonbit_init`, `moonbit_make_bytes_raw`, `moonbit_decref` and `Moonbit_array_length` from a header that calls itself "very unstable". Keep the toolchain pinned and the boundary versioned. |
| Undocumented export convention | Measured, not documented. Ask upstream to document it, or add `#borrow`/`#owned` support for exports. |
| Process abort on panic | A production design needs an upstream panic hook or a process boundary for untrusted input. |
| One runtime per extension | Each MoonBit extension links its own runtime and mimalloc. Only the module initialization symbol is exported, which lowers the risk of a symbol clash. Two runtimes in one process were not tested. |
| No `-fPIC` from moon | Moon compiles archive objects without `-fPIC`. macOS arm64 code is position-independent; Linux shared objects can need `-fPIC`, which path 2 can add. |
| Archive content | `ffi.a` depends on the toolchain layout (mimalloc, simdutf, runtime objects). A toolchain update can change it. |
| Size | About 9.4 MB for one module; the whole renderer is linked. |
| Stable ABI scope | The Limited API 3.12 build (`abi3`) loads in 3.12 and 3.15 (and loaded in 3.14.7 during development). CPython says `abi3` is for non-free-threaded builds; free-threaded builds need `abi3t`, which starts in 3.15. The spike did not build `abi3t`. The CPython docs also recommend tests with each supported minor version. ([stable ABI][abi]) |

## Fallback

The native path was not blocked, so the spike uses no fallback. If a future
toolchain removes the static archive or `moonbit_init`, first try path 2
(compile the generated C and runtime sources). A separate process that runs a
MoonBit native executable is the fallback for untrusted input or panics. It is
not in-process and must be reported as a different design.

## Next steps

1. Ask MoonBit upstream to document the export calling convention,
   `moonbit_init`, the archive output and a panic policy for embedders.
2. Run the same task on Linux x86_64 and arm64 in CI and fix `-fPIC` if needed.
3. Decide the production boundary: keep JSON, or add typed results for each
   diagram family and renderer options under a new boundary version.
4. Build wheels with one `abi3` file for each platform. Add an `abi3t` build
   (CPython 3.15 and later) only if free-threaded support is required; it
   needs a thread-safety design for the runtime first.
5. Add input limits and a corpus run to bound time and memory for each call.

## Cross-build update

The change `publish-python-package` builds all wheels on one host with zig
0.17.0. It does not use the moon archive, which holds precompiled host objects.
It compiles `ffi.c`, `runtime.c`, `env.c`, `utf.c`, `stdio.c`, `backtrace.c`,
the adapter and mimalloc 2.1.7 for each target. The pinned MoonBit runtime
reports `mi_version()` 217, so that is the same mimalloc version. Without
`MOONBIT_USE_SIMDUTF`, `utf.c` uses its scalar code.

| Build (macOS arm64, CPython 3.15.2) | Valid flowchart, median |
| --- | --- |
| moon archive (mimalloc and simdutf) | 1,430 µs |
| zig, pinned mimalloc, scalar UTF-8 | 1,416 µs |
| zig, system allocator, scalar UTF-8 | 2,884 µs |

So mimalloc gives the speed, and simdutf gives no measurable gain at this
boundary. `moonrockz/zig-cross exec` was not usable: with a custom compiler,
moon also compiles `dir.c`, which fails for Linux (`NAME_MAX`).

Local results of the cross-built wheels: macOS arm64 (3.12.16, 3.15.2) and
macOS x86_64 under Rosetta (3.12.16) pass the tests; Linux x86_64 and aarch64
pass in Docker (3.12, 3.15), and `auditwheel` reports `manylinux_2_17`. All
wheels pass `twine check --strict`. The Windows module imports only
`python3.dll`, the Universal CRT, `ADVAPI32` and `KERNEL32`. It also exports the
runtime functions that `moonbit.h` marks `dllexport` on Windows; Windows binds
each import to a named DLL, so these exports cause no conflict. CI runs the
tests on native runners for all five wheels.

## Runtime thread handoff

Change: `add-portable-tree-queries-and-python-traversal`, task 1.2 and group 5.
Date: 2026-10-30. Host: macOS 26.6.2, arm64, Apple clang 21.0.0, the same
pinned MoonBit toolchain. This section replaces the statement above that the
adapter holds the GIL during a call.

### Design under test

Every MoonBit entry (initialization, `diagrams_py_call`, the counters) runs
inside one process-wide runtime lock (`pthread_mutex_t`, `SRWLOCK` on
Windows). A call encodes its arguments into a malloc buffer with the GIL held,
detaches (`Py_BEGIN_ALLOW_THREADS`), waits for the lock, runs MoonBit, copies
the response into a second malloc buffer, releases both MoonBit values,
releases the lock and only then attaches again. No Python API runs while the
thread is detached or holds the lock. There is no owner thread.

### Audit of the pinned runtime (source evidence)

Sources: `lib/runtime/runtime.c`, `env.c`, `backtrace.c`,
`include/moonbit_runtime.h` under `mise where http:moonbit`, the generated
`ffi.c`, and mimalloc 2.1.7 (`src/page.c`, `src/heap.c`, `src/init.c`,
`src/prim/unix/prim.c`; archive SHA-256 as in `scripts/python-wheels.mbtx`).

| Finding | Evidence | Consequence |
| --- | --- | --- |
| No thread-local state, no thread identity | No `_Thread_local`, `__thread` or `pthread_self` in the runtime files, the headers or the generated `ffi.c` | The runtime can move between threads when entries are serialized. |
| Process-global state | `moonbit_cycle` and `moonbit_deferred` root lists in `runtime.c`; top-level values from `moonbit_init` | Every entry needs the lock. |
| Non-atomic reference counts | `MOONBIT_INC_RC_CNT` / `Moonbit_increase_rc_count` are plain `+=` | The lock (acquire/release) gives the happens-before order between threads. |
| mimalloc is thread-safe, with cross-thread frees | mimalloc design; heaps are per thread, frees from other threads use atomic lists | Values allocated on one thread and released on another are safe. |
| mimalloc calls a registered deferred-free function from allocation slow paths, with `force` on heap abandon at thread exit (`mi_thread_done` → `_mi_heap_collect_abandon`) and at process exit (`mi_process_done` → `mi_collect(true)`) | `page.c` `_mi_deferred_free`; `heap.c` `mi_heap_collect_ex`; `init.c` | The callback can run on a thread that does not hold the lock. |
| The runtime's callback runs `moonbit_collect_cycles()` | `runtime.c` `moonbit_mimalloc_deferred_free`, registered by `moonbit_allocator_init` from `moonbit_runtime_init` | Off-lock cycle collection would race with a locked call. |
| That registration exists only with `MOONBIT_TRIAL_DELETION` | `moonbit_runtime.h` defaults it to 0; `moon build --dry-run` passes no such flag; `runtime-runtime.o` has no reference to `mi_register_deferred_free` | **With the pinned toolchain the hazard is latent**: the runtime registers no callback and never collects cycles. A toolchain that enables trial deletion would make it real. |
| System-allocator builds collect only in `moonbit_malloc` | `runtime.c` and the inlined `moonbit_malloc_inlined` | They collect only during MoonBit work, which runs under the lock. |

### Fix

In mimalloc builds (`DIAGRAMS_PY_MIMALLOC=1`: the moon archive and all
wheels) the adapter calls `mi_register_deferred_free(guarded_deferred_free)`
right after `moonbit_init()`, inside the lock. This replaces any callback that
the runtime registered. The guard reads a `_Thread_local` flag that is set
right after the lock is taken and cleared right before it is released. On the
holding thread it collects with the runtime's own trigger (`force` or
`moonbit_cycle_collection_threshold()`); on any other thread it returns at
once, and the buffered roots stay for the next collection under the lock.
Builds must define `DIAGRAMS_PY_MIMALLOC`; the adapter does not compile
without it.

### Results (measured)

| Check | Command or setup | Result |
| --- | --- | --- |
| Thread tests (serial entry, GIL progress during a native call, third thread runs while one caller holds the lock and another waits, mixed-load deadline, finalizers that call native code under contention, 200 short-lived threads, concurrent imports, busy guard) | `mise run test:python-native` | 37 tests pass on CPython 3.12.16 (1 skipped: subinterpreters need 3.14) and 3.15.2 (none skipped); the thread tests take about 6 s |
| Same tests, ASan + UBSan, system allocator | `mise run test:python-native-sanitize` | 37 tests pass on 3.12 (2 skipped) and 3.15 (1 skipped; no bad-ABI build in this task), no sanitizer report |
| Maximum threads inside the lock | `_lock_stats()["max_inside"]` after every thread test | 1 |
| Thread exit reaches the callback off the lock | 50 threads that render and exit (default build) | `deferred_skipped` 50; `deferred_locked` 50,200; `deferred_collected` 0 (trial deletion off) |
| Guard with trial deletion on, mimalloc, ASan + UBSan | Manual build: generated C and runtime with `-DMOONBIT_TRIAL_DELETION=1 -DMOONBIT_ALLOCATOR=MOONBIT_ALLOCATOR_MIMALLOC`, mimalloc 2.1.7 `static.c`, sanitizers; 60 s of 16-thread groups that render and exit while one thread renders a large flowchart | 1,360 short threads, all results equal; 11 collections under the lock; 1,361 off-lock callbacks skipped; no sanitizer report |
| Same, unguarded (runtime callback left in place) | Same build with `DIAGRAMS_PY_MIMALLOC=0` | No failure in 60 s. The race window is small; this is **not** evidence that the unguarded build is safe. |
| Linux wheels with the thread tests | Docker `python:3.12-slim` and `python:3.15-slim` (3.12.16, 3.15.2), aarch64 native and x86_64 emulated | 37 tests pass in each of the four runs (bad-ABI test skipped, and the subinterpreter test on 3.12) |
| macOS wheels | arm64 natively (3.12.16, 3.15.2); x86_64 under Rosetta (python-build-standalone 3.12.16) | 37 tests pass in each run; `twine check --strict` passes for all five wheels |
| Windows wheel | Not run locally. Imports are the same DLL set as the 0.0.1 wheel (`python3.dll`, UCRT, `KERNEL32`, `ADVAPI32`); the lock uses `SRWLOCK` | CI must run the tests |

A dedicated owner thread was not needed: no evidence showed that serialized
handoff between threads is unsafe on the pinned runtime.

### Measured boundary and latency (macOS arm64, CPython 3.12.16)

`mise run python-native:measure`, 400 warm calls for each workload, 5 cold
processes. Times are microseconds, p50 (p99). `native` is the time inside the
runtime lock; `GIL held` is the public call time minus native time and lock
wait. These are single-thread measurements; there is no parallel speedup.

| Workload | Build | Public call | Native | GIL held | Response bytes | Cold first call |
| --- | --- | --- | --- | --- | --- | --- |
| no-op `echo` | mimalloc | 0.8 (2.8) | 0.4 | 0.3 | 19 | 15 |
| flowchart-valid | mimalloc | 1,821 (3,432) | 1,808 | 10.5 | 11,538 | 2,173 |
| flowchart-invalid | mimalloc | 13.3 (17.7) | 11.5 | 1.8 | 180 | 69 |
| unicode-non-bmp | mimalloc | 301 (415) | 297 | 3.9 | 8,613 | 674 |
| 300-edge flowchart | mimalloc | 52,031 (72,033) | 51,987 | 42.9 | 385,019 | 44,924 |
| flowchart-valid | system | 3,095 (4,358) | 3,091 | 5.5 | 11,538 | 3,557 |
| 300-edge flowchart | system | 118,727 (152,734) | 118,686 | 41.4 | 385,019 | 112,730 |

With two threads that call at the same time, the lock wait per call is about
the native time per call (flowchart-valid: 1,503 µs wait, 1,696 µs native),
and `max_inside` stays 1. Over 8,000 calls the growth is 0.0115 Python blocks
and 0.000125 malloc blocks per call (system allocator); `leaks` reports 0
leaks at baseline and after 4,000 calls.

Old JSON transport against the new record transport, same renderer (base
commit `fec214a` built the same way), same host, three interleaved runs of 400
calls (40 for the large flowchart), public-call p50 in µs:

| Fixture | JSON (base) | Records (this change) |
| --- | --- | --- |
| flowchart-invalid | 15.9, 20.4, 20.7 | 13.0, 13.1, 15.3 |
| unicode-non-bmp | 368, 378, 366 | 285, 291, 304 |
| sequence-valid | 259, 265, 305 | 241, 258, 258 |
| flowchart-valid | 1,734, 1,511, 1,572 | 1,397, 1,599, 1,841 |
| 300-edge flowchart | 43,918, 52,093, 67,372 | 44,490, 45,888, 45,569 |

Only the invalid and non-BMP rows differ by more than the run-to-run spread.
For the other rows the difference is inside the noise of this host, so this
report claims no speedup for them.

### Assumed, not measured

- Windows behavior of the lock and the GIL release (CI runs the tests).
- Lock fairness. The lock is not fair; the tests bound waits with deadlines
  only. One thread can wait for several calls of other threads.
- That a future toolchain keeps the export ownership convention and the
  `moonbit_cycle_collection_threshold` / `moonbit_collect_cycles` exports.
  The link check now also fails on an unresolved `mi_` symbol.

## Reproduce

```shell
mise run clean
mise run test:python-native
mise run test:python-native-sanitize
mise run python-native:measure
mise run python-native:wheels
```

The trial-deletion experiment in [Runtime thread handoff](#runtime-thread-handoff)
is manual: compile `_build/native/release/build/moonrockz/diagrams-python-native/ffi/ffi.c`
and the five runtime files with the `sanitize` flags of
`scripts/python-native.mbtx` plus `-DMOONBIT_TRIAL_DELETION=1
-DMOONBIT_ALLOCATOR=MOONBIT_ALLOCATOR_MIMALLOC`, add mimalloc 2.1.7
`src/static.c`, compile the adapter with `-DDIAGRAMS_PY_MIMALLOC=1` (guarded) or
`0` (unguarded), and run a thread that renders while groups of short-lived
threads render and exit.

## Sources

- MoonBit FFI: <https://docs.moonbitlang.com/en/stable/language/ffi.html> ([ffi])
- MoonBit package configuration: <https://docs.moonbitlang.com/en/stable/toolchain/moon/package.html> ([pkg])
- Extending and embedding Python: <https://docs.python.org/3/extending/index.html>
- C API stability: <https://docs.python.org/3/c-api/stable.html> ([abi])
- Module objects and slots: <https://docs.python.org/3/c-api/module.html>
- Pinned toolchain sources: `include/moonbit.h`, `lib/runtime/runtime.c`,
  `env.c` and `backtrace.c` under `mise where http:moonbit`.

[ffi]: https://docs.moonbitlang.com/en/stable/language/ffi.html
[pkg]: https://docs.moonbitlang.com/en/stable/toolchain/moon/package.html
[abi]: https://docs.python.org/3/c-api/stable.html
