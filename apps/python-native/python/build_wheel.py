"""Write one wheel of the PyPI project diagrams.mbt with the standard library.

Usage: python -P build_wheel.py --package DIR --platform TAG --readme FILE
       --license NAME=FILE [--license NAME=FILE]... --out DIR

DIR is a built ``diagrams_mbt`` package directory with its extension module.
TAG is a platform tag, for example ``macosx_11_0_arm64``; a compressed tag set
such as ``manylinux_2_17_x86_64.manylinux2014_x86_64`` is allowed. The version
comes from ``__version__`` in ``DIR/__init__.py``. The wheel is reproducible:
entries are sorted and have a fixed time stamp.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import pathlib
import re
import sys
import zipfile

NAME = "diagrams.mbt"
DIST = "diagrams_mbt"
PYTHON_TAG = "cp312"
ABI_TAG = "abi3"
STAMP = (1980, 1, 1, 0, 0, 0)

CLASSIFIERS = [
    "Development Status :: 2 - Pre-Alpha",
    "Intended Audience :: Developers",
    "Operating System :: MacOS",
    "Operating System :: Microsoft :: Windows",
    "Operating System :: POSIX :: Linux",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3 :: Only",
    "Programming Language :: Python :: Implementation :: CPython",
    "Topic :: Multimedia :: Graphics",
    "Typing :: Typed",
]

PROJECT_URLS = [
    ("Homepage", "https://github.com/moonrockz/diagrams.mbt"),
    ("Documentation", "https://moonrockz.github.io/diagrams.mbt/docs/python/"),
    ("Source", "https://github.com/moonrockz/diagrams.mbt/tree/main/apps/python-native"),
    ("Issues", "https://github.com/moonrockz/diagrams.mbt/issues"),
]


def version_of(package: pathlib.Path) -> str:
    text = (package / "__init__.py").read_text(encoding="utf-8")
    match = re.search(r'^__version__\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if match is None:
        raise SystemExit(f"{package}/__init__.py has no __version__")
    return match.group(1)


def metadata(version: str, readme: str, licenses: list[str]) -> str:
    lines = [
        "Metadata-Version: 2.4",
        f"Name: {NAME}",
        f"Version: {version}",
        "Summary: Render Mermaid diagrams to standalone SVG in process with the "
        "diagrams.mbt MoonBit renderer.",
        "Keywords: mermaid,svg,diagrams,moonbit",
        "Author: moonrockz",
        "License-Expression: Apache-2.0 AND MIT AND BSD-3-Clause AND CC-BY-SA-4.0",
    ]
    lines += [f"License-File: {name}" for name in licenses]
    lines += [f"Classifier: {c}" for c in CLASSIFIERS]
    lines += [f"Project-URL: {label}, {url}" for label, url in PROJECT_URLS]
    lines += [
        "Requires-Python: >=3.12",
        "Description-Content-Type: text/markdown",
        "",
        readme,
    ]
    return "\n".join(lines)


def wheel_file(platform: str) -> str:
    lines = [
        "Wheel-Version: 1.0",
        "Generator: diagrams.mbt build_wheel.py",
        "Root-Is-Purelib: false",
    ]
    lines += [f"Tag: {PYTHON_TAG}-{ABI_TAG}-{p}" for p in platform.split(".")]
    return "\n".join(lines) + "\n"


def record_hash(data: bytes) -> str:
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest())
    return "sha256=" + digest.rstrip(b"=").decode("ascii")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True, type=pathlib.Path)
    parser.add_argument("--platform", required=True)
    parser.add_argument("--readme", required=True, type=pathlib.Path)
    parser.add_argument("--license", action="append", default=[])
    parser.add_argument("--out", required=True, type=pathlib.Path)
    args = parser.parse_args()

    version = version_of(args.package)
    info = f"{DIST}-{version}.dist-info"
    entries: dict[str, tuple[bytes, int]] = {}

    for path in sorted(args.package.rglob("*")):
        if path.is_file() and "__pycache__" not in path.parts:
            name = f"{DIST}/{path.relative_to(args.package).as_posix()}"
            mode = 0o755 if path.suffix in (".so", ".pyd") else 0o644
            entries[name] = (path.read_bytes(), mode)

    license_names = []
    for item in args.license:
        name, _, file = item.partition("=")
        license_names.append(name)
        entries[f"{info}/licenses/{name}"] = (pathlib.Path(file).read_bytes(), 0o644)

    readme = args.readme.read_text(encoding="utf-8")
    entries[f"{info}/METADATA"] = (
        metadata(version, readme, license_names).encode("utf-8"),
        0o644,
    )
    entries[f"{info}/WHEEL"] = (wheel_file(args.platform).encode("utf-8"), 0o644)

    record = [f"{n},{record_hash(d)},{len(d)}" for n, (d, _) in sorted(entries.items())]
    record.append(f"{info}/RECORD,,")
    entries[f"{info}/RECORD"] = (("\n".join(record) + "\n").encode("utf-8"), 0o644)

    args.out.mkdir(parents=True, exist_ok=True)
    wheel = args.out / f"{DIST}-{version}-{PYTHON_TAG}-{ABI_TAG}-{args.platform}.whl"
    with zipfile.ZipFile(wheel, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        # The package files come first and the .dist-info files last.
        order = sorted(entries, key=lambda n: (n.startswith(info), n))
        for name in order:
            data, mode = entries[name]
            item = zipfile.ZipInfo(name, date_time=STAMP)
            item.external_attr = (0o100000 | mode) << 16
            item.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(item, data)
    print(wheel)
    return 0


if __name__ == "__main__":
    sys.exit(main())
