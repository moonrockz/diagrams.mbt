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

The adapter SHALL initialize the MoonBit runtime one time for each process,
before the first render. It SHALL copy each input and output buffer at the
boundary and release each MoonBit value that it receives. The extension SHALL
hold the GIL during each call and SHALL declare that it does not support more
than one interpreter.

#### Scenario: Repeated mixed calls give stable results

- **WHEN** Python calls `render_svg` many times with valid, invalid, empty and
  non-BMP fixtures in alternation
- **THEN** each result equals the first result for the same fixture

#### Scenario: Sanitizer build finds no memory errors

- **WHEN** the sanitizer build of the extension runs the repeated mixed calls
- **THEN** AddressSanitizer and UndefinedBehaviorSanitizer report no error

#### Scenario: Incompatible boundary version is refused

- **WHEN** the extension loads a MoonBit library with a different boundary version
- **THEN** the import fails with `ImportError`

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
