"""Actual current source guard and independently mutated admission records."""
import copy,json,unittest
from unittest.mock import patch
import native_n_production as p
class Admission(unittest.TestCase):
 def test_actual_current_source_guard(self):self.assertTrue(p.guard())
 def test_record_corruptions(self):
  mutations={
   'wrong_predecessor':lambda r:r.update(predecessor='0'*40),
   'whole_science':lambda r:r.update(whole_scientific_admission=True),
   'broaden_source':lambda r:r['production_delta'].update({'src/kernel/extra.f90':{}}),
   'broaden_bridge':lambda r:r['bridge_restore'].update({'app/extra.f90':{}}),
   'wrong_preimage':lambda r:r['bridge_restore'][p.SOURCES[0]].update(before='0'*40),
   'wrong_postimage':lambda r:r['bridge_restore'][p.SOURCES[0]].update(after='0'*40),
   'wrong_old_tree':lambda r:r['predecessor_production_trees'].update(src='0'*40),
   'dropped_gate':lambda r:r['gate_source_sha256'].pop(p.ENTRY),
   'wrong_gate':lambda r:r['gate_source_sha256'].update({p.ENTRY:'0'*64}),
  }
  loads=json.loads
  for name,mutate in mutations.items():
   def changed(raw,*a,**k):
    r=loads(raw,*a,**k)
    if isinstance(r,dict)and'gate_source_sha256'in r:r=copy.deepcopy(r);mutate(r)
    return r
   with self.subTest(name=name),patch.object(p.json,'loads',side_effect=changed):
    with self.assertRaises(AssertionError):p.guard()
if __name__=='__main__':unittest.main()
