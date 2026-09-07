from __future__ import annotations

import copy
import unittest

from reference_source_adapter import (
    QUALIFIED_ORACLE_STATUS,
    ReferenceSourceError,
    adapt_vq_reference_pin,
    fixture_reference_identity,
)


PIN = {
    "schema_version": 1,
    "workstream": "VQ",
    "slice": "B1.10-admission",
    "snapshot": "B1.10",
    "integration_commit": "0e5c58134b225014426c75e240f0b668affbb4a1",
    "snapshot_path": "reference/swap-4.3.1/snapshots/B1.10.yml",
    "snapshot_git_blob_sha1": "8d768f00d47224a663941f79bb2d35eacc66d16b",
    "source_tree": {
        "member_manifest_sha256": "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
    },
    "qualification": {
        "all_patch_artifact_hashes_match": True,
        "all_declared_b0_preimages_match_canonical_manifest": True,
        "swap002_ordered_preimage_gate": "PASS",
        "swap002_source_bound_compiled_start_gate": "PASS",
        "b1_10_oracle_status": QUALIFIED_ORACLE_STATUS,
    },
}


def adapt(pin=PIN):
    return adapt_vq_reference_pin(
        pin,
        repository="abhedwig-cell/SWAP5",
        pin_path="tools/vq/cases/b1-10-reference-pin.json",
        pin_git_blob_sha1="2422c3ec518afb1d9b7fbd55e869a806842161c9",
        expected_snapshot="B1.10",
    )


class ReferenceSourceAdapterTests(unittest.TestCase):
    def test_accepts_exact_qualified_b1_10_identity(self):
        identity = adapt()
        self.assertEqual(identity.snapshot, "B1.10")
        self.assertEqual(identity.integration_commit, PIN["integration_commit"])
        self.assertEqual(identity.oracle_status, QUALIFIED_ORACLE_STATUS)

    def test_identity_hash_is_deterministic(self):
        self.assertEqual(adapt().canonical_hash(), adapt().canonical_hash())

    def test_fixture_fragment_keeps_vq_pin_and_source_commit(self):
        fragment = fixture_reference_identity(adapt())
        self.assertEqual(fragment["source_commit"], PIN["integration_commit"])
        self.assertEqual(fragment["qualified_snapshot"], "B1.10")
        self.assertEqual(
            fragment["vq_reference_pin_git_blob_sha1"],
            "2422c3ec518afb1d9b7fbd55e869a806842161c9",
        )
        self.assertEqual(len(fragment["source_identity_sha256"]), 64)

    def test_rejects_branch_name_instead_of_exact_commit(self):
        bad = copy.deepcopy(PIN)
        bad["integration_commit"] = "main"
        with self.assertRaises(ReferenceSourceError):
            adapt(bad)

    def test_rejects_wrong_snapshot_binding(self):
        bad = copy.deepcopy(PIN)
        bad["snapshot_path"] = "reference/swap-4.3.1/snapshots/B1.9.yml"
        with self.assertRaises(ReferenceSourceError):
            adapt(bad)

    def test_rejects_unqualified_oracle(self):
        bad = copy.deepcopy(PIN)
        bad["qualification"]["b1_10_oracle_status"] = "CANDIDATE"
        with self.assertRaises(ReferenceSourceError):
            adapt(bad)

    def test_rejects_failed_vq_gate(self):
        bad = copy.deepcopy(PIN)
        bad["qualification"]["swap002_ordered_preimage_gate"] = "FAIL"
        with self.assertRaises(ReferenceSourceError):
            adapt(bad)

    def test_rejects_false_vq_boolean(self):
        bad = copy.deepcopy(PIN)
        bad["qualification"]["all_patch_artifact_hashes_match"] = False
        with self.assertRaises(ReferenceSourceError):
            adapt(bad)

    def test_rejects_malformed_hashes(self):
        bad = copy.deepcopy(PIN)
        bad["source_tree"]["member_manifest_sha256"] = "abc"
        with self.assertRaises(ReferenceSourceError):
            adapt(bad)

    def test_expected_snapshot_is_fail_closed(self):
        with self.assertRaises(ReferenceSourceError):
            adapt_vq_reference_pin(
                PIN,
                repository="abhedwig-cell/SWAP5",
                pin_path="tools/vq/cases/b1-10-reference-pin.json",
                expected_snapshot="B1.9",
            )


if __name__ == "__main__":
    unittest.main()
