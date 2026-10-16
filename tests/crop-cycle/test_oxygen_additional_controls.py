"""Fail-closed additional owner evidence mutation controls using actual raw data."""
import copy,json,unittest
from unittest.mock import patch
import verify_oxygen_successor as v
class Controls(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  s=json.loads((v.ROOT/'integration/audits/MC_CROP01_OXYGEN_CYCLE_STATUS.json').read_text());cls.record=s['additional_owner_evidence'];cls.data,cls.manifest=v.read_capsule(cls.record);cls.original=v.read_capsule
 def mutate(self,change=None,manifest_change=None):
  data=dict(self.data);m=copy.deepcopy(self.manifest)
  if change:
   r=json.loads(data['additional/RESULTS.json']);change(r);data['additional/RESULTS.json']=json.dumps(r).encode()
  if manifest_change:manifest_change(m)
  def read(record):
   return (data,m)if record['path']==self.record['path']else type(self).original(record)
  with patch.object(v,'read_capsule',side_effect=read):
   with self.assertRaises((ValueError,KeyError)):v.verify_qualification()
 def test_positive(self):v.verify_qualification()
 def test_partial(self):self.mutate(lambda r:r['steps'].pop())
 def test_duplicate(self):self.mutate(lambda r:r['steps'].__setitem__(-1,copy.deepcopy(r['steps'][0])))
 def test_failed(self):self.mutate(lambda r:r['steps'][0].__setitem__('exit',1))
 def test_command(self):self.mutate(lambda r:r['steps'][0]['command'].append('--foreign'))
 def test_log(self):self.mutate(lambda r:r['steps'][0].__setitem__('stdout_sha256','0'*64))
 def test_source(self):self.mutate(lambda r:r['source'].__setitem__('source_tree','0'*40))
 def test_stale_dependency(self):self.mutate(manifest_change=lambda m:m['dependency_blobs'].__setitem__(v.BOOT,'0'*40))
 def test_removed_test_dependency(self):self.mutate(manifest_change=lambda m:m['dependency_blobs'].pop('tests/fkt/test_fkt22_fmr_serialized_trajectory_runtime.f90'))
if __name__=='__main__':unittest.main()
