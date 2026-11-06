import copy,json,unittest
from unittest.mock import patch
import matrix_thermal_production as p

class ThermalAdmission(unittest.TestCase):
 def test_complete_current_source(self):self.assertTrue(p.guard())
 def test_actual_dirty_and_untracked_source_refusals(self):
  target=p.ROOT/p.SOURCE;original=target.read_bytes()
  try:
   target.write_bytes(original+b'\n! qualification-only dirty-source refusal\n')
   with self.assertRaises(AssertionError):p.guard()
  finally:target.write_bytes(original)
  probe=p.ROOT/'src/__s5mt_owned_scope_probe__.f90';assert probe.resolve().parent==(p.ROOT/'src').resolve() and not probe.exists()
  try:
   with probe.open('xb') as stream:stream.write(b'! unknown production owner\n')
   with self.assertRaises(AssertionError):p.guard()
  finally:probe.unlink()
 def test_old_status_promotion_refused(self):
  original=p.Path.read_text
  def changed(path,*args,**kwargs):
   raw=original(path,*args,**kwargs)
   if path==p.ROOT/p.STATUS:
    record=json.loads(raw);record['unreviewed_old_owner_promotion']=True;return json.dumps(record)
   return raw
  with patch.object(p.Path,'read_text',new=changed):
   with self.assertRaises(AssertionError):p.guard()
 def test_status_boolean_type_change_refused(self):
  original=p.Path.read_text
  def changed(path,*args,**kwargs):
   raw=original(path,*args,**kwargs)
   if path==p.ROOT/p.STATUS:
    record=json.loads(raw);record[p.KEY]['whole_scientific_admission']=0;return json.dumps(record)
   return raw
  with patch.object(p.Path,'read_text',new=changed):
   with self.assertRaises(AssertionError):p.guard()
 def test_scope_refusals(self):
  cases={
   'origin':lambda r:r.update(predecessor='0'*40),
   'scope':lambda r:r.update(scope='ALL_SCIENCE'),
   'phase':lambda r:r.update(phase='SOURCE_ONLY'),
   'science':lambda r:r.update(whole_scientific_admission=True),
   'windows':lambda r:r.update(windows_path_scope='UNICODE'),
   'abi':lambda r:r.update(binary_abi='PORTABLE'),
   'dirsync':lambda r:r.update(posix_stage6='SUCCESS_OR_PRECOMMIT_ONLY'),
   'win_stage6':lambda r:r.update(windows_stage6='NEW_GUARANTEE'),
   'private':lambda r:r['private_canonical'].update(tree='0'*40),
   'build':lambda r:r['build_canonical'].update(success=0),
   'old_failure':lambda r:r['build_canonical'].update(broad_mc_verdict='SUCCESS'),
   'postimage':lambda r:r.update(postimage_sha256='0'*64),
   'delta':lambda r:r['production_delta'].update({'src/extra.f90':{}}),
   'bridge':lambda r:r['bridge_restore'].pop(p.ENTRY),
   'tree':lambda r:r['predecessor_production_trees'].update(app='0'*40),
   'gate':lambda r:r['gate_source_sha256'].pop(p.ENTRY),
   'evidence':lambda r:r['qualified_artifact_records'].pop(next(iter(r['qualified_artifact_records']))),
  }
  original=json.loads
  for name,mutate in cases.items():
   def changed(raw,*args,**kwargs):
    record=original(raw,*args,**kwargs)
    if isinstance(record,dict) and record.get('scope')=='SAME_PLATFORM_S5MT0001_NATIVE_LOGICAL_AND_RESTART_PUBLICATION':record=copy.deepcopy(record);mutate(record)
    return record
   with self.subTest(name=name),patch.object(p.json,'loads',side_effect=changed):
    with self.assertRaises(AssertionError):p.guard()
if __name__=='__main__':unittest.main()
