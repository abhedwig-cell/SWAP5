from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.vq.reference_identity import verify_b0_archive


class ReferenceIdentityTests(unittest.TestCase):
    def _write_manifest(self, root: Path, payload: bytes) -> Path:
        manifest = {
            "reference_chain": {
                "B0": {
                    "distribution": {
                        "name": "SWAP_4.3.1.zip",
                        "size_bytes": len(payload),
                        "sha256": hashlib.sha256(payload).hexdigest(),
                    }
                }
            }
        }
        path = root / "reference-baseline.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        return path

    def test_exact_identity_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            payload = b"known-b0-fixture"
            archive = root / "candidate.zip"
            archive.write_bytes(payload)
            manifest = self._write_manifest(root, payload)

            result = verify_b0_archive(archive, manifest)

            self.assertTrue(result["qualified_identity"])
            self.assertTrue(result["checks"]["size_matches"])
            self.assertTrue(result["checks"]["sha256_matches"])

    def test_same_size_wrong_hash_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            expected = b"known-b0-fixture"
            observed = b"KNOWN-B0-FIXTURE"
            self.assertEqual(len(expected), len(observed))
            archive = root / "candidate.zip"
            archive.write_bytes(observed)
            manifest = self._write_manifest(root, expected)

            result = verify_b0_archive(archive, manifest)

            self.assertFalse(result["qualified_identity"])
            self.assertTrue(result["checks"]["size_matches"])
            self.assertFalse(result["checks"]["sha256_matches"])
            self.assertEqual(result["failure"], "identity_mismatch")

    def test_missing_archive_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = self._write_manifest(root, b"known-b0-fixture")

            result = verify_b0_archive(root / "missing.zip", manifest)

            self.assertFalse(result["qualified_identity"])
            self.assertEqual(result["failure"], "archive_not_found")


if __name__ == "__main__":
    unittest.main()
