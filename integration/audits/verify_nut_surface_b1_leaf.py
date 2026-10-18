"""Verify bounded leaf/direct evidence; never authorizes canonical admission."""
from pathlib import Path
import base64,hashlib,io,json,tarfile
ROOT=Path(__file__).resolve().parents[2]
CAPSULE='integration/audits/evidence/MC_NUT01_SURFACE_B1_ROOT_LEAF_DIAGNOSTICS_20261018.tar.xz.b64'
SHA256='37c4e96371b2263d12ace289d77f06a406359ac53d6dae2002ed4aa10c00501e'
def verify():
 raw=base64.b64decode((ROOT/CAPSULE).read_bytes())
 assert hashlib.sha256(raw).hexdigest()==SHA256,'evidence bytes changed'
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as archive:
  members=archive.getmembers();names=[m.name for m in members]
  assert len(names)==len(set(names))and all(m.isfile()and not m.name.startswith('/')and '..'not in Path(m.name).parts for m in members)
  payload={m.name:archive.extractfile(m).read()for m in members}
 manifest=json.loads(payload.pop('MANIFEST.json'))
 assert set(payload)==set(manifest)
 for path,data in payload.items():assert hashlib.sha256(data).hexdigest()==manifest[path],path
 expected={
  'surface-leaf-preservation-qualified':'POND_STABLE_EMPTYING_AND_PREVIOUS_BYTES_O0_O2_PASS_NOT_ADMITTED',
  'surface-leaf-full-trace-qualified':'POND_ACTUAL_TRACE_DIRECT_PASS_NOT_ADMITTED',
  'surface-direct-leaf-current':'SURFACE_N_B1_DIRECT_PASS_NOT_INTEGRATED',
 }
 for directory,status in expected.items():
  result=json.loads(payload[directory+'/result.json']);assert result['status']==status
  inputs=result.get('input_sha256',result.get('inputs'));assert inputs
  for path,digest in inputs.items():
   assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,('changed bounded proof input',path)
  events=json.loads(payload[directory+'/events.json']);assert events and all(e['returncode']==0 for e in events)
  assert all(any('-'+opt in e['command']for e in events if e['category']=='compile')for opt in ['O0','O2'])
 return {'status':'SURFACE_B1_CURRENT_LEAF_AND_DIRECT_EVIDENCE_PASS_NOT_ADMITTED','proofs':list(expected),'multiyear_qualified':False,'canonical_admission':False,'decoded_sha256':SHA256}
if __name__=='__main__':print(json.dumps(verify(),indent=2))
