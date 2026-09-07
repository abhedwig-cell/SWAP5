from __future__ import annotations
import copy
import json
import unittest
from pathlib import Path

from reference_candidate_gate import CandidateGateError, REQUIRED, assess

HERE = Path(__file__).resolve().parent
CANDIDATE = json.loads(
    (HERE / "reference_candidates" / "b1_10_quiet_candidate.json").read_text()
)


class ReferenceCandidateGateTests(unittest.TestCase):
    def test_current_b1_10_candidate_is_fail_closed(self):
        result = assess(CANDIDATE)
        self.assertFalse(result["admission_allowed"])
        self.assertIn("committed_state_at_t0", result["missing"])
        self.assertIn("unrounded_internal_mass_accounting", result["missing"])

    def test_all_admission_requirements_are_explicit(self):
        self.assertEqual(set(CANDIDATE["required_for_admission"]), REQUIRED)

    def test_cannot_admit_while_any_requirement_missing(self):
        bad = copy.deepcopy(CANDIDATE)
        bad["admission_allowed"] = True
        bad["status"] = "READY_FOR_FIXTURE_BUILD"
        with self.assertRaises(CandidateGateError):
            assess(bad)

    def test_cannot_hide_checkpoint_gap(self):
        bad = copy.deepcopy(CANDIDATE)
        bad["missing"].remove("committed_state_at_t0")
        with self.assertRaises(CandidateGateError):
            assess(bad)

    def test_branch_name_is_not_source_identity(self):
        bad = copy.deepcopy(CANDIDATE)
        bad["source_identity"]["source_commit"] = "main"
        with self.assertRaises(CandidateGateError):
            assess(bad)

    def test_ready_shape_requires_zero_missing(self):
        ready = copy.deepcopy(CANDIDATE)
        ready["missing"] = []
        ready["admission_allowed"] = True
        ready["status"] = "READY_FOR_FIXTURE_BUILD"
        ready["repository_evidence"]["event_checkpoint_artifact_found"] = True
        ready["evidence_inventory"].append(
            {
                "path": "future/reference-run.json",
                "git_blob_sha1": "a" * 40,
                "role": "qualified event checkpoint",
                "provides_event_checkpoint": True,
                "provides_unrounded_mass": True,
            }
        )
        result = assess(ready)
        self.assertTrue(result["admission_allowed"])


if __name__ == "__main__":
    unittest.main()
