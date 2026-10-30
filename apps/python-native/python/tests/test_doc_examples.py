"""The Python examples of the Python guides run and pass.

Each ```python block of a guide runs in document order in one namespace per
guide, so a guide can start with a setup block (``# Setup: ...``). Output is
captured. The guides are found from DIAGRAMS_NATIVE_FIXTURES.
"""

from __future__ import annotations

import contextlib
import io
import os
import pathlib
import re
import unittest
from typing import List

GUIDES = ("traversal.md", "query.md", "compatibility.md")


def repo_root() -> pathlib.Path:
    fixtures = pathlib.Path(os.environ["DIAGRAMS_NATIVE_FIXTURES"]).resolve()
    return fixtures.parents[2]


def python_blocks(text: str) -> List[str]:
    return re.findall(r"^```python\n(.*?)^```", text, flags=re.S | re.M)


class DocExamplesTest(unittest.TestCase):
    def test_every_python_block_runs(self) -> None:
        total = 0
        for guide in GUIDES:
            path = repo_root() / "docs" / "python" / guide
            blocks = python_blocks(path.read_text(encoding="utf-8"))
            namespace: dict = {"__name__": f"doc_{guide}"}
            for index, block in enumerate(blocks):
                with self.subTest(guide=guide, block=index):
                    code = compile(block, f"{path}:block{index}", "exec")
                    with contextlib.redirect_stdout(io.StringIO()):
                        exec(code, namespace)  # noqa: S102 - trusted repository docs
                total += 1
        self.assertGreaterEqual(total, 6)

    def test_a_setup_block_comes_first_when_a_guide_uses_source(self) -> None:
        for guide in GUIDES:
            blocks = python_blocks((repo_root() / "docs" / "python" / guide).read_text(encoding="utf-8"))
            if any("source" in b for b in blocks):
                with self.subTest(guide=guide):
                    self.assertTrue(blocks[0].startswith("# Setup:"))


if __name__ == "__main__":
    unittest.main()
