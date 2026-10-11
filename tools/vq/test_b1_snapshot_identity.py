from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.vq.b1_snapshot_identity import git_blob_sha1, verify_snapshot


class B1SnapshotIdentityTests(unittest.TestCase):
    def make_fixture(
        self,
        root: Path,
        patch_payload: bytes = b"exact patch bytes\n",
        expected_patch_sha256: str | None = None,
        expected_b0_sha256: str | None = None,
    ) -> Path:
        snapshot = root / "reference" / "swap-4.3.1" / "snapshots" / "TEST.yml"
        snapshot.parent.mkdir(parents=True)
        snapshot.write_text("snapshot: TEST\n", encoding="utf-8")

        manifest = root / "reference" / "swap-4.3.1" / "b0" / "file-manifest.sha256"
        manifest.parent.mkdir(parents=True)
        canonical_b0 = hashlib.sha256(b"canonical-b0-member").hexdigest()
        manifest.write_text(
            f"# fixture\n{canonical_b0}  19  SWAP/test.f90\n",
            encoding="utf-8",
        )

        patch_path = root / "reference" / "swap-4.3.1" / "patches" / "TEST" / "fix.patch"
        patch_path.parent.mkdir(parents=True)
        patch_path.write_bytes(patch_payload)

        pin = {
            "snapshot": "TEST",
            "integration_commit": "test",
            "snapshot_path": "reference/swap-4.3.1/snapshots/TEST.yml",
            "snapshot_git_blob_sha1": git_blob_sha1(snapshot),
            "b0_member_manifest_path": "reference/swap-4.3.1/b0/file-manifest.sha256",
            "b0_member_manifest_git_blob_sha1": git_blob_sha1(manifest),
            "patches": [
                {
                    "id": "TEST",
                    "path": "reference/swap-4.3.1/patches/TEST/fix.patch",
                    "expected_sha256": expected_patch_sha256 or hashlib.sha256(patch_payload).hexdigest(),
                    "b0_target": "SWAP/test.f90",
                    "expected_b0_sha256": expected_b0_sha256 or canonical_b0,
                }
            ],
        }
        pin_path = root / "pin.json"
        pin_path.write_text(json.dumps(pin), encoding="utf-8")
        return pin_path

    def test_exact_snapshot_patch_and_preimage_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pin = self.make_fixture(root)
            result = verify_snapshot(root, pin)
            self.assertTrue(result["qualified_identity"])
            self.assertTrue(result["snapshot_identity"]["matches"])
            self.assertTrue(result["b0_manifest_identity"]["matches"])
            self.assertTrue(result["patches"][0]["matches"])

    def test_patch_hash_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            wrong = hashlib.sha256(b"expected other patch\n").hexdigest()
            pin = self.make_fixture(root, expected_patch_sha256=wrong)
            result = verify_snapshot(root, pin)
            self.assertFalse(result["qualified_identity"])
            self.assertEqual(result["patches"][0]["failure"], "patch_artifact_identity_mismatch")

    def test_b0_preimage_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            wrong = hashlib.sha256(b"wrong b0 member").hexdigest()
            pin = self.make_fixture(root, expected_b0_sha256=wrong)
            result = verify_snapshot(root, pin)
            self.assertFalse(result["qualified_identity"])
            self.assertEqual(result["patches"][0]["failure"], "b0_preimage_identity_mismatch")

    def test_missing_patch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pin = self.make_fixture(root)
            (root / "reference" / "swap-4.3.1" / "patches" / "TEST" / "fix.patch").unlink()
            result = verify_snapshot(root, pin)
            self.assertFalse(result["qualified_identity"])
            self.assertEqual(result["patches"][0]["failure"], "patch_not_found")

    def test_snapshot_blob_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pin = self.make_fixture(root)
            snapshot = root / "reference" / "swap-4.3.1" / "snapshots" / "TEST.yml"
            snapshot.write_text("snapshot: CHANGED\n", encoding="utf-8")
            result = verify_snapshot(root, pin)
            self.assertFalse(result["qualified_identity"])
            self.assertFalse(result["snapshot_identity"]["matches"])


if __name__ == "__main__":
    unittest.main()
