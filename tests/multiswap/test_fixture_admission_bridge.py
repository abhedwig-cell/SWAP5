from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from fixture_admission_bridge import FixtureAdmissionBlocked, admit_reference_record

HERE = Path(__file__).resolve().parent
BLOCKED = json.loads(
    (HERE / "reference_candidates" / "b1_10_quiet_candidate.json").read_text()
)


def ready_candidate():
    candidate = copy.deepcopy(BLOCKED)
    candidate["missing"] = []
    candidate["admission_allowed"] = True
    candidate["status"] = "READY_FOR_FIXTURE_BUILD"
    candidate["repository_evidence"]["event_checkpoint_artifact_found"] = True
    candidate["evidence_inventory"].append(
        {
            "path": "future/reference-run.json",
            "git_blob_sha1": "a" * 40,
            "role": "qualified event checkpoint",
            "provides_event_checkpoint": True,
            "provides_unrounded_mass": True,
        }
    )
    return candidate


def bound_record():
    return {
        "source": {
            "kind": "reference_run",
            "repository": "abhedwig-cell/SWAP5",
            "commit": "0e5c58134b225014426c75e240f0b668affbb4a1",
            "reference_family": "SWAP-4.3.1-corrected",
            "reference_snapshot": "B1.10",
            "case_id": "quiet",
            "run_id": "future-qualified-run",
            "extractor_id": "future-extractor",
            "extraction_mode": "reference_run_checkpoint",
            "source_artifacts": {
                "source_tree_manifest": "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
            },
        }
    }


class FixtureAdmissionBridgeTests(unittest.TestCase):
    def test_current_blocked_candidate_never_calls_builder(self):
        called = False

        def builder(_record):
            nonlocal called
            called = True
            return {"should": "not happen"}

        with self.assertRaises(FixtureAdmissionBlocked):
            admit_reference_record(BLOCKED, bound_record(), builder=builder)
        self.assertFalse(called)

    def test_ready_matching_candidate_can_reach_builder(self):
        result = admit_reference_record(
            ready_candidate(), bound_record(), builder=lambda record: {"source": record["source"]}
        )
        self.assertEqual(result["source"]["reference_snapshot"], "B1.10")

    def test_commit_mismatch_is_rejected(self):
        record = bound_record()
        record["source"]["commit"] = "b" * 40
        with self.assertRaises(FixtureAdmissionBlocked):
            admit_reference_record(ready_candidate(), record, builder=lambda record: dict(record))

    def test_snapshot_mismatch_is_rejected(self):
        record = bound_record()
        record["source"]["reference_snapshot"] = "B1.9"
        with self.assertRaises(FixtureAdmissionBlocked):
            admit_reference_record(ready_candidate(), record, builder=lambda record: dict(record))

    def test_source_manifest_mismatch_is_rejected(self):
        record = bound_record()
        record["source"]["source_artifacts"]["source_tree_manifest"] = "c" * 64
        with self.assertRaises(FixtureAdmissionBlocked):
            admit_reference_record(ready_candidate(), record, builder=lambda record: dict(record))

    def test_non_checkpoint_extraction_is_rejected(self):
        record = bound_record()
        record["source"]["extraction_mode"] = "hand_assembled"
        with self.assertRaises(FixtureAdmissionBlocked):
            admit_reference_record(ready_candidate(), record, builder=lambda record: dict(record))


if __name__ == "__main__":
    unittest.main()
