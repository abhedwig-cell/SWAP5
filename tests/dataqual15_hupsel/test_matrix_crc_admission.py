"""Actual complete postimage guard and corrupted source admission records."""
import copy,json,unittest
from unittest.mock import patch
import matrix_crc_admission as p
class MatrixAdmission(unittest.TestCase):
 def test_actual_postimage(self):self.assertTrue(p.guard())
 def test_record_mutations(self):
  cases={'predecessor':lambda r:r.update(predecessor='0'*40),'science':lambda r:r.update(whole_scientific_admission=True),'phase':lambda r:r.update(phase='SOURCE_ONLY'),'delta':lambda r:r['production_delta'].update({'src/extra.f90':{}}),'bridge':lambda r:r['bridge_restore'].update({'app/extra.f90':{}}),'before':lambda r:r['bridge_restore'][p.SOURCE].update(before='0'*40),'after':lambda r:r['bridge_restore'][p.SOURCE].update(after='0'*40),'old_tree':lambda r:r['predecessor_production_trees'].update(src='0'*40),'gate':lambda r:r['gate_source_sha256'].pop(p.ENTRY),'artifact':lambda r:r['qualified_artifact_records'].pop(next(iter(r['qualified_artifact_records'])))}
  loads=json.loads
  for name,mutate in cases.items():
   def changed(raw,*a,**k):
    r=loads(raw,*a,**k)
    if isinstance(r,dict)and'qualified_artifact_records'in r:r=copy.deepcopy(r);mutate(r)
    return r
   with self.subTest(name=name),patch.object(p.json,'loads',side_effect=changed):
    with self.assertRaises(AssertionError):p.guard()
if __name__=='__main__':unittest.main()
