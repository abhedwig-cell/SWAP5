"""Verify retained corrected crop/soil harvest qualification; no canonical admission."""
from pathlib import Path
import base64,hashlib,io,json,tarfile
ROOT=Path(__file__).resolve().parents[2]
s=json.loads((ROOT/'integration/audits/F_KT_BOUNDARY_EVENT_STATUS_20261015.json').read_text())
e=s['harvest_joint_stage']['execution_evidence'];sha=lambda b:hashlib.sha256(b).hexdigest()
raw=base64.b64decode((ROOT/e['path']).read_bytes());assert sha(raw)==e['decoded_sha256']
with tarfile.open(fileobj=io.BytesIO(raw),mode='r:*')as t:
 files={m.name:t.extractfile(m).read()for m in t if m.isfile()}
assert set(files)==set(e['members'])
for p,digest in e['members'].items():assert sha(files[p])==digest,p
small=json.loads(files['small/result.json']);physical=json.loads(files['physical/result.json']);heat=json.loads(files['thermal/result.json'])
assert small['status']=='HARVEST_OWNER_AND_INCUMBENT_CONTRACT_PASS_NOT_ADMITTED'
assert physical['status']=='PASS'and physical['incumbent_endpoints_identical']
assert heat['status']=='ORIGINAL_THERMAL_NATIVE_FRESH_EXECUTION_BYTE_PRESERVED'
for result,key in [(small,'inputs'),(physical,'input_sha256'),(heat,'inputs')]:
 for p,digest in result[key].items():
  assert sha((ROOT/p).read_bytes())==digest,p
  if not p.endswith(('.tar.gz.b64','.tar.xz.b64')):assert sha(files['sources/'+p])==digest,p
assert not small['dirty_scientific_surface']
for event in small['events']:assert event['exit']==0
small_out=[files['small/'+x['stdout']]for x in small['events']if x['category']=='native']
assert len(small_out)==6
assert small_out[:3]==small_out[3:]
assert b'HARVEST_CHEMICAL_ASSERTIONS=40'in small_out[0]
assert b'WOFOST81_HARVEST_ASSERTIONS=3700'in small_out[1]
assert b'F_WOF_PP02_REPOSITORY_INTEGRATION_PASS'in small_out[2]
pe=json.loads(files['physical/events.json']);assert all(x['returncode']==0 for x in pe)
for event in pe:
 for stream in ['stdout','stderr']:
  assert sha(files['physical/'+event[stream+'_file']])==event[stream+'_sha256']
for opt in ['O0','O2']:
 h=physical['runs'][opt]['drivers']['test_harvest_joint']
 assert h['water_record_unchanged']and len(h['decoder_negatives'])==6
 assert h['endpoint_sha256']==physical['runs']['O0']['drivers']['test_harvest_joint']['endpoint_sha256']
 assert files['physical/'+opt+'/harvest-expected.bin']==files['physical/'+opt+'/harvest-fresh.bin']==files['physical/'+opt+'/harvest-expected.bin.opaque']
for event in heat['events']:assert event['exit']==0
# The earlier external negative is a retained FAIL, never inherited PASS.
old=json.loads(files['rejected-first/phase-negative.json']);assert not old['detected_by_decoder']and old['exit']!=0
recovery=json.loads(files['physical/COMPLETED_O0_RECOVERY.json'])
assert recovery['scope'].startswith('Terminal O0 science reused')
assert recovery['original_controller_sha256']==sha(files['physical/executed_runner.original.py'])
assert (ROOT/'src/kernel/mod_kernel_transactions.f90').read_bytes()==files['sources/src/kernel/mod_kernel_transactions.f90']
assert sha((ROOT/'src/kernel/mod_kernel_transactions.f90').read_bytes())=='3c7ebd554d85934e2885997b124cda318680b79941444025dd820c4dd5fa34de'
print(json.dumps(dict(status='RETAINED_CROP_SOIL_HARVEST_NATIVE_AND_ORIGINAL_THERMAL_VERIFIED',
 owner_assertions_per_optimization=3700,chemical_assertions_per_optimization=40,
 forged_phase_and_budget_native_negatives_per_optimization=6,original_base_endpoints_preserved=True,
 original_thermal_endpoints_preserved=True,kernel_exact_canonical=True,canonical_admission=False),indent=2))
