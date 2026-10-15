"""Verify retained corrected crop/soil harvest qualification; no canonical admission."""
from pathlib import Path
import base64,hashlib,io,json,tarfile,struct
ROOT=Path(__file__).resolve().parents[2]
s=json.loads((ROOT/'integration/audits/F_KT_BOUNDARY_EVENT_STATUS_20261015.json').read_text())
current='execution_evidence'in s.get('retirement_stage',{})
e=s['retirement_stage']['execution_evidence']if current else s['harvest_joint_stage']['execution_evidence'];sha=lambda b:hashlib.sha256(b).hexdigest()
raw=base64.b64decode((ROOT/e['path']).read_bytes());assert sha(raw)==e['decoded_sha256']
with tarfile.open(fileobj=io.BytesIO(raw),mode='r:*')as t:
 files={m.name:t.extractfile(m).read()for m in t if m.isfile()}
members=json.loads(files['MANIFEST.json'])if current else e['members']
assert set(files)==set(members)|({'MANIFEST.json'}if current else set())
if current:assert sha(files['MANIFEST.json'])==e['manifest_sha256']
for p,digest in members.items():assert sha(files[p])==digest,p
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
assert ('HARVEST_CHEMICAL_ASSERTIONS='+('74'if current else'40')).encode()in small_out[0]
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
if current:
 recovery=json.loads(files['physical/BUILD_RECOVERY.json'])
 assert recovery['scope']=='Compiler-only successful prefix reuse; zero native inheritance'
 assert recovery['original_controller_sha256']==sha(files['physical/failed-provider-build/executed_runner.py'])
 failed=json.loads(files['physical/failed-provider-build/events.json'])
 assert failed[-1]['returncode']!=0 and all(x['category']=='compile'for x in failed)
 assert recovery['reused_compile_events']==len(failed)-1
 for p,digest in e['source_sha256'].items():assert sha((ROOT/p).read_bytes())==digest,p
 predecessor=s['harvest_joint_stage']['execution_evidence']
 predecessor_raw=base64.b64decode((ROOT/predecessor['path']).read_bytes())
 assert sha(predecessor_raw)==predecessor['decoded_sha256']
 with tarfile.open(fileobj=io.BytesIO(predecessor_raw),mode='r:*')as prior:
  for opt in ['O0','O2']:
   assert len(physical['runs'][opt]['drivers'])==10
   for name in ['harvest-restart.bin','harvest-expected.bin','harvest-fresh.bin','harvest-expected.bin.opaque']:
    member='physical/'+opt+'/'+name
    assert files[member]==prior.extractfile(member).read(),member
 for opt in ['O0','O2']:
  row=physical['runs'][opt]['drivers']['test_rotation_joint']
  assert row['fresh_compact_and_successor_identity']and len(row['compact_decoder_negatives'])==12
  pending=files['physical/'+opt+'/rotation-restart.bin']
  retired=files['physical/'+opt+'/rotation-expected.bin.retired']
  nodes=struct.unpack_from('<i',pending,152)[0];history=struct.unpack_from('<i',pending,156)[0]
  water_end=160+16*nodes+16+(8*nodes if history else 0)
  assert pending[8:water_end]==retired[8:water_end], 'retirement changed complete accepted water'
  end=files['physical/'+opt+'/rotation-expected.bin']
  for name in ['rotation-fresh.bin','rotation-expected.bin.opaque','rotation-from-retired.bin','rotation-from-fallow.bin','rotation-successor-roundtrip.bin']:
   assert files['physical/'+opt+'/'+name]==end,name
  assert end==files['physical/O0/rotation-expected.bin']
else:
 # Historical failed phase-forgery proof remains part of predecessor evidence.
 old=json.loads(files['rejected-first/phase-negative.json']);assert not old['detected_by_decoder']and old['exit']!=0
 recovery=json.loads(files['physical/COMPLETED_O0_RECOVERY.json'])
 assert recovery['scope'].startswith('Terminal O0 science reused')
 assert recovery['original_controller_sha256']==sha(files['physical/executed_runner.original.py'])
assert (ROOT/'src/kernel/mod_kernel_transactions.f90').read_bytes()==files['sources/src/kernel/mod_kernel_transactions.f90']
assert sha((ROOT/'src/kernel/mod_kernel_transactions.f90').read_bytes())=='3c7ebd554d85934e2885997b124cda318680b79941444025dd820c4dd5fa34de'
print(json.dumps(dict(status='RETAINED_CROP_SOIL_HARVEST_NATIVE_AND_ORIGINAL_THERMAL_VERIFIED',
 owner_assertions_per_optimization=3700,chemical_assertions_per_optimization=74 if current else 40,
 forged_phase_and_budget_native_negatives_per_optimization=6,original_base_endpoints_preserved=True,
 original_thermal_endpoints_preserved=True,retirement_fallow_successor_native_identity=current,
 compact_decoder_negatives_per_optimization=12 if current else 0,kernel_exact_canonical=True,canonical_admission=False),indent=2))
