"""The admission-route exception must never hide owned grass changes."""
import sys, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/vq'))
from select_grass_sprint import APP,ENTRY,POLICY,classify

class Selection(unittest.TestCase):
    def test_exact_route_only_needs_source_guard_not_science_rerun(self):
        r=classify([APP,ENTRY,'integration/dataqual15/STATUS.json'],True)
        self.assertFalse(r['run_grass']);self.assertTrue(r['requires_current_source_guard']);self.assertFalse(r['scientific_pass'])
    def test_any_physics_change_selected(self):self.assertTrue(classify(['src/process/grass.f90'],True)['run_grass'])
    def test_other_application_change_selected(self):self.assertTrue(classify(['app/solute_column/main.f90'],True)['run_grass'])
    def test_grass_test_change_selected(self):self.assertTrue(classify(['tests/dataqual15/qualify_mowing.py'],True)['run_grass'])
    def test_old_native_guard_change_selected(self):self.assertTrue(classify(['tests/dataqual15/verify_native_restart_admission.py'],True)['run_grass'])
    def test_grass_input_builder_change_selected(self):self.assertTrue(classify(['tools/solute/build_grass_startup.py'],True)['run_grass'])
    def test_stress_evidence_change_selected(self):self.assertTrue(classify(['integration/dataqual15/STRESS_EVIDENCE.tar.xz'],True)['run_grass'])
    def test_native_inventory_change_selected(self):self.assertTrue(classify(['integration/dataqual15/STATUS.json'],False)['run_grass'])
    def test_policy_changes_require_registered_guard(self):
        for path in POLICY:self.assertTrue(classify([path],True)['requires_current_source_guard'])
    def test_unrelated_metadata_is_not_inherited_pass(self):
        r=classify(['docs/science/note.md'],True);self.assertFalse(r['run_grass']);self.assertFalse(r['scientific_pass'])

if __name__=='__main__':unittest.main(verbosity=2)
