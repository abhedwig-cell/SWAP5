import io
import tempfile
import unittest
import zipfile
from pathlib import Path
from extract_b111_meteo import extract, main, OLD, NEW

class ExactMeteoRecoveryTests(unittest.TestCase):
    def test_invalid_archive(self):
        with self.assertRaisesRegex(ValueError, "SHA mismatch"):
            extract(b"not a zip")
    def test_plausible_wrong_archive(self):
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, "w") as archive:
            archive.writestr("SWAP/MOD_meteo.f90", OLD)
        with self.assertRaisesRegex(ValueError, "SHA mismatch"):
            extract(stream.getvalue())
    def test_patch_identity(self):
        self.assertEqual(len(OLD)-len(NEW), 9)
        self.assertIn(b"do i = 1, ifnd", NEW)
    def test_missing_input_does_not_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)/"result.f90"
            with self.assertRaisesRegex(ValueError, "missing"):
                main(["extract", str(Path(tmp)/"missing.zip"), str(target)])
            self.assertFalse(target.exists())
    def test_wrong_input_does_not_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp)/"bad.zip"
            target = Path(tmp)/"result.f90"
            archive.write_bytes(b"wrong")
            with self.assertRaisesRegex(ValueError, "SHA mismatch"):
                main(["extract", str(archive), str(target)])
            self.assertFalse(target.exists())

if __name__ == "__main__":
    unittest.main()
