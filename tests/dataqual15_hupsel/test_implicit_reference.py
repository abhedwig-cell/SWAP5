"""No tuning or oracle promotion from a reference-family convergence screen."""
import copy,json,unittest
import implicit_reference as r

class Policy(unittest.TestCase):
    def levels(self):return [[dict(DATE=str(i),TREDWET='.003')for i in range(585)]for _ in range(3)]
    def test_self_convergence_cannot_promote_oracle(self):
        x=r.screen(self.levels());self.assertTrue(x['research_family_self_convergence_screen_pass'])
        for k in ('original_oracle_replaced','original_reference_accuracy_qualified','production_admission','whole_scientific_admission'):self.assertIs(x[k],False)
    def test_same_unchanged_bound(self):
        x=self.levels();x[2][584]['TREDWET']=str(.003+2*r.BOUND);a=r.screen(x);self.assertFalse(a['research_family_self_convergence_screen_pass']);self.assertEqual(a['unchanged_bound_cm'],r.BOUND)
    def test_missing_day_refused(self):
        x=self.levels();x[1].pop()
        with self.assertRaises(AssertionError):r.screen(x)
    def test_wrong_date_refused(self):
        x=self.levels();x[2][-1]['DATE']='foreign'
        with self.assertRaises(AssertionError):r.screen(x)
    def test_nonfinite_refused(self):
        x=self.levels();x[0][0]['TREDWET']='NaN'
        with self.assertRaises(AssertionError):r.screen(x)
    def test_unselected_cap_refused(self):
        with self.assertRaises(AssertionError):r.inputs({},.00001)
    def test_registration_preserves_oracle(self):
        x=json.loads((r.BASE/r.REG).read_text())
        for k in ('original_oracle_replaced','production_admission','whole_scientific_admission','migration_complete'):self.assertIs(x[k],False)

if __name__=='__main__':unittest.main()
