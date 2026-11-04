"""Refuse unbounded source substitutions and invalid independent oracle inputs."""
import base64,gzip,json,unittest
import film_accuracy as f

class Boundary(unittest.TestCase):
 def setUp(self):
  c=json.loads((f.ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text())
  self.source=gzip.decompress(base64.b64decode(c['gzip_base64'])).decode()
 def test_exact_seam_reversible(self):
  changed=f.adapted_source(self.source)
  self.assertEqual(changed.replace(f.USE,'').replace(f.SEAM,''),self.source.replace('\r\n','\n'))
 def test_missing_source_seam(self):
  with self.assertRaises(AssertionError):f.adapted_source(self.source.replace(f.ANCHOR.rstrip(),'missing anchor'))
 def test_duplicate_source_seam(self):
  with self.assertRaises(AssertionError):f.adapted_source(self.source+'\n'+f.ANCHOR)
 def test_unexpected_driver(self):
  with self.assertRaises(AssertionError):f.adapted_driver('not the pinned original driver')
 def test_nonfinite_inputs(self):
  for poison in ('NaN','Inf','-Inf'):
   with self.subTest(poison=poison),self.assertRaises(AssertionError):f.film([poison]*41)
 def test_incomplete_profile_coverage(self):
  with self.assertRaises(AssertionError):f.frames(b'0 1\n')
 def test_incomplete_node_state(self):
  with self.assertRaises(AssertionError):f.film(['1']*40)
 def test_saturated_branch_retained(self):
  row=['1']*41;row[11]='0'
  self.assertEqual(f.film(row),0)
 def test_extremely_dry_branch_retained(self):
  row=['1']*41;row[11]='-100001';row[22]='2';row[12]='1'
  self.assertEqual(float(f.film(row)),1e-8)
 def test_invalid_active_constitutive_input(self):
  row=['1']*41;row[11]='-10';row[22]='2';row[12]='1';row[24]='0'
  with self.assertRaises(AssertionError):f.film(row)
if __name__=='__main__':unittest.main(verbosity=2)
