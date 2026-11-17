"""Verify bounded negative performance observations; never run models."""
from pathlib import Path
import hashlib,io,json,zipfile
root=Path(__file__).resolve().parent;sha=lambda b:hashlib.sha256(b).hexdigest();seal=json.loads((root/'SEAL.json').read_bytes());index=json.loads((root/'FILES.json').read_bytes());result=json.loads((root/'RESULT.json').read_bytes())
assert sha((root/'FILES.json').read_bytes())==seal['index_sha256'];assert sha((root/seal['archive']).read_bytes())==seal['sha256']
assert result['performance_goal_achieved'] is False and result['production_changes'] is False and result['tolerances_changed'] is False
parent=json.loads((root.parent/'nomacro-rc3-20261117/local-raw.index.json').read_bytes())['files']
def rows(z,path):return [{k:v for k,v in json.loads(s).items() if k not in ('column','revision')} for s in z.read(path).decode().splitlines()]
def native(z,path):
 with zipfile.ZipFile(io.BytesIO(z.read(path))) as t:return {k:t.read(k) for k in ('result.end','macro.bin')}
with zipfile.ZipFile(root/seal['archive']) as z:
 for name,h in index.items():assert sha(z.read(name))==h,name
 reference=rows(z,'boundary-full/0-baseline/daily.jsonl')
 assert sha(z.read('boundary-full/0-baseline/daily.jsonl'))==parent['saltfarm-O2-candidate-full/daily.jsonl']['sha256']
 assert len(reference)==1461
 for case,p in result['controls'].items():
  raw=json.loads(z.read(case+'/RESULT.json'));assert len(raw['runs'])==4
  for i,run in enumerate(raw['runs']):
   prefix=case+'/'+str(i)+'-'+run['mode'];data=rows(z,prefix+'/daily.jsonl');assert data==reference[:len(data)]
   assert all(d['committed'] and abs(d['independent_residual_cm'])<=1e-10 and abs(d['kernel_residual_cm'])<=1e-10 and abs(d.get('solute_independent_residual_mg_cm2',0))<=1e-10 for d in data)
   assert native(z,prefix+'/accepted-column-1-day-109.zip')==native(z,'boundary-full/0-baseline/accepted-column-1-day-109.zip')
   if case=='boundary-full':assert native(z,prefix+'/accepted-column-1-day-1461.zip')==native(z,'boundary-full/0-baseline/accepted-column-1-day-1461.zip')
  assert [v['seconds'] for v in raw['runs'] if v['mode']=='baseline']==p['baseline_seconds'];assert [v['seconds'] for v in raw['runs'] if v['mode']=='candidate']==p['candidate_seconds']
 original=json.loads(z.read('ORIGINAL_CURRENT.json'));assert original==result['same_session_original'];assert original['returncode']==100 and original['wall_seconds']<=original['cap_seconds']
 assert original['counts']['original']['newton_iterations']==77664 and original['counts']['RC3']['newton_iterations']==138089
print('ALL_NEGATIVE_PROBES_PHYSICAL_NATIVE_AND_ACTUAL_TIMINGS_VERIFIED_NO_SPEEDUP_CLAIM')
