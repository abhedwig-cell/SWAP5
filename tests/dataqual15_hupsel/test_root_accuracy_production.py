"""Real Git controls for the exact bounded numerical-profile source boundary."""
import json,subprocess,tempfile,unittest
from pathlib import Path
import root_accuracy_production as m

class Boundary(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(prefix='s5-thermal-boundary-');self.root=Path(self.temp.name)
  self.previous=(m.ROOT,m.BASE);m.ROOT=self.root
  m.git('init','-q');m.git('config','user.name','Fixture');m.git('config','user.email','fixture@example.invalid');m.git('config','core.autocrlf','false')
  for p in m.PATHS:self.write(p,'incumbent owner\n')
  for p in m.GATES:self.write(p,'protected gate\n')
  self.write('reference/input','original\n');self.write('integration/dataqual15/STATUS.json',json.dumps({'native_disk_restart_20261102':{'immutable':True}}))
  self.commit();m.BASE=m.git('rev-parse','HEAD')
  for p in m.PATHS:self.write(p,'bounded numerical successor\n')
  self.write('integration/dataqual15/STATUS.json',json.dumps({'native_disk_restart_20261102':{'immutable':True},m.KEY:{'scope':m.SCOPE}}))
  self.commit()
  self.record=dict(predecessor=m.BASE,whole_scientific_admission=False,profile='pressure-film-refined',thermal_tolerance_c=1e-5,
   production_delta={p:dict(before=m.blob(m.BASE,p),after=m.blob('HEAD',p))for p in m.PATHS},
   gate_sha256={p:m.sha((self.root/p).read_bytes())for p in m.GATES})
 def tearDown(self):m.ROOT,m.BASE=self.previous;self.temp.cleanup()
 def write(self,p,s):
  f=self.root/p;f.parent.mkdir(parents=True,exist_ok=True);f.write_text(s,encoding='utf-8',newline='\n')
 def commit(self):m.git('add','.');m.git('commit','-qm','fixture')
 def test_exact(self):m.guard(self.record)
 def test_unknown_production(self):
  self.write('src/unknown.f90','unknown\n');self.commit()
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_changed_postimage(self):
  self.write(next(iter(m.PATHS)),'changed\n');self.commit()
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_dirty_source(self):
  self.write(next(iter(m.PATHS)),'dirty\n')
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_untracked_source(self):
  self.write('src/unknown.f90','untracked\n')
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_gate_drift(self):
  self.write(m.ENTRY,'weakened\n')
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_old_authority_drift(self):
  self.write('integration/dataqual15/STATUS.json',json.dumps({m.KEY:{'scope':m.SCOPE}}))
  with self.assertRaises(AssertionError):m.guard(self.record)
 def test_science_promotion(self):
  self.record['whole_scientific_admission']=True
  with self.assertRaises(AssertionError):m.guard(self.record)

if __name__=='__main__':unittest.main(verbosity=2)
