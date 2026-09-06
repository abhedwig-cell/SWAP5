from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.vq.b1_snapshot_identity import verify_snapshot


class B1SnapshotIdentityTests(unittest.TestCase):
    def make_pin(self, root: Path, payload: bytes, expected_sha256: str | None = None) -> Path:
        patch_path = root / "reference" / "swap-4.3.1" / "patches" / "TEST" / "fix.patch"
        patch_path.parent.mkdir(parents=True)
        patch_path.write_bytes(payload)
        expected = expected_sha256 or hashlib.sha256(payload).hexdigest()
        pin = {
            "snapshot": "TEST",
            "integration_commit": "test",
            "patches": [
                {
                    "id": "TEST",
                    "path": "reference/swap-4.3.1/patches/TEST/fix.patch",
                    "expected_sha256": expected,
                }
            ],
        }
        pin_path = root / "pin.json"
        pin_path.write_text(json.dumps(pin), encoding="utf-8")
        return pin_path

    def test_exact_patch_identity_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pin = self.make_pin(root, b"exact patch bytes\n")
            result = verify_snapshot(root, pin)
            self.assertTrue(result["qualified_identity"])
            self.assertTrue(result["patches"][0]["matches"])

    def test_hash_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pin = self.make_pin(root, b"actual\n", hashlib.sha256(b"expected\n").hexdigest())
            result = verify_snapshot(root, pin)
            self.assertFalse(result["qualified_identity"])
            self.assertEqual(result["failure"], "patch_artifact_identity_mismatch")

    def test_missing_patch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pin = self.make_pin(root, b"present\n")
            (root / "reference" / "swap-4.3.1" / "patches" / "TEST" / "fix.patch").unlink()
            result = verify_snapshot(root, pin)
            self.assertFalse(result["qualified_identity"])
            self.assertEqual(result["patches"][0]["failure"], "patch_not_found")


if __name__ == "__main__":
    unittest.main()
