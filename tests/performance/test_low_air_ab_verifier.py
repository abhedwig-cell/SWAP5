#!/usr/bin/env python3
"""Positive/negative controls using actually executed complete A/B records."""
import copy,importlib.util,json,pathlib,sys,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('verify',ROOT/'tools/performance/verify_low_air_ab.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
class Controls(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.out=pathlib.Path(self.tmp.name)
  self.source=pathlib.Path(sys.argv[1]);self.record=json.loads((self.source/'RESULTS.json').read_text())
  for p in self.source.glob('*.stdout'):(self.out/p.name).write_bytes(p.read_bytes())
 def tearDown(self):self.tmp.cleanup()
 def check(self,record):
  (self.out/'RESULTS.json').write_text(json.dumps(record));return v.verify(self.out)
 def test_complete(self):self.assertFalse(self.check(self.record)['canonical_admission'])
 def test_missing(self):
  r=copy.deepcopy(self.record);r['runs'].pop()
  with self.assertRaises(ValueError):self.check(r)
 def test_duplicate(self):
  r=copy.deepcopy(self.record);r['runs'].append(r['runs'][0])
  with self.assertRaises(ValueError):self.check(r)
 def test_failed(self):
  r=copy.deepcopy(self.record);r['runs'][0]['exit']=1
  with self.assertRaises(ValueError):self.check(r)
 def test_nonfinite_cost(self):
  r=copy.deepcopy(self.record);r['runs'][0]['wall_seconds']=float('nan')
  with self.assertRaises(ValueError):self.check(r)
 def test_drift(self):
  p=next(self.out.glob('*.stdout'));p.write_bytes(p.read_bytes()+b'drift')
  with self.assertRaises(ValueError):self.check(self.record)
 def test_incomplete(self):
  r=copy.deepcopy(self.record);r['complete_single_optimization_ab']=False
  with self.assertRaises(ValueError):self.check(r)
if __name__=='__main__':unittest.main(argv=[sys.argv[0]])
