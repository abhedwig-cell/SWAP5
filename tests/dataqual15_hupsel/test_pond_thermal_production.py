import copy,json,unittest
from unittest.mock import patch
import pond_thermal_production as p

class PondAdmission(unittest.TestCase):
 def test_complete_current_source(self):self.assertTrue(p.guard())
 def test_actual_dirty_source_refusal(self):
  path=p.ROOT/p.SOURCE;before=path.read_bytes()
  try:
   path.write_bytes(before+b'\n! qualification mutation\n')
   with self.assertRaises(AssertionError):p.guard()
  finally:path.write_bytes(before)
 def test_actual_unknown_source_refusal(self):
  path=p.ROOT/'src/__s5pt_scope_probe__.f90';assert not path.exists()
  try:
   with path.open('xb') as f:f.write(b'! unknown owner\n')
   with self.assertRaises(AssertionError):p.guard()
  finally:path.unlink()
 def test_scope_mutations_refused(self):
  cases=[lambda r:r.update(predecessor='0'*40),lambda r:r.update(scope='ALL_SCIENCE'),
   lambda r:r.update(phase='SOURCE_ONLY'),lambda r:r.update(whole_scientific_admission=True),
   lambda r:r.update(binary_abi='PORTABLE'),lambda r:r.update(windows_path_scope='UNICODE'),
   lambda r:r.update(posix_stage6='SUCCESS'),lambda r:r.update(pending_retry='DELETE_AND_RETRY'),
   lambda r:r.update(postimage_sha256='0'*64),lambda r:r['private_canonical_merges'].pop(),
   lambda r:r['production_delta'].update({'src/unknown.f90':{}}),lambda r:r['bridge_restore'].pop(p.ENTRY),
   lambda r:r['predecessor_production_trees'].update(app='0'*40),lambda r:r['gate_source_sha256'].pop(p.ENTRY),
   lambda r:r['frozen_authority'].pop(next(iter(r['frozen_authority'])))]
  original=json.loads
  for i,mutate in enumerate(cases):
   def changed(raw,*args,**kw):
    r=original(raw,*args,**kw)
    if isinstance(r,dict) and r.get('scope')=='SAME_PLATFORM_S5PT_NATIVE_LOGICAL_AND_PUBLICATION':r=copy.deepcopy(r);mutate(r)
    return r
   with self.subTest(case=i),patch.object(p.json,'loads',side_effect=changed):
    with self.assertRaises(AssertionError):p.guard()
 def test_previous_status_and_type_promotion_refused(self):
  original=p.Path.read_text
  for mode in ('old-owner','boolean-type'):
   def changed(path,*args,**kw):
    text=original(path,*args,**kw)
    if path==p.ROOT/p.STATUS:
     r=json.loads(text)
     if mode=='old-owner':r['unknown_previous_admission']=True
     else:r[p.KEY]['whole_scientific_admission']=0
     return json.dumps(r)
    return text
   with self.subTest(mode=mode),patch.object(p.Path,'read_text',new=changed):
    with self.assertRaises(AssertionError):p.guard()

if __name__=='__main__':unittest.main(verbosity=2)
