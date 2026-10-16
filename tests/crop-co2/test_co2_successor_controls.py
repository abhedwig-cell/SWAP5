import os,sys
from pathlib import Path
_swrd3=Path(__file__).resolve().parents[1]/'root-growth/check_swrd3_controls.py'
if (_swrd3.parents[1].parent/'src/runtime/mod_fmr_biomass_root_uptake_input.f90').exists():
 os.execv(sys.executable,[sys.executable,'-B',str(_swrd3)])
import copy,json,tempfile,unittest
from pathlib import Path
import verify_co2_successor as v
class Controls(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.source=v.verify_source();s=json.loads(v.STATUS.read_text());cls.record=s['evidence'];cls.data,cls.manifest=v.read_capsule(cls.record)
 def mutate(self,change):
  d=dict(self.data);r=json.loads(d['physical/RESULTS.json']);change(r);d['physical/RESULTS.json']=json.dumps(r).encode()
  with self.assertRaises((ValueError,KeyError)):v.validate_physical(d,self.manifest,self.source)
 def test_positive(self):v.validate_physical(self.data,self.manifest,self.source)
 def test_missing(self):self.mutate(lambda r:r['results'].pop())
 def test_duplicate(self):self.mutate(lambda r:r['results'].__setitem__(-1,copy.deepcopy(r['results'][0])))
 def test_failed(self):self.mutate(lambda r:r['results'][0].__setitem__('returncode',1))
 def test_nan_duration(self):self.mutate(lambda r:r['results'][0].__setitem__('wall_seconds',float('nan')))
 def test_stale_dependency(self):self.mutate(lambda r:r['source_inputs'].__setitem__(v.BOOT,'0'*64))
 def test_removed_dependency(self):self.mutate(lambda r:r['source_inputs'].pop(v.ATM))
 def test_missing_native(self):self.mutate(lambda r:r['events'].pop(next(i for i,e in enumerate(r['events'])if Path(e['command'][0]).name.startswith('test-'))))
 def test_flags(self):self.mutate(lambda r:next(e for e in r['events']if '-c'in e['command'])['command'].__setitem__(1,'-std=legacy'))
 def test_raw_output(self):
  d={k:(b'corrupt'if k.endswith('.stdout')else b)for k,b in self.data.items()}
  with self.assertRaises(ValueError):v.validate_physical(d,self.manifest,self.source)
 def test_foreign_source(self):
  with self.assertRaises(ValueError):v.validate_source(sorted([*v.PINS,'src/foreign.f90']),v.PINS,'ref','ref')
 def test_source_postimage(self):
  pins=dict(v.PINS);pins[v.BOOT]='0'*40
  with self.assertRaises(ValueError):v.validate_source(sorted(pins),pins,'ref','ref')
 def test_reference(self):
  with self.assertRaises(ValueError):v.validate_source(sorted(v.PINS),v.PINS,'changed','ref')
 def test_capsule(self):
  with tempfile.TemporaryDirectory()as t:
   p=Path(t)/'corrupt.b64';raw=(v.ROOT/self.record['path']).read_bytes();p.write_bytes((b'A'if raw[:1]!=b'A'else b'B')+raw[1:])
   with self.assertRaises(ValueError):v.read_capsule({**self.record,'path':str(p)})
if __name__=='__main__':unittest.main()
