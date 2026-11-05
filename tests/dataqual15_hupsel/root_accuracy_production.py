"""Exact opt-in root numerical successor; no scientific tolerance promotion."""
import argparse,csv,hashlib,io,json,math,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='f0939f4cbc4410a9e7fd88c38e47f61310d39fb6'
SCOPE='integration/dataqual15_hupsel/ROOT_ACCURACY_PRODUCTION_SCOPE_20261105.json'
KEY='root_numerical_accuracy_successor_20261105'
ENTRY='tests/dataqual15/verify_current_native_admission.py'
PATHS={'app/solute_project/main.f90','src/process/mod_root_micro_de_willigen_process.f90',
 'src/physics/oxygen/mod_bartholomeus_waterfilm_independent.f90','src/physics/oxygen/mod_bartholomeus_waterfilm_provider.f90',
 'src/physics/oxygen/mod_bartholomeus_factor_provider.f90','src/runtime/mod_fmr_bartholomeus_execution.f90','src/runtime/mod_fmr_serialized_reference_backend.f90'}
GATES={ENTRY,'tests/dataqual15_hupsel/root_accuracy_production.py','tests/dataqual15_hupsel/root_accuracy_production_runtime.py',
 'tests/dataqual15_hupsel/qualify_root_accuracy_component.py','tests/dataqual15_hupsel/root_accuracy_component_driver.f90',
 'tests/dataqual15_hupsel/qualify_root_profile_controls.py','tests/dataqual15_hupsel/seal_root_accuracy_production.py',
 'tests/dataqual15_hupsel/qualify_root_runtime_preservation.py','tests/dataqual15_hupsel/test_root_accuracy_production.py','tests/dataqual15_hupsel/root_accuracy_native_smoke.py','.github/workflows/hupsel-root-accuracy-production.yml'}
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def blob(ref,p):return git('rev-parse',ref+':'+p)
def guard(r):
 assert r['predecessor']==git('rev-parse',BASE)and r['whole_scientific_admission']is False
 assert r['profile']=='pressure-film-refined'and r['film_relative_tolerance']==1e-5
 assert set(r['production_delta'])==PATHS and set(r['gate_sha256'])==GATES
 assert set(git('diff','--name-only',BASE,'HEAD','--','src','app','reference').splitlines())==PATHS
 assert not git('diff','HEAD','--','src','app','reference')and not git('ls-files','--others','--exclude-standard','--','src','app','reference')
 for p,pins in r['production_delta'].items():
  assert blob(BASE,p)==pins['before']and blob('HEAD',p)==pins['after'],p
  assert(ROOT/p).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+p],cwd=ROOT),p
 for p,pin in r['gate_sha256'].items():assert sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))==pin,p
 old=json.loads(subprocess.check_output(['git','show',BASE+':integration/dataqual15/STATUS.json'],cwd=ROOT));now=json.loads((ROOT/'integration/dataqual15/STATUS.json').read_text())
 assert now[KEY]=={'scope':SCOPE}
 for key,value in old.items():
  if key.endswith(('20261102','20261104','20261105')):assert now.get(key)==value,key
 for p,pin in r.get('frozen_predecessor_assets',{}).items():
  assert blob('HEAD',p)==pin,p
  assert (ROOT/p).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+p],cwd=ROOT)if not p.endswith(('.xz','.zip'))else sha((ROOT/p).read_bytes())==sha(subprocess.check_output(['git','show','HEAD:'+p],cwd=ROOT)),p

def unpack(r):
 raw=(ROOT/r['archive']).read_bytes();assert sha(raw)==r['archive_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers();assert all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in members)
  assert len(members)==len({m.name for m in members});f={m.name:t.extractfile(m).read()for m in members}
 assert json.loads(f.pop('MANIFEST.json'))=={n:sha(b)for n,b in f.items()};return f

def verify(f):
 j=lambda n:json.loads(f[n]);rows=lambda n:list(csv.DictReader(io.StringIO(f[n].decode())))
 for n,b in f.items():
  if n.startswith('assets/'):assert sha(b)==n.split('/')[-1],n
 for opt in ('O0','O2'):
  build=j('native-'+opt+'/BUILD.json');run=j('runtime-'+opt+'/RESULT.json')
  assert build['provider_count']==236 and '-'+opt in build['flags']and '-fcheck=all'in build['flags']
  for pin in [*build['source_sha256'].values(),*build['object_sha256'].values(),build['executable_sha256'],build['archive_sha256']]:assert 'assets/'+pin in f,pin
  pub=build['publication_provider']
  for key in ('source_sha256','object_sha256'):assert 'assets/'+pub[key]in f
  for name,pin in build['source_sha256'].items():
   rel=next((area+'/'+name.replace('\\','/').split('/'+area+'/',1)[1]for area in ('src','app')if'/'+area+'/'in name.replace('\\','/')),None)
   if rel:assert f['assets/'+pin].replace(b'\r\n',b'\n')==(ROOT/rel).read_bytes().replace(b'\r\n',b'\n'),rel
  assert run['status']=='ACTUAL_CURRENT_ROOT_PROFILE_FULL1096_LEDGER_AND_STRICT_OWN_RESTARTS_PASS'and run['days']==1096
  assert run['executable_sha256']==build['executable_sha256']and run['source_sha256']==build['source_sha256']
  assert run['whole_scientific_admission']is False and run['science']['passing']==36 and run['science']['total']==37
  assert [k for k,v in run['science']['assessment'].items()if not v['inside_frozen_bound']]==['oxygen']
  assert run['science']['oxygen_day584']['absolute_error']>run['science']['oxygen_day584']['limit']
  profile=j('runtime-'+opt+'/PROFILE.json');selected=f['runtime-'+opt+'/inputs/swap.swp'];delta=profile['only_input_delta'].encode()
  assert selected.endswith(delta)and sha(selected[:-len(delta)])==profile['original_swp_sha256']and sha(selected)==profile['selected_swp_sha256']
  full='runtime-'+opt+'/full1096/'
  assert j(full+'RESULT.json')['returncode']==0 and j(full+'START.json')['restart_sha256']is None
  water=[{k:float(v)for k,v in x.items()}for x in rows(full+'budget.csv')]
  assert water[0]['t0_day']==0 and water[-1]['t1_day']==1096
  assert all(x['t1_day']>x['t0_day']and all(math.isfinite(v)for v in x.values())for x in water)
  assert all(a['t1_day']==b['t0_day']for a,b in zip(water,water[1:]))
  for kind,unit in [('water','cm'),('solute','mg_cm2')]:
   start,end,inp,output=[kind+'_'+k+'_'+unit for k in ('start','end','in','out')]
   assert max(abs(x[end]-x[start]-x[inp]+x[output])for x in water)<=1e-10
   assert max(abs(a[end]-b[start])for a,b in zip(water,water[1:]))<=1e-10
   assert abs(water[-1][end]-water[0][start]-math.fsum(x[inp]for x in water)+math.fsum(x[output]for x in water))<=1e-8
  pairs=run['strict_windows'];assert len(pairs)==10 and [365,367]in pairs and [1095,1096]in pairs
  for first,last in pairs:
   strict='runtime-'+opt+f'/restarts/{first}-to-{last}/'
   assert f[strict+'checkpoint.bin']==f[full+f'checkpoint-{last}.bin']
   for name,key in (('budget.csv','t1_day'),('crop.csv','day')):assert rows(strict+name)==[x for x in rows(full+name)if first<float(x[key])<=last]
  for kind in ('water','solute'):
   assert max(run['interval_ledger'][kind].values())<=1e-10
   assert abs(run['ledger']['ledgers'][kind]['cumulative_independent_defect'])<=1e-8
  controls=j('controls-'+opt+'/RESULT.json');assert controls['status']=='CURRENT_ROOT_PROFILE_WRITER_OWNER_APP_AND_SELECTOR_CONTROLS_PASS'
  assert(controls['writer'],controls['owner'],controls['app'])==(6,37,11)and len(controls['profile'])==2
  assert all(e['returncode']!=0 and e['prior_target_preserved']for e in controls['profile'])
  for label,total in [('app-refusals',11),('owner-controls',37)]:
   events=j('controls-'+opt+'/'+label+'/RESULT.json')['events'];assert len(events)==total and all(e['returncode']==1 for e in events)
  assert j('controls-'+opt+'/publication/RESULT.json')['finite_writer_refusals']==6
 thermal=j('thermal-preservation/RESULT.json');assert thermal['status']=='SPRINT03_CURRENT_RUNTIME_AND_THERMAL_TEMPORAL_CONTRACT_PASS'and all(e['returncode']==0 for e in thermal['events'])
 assert sum(e['label']=='native_existing_contract'for e in thermal['events'])==10
 component=j('component/RESULT.json');assert component['status']=='CURRENT_ROOT_API_DEFAULT_AND_REFINED_FROZEN_ALGORITHM_CONTRACTS_PASS'
 assert len(component['selected_original_nodes'])==64 and len(component['results'])==8
 return dict(full_original_days={'O0':1096,'O2':1096},strict_own_windows_per_build=10,original_science='36/37; oxygen FAILED',whole_scientific_admission=False)

def data_controls(f):
 cases={'changed-linked-object':(next(n for n in f if n.startswith('assets/')),lambda b:b+b'x'),
 'changed-year-restart':('runtime-O2/restarts/365-to-367/checkpoint.bin',lambda b:b+b'x'),
 'promoted-science':('runtime-O2/RESULT.json',lambda b:json.dumps({**json.loads(b),'whole_scientific_admission':True}).encode()),
 'erased-oxygen-failure':('runtime-O2/RESULT.json',lambda b:json.dumps({**json.loads(b),'science':{**json.loads(b)['science'],'passing':37}}).encode()),
 'missing-owner-controls':('controls-O0/RESULT.json',lambda b:json.dumps({**json.loads(b),'owner':36}).encode())}
 refused=[]
 for label,(name,change)in cases.items():
  bad=f.copy();bad[name]=change(f[name])
  try:verify(bad)
  except(AssertionError,KeyError,ValueError):refused.append(label)
  else:raise AssertionError('accepted corrupted evidence '+label)
 return refused

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path);p.add_argument('--verify-only',action='store_true');a=p.parse_args()
 r=json.loads((ROOT/SCOPE).read_text());guard(r);f=unpack(r);proof=verify(f);proof['actual_data_refusals']=data_controls(f)
 if a.verify_only:print(json.dumps(proof));return
 assert a.output is not None;a.output.mkdir(parents=True,exist_ok=False)
 (a.output/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_ROOT_NUMERICAL_PROFILE_NATIVE_EVIDENCE_AND_EXACT_SOURCE_PASS',current=proof,predecessor=BASE,whole_scientific_admission=False),indent=2)+'\n')
if __name__=='__main__':main()
