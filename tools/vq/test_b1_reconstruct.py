from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path

from tools.vq.b1_reconstruct import Correction, Replacement, apply_correction, source_manifest


class B1ReconstructTests(unittest.TestCase):
    def make_correction(self, source: bytes, old: bytes, new: bytes) -> Correction:
        corrected = source.replace(old, new, 1)
        return Correction(
            patch_id="TEST",
            target="SWAP/test.f90",
            b0_sha256=hashlib.sha256(source).hexdigest(),
            corrected_sha256=hashlib.sha256(corrected).hexdigest(),
            replacements=(Replacement(old, new),),
        )

    def test_exact_byte_replacement_passes(self) -> None:
        source = b"before\r\ntarget\r\nafter\r\n"
        correction = self.make_correction(source, b"target\r\n", b"replacement\r\n")
        result = apply_correction(source, correction)
        self.assertEqual(result, b"before\r\nreplacement\r\nafter\r\n")

    def test_wrong_preimage_fails_closed(self) -> None:
        source = b"before\r\ntarget\r\nafter\r\n"
        correction = self.make_correction(source, b"target\r\n", b"replacement\r\n")
        with self.assertRaisesRegex(ValueError, "B0 preimage SHA mismatch"):
            apply_correction(source + b"changed", correction)

    def test_non_unique_target_fails_closed(self) -> None:
        source = b"target\r\ntarget\r\n"
        correction = Correction(
            patch_id="TEST",
            target="SWAP/test.f90",
            b0_sha256=hashlib.sha256(source).hexdigest(),
            corrected_sha256="unused",
            replacements=(Replacement(b"target\r\n", b"replacement\r\n"),),
        )
        with self.assertRaisesRegex(ValueError, "expected one target sequence, found 2"):
            apply_correction(source, correction)

    def test_source_manifest_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "b.f90").write_bytes(b"b\r\n")
            (root / "a.f90").write_bytes(b"a\r\n")
            first = source_manifest(root)
            second = source_manifest(root)
            self.assertEqual(first, second)
            self.assertEqual(first.splitlines()[0].split()[-1], b"SWAP/a.f90")


if __name__ == "__main__":
    unittest.main()
