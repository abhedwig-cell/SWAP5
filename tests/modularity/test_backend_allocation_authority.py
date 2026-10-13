"""Actual pinned source mutation and missing-proof negative controls."""
import subprocess
import unittest
import tempfile
import json
from unittest.mock import patch
from pathlib import Path
from backend_allocation_authority import (BASE, BACKEND, ROOT, PUBLICATION,
                                         validate_change, validate_publication_change, verify_source)
from verify_backend_owner_evidence import verify_owner, read_archive


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

    def test_exact_beginning_balance_move(self):
        old = subprocess.check_output(['git', 'show', BASE + ':' + PUBLICATION], cwd=ROOT)
        assignment = b'    initial_total = committed_ledger_total(result%ledger_snapshots, order)\n'
        new = old.replace(assignment, b'').replace(b'    end do\n\n    do k = 1, n\n',
            b'    end do\n\n' + assignment + b'\n    do k = 1, n\n')
        validate_publication_change(old, new)
        for mutant in (old, new + b'\n', new.replace(b'same_multiswap_mass', b'weakened_mass', 1)):
            with self.subTest(mutant=mutant[-40:]):
                with self.assertRaises(AssertionError):
                    validate_publication_change(old, mutant)

    def test_real_progress_archive_corruption_rejected(self):
        status = json.loads((ROOT / 'integration/audits/MODULAR_TESTABILITY_20261013.json').read_text())
        record = status['backend_qualification']['progress_evidence']
        with self.assertRaises(AssertionError):
            read_archive({**record, 'decoded_sha256': '0' * 64})

    def test_real_unsealed_evidence_cannot_admit_owner(self):
        original = json.loads((ROOT / 'integration/audits/MODULAR_TESTABILITY_20261013.json').read_text())
        record = original['backend_qualification']['progress_evidence']
        source = verify_source()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = root / record['path']
            artifact.parent.mkdir(parents=True)
            artifact.write_bytes((ROOT / record['path']).read_bytes())
            status = root / 'integration/audits/MODULAR_TESTABILITY_20261013.json'
            status.write_text(json.dumps({'backend_qualification': {'owner_evidence': record}}))
            with patch('verify_backend_owner_evidence.ROOT', root), \
                 patch('verify_backend_owner_evidence.verify_source', return_value=source):
                with self.assertRaises(KeyError):
                    verify_owner()


if __name__ == '__main__':
    unittest.main()
