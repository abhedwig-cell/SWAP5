import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
ADMISSION = ROOT / "tests" / "multiswap" / "fmq14_fsi02_admission.json"
STATUS = ROOT / "tests" / "multiswap" / "fmq14_status.json"


class Fmq14AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.admission = json.loads(ADMISSION.read_text())
        cls.status = json.loads(STATUS.read_text())

    def test_lineage_is_exact(self):
        self.assertEqual(self.admission["lineage"]["fmq13_head"], "871f4062caf490fc244db5c61693dc9a7c620f83")
        self.assertEqual(self.admission["lineage"]["fsi02_head"], "da1d5da0d909c5ce55efa17507b805bffd6b82f9")
        self.assertEqual(self.admission["lineage"]["fsi02_tested_postimage"], "9715465216edb400cbcd125a8572a1498a6b0211")

    def test_source_blobs_are_pinned(self):
        pins = self.admission["source_blob_pins"]
        self.assertEqual(pins["integration/f-si/F-SI02_QUALIFICATION.json"], "d29e6944cb342c47ab06d61faaa4378d79719c69")
        self.assertEqual(pins["src/solver/mod_soil_water_solver_contract.f90"], "57b51997d28807fbe2da1b2e5bf654fc4167adb9")
        self.assertEqual(pins["src/solver/mod_reference_richards_workspace.f90"], "f35fc559aec8462313d9e9b6c95171983b3cf8ef")

    def test_common_layer_capabilities_are_admitted(self):
        adm = self.admission["fsi02_admission"]
        self.assertTrue(adm["qualified"])
        self.assertTrue(adm["common_contract_compiles_o0_o2"])
        self.assertEqual(adm["workspace_reset_and_scratch_poisoning"], "PASS")
        self.assertEqual(adm["workspace_isolation_threads"], [1, 2, 4, 8])
        self.assertEqual(adm["warm_start_reset_not_physical_state"], "PASS")

    def test_workspace_is_not_promoted_to_column_state(self):
        ws = self.admission["fsi02_admission"]["workspace"]
        self.assertTrue(ws["worker_owned"])
        self.assertFalse(ws["persistent_per_logical_column"])
        self.assertTrue(ws["explicit_reset"])
        self.assertTrue(ws["explicit_poison"])
        self.assertTrue(ws["warm_start_separate_from_physical_state"])

    def test_real_reference_solver_claims_remain_closed(self):
        adm = self.admission["fsi02_admission"]
        self.assertFalse(adm["reference_richards_binding_qualified"])
        self.assertFalse(adm["reference_richards_reentrancy_qualified"])
        self.assertFalse(adm["unrounded_physical_water_balance_identity_qualified"])
        self.assertFalse(adm["solver_route_iteration_identity_qualified"])
        self.assertFalse(adm["parallel_multiswap_backend_qualified"])
        self.assertFalse(adm["interface_tangent_algorithm_implemented"])

    def test_matrix_coverage_is_unchanged(self):
        effect = self.admission["coverage_effect"]
        self.assertEqual(effect["synthetic_executable_before"], 27)
        self.assertEqual(effect["synthetic_executable_after"], 27)
        self.assertEqual(effect["real_physics_executable_before"], 0)
        self.assertEqual(effect["real_physics_executable_after"], 0)
        self.assertEqual(effect["production_runtime_qualified_before"], 0)
        self.assertEqual(effect["production_runtime_qualified_after"], 0)
        self.assertEqual(effect["promotions"], [])

    def test_fvq09_checkpoint_is_not_admitted(self):
        obs = self.admission["fvq09_observation"]
        self.assertFalse(obs["admitted"])
        self.assertFalse(self.status["downstream_observation"]["fvq09_qualified"])

    def test_closures_retain_open_reference_or_runtime_requirements(self):
        closures = {item["id"]: item for item in self.admission["common_layer_prerequisite_closures"]}
        for requirement in ("P03", "P05", "P06", "P16", "P18", "P19", "PFX01"):
            self.assertIn(requirement, closures)
            self.assertTrue(closures[requirement]["closed"])
            self.assertTrue(closures[requirement]["open"])


if __name__ == "__main__":
    unittest.main()
