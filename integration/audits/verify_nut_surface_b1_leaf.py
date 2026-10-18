"""Verify exact current direct evidence; never authorizes canonical admission."""
from pathlib import Path
import base64,hashlib,io,json,tarfile
ROOT=Path(__file__).resolve().parents[2]
CAPSULES=[
 ('integration/audits/evidence/MC_NUT01_SURFACE_B1_ROOT_LEAF_DIAGNOSTICS_20261018.tar.xz.b64','37c4e96371b2263d12ace289d77f06a406359ac53d6dae2002ed4aa10c00501e'),
 ('integration/audits/evidence/MC_NUT01_SURFACE_B1_GROSS_BOUNDARY_20261018.tar.xz.b64','d0df8d58305370867c53d956b8324577a9e05f18511b343408203b27e38a1db2'),
]
def capsule(path,digest):
 raw=base64.b64decode((ROOT/path).read_bytes());assert hashlib.sha256(raw).hexdigest()==digest,'evidence bytes changed'
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as archive:
  members=archive.getmembers();names=[m.name for m in members]
  assert len(names)==len(set(names))and all(m.isfile()and not m.name.startswith('/')and '..'not in Path(m.name).parts for m in members)
  payload={m.name:archive.extractfile(m).read()for m in members}
 manifest=json.loads(payload.pop('MANIFEST.json'));assert set(payload)==set(manifest)
 for path,data in payload.items():assert hashlib.sha256(data).hexdigest()==manifest[path],path
 return payload

def verify():
 files=[capsule(*c)for c in CAPSULES]
 # The first capsule's owner proof is explicitly superseded, not projected
 # through an old reader: the second contains freshly compiled current inputs.
 expected=[
  (0,'surface-leaf-preservation-qualified','POND_STABLE_EMPTYING_AND_PREVIOUS_BYTES_O0_O2_PASS_NOT_ADMITTED'),
  (0,'surface-leaf-full-trace-qualified','POND_ACTUAL_TRACE_DIRECT_PASS_NOT_ADMITTED'),
  (1,'surface-gross-direct-current','SURFACE_N_B1_DIRECT_PASS_NOT_INTEGRATED'),
  (1,'surface-gross-boundary-current','DIRECT_PASS'),
  (1,'surface-gross-mineral-current','DIRECT_PASS'),
 ]
 for index,directory,status in expected:
  payload=files[index];result=json.loads(payload[directory+'/result.json']);assert result['status']==status
  inputs=result.get('input_sha256',result.get('inputs'));assert inputs
  for path,digest in inputs.items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,('changed bounded proof input',path)
  events=json.loads(payload[directory+'/events.json']);assert events and all(e['returncode']==0 for e in events)
  for opt in ['O0','O2']:
   compiled=[e for e in events if e['category']in ['compile','direct_compile']and'-'+opt in e['command']]
   assert compiled and all('-fcheck=all'in e['command']and'-ffpe-trap=invalid,zero,overflow'in e['command']for e in compiled)
  if directory=='surface-gross-boundary-current':
   assert result['o0_o2_endpoint_identity']
   for opt in ['O0','O2']:assert 'REACTIVE_B1_GROSS_BOTTOM_LATERAL_OUTFLOW_LITERAL_AND_DEFAULT_ATOMIC=PASS'in result['runs'][opt]['direct_stdout']
 old=files[1]['predecessor/mineral_owner.f90'];assert hashlib.sha256(old).hexdigest()=='409acdd4eff33183b7735681294b177322b8add16fc49182fd27d4ecdc280842'
 text=old.decode();a=text.index(' subroutine apply_mineral_day_transfer(');head,tail=text[:a],text[a:]
 before='   if(outflow>0d0.and.(in_bottom>0d0.or.in_lateral>0d0))return'
 after='''   ! Corrected B1 reactive candidates already book the gross boundary inputs
   ! and outputs in the existing original analytical chemistry. Retain the old
   ! bounded-mode eligibility restriction and every water/N acceptance gate.
   if(outflow>0d0.and.(in_bottom>0d0.or.in_lateral>0d0).and..not.state%p%surface_n_enabled)return'''
 assert tail.count(before)==1
 assert(ROOT/'src/process/mod_b111_soil_n_mineral_owner.f90').read_text()==head+tail.replace(before,after),'unregistered owner change'
 return dict(status='SURFACE_B1_CURRENT_LEAF_GROSS_AND_DIRECT_EVIDENCE_PASS_NOT_ADMITTED',proofs=[d for _,d,_ in expected],multiyear_qualified=False,canonical_admission=False,decoded_sha256=[d for _,d in CAPSULES])
if __name__=='__main__':print(json.dumps(verify(),indent=2))
