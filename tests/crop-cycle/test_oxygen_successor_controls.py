"""Actual evidence/source corruption controls for this bounded admission successor."""
import copy,json,unittest
import verify_oxygen_successor as v
class Controls(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.source=v.verify_source();s=json.loads((v.ROOT/'integration/audits/MC_CROP01_OXYGEN_CYCLE_STATUS.json').read_text());cls.record=s['evidence'];cls.data,cls.manifest=v.read_capsule(cls.record)
 def mutate(self,change):
  data=dict(self.data);r=json.loads(data['cycle-physical-attempt2/RESULTS.json']);change(r);data['cycle-physical-attempt2/RESULTS.json']=json.dumps(r).encode()
  with self.assertRaises((ValueError,KeyError)):v.validate_physical(data,self.manifest,self.source)
 def test_positive(self):v.validate_physical(self.data,self.manifest,self.source)
 def test_partial(self):self.mutate(lambda r:r['results'].pop())
 def test_duplicate(self):self.mutate(lambda r:r['results'].__setitem__(-1,copy.deepcopy(r['results'][0])))
 def test_failed(self):self.mutate(lambda r:r['results'][0].__setitem__('returncode',1))
 def test_missing_native(self):self.mutate(lambda r:r['events'].pop(next(i for i,x in enumerate(r['events'])if x['command'][0].split('/')[-1].startswith('test-'))))
 def test_duplicate_native(self):
  def f(r):
   ids=[i for i,x in enumerate(r['events'])if x['command'][0].split('/')[-1].startswith('test-')];r['events'][ids[-1]]=copy.deepcopy(r['events'][ids[0]])
  self.mutate(f)
 def test_flags(self):self.mutate(lambda r:next(x for x in r['events']if '-c' in x['command'])['command'].__setitem__(1,'-std=legacy'))
 def test_nan_cost(self):self.mutate(lambda r:r['results'][0].__setitem__('wall_seconds',float('nan')))
 def test_stale_dependency(self):self.mutate(lambda r:r['source_inputs'].__setitem__(v.BOOT,'0'*64))
 def test_removed_dependency(self):self.mutate(lambda r:r['source_inputs'].pop('src/process/mod_root_water_uptake_process.f90'))
 def test_corrupt_raw(self):
  d={k:b for k,b in self.data.items()if not(k.startswith('cycle-physical-attempt2/')and k.endswith('.stdout'))}
  with self.assertRaises(ValueError):v.validate_physical(d,self.manifest,self.source)
 def test_corrupt_capsule(self):
  record=dict(self.record);record['decoded_sha256']='0'*64
  with self.assertRaises(ValueError):v.read_capsule(record)
 def test_foreign_source(self):
  old=v.subprocess.check_output(['git','show',v.BASE+':'+v.BOOT],cwd=v.ROOT);new=(v.ROOT/v.BOOT).read_bytes()
  with self.assertRaises(ValueError):v.validate_source(old,new,[v.BOOT,'src/solver/foreign.f90'],'ref','ref')
 def test_changed_postimage(self):
  old=v.subprocess.check_output(['git','show',v.BASE+':'+v.BOOT],cwd=v.ROOT);new=(v.ROOT/v.BOOT).read_bytes()
  with self.assertRaises(ValueError):v.validate_source(old,new+b'\n',[v.BOOT],'ref','ref')
 def test_reference(self):
  old=v.subprocess.check_output(['git','show',v.BASE+':'+v.BOOT],cwd=v.ROOT);new=(v.ROOT/v.BOOT).read_bytes()
  with self.assertRaises(ValueError):v.validate_source(old,new,[v.BOOT],'newref','oldref')
if __name__=='__main__':unittest.main()
