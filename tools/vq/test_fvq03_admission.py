from __future__ import annotations

import unittest

from tools.vq import fvq03_admission as gate


class FVQ03AdmissionTests(unittest.TestCase):
    def test_fci13_status_is_exact_and_temporal_stays_blocked(self) -> None:
        checks = gate.check_fci13_status()
        self.assertTrue(all(checks.values()), checks)

    def test_failure_evidence_keeps_testdouble_boundary_explicit(self) -> None:
        checks = gate.check_failure_evidence()
        self.assertTrue(all(checks.values()), checks)

    def test_fvq02_verifier_layer_is_carried_forward_without_physics_promotion(self) -> None:
        checks = gate.check_fvq02_carry_forward()
        self.assertTrue(all(checks.values()), checks)

    def test_readiness_admits_status_contract_but_not_reference_execution(self) -> None:
        checks = gate.check_readiness()
        self.assertTrue(all(checks.values()), checks)

    def test_matrix_never_promotes_blocked_claims(self) -> None:
        checks = gate.validate_matrix(gate._json(gate.MATRIX))
        self.assertTrue(all(checks.values()), checks)

    def test_change_scope_is_qualification_only(self) -> None:
        checks = gate.check_change_scope()
        self.assertTrue(all(checks.values()), checks)


if __name__ == "__main__":
    unittest.main()
