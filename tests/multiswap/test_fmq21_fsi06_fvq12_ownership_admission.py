import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ADMISSION = ROOT / 'tests/multiswap/fmq21_fsi06_fvq12_ownership_admission.json'
STATUS = ROOT / 'tests/multiswap/fmq21_status.json'


class Fmq21AdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.admission = json.loads(ADMISSION.read_text())
        cls.status = json.loads(STATUS.read_text())

    def test_exact_lineage_and_matrix_pin(self):
        a = self.admission
        self.assertEqual(a['matrix_blob'], '4b53b71375833ae94e788da8b6eab0dc2e6c1dad')
        self.assertEqual(a['matrix_rows'], 35)
        self.assertEqual(a['fsi06']['qualification_head'], 'd0f0cc0817f2e2b8ca55dd90752cfda2f7b0e6e8')
        self.assertEqual(a['fsi06']['tested_checkpoint'], 'dfed799dbc0930bdf5218e713934ea0f148e3872')
        self.assertEqual(a['fvq12']['qualification_head'], '7cd06ba606429c891dab7f355a85b58ca56a3bca')

    def test_fsi06_history_isolation_is_admitted(self):
        f = self.admission['fsi06']
        self.assertTrue(f['headcalc_hidden_save_removed'])
        self.assertTrue(f['reporting_history_explicit'])
        self.assertTrue(f['common_reference_history_call_local'])
        self.assertTrue(f['serial_focused_aba_identity'])
        self.assertTrue(f['common_workspace_parallel_isolation'])

    def test_real_headcalc_parallel_stays_fail_closed(self):
        f = self.admission['fsi06']
        self.assertFalse(f['full_real_headcalc_parallel_reentrancy'])
        self.assertEqual(f['parallel_blocker'], 'SHARED_LEGACY_GLOBAL_TRANSLATION')
        self.assertIn('BLOCKED', self.admission['requirement_effects']['P03'])
        self.assertIn('BLOCKED', self.admission['requirement_effects']['P18'])

    def test_fvq12_nonconflict_only(self):
        v = self.admission['fvq12']
        self.assertTrue(v['fkt05_source_bound_admitted'])
        self.assertTrue(v['fsi05_source_bound_admitted'])
        self.assertTrue(v['contractual_nonconflict_qualified'])
        self.assertFalse(v['composed_runtime_qualified'])
        self.assertEqual(v['production_reference_admission'], 'BLOCKED_FAIL_CLOSED')
        self.assertFalse(v['production_multiswap_admission'])

    def test_matrix_minimums_prevent_order_promotion(self):
        p02 = self.admission['requirement_effects']['P02']
        self.assertIn('8_COLUMNS_4_WORKERS', p02)
        self.assertIn('FMR_SCHEDULER_STILL_REQUIRED', self.admission['requirement_effects']['R06'])

    def test_no_coverage_promotion(self):
        c = self.admission['coverage_effect']
        self.assertEqual(c['synthetic_executable_before'], c['synthetic_executable_after'])
        self.assertEqual(c['real_physics_executable_before'], c['real_physics_executable_after'])
        self.assertEqual(c['production_runtime_qualified_before'], c['production_runtime_qualified_after'])
        self.assertEqual(c['promotions'], [])

    def test_hard_nonclaims_preserved(self):
        claims = ' | '.join(self.admission['hard_nonclaims'])
        for token in ('real HeadCalc', 'production MultiSWAP', 'full unrounded SWAP', 'production B1.10'):
            self.assertIn(token, claims)

    def test_status_lifecycle_is_qualification_only(self):
        s = self.status
        self.assertEqual(s['mode'], 'QUALIFICATION_ONLY')
        self.assertFalse(s['production_source_changed'])
        self.assertTrue(s['persisted'])
        self.assertIn(s['qualified'], (False, True))
        if s['qualified']:
            self.assertTrue(s['tested'])
            self.assertEqual(s['status'], 'QUALIFIED_FSI06_HISTORY_FVQ12_NONCONFLICT_ADMITTED_NO_MATRIX_ROW_PROMOTION')


if __name__ == '__main__':
    unittest.main()
