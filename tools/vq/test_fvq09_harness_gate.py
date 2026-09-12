import copy
import json
import tempfile
import unittest
from pathlib import Path

from tools.vq import fvq09_asset_bundle as assets
from tools.vq import fvq09_harness_gate as gate
from tools.vq import fvq09_observation as observation


class FVQ09AssetContractTests(unittest.TestCase):
    def test_directory_manifest_is_deterministic_and_content_bound(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "b.txt").write_bytes(b"B")
            (root / "a.txt").write_bytes(b"A")
            first = assets.directory_manifest(root)
            second = assets.directory_manifest(root)
            self.assertEqual(first["manifest_sha256"], second["manifest_sha256"])
            self.assertEqual([x["path"] for x in first["entries"]], ["a.txt", "b.txt"])
            (root / "a.txt").write_bytes(b"changed")
            third = assets.directory_manifest(root)
            self.assertNotEqual(first["manifest_sha256"], third["manifest_sha256"])

    def test_directory_manifest_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "real.txt").write_text("x", encoding="utf-8")
            (root / "link.txt").symlink_to(root / "real.txt")
            with self.assertRaisesRegex(ValueError, "symlink_not_allowed"):
                assets.directory_manifest(root)

    def test_external_directory_candidate_cannot_self_admit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "swap.swp").write_text("case", encoding="utf-8")
            spec = {"required_anchor_files": ["swap.swp"], "admitted_manifest_sha256": None, "admitted_file_count": None}
            result = assets.validate_external_directory(root, spec, "CASE")
            self.assertFalse(result["admitted"])
            self.assertEqual(result["status"], "BLOCKED_NOT_INDEPENDENTLY_ADMITTED")

    def test_external_directory_exact_independent_admission_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "swap.swp").write_text("case", encoding="utf-8")
            candidate = assets.directory_manifest(root)
            spec = {
                "required_anchor_files": ["swap.swp"],
                "admitted_manifest_sha256": candidate["manifest_sha256"],
                "admitted_file_count": candidate["file_count"],
            }
            result = assets.validate_external_directory(root, spec, "CASE")
            self.assertTrue(result["admitted"])
            self.assertEqual(result["status"], "PASS_ADMITTED")


class FVQ09GateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = gate.load_json("integration/f-vq/F-VQ09_ASSET_BUNDLE_CONTRACT.json")
        cls.matrix = gate.load_json("integration/f-vq/F-VQ09_ADMISSION_MATRIX.json")
        cls.status = gate.load_json("integration/f-vq/F-VQ09_STATUS.json")
        cls.probe = gate.read("tools/vq/fvq09_real_b1_10_temporal_probe.f90")
        cls.runner = gate.read("tools/vq/run_fvq09_real_temporal_probe.sh")

    def test_exact_contract_is_accepted(self):
        self.assertTrue(all(gate.validate_contract(copy.deepcopy(self.contract)).values()))

    def test_contract_rejects_wrong_production_source(self):
        x = copy.deepcopy(self.contract)
        x["qualified_production_source_head"] = "0" * 40
        self.assertFalse(gate.validate_contract(x)["production_source_exact"])

    def test_matrix_preserves_blocked_real_execution(self):
        qualified = self.status.get("qualified") is True
        self.assertTrue(all(gate.validate_matrix(copy.deepcopy(self.matrix), qualified).values()))
        x = copy.deepcopy(self.matrix)
        x["claims"][6]["claim_qualified"] = True
        self.assertFalse(gate.validate_matrix(x, qualified)["blocked_flags_false"])

    def test_probe_requires_same_trial_capsule_restore(self):
        self.assertTrue(all(gate.validate_probe(self.probe).values()))
        x = self.probe.replace("call restore_b1_10_legacy_trial_capsule(start_capsule)", "! removed", 1)
        self.assertFalse(gate.validate_probe(x)["split_restores_same_capsule"])

    def test_runner_validates_assets_before_materialization(self):
        self.assertTrue(all(gate.validate_runner(self.runner).values()))
        x = self.runner.replace("python \"$ROOT/tools/vq/fvq09_asset_bundle.py\" validate-bundle", "# validation removed")
        self.assertFalse(gate.validate_runner(x)["validates_before_materialize"])


class FVQ09ObservationTests(unittest.TestCase):
    def _probe_text(self, full_residual="1.0E-8", split_residual="-2.0E-8"):
        values = {key: "0.0" for key in observation.REAL_KEYS}
        values.update({
            "T0_DAYS": "100.25", "TMID_DAYS": "100.75", "T1_DAYS": "101.25",
            "PREFIX_DAYS": "0.25", "DURATION_DAYS": "1.0",
            "HARD_MASS_LIMIT_CM": "1.0E-6",
            "FULL_RESIDUAL_CM": full_residual,
            "SPLIT_RESIDUAL_CM": split_residual,
        })
        ints = {
            "COMPATIBLE": "1", "WATER_SCOPE_COMPLETE": "1",
            "OPTIONAL_PROCESS_STATE_PRESENT": "1", "PROCESS_SCOPE_COMPLETE": "0",
            "ALLOCATION_MISMATCHES": "0",
        }
        lines = [f"{key}={values[key]}" for key in sorted(values)]
        lines += [f"{key}={ints[key]}" for key in sorted(ints)]
        lines.append("FVQ09_REAL_TEMPORAL_PROBE_PASS")
        return "\n".join(lines) + "\n"

    def _files(self, root: Path, probe_text: str):
        probe = root / "probe.log"; probe.write_text(probe_text, encoding="utf-8")
        bundle = root / "bundle.json"; bundle.write_text(json.dumps({
            "bundle_admitted": True,
            "b0": {"observed_sha256": gate.B0_SHA},
            "ttutil": {"candidate_manifest_sha256": "a" * 64},
            "hupsel_case": {"candidate_manifest_sha256": "b" * 64},
        }), encoding="utf-8")
        materialization = root / "materialization.json"; materialization.write_text(json.dumps({
            "status": "PASS_MATERIALIZED_QUALIFIED_PHYSICAL_SOURCE",
            "materialized_source_manifest_sha256": "c" * 64,
        }), encoding="utf-8")
        compiler = root / "compiler.txt"; compiler.write_text("GNU Fortran test", encoding="utf-8")
        return probe, bundle, materialization, compiler

    def test_raw_observation_has_no_temporal_acceptance(self):
        with tempfile.TemporaryDirectory() as tmp:
            paths = self._files(Path(tmp), self._probe_text())
            result = observation.build_observation(*paths, optimization="O0", harness_commit="d" * 40)
            self.assertIsNone(result["temporal_numeric_limits"])
            self.assertIsNone(result["normalized_temporal_score"])
            self.assertTrue(result["mass"]["full_path"]["pass"])
            self.assertFalse(result["scope"]["process_scope_complete"])

    def test_observation_rejects_mass_violation(self):
        with tempfile.TemporaryDirectory() as tmp:
            paths = self._files(Path(tmp), self._probe_text(full_residual="2.0E-6"))
            with self.assertRaisesRegex(ValueError, "hard_mass_gate_failed"):
                observation.build_observation(*paths, optimization="O2", harness_commit="d" * 40)


if __name__ == "__main__":
    unittest.main()
