import copy,json,unittest
from unittest.mock import patch
import generation_crc_admission as p
class GenerationAdmission(unittest.TestCase):
 def test_actual_postimage(self):self.assertTrue(p.guard())
 def test_record_mutations(self):
  source=sorted(p.SOURCES)[0]
  cases={'predecessor':lambda r:r.update(predecessor='0'*40),'science':lambda r:r.update(whole_scientific_admission=True),'phase':lambda r:r.update(phase='SOURCE_ONLY'),'delta':lambda r:r['production_delta'].update({'src/extra.f90':{}}),'bridge':lambda r:r['bridge_restore'].update({'app/extra.f90':{}}),'before':lambda r:r['bridge_restore'][source].update(before='0'*40),'after':lambda r:r['bridge_restore'][source].update(after='0'*40),'old_tree':lambda r:r['predecessor_production_trees'].update(src='0'*40),'gate':lambda r:r['gate_source_sha256'].pop(p.ENTRY),'artifact':lambda r:r['qualified_artifact_records'].pop(next(iter(r['qualified_artifact_records']))),'postimage':lambda r:r['qualified_full_postimage_sha256'].update({source:'0'*64}),'windows_scope':lambda r:r.update(windows_native_publication_admission=True),'platform':lambda r:r.update(scope='ALL_PLATFORMS_ALL_SCIENCE')}
  loads=json.loads
  for name,mutate in cases.items():
   def changed(raw,*a,**k):
    r=loads(raw,*a,**k)
    if isinstance(r,dict)and'qualified_artifact_records'in r:r=copy.deepcopy(r);mutate(r)
    return r
   with self.subTest(name=name),patch.object(p.json,'loads',side_effect=changed):
    with self.assertRaises(AssertionError):p.guard()
if __name__=='__main__':unittest.main()
