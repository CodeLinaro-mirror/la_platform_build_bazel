import enum
import json
import tokenize
import unittest
from typing import Dict

from python.runfiles import Runfiles

_JSON_FILE = "goldfish_build+/toolchains/tool_versions.json"
_MODULE_FILE = "goldfish_build+/bzlmod/toolchain.MODULE.bazel"

_runfiles: Runfiles = Runfiles.Create()

class TestVersion(unittest.TestCase):

    def test_versions_match(self):
        versions_json = _version_from_json(_runfiles)
        versions_bzl = _version_from_module(_runfiles)

        self.assertDictEqual(versions_json, versions_bzl)


class TokenState(enum.Enum):
    PENDING_ANCHOR = 1
    PENDING_OPEN = 2
    PENDING_CLOSE = 3


def _version_from_json(runfile_helper: Runfiles) -> Dict[str, str]:
    with open(runfile_helper.Rlocation(_JSON_FILE), "r") as f:
        return json.load(f)


def _version_from_module(runfile_helper: Runfiles) -> Dict[str, str]:
    version_declares = []
    with tokenize.open(runfile_helper.Rlocation(_MODULE_FILE)) as f:
        tokens = tokenize.generate_tokens(f.readline)
        state = TokenState.PENDING_ANCHOR
        for token in tokens:
            match (state, token.type, token.string):
                case (TokenState.PENDING_ANCHOR, tokenize.NAME, "TOOL_VERSIONS"):
                    state = TokenState.PENDING_OPEN
                case (TokenState.PENDING_OPEN, tokenize.OP, "{"):
                    state = TokenState.PENDING_CLOSE
                    version_declares.append(token[:2])
                case (TokenState.PENDING_CLOSE, tokenize.OP, "}"):
                    version_declares.append(token[:2])
                    break
                case (TokenState.PENDING_CLOSE, _, _):
                    version_declares.append(token[:2])
    return eval(tokenize.untokenize(version_declares), {})


if __name__ == "__main__":
    unittest.main()
