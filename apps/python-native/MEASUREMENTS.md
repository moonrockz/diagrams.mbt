# Measurements: Python binding boundary, queries and traversal

Change: `add-portable-tree-queries-and-python-traversal`, task 7.2 and the
boundary part of 7.3. Date: 2026-10-30. These are measurements on one host.
They are evidence for the binding's cost structure, not performance promises,
and they do not show a parallel speedup. The
[feasibility report](FEASIBILITY.md#runtime-thread-handoff) has the
synchronization audit.

## Environment

| Item | Value |
| --- | --- |
| Host | Apple M5 Max, macOS 26.6.2, arm64 |
| Interpreter | CPython 3.12.16 (mise) |
| MoonBit | `moon 0.1.20261021`, `moonc v0.10.17+093cb8f9c` |
| C compiler | Apple clang 21.0.0 |
| Builds | `default`: the moon archive, mimalloc, `-O2`. `sysalloc`: generated C and runtime with the system allocator, `-O2` |
| Boundary | `ABI_VERSION` 2, `_native.abi3.so` |

## Method

`mise run python-native:measure` runs `apps/python-native/python/measure.py`
with `--report`. The BPMN workloads are in `measure_bpmn.py`.

- **Trees.** Generated BPMN documents: one process with `S` sub-processes,
  each with `T` tasks (`userTask` and `serviceTask` in turn) and `T - 1`
  sequence flows. One task in 100 is named `Approve`. Small is 2 × 5
  (23 tree nodes), medium 10 × 25 (503 nodes), large 50 × 100 (10,003 nodes).
  The document and tree are built once per process and are not timed.
- **Equal work.** All queries project `id`. Pairs that produce the same
  result:
  - `query-selective-b*`, `visitor-selective` (Python checks the kind and
    reads the `name` scalar of each user task) and `native-query-selective`
    find the user tasks named `Approve`;
  - `query-all-b*`, `visitor-fields` and `native-walk-ids` give every node
    ID;
  - `visitor-pruning` and `native-walk-pruned` skip each sub-process body.
- **Native oracle.** `native-*` rows call the bridge operations
  `measure_query` (`QueryPlan::collect` with the same plan and projection) and
  `measure_walk` (`@bpmn.walk`) once, inside the runtime lock, and return
  only counts. Their "native" time is MoonBit work without record conversion
  or Python objects. `native-walk-records` and `native-walk-encoded` also
  build, and build and encode, the node snapshot record that every event,
  visitor callback and capture carries.
- **Timing.** For each warm call the extension's atomics give the time inside
  the runtime lock (native), the wait for it, and the C codec time. "GIL held"
  is public time minus native time and lock wait. Visitors time their own
  callback bodies (`perf_counter_ns`); "public − callbacks" is the native
  advancement, boundary and binding time. The selective visitor's callback
  body includes one native `scalar` call for each user task.
- **Counts.** Native entries are runtime-lock acquisitions per call. Python
  callbacks are the visitor calls the binding made. Response bytes are the
  record bytes the extension decoded.
- **Calls.** Up to 400 warm calls, fewer when one workload would take more
  than 2 s (at least 5). One unmeasured call comes first. Cold is the first
  call in each of 5 fresh processes, after the import and the tree build.
- **Times** are in microseconds.

## Results

### Large tree (10,003 nodes), mimalloc

| Workload | Calls | Public p50 (p99) | Native (in lock) p50 | GIL held p50 | Lock wait p50 | Native entries | Python callbacks | Callback body p50 | Public − callbacks p50 | Response bytes | Items/s at p50 | Cold first call p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `bpmn-large-native-query-selective` | 400 | 503.5 (781.5) | 502.6 | 1.0 | 0.0 | 1 | 0 | 0.0 | 503.5 | 41 | 99,305 | 1,434 |
| `bpmn-large-query-selective-b1` | 400 | 1,480 (1,856) | 1,276 | 200.0 | 0.0 | 53 | 0 | 0.0 | 1,480 | 19,762 | 33,784 | 122,012 |
| `bpmn-large-query-selective-b64` | 400 | 1,299 (1,593) | 1,171 | 127.6 | 0.0 | 4 | 0 | 0.0 | 1,299 | 18,145 | 38,479 | 120,886 |
| `bpmn-large-query-selective-b256` | 400 | 1,300 (1,649) | 1,172 | 128.1 | 0.0 | 4 | 0 | 0.0 | 1,300 | 18,145 | 38,468 | 121,970 |
| `bpmn-large-visitor-selective` | 6 | 311,266 (318,148) | 267,033 | 44,326 | 0.0 | 22,509 | 10,003 | 4,432 | 306,834 | 6,318,605 | 32,136 | 312,260 |
| `bpmn-large-native-query-all` | 344 | 3,212 (4,141) | 3,208 | 2.0 | 0.0 | 1 | 0 | 0.0 | 3,212 | 41 | 3,114,744 | 4,845 |
| `bpmn-large-query-all-b1` | 10 | 190,938 (194,206) | 143,036 | 47,075 | 0.0 | 10,006 | 0 | 0.0 | 190,938 | 4,001,841 | 52,389 | 310,533 |
| `bpmn-large-query-all-b64` | 11 | 172,604 (177,190) | 133,844 | 37,638 | 0.0 | 160 | 0 | 0.0 | 172,604 | 3,676,923 | 57,954 | 289,997 |
| `bpmn-large-query-all-b256` | 11 | 173,185 (177,124) | 135,024 | 37,453 | 0.0 | 43 | 0 | 0.0 | 173,185 | 3,673,062 | 57,759 | 291,609 |
| `bpmn-large-native-walk-ids` | 400 | 1,220 (1,754) | 1,220 | 0.8 | 0.0 | 1 | 0 | 0.0 | 1,220 | 37 | 8,197,165 | 2,708 |
| `bpmn-large-visitor-fields` | 6 | 307,477 (311,054) | 265,049 | 42,429 | 0.0 | 20,009 | 10,003 | 658.6 | 306,816 | 6,209,445 | 32,532 | 306,528 |
| `bpmn-large-native-walk` | 400 | 275.7 (701.1) | 274.9 | 0.7 | 0.0 | 1 | 0 | 0.0 | 275.7 | 37 | 36,282,191 | 749.2 |
| `bpmn-large-native-walk-records` | 15 | 125,113 (129,049) | 125,100 | 14.0 | 0.0 | 1 | 0 | 0.0 | 125,113 | 37 | 79,952 | 124,211 |
| `bpmn-large-native-walk-encoded` | 15 | 129,539 (134,345) | 129,526 | 13.7 | 0.0 | 1 | 0 | 0.0 | 129,539 | 37 | 77,220 | 129,819 |
| `bpmn-large-events-b1` | 6 | 328,812 (341,102) | 272,742 | 55,844 | 0.0 | 20,009 | 0 | 0.0 | 328,812 | 6,649,599 | 60,843 | 326,841 |
| `bpmn-large-events-b64` | 6 | 288,663 (289,406) | 254,947 | 33,635 | 0.0 | 316 | 0 | 0.0 | 288,663 | 5,940,652 | 69,306 | 288,938 |
| `bpmn-large-events-b256` | 6 | 296,158 (298,602) | 254,540 | 41,646 | 0.0 | 82 | 0 | 0.0 | 296,158 | 5,932,228 | 67,552 | 294,784 |
| `bpmn-large-visitor-noop` | 6 | 306,913 (314,830) | 264,142 | 42,528 | 0.0 | 20,009 | 10,003 | 537.2 | 306,380 | 6,209,445 | 32,592 | 306,087 |
| `bpmn-large-visitor-substantive` | 5 | 427,951 (430,944) | 266,049 | 162,522 | 0.0 | 20,009 | 10,003 | 119,065 | 308,885 | 6,209,445 | 23,374 | 424,792 |
| `bpmn-large-native-walk-pruned` | 400 | 2.6 (3.5) | 2.2 | 0.4 | 0.0 | 1 | 0 | 0.0 | 2.6 | 37 | 20,384,615 | 13.1 |
| `bpmn-large-visitor-pruning` | 400 | 1,586 (1,681) | 1,362 | 224.2 | 0.0 | 109 | 53 | 3.5 | 1,583 | 31,825 | 33,407 | 1,708 |

### Medium tree (503 nodes), mimalloc

| Workload | Calls | Public p50 (p99) | Native (in lock) p50 | GIL held p50 | Lock wait p50 | Native entries | Python callbacks | Callback body p50 | Public − callbacks p50 | Response bytes | Items/s at p50 | Cold first call p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `bpmn-medium-native-query-selective` | 400 | 20.5 (21.7) | 19.9 | 0.5 | 0.0 | 1 | 0 | 0.0 | 20.5 | 41 | 146,342 | 54.5 |
| `bpmn-medium-query-selective-b1` | 400 | 81.9 (122.4) | 67.0 | 14.9 | 0.0 | 6 | 0 | 0.0 | 81.9 | 1,258 | 36,630 | 6,100 |
| `bpmn-medium-query-selective-b64` | 400 | 77.2 (108.7) | 65.1 | 12.0 | 0.0 | 4 | 0 | 0.0 | 77.2 | 1,192 | 38,860 | 6,161 |
| `bpmn-medium-query-selective-b256` | 400 | 77.5 (91.7) | 65.2 | 12.2 | 0.0 | 4 | 0 | 0.0 | 77.5 | 1,192 | 38,710 | 6,126 |
| `bpmn-medium-visitor-selective` | 126 | 15,477 (16,002) | 13,222 | 2,253 | 0.0 | 1,139 | 503 | 211.2 | 15,263 | 316,022 | 32,500 | 15,413 |
| `bpmn-medium-native-query-all` | 400 | 118.3 (143.6) | 117.7 | 0.6 | 0.0 | 1 | 0 | 0.0 | 118.3 | 41 | 4,251,902 | 159.6 |
| `bpmn-medium-query-all-b1` | 213 | 8,962 (10,445) | 6,971 | 1,975 | 0.0 | 506 | 0 | 0.0 | 8,962 | 199,781 | 56,129 | 15,344 |
| `bpmn-medium-query-all-b64` | 231 | 8,036 (9,933) | 6,545 | 1,488 | 0.0 | 11 | 0 | 0.0 | 8,036 | 183,446 | 62,595 | 14,574 |
| `bpmn-medium-query-all-b256` | 234 | 8,072 (9,717) | 6,567 | 1,500 | 0.0 | 5 | 0 | 0.0 | 8,072 | 183,248 | 62,316 | 14,551 |
| `bpmn-medium-native-walk-ids` | 400 | 51.2 (54.0) | 50.8 | 0.5 | 0.0 | 1 | 0 | 0.0 | 51.2 | 37 | 9,824,219 | 72.7 |
| `bpmn-medium-visitor-fields` | 127 | 15,261 (15,588) | 13,123 | 2,134 | 0.0 | 1,009 | 503 | 37.3 | 15,224 | 310,485 | 32,959 | 15,280 |
| `bpmn-medium-native-walk` | 400 | 14.7 (16.1) | 14.2 | 0.5 | 0.0 | 1 | 0 | 0.0 | 14.7 | 37 | 34,217,687 | 20.4 |
| `bpmn-medium-native-walk-records` | 312 | 6,127 (6,268) | 6,124 | 2.2 | 0.0 | 1 | 0 | 0.0 | 6,127 | 37 | 82,097 | 6,156 |
| `bpmn-medium-native-walk-encoded` | 298 | 6,364 (6,492) | 6,362 | 2.1 | 0.0 | 1 | 0 | 0.0 | 6,364 | 37 | 79,036 | 6,482 |
| `bpmn-medium-events-b1` | 121 | 16,000 (16,852) | 13,293 | 2,707 | 0.0 | 1,009 | 0 | 0.0 | 16,000 | 332,639 | 62,874 | 16,085 |
| `bpmn-medium-events-b64` | 135 | 14,324 (17,509) | 12,606 | 1,710 | 0.0 | 19 | 0 | 0.0 | 14,324 | 297,000 | 70,233 | 14,976 |
| `bpmn-medium-events-b256` | 132 | 14,576 (16,462) | 12,573 | 1,993 | 0.0 | 7 | 0 | 0.0 | 14,576 | 296,568 | 69,018 | 15,069 |
| `bpmn-medium-visitor-noop` | 125 | 15,289 (15,830) | 13,149 | 2,146 | 0.0 | 1,009 | 503 | 28.3 | 15,261 | 310,485 | 32,900 | 15,280 |
| `bpmn-medium-visitor-substantive` | 93 | 21,024 (25,245) | 13,212 | 7,813 | 0.0 | 1,009 | 503 | 5,644 | 15,376 | 310,485 | 23,926 | 20,927 |
| `bpmn-medium-native-walk-pruned` | 400 | 1.3 (2.3) | 0.9 | 0.4 | 0.0 | 1 | 0 | 0.0 | 1.3 | 37 | 10,000,000 | 4.6 |
| `bpmn-medium-visitor-pruning` | 400 | 317.8 (363.4) | 262.2 | 55.5 | 0.0 | 29 | 13 | 0.8 | 317.0 | 7,425 | 40,906 | 373.9 |

### Small tree (23 nodes), mimalloc

| Workload | Calls | Public p50 (p99) | Native (in lock) p50 | GIL held p50 | Lock wait p50 | Native entries | Python callbacks | Callback body p50 | Public − callbacks p50 | Response bytes | Items/s at p50 | Cold first call p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `bpmn-small-native-query-selective` | 400 | 2.4 (3.4) | 1.9 | 0.4 | 0.0 | 1 | 0 | 0.0 | 2.4 | 41 | 416,667 | 11.2 |
| `bpmn-small-query-selective-b1` | 400 | 25.4 (33.0) | 18.3 | 7.1 | 0.0 | 4 | 0 | 0.0 | 25.4 | 474 | 39,370 | 311.9 |
| `bpmn-small-query-selective-b64` | 400 | 25.2 (29.7) | 18.2 | 7.0 | 0.0 | 4 | 0 | 0.0 | 25.2 | 474 | 39,682 | 316.2 |
| `bpmn-small-query-selective-b256` | 400 | 25.5 (34.2) | 18.5 | 7.0 | 0.0 | 4 | 0 | 0.0 | 25.5 | 474 | 39,216 | 311.7 |
| `bpmn-small-visitor-selective` | 400 | 646.9 (695.7) | 545.8 | 100.8 | 0.0 | 55 | 23 | 9.2 | 637.7 | 13,908 | 35,554 | 697.8 |
| `bpmn-small-native-query-all` | 400 | 6.6 (8.4) | 6.1 | 0.5 | 0.0 | 1 | 0 | 0.0 | 6.6 | 41 | 3,484,848 | 14.4 |
| `bpmn-small-query-all-b1` | 400 | 374.5 (633.5) | 288.9 | 85.3 | 0.0 | 26 | 0 | 0.0 | 374.5 | 8,853 | 61,415 | 705.0 |
| `bpmn-small-query-all-b64` | 400 | 331.0 (386.7) | 271.8 | 58.7 | 0.0 | 4 | 0 | 0.0 | 331.0 | 8,127 | 69,486 | 660.2 |
| `bpmn-small-query-all-b256` | 400 | 329.5 (377.0) | 271.0 | 58.4 | 0.0 | 4 | 0 | 0.0 | 329.5 | 8,127 | 69,803 | 659.2 |
| `bpmn-small-native-walk-ids` | 400 | 3.0 (5.0) | 2.6 | 0.4 | 0.0 | 1 | 0 | 0.0 | 3.0 | 37 | 7,666,667 | 5.9 |
| `bpmn-small-visitor-fields` | 400 | 638.5 (688.6) | 541.5 | 97.0 | 0.0 | 49 | 23 | 1.6 | 637.0 | 13,657 | 36,022 | 688.8 |
| `bpmn-small-native-walk` | 400 | 1.5 (2.5) | 1.1 | 0.4 | 0.0 | 1 | 0 | 0.0 | 1.5 | 37 | 15,333,333 | 4.0 |
| `bpmn-small-native-walk-records` | 400 | 252.1 (268.5) | 251.6 | 0.5 | 0.0 | 1 | 0 | 0.0 | 252.1 | 37 | 91,234 | 258.7 |
| `bpmn-small-native-walk-encoded` | 400 | 263.4 (288.0) | 262.9 | 0.5 | 0.0 | 1 | 0 | 0.0 | 263.4 | 37 | 87,320 | 274.3 |
| `bpmn-small-events-b1` | 400 | 671.0 (736.2) | 548.6 | 122.3 | 0.0 | 49 | 0 | 0.0 | 671.0 | 14,691 | 68,554 | 719.0 |
| `bpmn-small-events-b64` | 400 | 594.2 (675.7) | 517.8 | 76.1 | 0.0 | 4 | 0 | 0.0 | 594.2 | 13,072 | 77,415 | 671.0 |
| `bpmn-small-events-b256` | 400 | 594.0 (649.8) | 517.6 | 76.4 | 0.0 | 4 | 0 | 0.0 | 594.0 | 13,072 | 77,441 | 671.0 |
| `bpmn-small-visitor-noop` | 400 | 639.4 (922.4) | 542.2 | 96.9 | 0.0 | 49 | 23 | 1.3 | 638.2 | 13,657 | 35,971 | 695.5 |
| `bpmn-small-visitor-substantive` | 400 | 897.9 (955.1) | 543.4 | 354.5 | 0.0 | 49 | 23 | 256.9 | 640.7 | 13,657 | 25,615 | 950.2 |
| `bpmn-small-native-walk-pruned` | 400 | 1.1 (1.8) | 0.7 | 0.4 | 0.0 | 1 | 0 | 0.0 | 1.1 | 37 | 4,545,454 | 3.9 |
| `bpmn-small-visitor-pruning` | 400 | 90.5 (101.9) | 69.1 | 21.3 | 0.0 | 13 | 5 | 0.3 | 90.1 | 2,561 | 55,249 | 130.2 |

### Medium tree, system allocator

| Workload | Calls | Public p50 (p99) | Native (in lock) p50 | GIL held p50 | Lock wait p50 | Native entries | Python callbacks | Callback body p50 | Public − callbacks p50 | Response bytes | Items/s at p50 | Cold first call p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `bpmn-medium-native-query-selective` | 400 | 46.5 (83.8) | 46.0 | 0.5 | 0.0 | 1 | 0 | 0.0 | 46.5 | 41 | 64,516 | 83.5 |
| `bpmn-medium-query-selective-b1` | 400 | 118.0 (150.6) | 103.4 | 14.6 | 0.0 | 6 | 0 | 0.0 | 118.0 | 1,258 | 25,424 | 7,436 |
| `bpmn-medium-query-selective-b64` | 400 | 111.5 (135.5) | 99.4 | 12.0 | 0.0 | 4 | 0 | 0.0 | 111.5 | 1,192 | 26,906 | 7,466 |
| `bpmn-medium-query-selective-b256` | 400 | 107.4 (116.0) | 95.6 | 11.8 | 0.0 | 4 | 0 | 0.0 | 107.4 | 1,192 | 27,933 | 9,251 |
| `bpmn-medium-visitor-selective` | 87 | 20,598 (24,012) | 18,277 | 2,235 | 0.0 | 1,139 | 503 | 302.8 | 20,285 | 316,022 | 24,419 | 19,133 |
| `bpmn-medium-native-query-all` | 400 | 312.0 (516.2) | 311.4 | 0.6 | 0.0 | 1 | 0 | 0.0 | 312.0 | 41 | 1,612,180 | 378.3 |
| `bpmn-medium-query-all-b1` | 171 | 11,125 (12,623) | 9,230 | 1,892 | 0.0 | 506 | 0 | 0.0 | 11,125 | 199,781 | 45,214 | 18,827 |
| `bpmn-medium-query-all-b64` | 159 | 10,055 (12,452) | 8,545 | 1,533 | 0.0 | 11 | 0 | 0.0 | 10,055 | 183,446 | 50,023 | 17,687 |
| `bpmn-medium-query-all-b256` | 192 | 10,041 (14,276) | 8,553 | 1,506 | 0.0 | 5 | 0 | 0.0 | 10,041 | 183,248 | 50,097 | 17,376 |
| `bpmn-medium-native-walk-ids` | 400 | 124.5 (139.1) | 124.0 | 0.5 | 0.0 | 1 | 0 | 0.0 | 124.5 | 37 | 4,040,161 | 132.8 |
| `bpmn-medium-visitor-fields` | 95 | 21,169 (22,563) | 18,809 | 2,369 | 0.0 | 1,009 | 503 | 50.6 | 21,120 | 310,485 | 23,761 | 20,549 |
| `bpmn-medium-native-walk` | 400 | 36.7 (39.8) | 36.2 | 0.4 | 0.0 | 1 | 0 | 0.0 | 36.7 | 37 | 13,705,722 | 39.8 |
| `bpmn-medium-native-walk-records` | 254 | 7,744 (8,398) | 7,740 | 2.4 | 0.0 | 1 | 0 | 0.0 | 7,744 | 37 | 64,958 | 7,644 |
| `bpmn-medium-native-walk-encoded` | 241 | 8,197 (8,454) | 8,195 | 2.6 | 0.0 | 1 | 0 | 0.0 | 8,197 | 37 | 61,364 | 8,209 |
| `bpmn-medium-events-b1` | 99 | 19,732 (20,477) | 17,137 | 2,595 | 0.0 | 1,009 | 0 | 0.0 | 19,732 | 332,639 | 50,982 | 19,829 |
| `bpmn-medium-events-b64` | 107 | 21,694 (28,707) | 18,907 | 2,515 | 0.0 | 19 | 0 | 0.0 | 21,694 | 297,000 | 46,373 | 25,438 |
| `bpmn-medium-events-b256` | 90 | 24,650 (28,643) | 20,911 | 3,551 | 0.0 | 7 | 0 | 0.0 | 24,650 | 296,568 | 40,811 | 23,365 |
| `bpmn-medium-visitor-noop` | 86 | 22,425 (24,950) | 19,838 | 2,650 | 0.0 | 1,009 | 503 | 34.1 | 22,393 | 310,485 | 22,430 | 22,159 |
| `bpmn-medium-visitor-substantive` | 80 | 24,753 (27,975) | 17,058 | 7,698 | 0.0 | 1,009 | 503 | 5,696 | 19,047 | 310,485 | 20,321 | 25,096 |
| `bpmn-medium-native-walk-pruned` | 400 | 2.4 (2.7) | 2.0 | 0.4 | 0.0 | 1 | 0 | 0.0 | 2.4 | 37 | 5,416,667 | 6.8 |
| `bpmn-medium-visitor-pruning` | 400 | 399.9 (443.2) | 349.0 | 50.7 | 0.0 | 29 | 13 | 0.8 | 399.0 | 7,425 | 32,508 | 477.2 |

### Rendering, mimalloc

| Workload | Calls | Public p50 (p99) | Native (in lock) p50 | GIL held p50 | Lock wait p50 | Native entries | Python callbacks | Callback body p50 | Public − callbacks p50 | Response bytes | Items/s at p50 | Cold first call p50 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `boundary-noop` | 400 | 0.5 (1.3) | 0.3 | 0.2 | 0.0 | 1 | - | - | - | 19 | - | 23.2 |
| `render-flowchart` | 400 | 1,364 (1,610) | 1,361 | 2.4 | 0.0 | 1 | - | - | - | 11,538 | - | 1,888 |
| `render-invalid` | 400 | 12.8 (14.3) | 11.1 | 1.8 | 0.0 | 1 | - | - | - | 180 | - | 79.6 |
| `render-non-bmp` | 400 | 279.1 (366.7) | 275.7 | 3.3 | 0.0 | 1 | - | - | - | 8,613 | - | 590.2 |
| `render-large-flowchart` | 47 | 42,117 (47,195) | 42,076 | 37.7 | 0.0 | 1 | - | - | - | 385,019 | - | 42,467 |

### Two threads at the same time

Each row runs the same calls from two threads. The runtime lock serializes
them: the lock wait per call is close to the native time per call, and at
most one thread is inside the lock.

| Build | Workload | Calls | Calls/s | Contended fraction | Lock wait per call | Native per call | Max inside |
| --- | --- | --- | --- | --- | --- | --- | --- |
| mimalloc | `boundary-noop` | 200 | 559963.7 | 0.095 | 1.1 | 0.5 | 1 |
| mimalloc | `render-flowchart` | 200 | 701.1 | 0.12 | 1299.3 | 1419.6 | 1 |
| mimalloc | `render-invalid` | 200 | 66181.3 | 0.03 | 9.7 | 12.0 | 1 |
| mimalloc | `render-non-bmp` | 200 | 3401.3 | 0.1 | 168.2 | 288.6 | 1 |
| mimalloc | `render-large-flowchart` | 22 | 23.6 | 0.955 | 40407.7 | 42353.3 | 1 |
| mimalloc | `bpmn-large-query-selective-b256` | 200 | 700.1 | 0.985 | 1232.5 | 1304.5 | 1 |
| mimalloc | `bpmn-large-visitor-noop` | 2 | 2.9 | 356.0 | 325011.0 | 277697.3 | 1 |
| system | `boundary-noop` | 200 | 459725.7 | 0.12 | 1.3 | 0.7 | 1 |
| system | `render-flowchart` | 200 | 326.8 | 0.245 | 2480.6 | 3052.5 | 1 |
| system | `render-invalid` | 200 | 43754.1 | 0.015 | 11.9 | 19.8 | 1 |
| system | `render-non-bmp` | 200 | 1871.2 | 0.185 | 456.3 | 527.9 | 1 |
| system | `render-large-flowchart` | 8 | 8.5 | 0.875 | 102147.9 | 118060.3 | 1 |

### Allocation growth

Over the warm calls of every row, the Python block count changed by −20 to
125 blocks and the malloc zone by 0 to 9 blocks, for 5 calls as for 400. This is
a fixed offset of the measurement, not growth per call. The growth batches
(8,000 mixed render calls) give 0.0114 Python blocks and 0.000125 malloc
blocks per call on both builds, and `leaks` reports 0 leaks at baseline and
after 4,000 calls (system allocator). Resident size rose by at most 3.7 MB
during the large match-all rows (4 MB responses), and by 0 for the other
large BPMN rows.

## Findings (measured on this host)

1. **Selective queries call no Python code for each candidate.** On the large
   tree the selective query makes 0 Python callbacks and 4 native entries with
   batch 64 or 256, and takes 1.30 ms at p50 (native oracle: 0.50 ms). The
   equal-work Python visitor makes 10,003 callbacks and 22,509 native entries
   and takes 311 ms.
2. **The node snapshot record dominates traversal and capture cost.** The
   native walk of the large tree takes 0.28 ms; building every node record
   takes 125 ms; encoding adds 4.4 ms. A temporary split of the record fields
   (medium tree, 20 runs) gave 11.8 µs per node for `@bpmn.NodeRef::category`
   and 0.04 to 0.11 µs for each other field. So the match-all query
   (135 ms native for 10,003 captures), events and visitors spend most of
   their native time in `category()`, not in matching, walking or the
   boundary.
3. **Opening a query view costs the same per node.** The first query of a
   tree opens its index: 6.3 ms (medium) and 119 ms (large), all inside the
   runtime lock. That is the cold first-call cost of the query rows (122 ms
   against 1.3 ms warm on the large tree).
4. **Batch size.** On the large tree, batch 1 against 256 gives 191 ms against
   173 ms for match-all (10,006 against 43 native entries) and 329 ms against
   296 ms for events. 64 and 256 are equal within noise.
5. **Callbacks are separate from advancement.** The substantive visitor
   (64 SHA-256 rounds per node) spends 119 ms in callback bodies and 309 ms in
   advancement, against 0.5 ms and 306 ms for the no-op visitor. The time
   inside the runtime lock is the same in all large visitor rows (264 to
   267 ms).
6. **GIL.** In the large visitor rows the GIL is held for 42 to 44 ms of
   307 to 311 ms; the rest (native work) runs without it. With substantive
   callbacks the GIL is held for 163 ms, because the callbacks are Python.
7. **Allocator.** On the medium tree the native time with the system
   allocator is 1.26 to 2.65 times the mimalloc time for the same rows.

Not claimed: a speedup on other hosts, a parallel native speedup (two
threads give the same total throughput or less), or a result for other
document shapes. Visitor and query costs fall if `NodeRef::category` gets
cheaper; that change is outside this measurement.

## Reproduce

```shell
mise run python-native:measure
# One group only, for example the large tree:
PYTHONPATH=_build/python-native/default mise exec python@3.12.16 -- \
  python -P apps/python-native/python/measure.py --fixtures apps/python-native/fixtures \
  --batches 0 --report --workload bpmn-large
```
