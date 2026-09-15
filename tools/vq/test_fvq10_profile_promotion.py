import copy
import unittest

from tools.vq import fvq10_profile_promotion as promo


class FVQ10PromotionTests(unittest.TestCase):
    def candidate(self, *, optional_complete=True):
        candidate = {
            "record_type": promo.CANDIDATE_RECORD_TYPE,
            "profile_scope": {"workload_class": "TEST_FIXTURE_ONLY"},
            "execution_environment_scope": {"compiler": "TEST_FIXTURE_ONLY"},
            "optional_process_scope": {"complete": optional_complete, "covered_domains": ["water"]},
            "calibration_observation_ids": ["cal-1"],
            "validation_observation_ids": ["val-1"],
            "limits": {
                metric: {
                    "value": 1.0,
                    "unit": unit,
                    "origin_class": promo.ALLOWED_ORIGIN,
                    "rationale": "synthetic unit-test value; not production evidence",
                    "evidence_refs": ["TEST_FIXTURE_ONLY"],
                }
                for metric, unit in promo.METRIC_UNITS.items()
            },
        }
        candidate["frozen_profile_hash"] = promo.candidate_hash(candidate)
        return candidate

    def observation(self, *, delta=0.5, process_complete=True, full_pass=True, split_pass=True):
        return {
            "record_type": promo.RAW_RECORD_TYPE,
            "provenance": {"fixture": "TEST_FIXTURE_ONLY"},
            "endpoint_differences": {metric: delta for metric in promo.METRICS},
            "mass": {
                "full_path": {"pass": full_pass, "hard_limit_cm": 1.0e-6, "residual_cm": 0.0 if full_pass else 2.0e-6},
                "two_half_path": {"pass": split_pass, "hard_limit_cm": 1.0e-6, "residual_cm": 0.0 if split_pass else 2.0e-6},
            },
            "scope": {
                "compatible": True,
                "water_scope_complete": True,
                "optional_process_state_present": True,
                "process_scope_complete": process_complete,
                "allocation_mismatches": 0,
            },
            "temporal_numeric_limits": None,
            "normalized_temporal_score": None,
            "raw_observation_is_production_temporal_acceptance": False,
        }

    def test_valid_candidate_requires_frozen_hash(self):
        candidate = self.candidate()
        self.assertEqual(promo.validate_candidate(candidate), [])
        candidate["limits"]["h_cm"]["value"] = 2.0
        self.assertIn("frozen_profile_hash_mismatch", promo.validate_candidate(candidate))

    def test_calibration_validation_overlap_rejected(self):
        candidate = self.candidate()
        candidate["validation_observation_ids"] = ["cal-1"]
        candidate["frozen_profile_hash"] = promo.candidate_hash(candidate)
        self.assertIn("calibration_validation_overlap", promo.validate_candidate(candidate))

    def test_tolerance_substitution_origin_rejected(self):
        candidate = self.candidate()
        candidate["limits"]["gwl_cm"]["origin_class"] = "HARD_MASS_TOLERANCE"
        candidate["frozen_profile_hash"] = promo.candidate_hash(candidate)
        self.assertIn("limit_origin:gwl_cm", promo.validate_candidate(candidate))

    def test_raw_observation_requires_both_mass_paths(self):
        observation = self.observation(split_pass=False)
        errors = promo.validate_raw_observation(observation)
        self.assertIn("mass_gate:two_half_path", errors)
        self.assertIn("mass_residual:two_half_path", errors)

    def test_zero_limit_requires_exact_equality(self):
        self.assertEqual(promo.normalized_ratio(0.0, 0.0), 0.0)
        self.assertEqual(promo.normalized_ratio(1.0e-12, 0.0), float("inf"))

    def test_held_out_validation_must_all_pass(self):
        candidate = self.candidate()
        candidate["validation_observation_ids"] = ["val-1", "val-2"]
        candidate["frozen_profile_hash"] = promo.candidate_hash(candidate)
        observations = {"val-1": self.observation(delta=0.5), "val-2": self.observation(delta=1.5)}
        result = promo.validate_held_out_set(candidate, observations)
        self.assertTrue(result["complete"])
        self.assertFalse(result["accepted"])
        self.assertFalse(result["production_profile_promoted"])
        self.assertFalse(result["canonical_reference_admitted"])

    def test_optional_process_incomplete_never_accepts_complete_profile(self):
        candidate = self.candidate(optional_complete=True)
        result = promo.assess_observation(candidate, self.observation(delta=0.5, process_complete=False))
        self.assertTrue(result["metric_norm_pass"])
        self.assertFalse(result["accepted"])
        self.assertFalse(result["production_promotion_by_this_result"])

    def test_water_only_candidate_never_claims_complete_acceptance(self):
        candidate = self.candidate(optional_complete=False)
        result = promo.assess_observation(candidate, self.observation(delta=0.5, process_complete=True))
        self.assertTrue(result["metric_norm_pass"])
        self.assertFalse(result["accepted"])

    def test_validation_missing_is_fail_closed(self):
        candidate = self.candidate()
        result = promo.validate_held_out_set(candidate, {})
        self.assertFalse(result["complete"])
        self.assertFalse(result["accepted"])
        self.assertIn("validation_observation_missing:val-1", result["errors"])

    def test_raw_observation_cannot_carry_profile_limits(self):
        observation = self.observation()
        observation["temporal_numeric_limits"] = {"h_cm": 1.0}
        self.assertIn("raw_contains_temporal_limits", promo.validate_raw_observation(observation))


if __name__ == "__main__":
    unittest.main()
