#!/usr/bin/env python3
"""Fast negative/positive selection checks; no SWAP build or scientific run."""
import importlib.util
import pathlib
import unittest

MODULE_PATH = pathlib.Path(__file__).with_name("select_component_impact.py")
spec = importlib.util.spec_from_file_location("component_impact", MODULE_PATH)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class RossFastImpactSelection(unittest.TestCase):
    def test_crop_only(self):
        self.assertEqual(mod.classify(["src/crop/mod_crop.f90"])[0], "NOT_SELECTED_IMPACT")

    def test_changed_boundary_values_in_process(self):
        self.assertEqual(mod.classify(["src/root/mod_root.f90"])[0], "NOT_SELECTED_IMPACT")

    def test_direct_solver(self):
        self.assertEqual(mod.classify(["src/solver/mod_rossfast_d3r_table_kernel.f90"])[0], "SELECT_FOCUSED_ROSSFAST")

    def test_shared_contract(self):
        self.assertEqual(mod.classify(["src/solver/mod_soil_water_solver_contract.f90"])[0], "SELECT_FOCUSED_ROSSFAST")

    def test_unclassified_runtime(self):
        self.assertEqual(mod.classify(["src/runtime/other_state.f90"])[0], "REVIEW_REQUIRED")

    def test_changed_fci_runner(self):
        self.assertEqual(mod.classify(["tests/fci/run_fci_canonical_p2e05_moving_preservation.sh"])[0], "REVIEW_REQUIRED")

    def test_docs_only(self):
        self.assertEqual(mod.classify(["docs/science/note.md"])[0], "NOT_SELECTED_IMPACT")

    def test_mixed_change_conservative(self):
        self.assertEqual(mod.classify(["src/crop/crop.f90", "src/solver/mod_rossfast_d3r_table_kernel.f90"])[0], "SELECT_FOCUSED_ROSSFAST")

    def test_unknown_mixed_change(self):
        self.assertEqual(mod.classify(["src/crop/crop.f90", "src/adapter/another.f90"])[0], "REVIEW_REQUIRED")

if __name__ == "__main__":
    unittest.main()
