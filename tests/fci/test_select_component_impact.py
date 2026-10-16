#!/usr/bin/env python3
"""Fast negative/positive selection checks; no SWAP build or scientific run."""
import importlib.util
import pathlib
import unittest
import subprocess
import tempfile
from unittest.mock import patch

MODULE_PATH = pathlib.Path(__file__).with_name("select_component_impact.py")
spec = importlib.util.spec_from_file_location("component_impact", MODULE_PATH)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class RossFastImpactSelection(unittest.TestCase):
    def test_direct_and_unknown_requires_review(self):
        self.assertEqual(mod.classify(["src/solver/mod_rossfast_d3r_table_kernel.f90", "src/runtime/unknown.f90"])[0], "REVIEW_REQUIRED")

    def test_path_traversal_requires_review(self):
        self.assertEqual(mod.classify(["src/crop/../../solver/unknown.f90"])[0], "REVIEW_REQUIRED")

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

class ImpactEntrypoint(unittest.TestCase):
    def run_shell(self, *args):
        return subprocess.run(["bash", "tests/fci/run_fci_canonical_p2e05_moving_preservation.sh", *args], cwd=mod.ROOT, capture_output=True, text=True)

    def test_actual_preflight_exits_before_selection(self):
        import json
        p = self.run_shell("--plan-rossfast-impact", "952d6dc157d9548ced6c84f2564666e29ff7e56c")
        self.assertEqual(p.returncode, 0, p.stderr)
        report = json.loads(p.stdout)
        self.assertEqual(report['decision'], 'REVIEW_REQUIRED')
        self.assertFalse(report['full_fci_pass'])
        self.assertFalse(report['test_pass'])

    def test_missing_base_refused(self):
        self.assertEqual(self.run_shell("--plan-rossfast-impact").returncode, 2)

    def test_extra_argument_refused(self):
        self.assertEqual(self.run_shell("--plan-rossfast-impact", "HEAD", "extra").returncode, 2)

    def test_invalid_git_ref_refused(self):
        import json
        p = self.run_shell("--plan-rossfast-impact", "not-a-real-ref-1250")
        self.assertEqual(p.returncode, 2)
        self.assertEqual(json.loads(p.stdout)['decision'], 'REVIEW_REQUIRED')

    def test_default_still_requires_selection(self):
        p = self.run_shell()
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('selection', p.stdout + p.stderr)

    def test_rename_retains_solver_preimage(self):
        with tempfile.TemporaryDirectory() as d:
            root = pathlib.Path(d)
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
            git('init', '-q')
            git('config', 'user.email', 'test@example.invalid')
            git('config', 'user.name', 'Test')
            old = 'src/solver/mod_rossfast_d3r_table_kernel.f90'
            (root / old).parent.mkdir(parents=True)
            (root / old).write_text('module example\nend module\n')
            git('add', '.')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD')
            new = 'src/crop/moved.f90'
            (root / new).parent.mkdir(parents=True)
            git('mv', old, new)
            git('commit', '-qm', 'rename')
            with patch.object(mod, 'ROOT', root):
                paths = mod.changed_paths(base, 'HEAD')
            self.assertIn(old, paths)
            self.assertIn(new, paths)
            self.assertEqual(mod.classify(paths)[0], 'SELECT_FOCUSED_ROSSFAST')

if __name__ == "__main__":
    unittest.main()
