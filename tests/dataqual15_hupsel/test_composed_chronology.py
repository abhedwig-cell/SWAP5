"""Analytical unequal-grid attribution and interval refusal boundaries."""
import json,unittest
import composed_chronology as c

class Intervals(unittest.TestCase):
    def test_actual_overlap_partition(self):
        a=[(0,.3,2,.4),(.3,1,2,.4)];b=[(0,.7,3,.9),(.7,1,3,.9)]
        cells=c.overlaps(a,b);self.assertEqual([(i,j)for i,j,_ in cells],[(0,0),(1,0),(1,1)]);self.assertAlmostEqual(sum(w for _,_,w in cells),1)
        r=c.algebra.attribution(a,b);self.assertAlmostEqual(r['potential_contribution_cm'],.25);self.assertAlmostEqual(r['stress_fraction_contribution_cm'],.25);self.assertAlmostEqual(r['total_delta_cm'],.5)
    def test_nonfinite_rate_refused(self):
        with self.assertRaises(AssertionError):c.validate_intervals([(0,1,2,float('nan'))])
    def test_missing_tail_refused(self):
        with self.assertRaises(AssertionError):c.validate_intervals([(0,.9,2,.4)])
    def test_duplicate_interval_refused(self):
        with self.assertRaises(AssertionError):c.validate_intervals([(0,1,2,.4),(0,1,2,.4)])
    def test_gap_refused(self):
        with self.assertRaises(AssertionError):c.validate_intervals([(0,.3,2,.4),(.4,1,2,.4)])
    def test_excess_loss_refused(self):
        with self.assertRaises(AssertionError):c.validate_intervals([(0,1,1,1.01)])
    def test_no_promotion_registered(self):
        r=json.loads((c.BASE/c.REG).read_text());self.assertIn('hupsel_rotation_restart',r['scope_reconciliation'])
        for k in ('production_admission','whole_scientific_admission','migration_complete'):self.assertIs(r[k],False)

if __name__=='__main__':unittest.main()
