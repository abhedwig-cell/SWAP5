from __future__ import annotations
import copy, json, unittest
from pathlib import Path
from tools.vq import fvq06_fci18_handoff_gate as gate
ROOT=Path(__file__).resolve().parents[2]
def load(rel): return json.loads((ROOT/rel).read_text(encoding="utf-8"))
class Fvq06Fci18HandoffGateTests(unittest.TestCase):
    def test_current_qualified_scope_keeps_final_exit_blocked(self):
        self.assertTrue(all(gate.validate_readiness(load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json")).values()))
    def test_promoting_final_exit_without_gate_commit_is_rejected(self):
        d=copy.deepcopy(load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json")); d["fci18_final_exit_handoff_qualified"]=True; self.assertFalse(gate.validate_readiness(d)["final_exit_blocked"])
    def test_promoting_downstream_release_is_rejected(self):
        d=copy.deepcopy(load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json")); d["downstream_release_admitted_by_fvq06"]=True; self.assertFalse(gate.validate_readiness(d)["no_fvq_release"])
    def test_blocked_final_promotion_claim_cannot_be_promoted(self):
        m=copy.deepcopy(load("integration/f-vq/F-VQ06_ADMISSION_MATRIX.json")); [c.update(claim_qualified=True) for c in m["claims"] if c["claim_id"]=="FVQ06-C06"]; self.assertFalse(gate.validate_matrix(m)["final_promotion_not_claimed"])
    def test_source_bound_fci18_delta_contains_no_production_or_reference_source(self):
        p=gate.changed(gate.FCI17_BASIS,gate.FCI18_SOURCE); self.assertFalse(any(x.startswith("src/") for x in p)); self.assertFalse(any(x.startswith("reference/swap-4.3.1/") for x in p))
    def test_pr_merge_failure_non_authoritative_push_qualified(self):
        d=load("integration/f-vq/F-VQ06_FCI18_HANDOFF_READINESS.json"); self.assertEqual(d["qualification_handoff"]["workflow_result"],"SUCCESS"); self.assertTrue(all(x["authoritative_for_fci18_qualification"] is False for x in d["superseded_or_non_authoritative_failure_observations"]))
    def test_fvq05_reference_and_temporal_blocks_preserved(self):
        e=load("integration/f-vq/evidence/F-VQ05_QUALIFICATION.json"); self.assertFalse(e["production_temporal_profile_qualified"]); self.assertFalse(e["real_b1_10_temporal_acceptance_qualified"]); self.assertEqual(e["canonical_reference_admission"],"BLOCKED_FAIL_CLOSED")
    def test_matrix_qualified_targets_and_blocks_exact(self):
        self.assertTrue(all(gate.validate_matrix(load("integration/f-vq/F-VQ06_ADMISSION_MATRIX.json")).values()))
if __name__=="__main__": unittest.main()
