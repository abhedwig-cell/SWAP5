"""Compare immutable pre-Boesten proof to freshly qualified current proof."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OLD='2570ba6f43f67599fd62762e51112535ac316605'
sha=lambda b:hashlib.sha256(b).hexdigest()
def read(raw):
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:f={m.name:t.extractfile(m).read() for m in t.getmembers()}
 manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(v) for p,v in f.items()};return f
def assess():
 old64=subprocess.check_output(['git','show',OLD+':integration/mc-sol01/fct_accepted_trace/EVIDENCE.tar.xz.b64'],cwd=ROOT)
 oldraw=base64.b64decode(old64);assert sha(oldraw)=='e8167024768acfa76b99e1a87aa01561044e7e8675aaae6a41416997892a85cb'
 newraw=base64.b64decode((HERE/'EVIDENCE.tar.xz.b64').read_bytes());assert sha(newraw)=='662295833db1ecf70e666eb2272152e9f658df5b81a753bb5aafcd3c924309c8'
 old,new=read(oldraw),read(newraw);a=json.loads(old['water/execution.json']);b=json.loads(new['water/execution.json'])
 assert set(a['inputs'])==set(b['inputs']);changed={p:{'before':a['inputs'][p],'after':h} for p,h in b['inputs'].items() if a['inputs'][p]!=h}
 assert set(changed)=={'src/runtime/mod_fmr_serialized_reference_backend.f90'}
 for c in b['water_cases']:assert new['water/'+c['path']]==old['water/'+c['path']]
 a=json.loads(old['replay/execution.json']);b=json.loads(new['replay/execution.json']);assert a['inputs']==b['inputs']
 keys=['optimization','n','factor','exponent','shape'];prior={tuple(c[k] for k in keys):c for c in a['cases']}
 for c in b['cases']:assert new['replay/'+c['stdout']]==old['replay/'+prior[tuple(c[k] for k in keys)]['stdout']]
 assert new['VERIFICATION.json']==old['VERIFICATION.json']
 return dict(status='CURRENT_BOESTEN_WATER_AND_REPLAY_REQUALIFIED_EXACT',previous_published_head=OLD,previous_capsule_sha256=sha(oldraw),current_capsule_sha256=sha(newraw),
  changed_water_inputs=changed,unchanged_replay_inputs=True,water_cases_exact=12,replay_profiles_exact=72,independent_accuracy_result_exact=True,
  current_water_checkpoint=json.loads(new['water/execution.json'])['baseline'],current_replay_checkpoint=json.loads(new['replay/execution.json'])['baseline'],
  current_preservation_controls=json.loads(new['PRESERVATION.json'])['current_controls'],source_sha256=sha(Path(__file__).read_bytes()))
if __name__=='__main__':
 result=assess();(HERE/'CURRENT_RECONCILIATION.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
