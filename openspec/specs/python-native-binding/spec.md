# python-native-binding Specification

## Purpose
Lets Python code render Mermaid source to SVG in the same process through the
MoonBit native backend, with structured diagnostics. This capability is
experimental. It is not a stable Python API.

## Requirements

### Requirement: In-process rendering through the native backend

The Python adapter SHALL render Mermaid source through the existing MoonBit
`render_svg` function of `moonrockz/diagrams-mermaid`, compiled by the MoonBit
native C backend and linked into a CPython extension module. The adapter MUST
NOT start a child process and MUST NOT use a WebAssembly or JavaScript build of
the renderer.

#### Scenario: Valid source renders in the calling process

- **WHEN** Python calls `render_svg` with a valid Mermaid flowchart
- **THEN** the result contains SVG text and no error diagnostic
- **AND** no child process starts during the call

#### Scenario: Output equals the direct MoonBit output

- **WHEN** Python calls `render_svg` with each shared fixture
- **THEN** the SVG text equals the UTF-8 text that a native MoonBit program writes
  for the same fixture with `render_svg` and the default renderer
- **AND** the media type is `image/svg+xml`

### Requirement: Structured diagnostics for malformed input

The Python adapter SHALL return the diagnostics of the MoonBit renderer as Python
values. Each diagnostic SHALL have its code, severity, message and optional span.
A span SHALL have a start and an end position with line, column and offset. The
adapter MUST NOT raise an exception for a diagnostic that the renderer returns.

#### Scenario: Invalid syntax gives diagnostics and no SVG

- **WHEN** Python calls `render_svg` with Mermaid source that has a syntax error
- **THEN** the result has no SVG text
- **AND** the result has at least one diagnostic with severity `error`
- **AND** the code, severity, message and span of each diagnostic equal the values
  that the native MoonBit program writes for the same fixture

#### Scenario: Empty input gives the direct result

- **WHEN** Python calls `render_svg` with an empty string
- **THEN** the output and the diagnostics equal the direct MoonBit result for an
  empty source

### Requirement: Unicode text at the boundary

The adapter SHALL send source text to MoonBit as UTF-8 and SHALL decode the
result from UTF-8. Text outside the Basic Multilingual Plane SHALL keep its value
in both directions. The adapter SHALL state the unit of diagnostic columns and
offsets.

#### Scenario: Non-BMP labels keep their value

- **WHEN** Python calls `render_svg` with a flowchart label that contains a
  character above U+FFFF
- **THEN** the SVG text contains the same character
- **AND** the SVG text equals the direct MoonBit output

#### Scenario: Text that is not valid Unicode is refused before the call

- **WHEN** Python calls `render_svg` with a string that contains a lone surrogate
- **THEN** the adapter raises `UnicodeEncodeError`
- **AND** the adapter does not call the MoonBit renderer

### Requirement: Runtime initialization and ownership

The adapter SHALL initialize the MoonBit runtime once per process before use, preserve owned input and output lifetimes, and release received MoonBit values. A native lock SHALL serialize all runtime access. Native computation and lock waits SHALL release the GIL; Python object access SHALL hold it. User callbacks SHALL run outside the runtime lock. Multiple interpreters SHALL remain unsupported.

#### Scenario: Repeated mixed calls give stable results

- **WHEN** Python calls `render_svg` many times with valid, invalid, empty and non-BMP fixtures in alternation
- **THEN** each result equals the first result for the same fixture

#### Scenario: Sanitizer build finds no memory errors

- **WHEN** the sanitizer build of the extension runs the repeated mixed calls
- **THEN** AddressSanitizer and UndefinedBehaviorSanitizer report no error

#### Scenario: Incompatible boundary version is refused

- **WHEN** the extension loads a MoonBit library with a different boundary version
- **THEN** the import fails with `ImportError`

#### Scenario: Native work permits Python progress

- **WHEN** one thread performs a controlled long native render or query and another runs Python code
- **THEN** the second thread makes observable progress during the native computation, not only before or after the call

#### Scenario: A waiting caller does not block Python

- **WHEN** one native call owns the runtime lock and a second Python thread waits to make a native call
- **THEN** a third Python thread can run while the second waits
- **AND** repeated runs complete within a test deadline without overlapping runtime entry

#### Scenario: Initialization and cleanup are serialized

- **WHEN** different threads import, execute and release query or traversal owners
- **THEN** runtime initialization occurs once and runtime allocation, cleanup and diagnostic-counter access obey the same synchronization policy

### Requirement: Reproducible spike build

The repository SHALL build and test the Python extension from a clean tree with
one mise task. The task SHALL use the pinned MoonBit toolchain and a pinned
CPython version. The extension module SHALL export only its CPython module
initialization symbol.

#### Scenario: Clean build and test

- **WHEN** a developer runs `mise run clean` and then `mise run test:python-native`
- **THEN** the task builds the native MoonBit library, the oracle and the
  extension, and runs the Python tests
- **AND** the task exits with code 0 when all tests pass and with a nonzero code
  when a test fails

### Requirement: Python package identity

The Python package SHALL have the PyPI project name `diagrams.mbt` and the
import package `diagrams_mbt`. Its version SHALL come from
`diagrams_mbt.__version__` and SHALL be independent of the MoonBit module
version.

#### Scenario: Installed version matches the wheel

- **WHEN** a user installs the wheel for version 0.0.1 and imports `diagrams_mbt`
- **THEN** `diagrams_mbt.__version__` is `0.0.1`
- **AND** `importlib.metadata.version("diagrams.mbt")` is `0.0.1`

### Requirement: Cross-built Limited API wheels

The repository SHALL build these wheels on one host with the pinned zig
compiler and pinned CPython headers with verified SHA-256 digests:
`cp312-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64`,
`cp312-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64`,
`cp312-abi3-macosx_11_0_arm64`, `cp312-abi3-macosx_11_0_x86_64` and
`cp312-abi3-win_amd64`. Each wheel SHALL contain only the `diagrams_mbt`
package, its extension module and the `.dist-info` files with the license.

#### Scenario: One command builds all wheels

- **WHEN** a developer runs `mise run python-native:wheels` on Linux or macOS
- **THEN** the task writes the five wheels and the oracle results under
  `_build/python-native/`
- **AND** the task fails when a header archive does not have its pinned digest

### Requirement: Wheel verification before publication

Each wheel SHALL pass the Python tests on a native runner for its platform with
CPython 3.12 and 3.15 before publication. The Linux wheels SHALL pass
`auditwheel show` with their manylinux tag, and all wheels SHALL pass
`twine check`.

#### Scenario: A failing platform blocks publication

- **WHEN** the tests fail for one wheel in a release run
- **THEN** the release run does not upload any wheel to PyPI

### Requirement: Trusted publishing to PyPI

The Release workflow SHALL publish the wheels to PyPI with trusted publishing
from the job environment `pypi`, without a stored API token. It SHALL publish
only from `main`, and only when PyPI does not have the version of
`diagrams_mbt.__version__`. A pull request run SHALL build and test the wheels
and SHALL NOT publish.

#### Scenario: New version on main is published

- **WHEN** a push to `main` changes `diagrams_mbt.__version__` to a version that
  PyPI does not have
- **THEN** the Release workflow uploads the five tested wheels to the PyPI
  project `diagrams.mbt`

#### Scenario: Existing version is skipped

- **WHEN** the Release workflow runs on `main` and PyPI already has the version
- **THEN** the workflow does not build or upload wheels

### Requirement: Public query and traversal parity

Python SHALL expose the complete query and BPMN traversal surface listed in the public compatibility map. It SHALL call the shared MoonBit implementations for domain operations. Equal inputs, options and limits SHALL give equal normalized values, ordering, identity, diagnostics and failures. Python naming and iteration conventions SHALL not change domain semantics.

#### Scenario: A compiled query has the same meaning

- **WHEN** MoonBit and Python compile equal query text with equal schema and namespace options
- **THEN** both return equal plans by their public normalized representation or equal compile diagnostics
- **AND** executions return equal pattern indices, capture roles, projected values and completion states

#### Scenario: The four-target oracle agrees

- **WHEN** shared query and traversal fixtures run on all four MoonBit targets and each supported Python wheel
- **THEN** results equal a common normalized oracle without suppressing platform-specific failures

### Requirement: BPMN inputs and owned read-only views

Python SHALL accept BPMN source and explicit resource inputs needed for traversal, retaining reader diagnostics and immutable document owners. Node views, paths, query plans, cursors and captures SHALL retain or validate their owners. Closing one cursor SHALL not invalidate independent views. Invalid, closed or mismatched handles SHALL give documented failures, not memory access to another object.

#### Scenario: A view outlives a local document variable

- **WHEN** Python retains a captured view after dropping the local document variable
- **THEN** its declared fields remain readable while the retained owner is alive
- **AND** release of the final owner frees its native resources under the runtime lock

#### Scenario: Concurrent use of one mutable cursor

- **WHEN** two threads try to advance the same cursor at the same time
- **THEN** the binding rejects concurrent use with a documented busy error
- **AND** independent cursors remain usable and the document stays unchanged

### Requirement: Callback control and exception parity

Python walking, visitors and pruned reduction SHALL apply each control decision before advancing past its node. Skipping children SHALL still leave that node; stopping SHALL emit no later callbacks. Nested traversals SHALL keep independent state. A Python callback exception SHALL stop traversal, release native resources and propagate the original exception without later callbacks.

#### Scenario: Skip then continue

- **WHEN** a Python enter callback skips a subprocess
- **THEN** it receives that subprocess's leave event, no descendant events, and the next sibling in the same order as MoonBit

#### Scenario: A callback reenters the extension

- **WHEN** a visitor starts a nested walk or calls `render_svg`
- **THEN** it completes without holding the outer runtime lock across user code
- **AND** the outer traversal resumes at its original position

#### Scenario: An exception prevents later leave callbacks

- **WHEN** a user callback raises a Python exception
- **THEN** the same exception reaches the caller and no subsequent enter, typed or leave callback runs
- **AND** later independent native operations still succeed

### Requirement: Batched inspection does not weaken visitor control

Python SHALL support bounded observational query and event batches with the same order and cumulative limits as MoonBit. Interactive visitor decisions SHALL not be delayed until after descendants have been observed. Both consumers SHALL distinguish an intentionally stopped traversal from a complete or failed execution.

#### Scenario: Stop before a child is observed

- **WHEN** a visitor returns stop at a node whose children would otherwise be in the next observational batch
- **THEN** no child or later leave callback is exposed
- **AND** the stopped status does not claim complete traversal

### Requirement: Direct result transport and existing rendering compatibility

The extension SHALL return SVG output through a dedicated UTF-8 buffer and traversal/query values through versioned structured records. It SHALL NOT serialize complete SVG, node snapshots or query batches as JSON for Python to parse again. Public `render_svg`, result dataclasses, Unicode behavior and renderer diagnostics SHALL retain their existing observable behavior.

#### Scenario: Legacy rendering remains equal

- **WHEN** the old rendering corpus runs through the updated Python API
- **THEN** SVG bytes, media type, diagnostics and `ok` values equal the direct MoonBit results
- **AND** malformed input remains returned diagnostics rather than a new exception category

#### Scenario: Inspect a projected result

- **WHEN** Python requests a batch of activity IDs, names and source positions
- **THEN** it receives those fields without invoking a Python callback or making a native property call for each requested field

### Requirement: Measured boundary and locking behavior

Reproducible qualification SHALL report native work, public-call latency, callback count, result conversion, allocation growth, GIL-held time and runtime-lock wait across declared workloads. It SHALL compare direct native operations, queries, batches and Python visitors on equal work. Results SHALL identify platform and toolchain and SHALL NOT claim an unmeasured speedup or parallel native execution.

#### Scenario: Selective inspection avoids per-node callbacks

- **WHEN** a native query selects a small fraction of a declared large tree and projects its requested fields
- **THEN** no Python predicate or visitor is called for the rejected nodes
- **AND** the report compares it with an equivalent visitor and includes conversion and materialization time

#### Scenario: Expensive callbacks remain visible

- **WHEN** a benchmark uses both no-op and substantive Python callbacks
- **THEN** it reports callback work separately from native advancement and does not attribute all elapsed time to boundary dispatch
