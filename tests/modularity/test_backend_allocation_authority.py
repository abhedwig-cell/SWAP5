"""Actual pinned source mutation and missing-proof negative controls."""
import subprocess
import unittest
import tempfile
import json
from unittest.mock import patch
from pathlib import Path
from backend_allocation_authority import BASE, BACKEND, ROOT, validate_change, verify_source
from verify_backend_owner_evidence import verify_owner


class SourceControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = subprocess.check_output(['git', 'show', BASE + ':' + BACKEND], cwd=ROOT)
        cls.new = (ROOT / BACKEND).read_bytes()

    def test_exact_guard(self):
        validate_change(self.old, self.new)

    def test_changed_physics_rejected(self):
        with self.assertRaises(AssertionError):
            validate_change(self.old, self.new.replace(b'fixed_top_conductivity_ok', b'other_conductivity_ok', 1))

    def test_removed_guard_rejected(self):
        with self.assertRaises(AssertionError):
            validate_change(self.old, self.new.replace(b'if (allocated(self%macropore_config)) then', b'if (.true.) then', 1))

    def test_extra_change_rejected(self):
        with self.assertRaises(AssertionError):
            validate_change(self.old, self.new + b'\n')

    def test_wrong_preimage_rejected(self):
        with self.assertRaises(AssertionError):
            validate_change(self.old + b'\n', self.new)

    def test_missing_owner_proof_rejected(self):
        # The temporary metadata fixture cannot inherit a real owner capsule.
        source = verify_source()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            status = root / 'integration/audits/MODULAR_TESTABILITY_20261013.json'
            status.parent.mkdir(parents=True)
            status.write_text(json.dumps({'backend_qualification': {}}))
            with patch('verify_backend_owner_evidence.ROOT', root), \
                 patch('verify_backend_owner_evidence.verify_source', return_value=source):
                with self.assertRaises(KeyError):
                    verify_owner()


if __name__ == '__main__':
    unittest.main()
