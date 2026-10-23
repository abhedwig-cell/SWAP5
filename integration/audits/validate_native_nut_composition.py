"""Reconcile the fresh SOL/NUT composition with the admitted thermal fallow oracle."""
import hashlib,json,runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PARENT='integration/audits/verify_nut_thermal_fallow_output.py'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def validate(files,reader=lambda p:(ROOT/p).read_bytes()):
 owner=runpy.run_path(str(ROOT/PARENT));prior=owner['capsule']()
 frozen=json.loads(files['thermal-canonical.json'])
 assert frozen['owner']['qualified']and len(frozen['controls'])==36
 assert frozen['canonical']=='02d1e527f4a3cc0a64ae9a600c134c10a14afc7d'
 current={p[len('nut-current/'):]:v for p,v in files.items()if p.startswith('nut-current/')}
 # Preserve the original component and predecessor authorities. Replace only
 # actual freshly executed cold, heat, saved and accepted-heat fallow records.
 composed=dict(prior)
 for source,target in [('cold/','build/cold/'),('thermal/','build/thermal/'),('saved/','cold/'),('fallow/','thermal/')]:
  for p,v in current.items():
   if p.startswith(source):composed[target+p[len(source):]]=v
 for prefix in ['build/cold','build/thermal','cold','thermal']:
  r=json.loads(composed[prefix+'/result.json'])
  for field in ['input_sha256','cold_input_sha256','thermal_input_sha256']:
   for p,h in r.get(field,{}).items():assert sha(reader(p))==h,('fresh NUT source',prefix,p)
  assert sha(composed[prefix+'/driver.f90'])==r['generated_driver_sha256']
  events=json.loads(composed[prefix+'/events.json'])
  assert events and all(e['returncode']==0 for e in events)
  for e in events:
   for stream in ['stdout','stderr']:assert prefix+'/'+e[stream]in composed
 component=json.loads(composed['component/result.json'])
 for p,h in component['input_sha256'].items():assert sha(reader(p))==h,('inherited source-exact residue component',p)
 result=owner['validate'](composed)
 result['cold_preservation']=owner['cold_validate'](composed)
 # Every physical output shared with the accepted canonical specimen must
 # remain byte exact, including generation memory and fresh-process endpoints.
 exact=[]
 for p,old in prior.items():
  if not p.startswith(('build/cold/','build/thermal/','cold/','thermal/')):continue
  if not p.rsplit('/',1)[-1].startswith(('endpoint','native.endpoint','default.endpoint','saved-roundtrip','deferred-roundtrip','saved-continue','deferred-continue')):continue
  if p.endswith(('.json','.f90','.o','.mod','.stdout','.stderr')):continue
  assert p in composed and composed[p]==old,('canonical thermal/cold physical drift',p)
  exact.append(p)
 assert len(exact)>100
 result.update(current_composition=True,exact_canonical_physical_files=len(exact),
  current_complete_builds=['cold O0/O2','thermal O0/O2'],
  fresh_saved_and_thermal_fallow=True,full_mc_nut01_closed=False)
 cycle=runpy.run_path(str(ROOT/'integration/audits/verify_nut_cycle_output.py'))
 old=cycle['capsule']();fresh=dict(old)
 for p,v in current.items():
  if p.startswith('cycle/'):fresh['qualified/'+p[len('cycle/'):]]=v
 receipt=json.loads(fresh['qualified/result.json'])
 for p,h in receipt['input_sha256'].items():assert sha(reader(p))==h,('fresh cycle source',p)
 result['cycle_output']=cycle['validate'](fresh)
 latest=json.loads(files['latest-canonical.json'])
 assert latest['canonical']=='d3986e2642ede0dc4ce2acd0194fc38807bf0adb'and latest['owner']['qualified']and len(latest['controls'])==53
 return result
