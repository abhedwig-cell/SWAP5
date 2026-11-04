"""Refuse policy drift and invalid complete-corpus authority."""
import unittest
import film_refinement as owner
import film_refinement_candidate as candidate

class Boundary(unittest.TestCase):
 def setUp(self):self.source=(owner.f.ROOT/owner.SOURCE).read_text()
 def test_changed_integral_criterion_refused(self):
  with self.assertRaises(AssertionError):candidate.candidate(self.source.replace('1.0e-5_real64','1.0e-4_real64'))
 def test_changed_maximum_budget_refused(self):
  with self.assertRaises(AssertionError):candidate.candidate(self.source.replace('do level = 2, 24','do level = 2, 25'))
 def test_missing_refinement_seam_refused(self):
  with self.assertRaises(AssertionError):owner.observed(self.source.replace(owner.STEP,''),[])
 def test_duplicate_refinement_seam_refused(self):
  with self.assertRaises(AssertionError):owner.observed(self.source+owner.STEP,[])
 def test_incomplete_native_corpus_refused(self):
  with self.assertRaises(AssertionError):candidate.errors([],[],[])
 def test_missing_actual_trace_refused(self):
  with self.assertRaises(AssertionError):owner.receipts(b'',[])
 def test_forged_trace_content_refused(self):
  with self.assertRaises(AssertionError):owner.receipts(b'UNMEASURED PASS\n',[])
if __name__=='__main__':unittest.main(verbosity=2)
