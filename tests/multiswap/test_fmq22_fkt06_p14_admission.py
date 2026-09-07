#!/usr/bin/env python3
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
OVERLAY = ROOT / "tests/multiswap/fmq22_fkt06_p14_admission.json"
STATUS = ROOT / "tests/multiswap/fmq22_status.json"
MATRIX = ROOT / "tests/multiswap/qualification_matrix.json"
FORTRAN = ROOT / "tests/multiswap/test_fmq22_p14_optional_state.f90"


class Fmq22Admission(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.overlay = json.loads(OVERLAY.read_text())
        cls.status = json.loads(STATUS.read_text())
        cls.matrix = json.loads(MATRIX.read_text())
        cls.source = FORTRAN.read_text()

    def test_exact_lineage_and_fkt06_pins(self):
        self.assertEqual(self.status["fmq_parent"]["commit"], "ae843506cd0d5ed54a550ef75aaf9c322959d1d3")
        fkt = self.overlay["fkt06"]
        self.assertEqual(fkt["qualification_head"], "42872c266bc6f4fbf6815b1facbc3ed5d64df19a")
        self.assertEqual(fkt["tested_postimage"], "80a68dea3bfa45d7e8d533ec5a67fc89bdb786db")
        self.assertEqual(fkt["qualification_blob"], "75cc6d399facdb6bb8303ca905ac8056aeda3b2c")
        self.assertEqual(fkt["contract_blob"], "64f285ac6ae89297ca221048c2ff55cc580e3492")
        self.assertEqual(fkt["gate_blob"], "7c19f062efae19fb3d1c73b7f9a104bc013bd982")
        self.assertFalse(fkt["production_source_changed"])

    def test_matrix_p14_exact_minimums(self):
        row = next(item for item in self.matrix["entries"] if item["id"] == "P14")
        req = self.overlay["p14_matrix_requirement"]
        self.assertEqual(row["min_columns"], 2)
        self.assertEqual(row["min_workers"], 1)
        self.assertEqual(row["fixture"], "paired-module-off-on-layout")
        self.assertEqual(row["expected_result"], req["expected_result"])
        self.assertEqual(row["mass_gate"], req["mass_gate"])
        self.assertEqual(row["determinism"], req["determinism"])

    def test_two_column_gate_meets_p14_shape(self):
        gate = self.overlay["fmq22_executable_gate"]
        self.assertEqual(gate["columns"], 2)
        self.assertEqual(gate["workers"], 1)
        self.assertTrue(gate["paired_module_off_on"])
        self.assertEqual(gate["inactive_dynamic_payload_bytes_expected"], 0)
        self.assertEqual(gate["shared_immutable_parameter_objects_expected"], 1)
        for token in (
            "type(kernel_committed_state_t) :: columns(2)",
            "call make_seed(seed, .false., 0)",
            "call make_seed(seed, .true., 17)",
            "module-off column allocates zero optional continuation payload",
            "immutable parameters shared by reference",
            "F-MQ22_P14_TWO_COLUMN_GATE PASS",
        ):
            self.assertIn(token, self.source)

    def test_only_p14_synthetic_promotes(self):
        effect = self.overlay["coverage_effect"]
        self.assertEqual(effect["synthetic_executable_before"], 27)
        self.assertEqual(effect["synthetic_executable_after"], 28)
        self.assertEqual(effect["real_physics_executable_before"], 0)
        self.assertEqual(effect["real_physics_executable_after"], 0)
        self.assertEqual(effect["production_runtime_qualified_before"], 0)
        self.assertEqual(effect["production_runtime_qualified_after"], 0)
        self.assertEqual(effect["promotions"], ["P14:SYNTHETIC_EXECUTABLE"])

    def test_real_and_runtime_claims_stay_closed(self):
        nonclaims = set(self.overlay["hard_nonclaims"])
        self.assertIn("real B1.10 P14 physical execution", nonclaims)
        self.assertIn("production MultiSWAP runtime", nonclaims)
        self.assertIn("macropore production admission", nonclaims)
        self.assertIn("full SWAP mass identity", nonclaims)
        self.assertIn("parallel real HeadCalc reentrancy", nonclaims)
        self.assertIn("production reference admission", nonclaims)

    def test_pending_downstream_is_context_only(self):
        context = self.overlay["context_not_evidence"]
        self.assertFalse(context["fsi07_qualified"])
        self.assertFalse(context["fmr01_qualified"])
        self.assertFalse(context["fvq13_qualified"])

    def test_checkpoint_status_precedes_qualification(self):
        self.assertTrue(self.status["persisted"])
        if not self.status["qualified"]:
            self.assertFalse(self.status["tested"])
            self.assertEqual(self.status["status"], "PERSISTED_FKT06_P14_ADMISSION_CANDIDATE")
        else:
            self.assertTrue(self.status["tested"])
            self.assertEqual(self.status["status"], "QUALIFIED_FKT06_P14_SYNTHETIC_PROMOTED")


if __name__ == "__main__":
    unittest.main(verbosity=2)
