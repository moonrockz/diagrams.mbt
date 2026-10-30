# Spec Delta

## ADDED Requirements

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
