"""Actual positive and corrupt/partial/foreign scientific seal controls."""
import base64,hashlib,importlib.util,io,json,pathlib,tarfile,tempfile,unittest
from unittest.mock import patch
p=pathlib.Path(__file__).with_name('verify_low_air_successor.py');s=importlib.util.spec_from_file_location('successor',p);v=importlib.util.module_from_spec(s);s.loader.exec_module(v)
class Controls(unittest.TestCase):
 def test_actual_complete(self):self.assertEqual(v.verify_successor()['highest_programs'],12)
 def mutate(self,change):
  raw=base64.b64decode((v.ROOT/v.CAPSULE).read_bytes())
  with tarfile.open(fileobj=io.BytesIO(raw))as t:files={n:t.extractfile(n).read()for n in t.getnames()}
  change(files);files['INDEX.json']=(json.dumps({k:hashlib.sha256(x).hexdigest()for k,x in files.items()if k!='INDEX.json'})+'\n').encode()
  out=io.BytesIO()
  with tarfile.open(fileobj=out,mode='w:xz')as t:
   for k,x in files.items():h=tarfile.TarInfo(k);h.size=len(x);t.addfile(h,io.BytesIO(x))
  # Re-seal in the test to exercise semantic checks after checksum acceptance.
  raw=out.getvalue()
  with tempfile.TemporaryDirectory()as tmp:
   p=pathlib.Path(tmp)/'negative.b64';p.write_bytes(base64.b64encode(raw))
   with patch.object(v,'CAPSULE',str(p)),patch.object(v,'CAPSULE_SHA',hashlib.sha256(raw).hexdigest()):
    with self.assertRaises((ValueError,AssertionError)):v.verify_successor()
 def test_foreign_source(self):
  def change(f):d=json.loads(f['OWNER.json']);d['source_tree']='0'*40;f['OWNER.json']=json.dumps(d).encode()
  self.mutate(change)
 def test_partial_matrix(self):
  def change(f):p='final-current-qualification/qual-o0/RESULTS.json';d=json.loads(f[p]);d['runs'].pop();f[p]=json.dumps(d).encode()
  self.mutate(change)
 def test_changed_assertions(self):
  def change(f):p='final-current-qualification/qual-o2/candidate.f90';f[p]=f[p].replace(b'head_diff<=1.e-6_real64',b'head_diff<=1.e-3_real64')
  self.mutate(change)
 def test_partial_coupling(self):
  self.mutate(lambda f:f.__setitem__('coupling-final.stdout',f['coupling-final.stdout'].replace(b'FGC25_test_fgc25_multiswap_commit_O0=PASS',b'MISSING')))
 def test_stale_direct_input(self):
  def change(f):p='disabled-span-fixed/RESULTS.json';d=json.loads(f[p]);d['records'][0]['inputs']['src/runtime/mod_canonical_contracts.f90']='0'*64;f[p]=json.dumps(d).encode()
  self.mutate(change)
if __name__=='__main__':unittest.main()
