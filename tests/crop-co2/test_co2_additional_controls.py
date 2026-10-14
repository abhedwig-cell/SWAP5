import copy,json,unittest
from unittest.mock import patch
import verify_co2_successor as v
class Controls(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  s=json.loads(v.STATUS.read_text());cls.record=s['additional_owner_evidence'];cls.data,cls.manifest=v.read_capsule(cls.record)
 def mutate(self,change=None,manifest_change=None):
  d=dict(self.data);m=copy.deepcopy(self.manifest)
  r=json.loads(d['additional/RESULTS.json'])
  if change:change(r)
  d['additional/RESULTS.json']=json.dumps(r).encode()
  if manifest_change:manifest_change(m)
  original=v.read_capsule
  def read(record):return(d,m)if record['path']==self.record['path']else original(record)
  with patch.object(v,'read_capsule',read),self.assertRaises((ValueError,KeyError)):v.verify_qualification()
 def test_positive(self):v.verify_qualification()
 def test_missing(self):self.mutate(lambda r:r['steps'].pop())
 def test_duplicate(self):self.mutate(lambda r:r['steps'].__setitem__(-1,copy.deepcopy(r['steps'][0])))
 def test_failed(self):self.mutate(lambda r:r['steps'][0].__setitem__('exit',1))
 def test_command(self):self.mutate(lambda r:r['steps'][0]['command'].append('--foreign'))
 def test_log(self):self.mutate(lambda r:r['steps'][0].__setitem__('stdout_sha256','0'*64))
 def test_source(self):self.mutate(lambda r:r['source'].__setitem__('source_tree','0'*40))
 def test_dependency(self):self.mutate(manifest_change=lambda m:m['dependency_blobs'].__setitem__(v.BOOT,'0'*40))
 def test_removed_dependency(self):self.mutate(manifest_change=lambda m:m['dependency_blobs'].pop('tests/fkt/test_fkt22_fmr_serialized_trajectory_runtime.f90'))
if __name__=='__main__':unittest.main()
