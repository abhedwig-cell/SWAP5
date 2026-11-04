"""Reject mixed/default provenance and malformed measurement streams."""
import copy,hashlib,json,os,struct,tarfile,unittest,zlib
from pathlib import Path
import film_runtime as run
from film_runtime_profiles import profile4

class Boundary(unittest.TestCase):
 def setUp(self):
  self.base=Path(os.environ.get('FILM_RUNTIME_TEST_BASELINE',str(run.ROOT.parent/'film-runtime-20261104/baseline-O2'))).resolve()
  self.meta=json.loads((self.base/'BUILD.json').read_text())
 def test_actual_clean_baseline(self):run.validate_baseline(self.base,self.meta)
 def test_research_reuse_refused(self):
  bad=copy.deepcopy(self.meta);bad['build_mode']='verified-reuse'
  with self.assertRaises(AssertionError):run.validate_baseline(self.base,bad)
 def test_foreign_numerical_source_refused(self):
  bad=copy.deepcopy(self.meta);path=str(run.ROOT/run.counter.SOURCE);pin=bad['source_sha256'].pop(path);bad['source_sha256']['C:/foreign/numerical-source.f90']=pin
  with self.assertRaises(AssertionError):run.validate_baseline(self.base,bad)
 def test_unchecked_flags_refused(self):
  bad=copy.deepcopy(self.meta);bad['flags'].append('-ffast-math')
  with self.assertRaises(AssertionError):run.validate_baseline(self.base,bad)
 def test_mixed_optimization_refused(self):
  bad=copy.deepcopy(self.meta);bad['flags'].insert(0,'-O0')
  with self.assertRaises(AssertionError):run.validate_baseline(self.base,bad)
 def test_observer_source_does_not_mutate_root(self):
  src=(run.ROOT/run.counter.SOURCE).read_text();main=(run.ROOT/run.counter.MAIN).read_text()
  run.counter.kernel(run.counter.candidate.candidate(src));run.counter.main(main)
  self.assertEqual(src,(run.ROOT/run.counter.SOURCE).read_text());self.assertEqual(main,(run.ROOT/run.counter.MAIN).read_text())
 def test_actual_s5hr4_and_corruption_controls(self):
  meta=json.loads((run.BASE/'DEFAULT_DIAGNOSTIC_EVIDENCE_20261104.json').read_text());archive=run.BASE/'DEFAULT_DIAGNOSTIC_EVIDENCE_20261104.tar.xz'
  self.assertEqual(run.sha(archive),meta['archive_sha256']);name='O2/measurement/uninterrupted525/checkpoint.bin'
  with tarfile.open(archive)as t:raw=t.extractfile(name).read()
  self.assertEqual(hashlib.sha256(raw).hexdigest(),meta['files_sha256'][name]);self.assertEqual(profile4(raw)['day'],525)
  cases=[];bad=bytearray(raw);bad[-30]^=1;cases.append(bad)
  bad=bytearray(raw);bad[:8]=b'S5HR0003';struct.pack_into('=I',bad,len(bad)-4,zlib.crc32(bad[:-4]));cases.append(bad)
  bad=bytearray(raw);struct.pack_into('=d',bad,len(bad)-20,float('nan'));struct.pack_into('=I',bad,len(bad)-4,zlib.crc32(bad[:-4]));cases.append(bad)
  for bad in cases:
   with self.assertRaises(AssertionError):profile4(bytes(bad))
if __name__=='__main__':unittest.main(verbosity=2)
