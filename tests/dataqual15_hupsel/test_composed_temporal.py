"""Actual cap-only transformation and inherited numerical-boundary policies."""
import json,unittest
import composed_temporal as run

class Policy(unittest.TestCase):
    def test_exact_original_cap_only(self):
        raw=b'forcing=17\r\n DTMAX = 0.01 ! accepted\r\nDTMIN=1e-6\r\n'
        for cap in run.CAPS:self.assertEqual(run.cap_input(raw,cap),raw.replace(b'0.01',str(cap).encode()))
    def test_duplicate_refused(self):
        with self.assertRaises(AssertionError):run.cap_input(b'DTMAX=.01\nDTMAX=.01\n',.005)
    def test_missing_refused(self):
        with self.assertRaises(AssertionError):run.cap_input(b'DTMIN=.01\n',.005)
    def test_nonoriginal_refused(self):
        with self.assertRaises(AssertionError):run.cap_input(b'DTMAX=.005\n',.005)
    def test_unselected_cap_refused(self):
        with self.assertRaises(AssertionError):run.cap_input(b'DTMAX=.01\n',.001)
    def test_explicit_scope(self):
        reg=json.loads((run.BASE/run.REG).read_text());self.assertEqual(reg['selected']['caps'],list(run.CAPS));self.assertEqual(reg['selected']['capture_days'],list(run.DAYS))
        for k in ('production_admission','whole_scientific_admission','migration_complete'):self.assertIs(reg[k],False)

if __name__=='__main__':unittest.main()
