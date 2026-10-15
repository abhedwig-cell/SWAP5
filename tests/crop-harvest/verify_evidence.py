"""Verify retained real-owner harvest evidence; no event or physical admission."""
from pathlib import Path
import base64,hashlib,io,json,tarfile
ROOT=Path(__file__).resolve().parents[2]
status=json.loads((ROOT/'integration/audits/F_KT_BOUNDARY_EVENT_STATUS_20261015.json').read_text())
e=status['harvest_owner_stage']['execution_evidence']
raw=base64.b64decode((ROOT/e['path']).read_bytes())
sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(raw)==e['decoded_sha256']
with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz')as t:
    files={m.name:t.extractfile(m).read()for m in t if m.isfile()}
assert set(files)==set(e['members'])
for p,digest in e['members'].items():assert sha(files[p])==digest,p
r=json.loads(files['final/result.json'])
assert r['status']=='HARVEST_OWNER_AND_INCUMBENT_CONTRACT_PASS_NOT_ADMITTED'
assert not r['dirty_scientific_surface']
for p,digest in r['inputs'].items():
    assert sha((ROOT/p).read_bytes())==digest,p
    assert sha(files['sources/'+p])==digest,p
assert all(x['exit']==0 for x in r['events'])
natives=[x for x in r['events']if x['category']=='native']
assert len(natives)==4
out=[files['final/'+x['stdout']]for x in natives]
assert out[0]==out[2] and out[1]==out[3]
assert b'WOFOST81_HARVEST_ASSERTIONS=3700' in out[0]
assert b'WOFOST81_HARVEST_OWNER_LITERAL_ORACLE=PASS' in out[0]
assert b'F_WOF_PP02_REPOSITORY_INTEGRATION_PASS' in out[1]
donor=files['donor/wofostnut.f90']
assert sha(donor)=='071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2'
s=donor.decode().replace('\r\n','\n')
a=s.index('            HarLosOrm_rt = wrt');b=s.index('\n        end if',a)
assert s[a:b] in files['sources/tests/crop-harvest/mod_harvest_oracle.f90'].decode()
strict=[x for x in r['events']if x['category']=='provider_compile'and any(
    p in x['command'] for p in [str(ROOT/'src/crop/mod_wofost81_crop_owner_state.f90'),
    str(ROOT/'src/crop/mod_wofost81_one_day_candidate.f90')])]
assert len(strict)==4 and all('-Werror'in x['command']for x in strict)
print(json.dumps(dict(status='RETAINED_HARVEST_OWNER_EXECUTION_VERIFIED',
    execution_commit=r['execution_commit'],assertions_per_optimization=3700,
    native_executions=4,canonical_admission=False,physical_event_publication=False),indent=2))
