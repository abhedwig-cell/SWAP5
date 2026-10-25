"""Current existing-owner Boesten/drainage/numeric heat admission."""
import base64,csv,hashlib,io,json,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='d6378c7ac492a9e051b04468b814be6d1d54d121';STATUS='integration/mc-sol01/drainage/COMPOSED_HEAT_STATUS.json';SELF='integration/audits/verify_composed_heat_current.py';PARENT='integration/audits/verify_project_heat_current.py';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
ROUTINES={
 'src/runtime/mod_fmr_serialized_reference_backend.f90':['joint_drainage_trace_valid','fmr_new_b110_boesten_evaporation_committed_state','fmr_serialized_backend_run_trial','fmr_serialized_execution_admitted','fmr_serialized_prepare_interval'],
 'src/runtime/mod_fmr_restart_state_contract.f90':['fmr_restart_state_matches_template'],
 'src/runtime/mod_fmr_b111_pond_thermal_application.f90':['matrix_thermal_template','pond_thermal_states_match','run_pond_thermal_interval'],
 'src/adapter/mod_pond_thermal_restart_file.f90':['heat_vector','write_pond_thermal_restart','read_pond_thermal_restart']}
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  start=re.search(r'^def '+name+r'\(',t,re.M).start();at=t.index(':',t.index(')',start))+1
  if t[at:at+1]!='\n':t=t[:at]+'\n '+t[at:]
  at=t.index('\n',start)+1;t=t[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[at:]
 return t.encode()
def outside_routines(t,names):
 for name in names:
  pat=r'(?im)^[ \t]*(?:(?:pure|logical|integer|recursive|elemental)\s+)*(subroutine|function)\s+'+name+r'\s*\('
  ms=list(re.finditer(pat,t));assert len(ms)==1,name;m=ms[0];end=re.search(r'(?im)^[ \t]*end\s+'+m[1]+r'(?:[ \t]+'+name+r')?[ \t]*$',t[m.start():]);assert end,name
  t=t[:m.start()]+'! COMPOSITION '+name+'\n'+t[m.start()+end.end():]
 return t
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-sol01/drainage/SATURATION_STORAGE_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_saturation_storage_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'];assert {p for p in delta if p.startswith('src/')}==set(ROUTINES)
 assert not git('status','--porcelain','--',*SCIENCE);assert reader(PARENT)==projection()
 for p,names in ROUTINES.items():
  old=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True);now=reader(p).decode()
  if p.endswith('mod_pond_thermal_restart_file.f90'):now=now.replace(' use mod_restricted_surface_evaporation,only:boesten_evaporation_state_t\n','')
  assert outside_routines(old,names)==outside_routines(now,names),('outside declared ownership changes',p)
 for p,h in s['postimages'].items():assert sha(reader(p))==h,('composed heat source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 inherited=runpy.run_path(str(ROOT/PARENT))['validate'](f);assert inherited['qualified']
 parent=json.loads(f['composed-parent/proof.json']);assert parent['owner']['qualified']and len(parent['controls'])==17
 raw=f['composed-parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 for opt in ['O0','O2']:
  rollback='rollback-'+opt+'/';rr=json.loads(f[rollback+'RESULT.json']);assert rr['status']=='COMPOSED_REAL_ROLLBACK_RETRY_PASS'and rr['rejected_generation_exact']and rr['accepted_retry_advances']
  assert len(rr['events'])==2 and all(e['returncode']==0 for e in rr['events'])
  for p,h in rr['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
  for p,h in rr['files'].items():assert sha(f[rollback+p])==h
  assert f[rollback+'state.before']==f[rollback+'state.after']and f[rollback+'state.before']!=f[rollback+'state.retry']
  assert f[rollback+'state.before']==f[rollback+'state.initialized']and f[rollback+'state.legacy_target']==b'PRESERVED\n'
  # All prior positive heat-project physical artifacts, including S5PT0001,
  # remain exact. Promoted negative domains are tested positively below.
  old=json.loads(f['baseline-heat-'+opt+'-RESULT.json']);current=json.loads(f['heat-'+opt+'/RESULT.json']);assert current['composed_preservation']and current['results']==old['results']
  prefix='composed-'+opt+'/';r=json.loads(f[prefix+'RESULT.json']);assert r['status']=='COMPOSED_BOESTEN_DRAIN_HEAT481_RESTART_PASS';assert r['coupled_cases']==r['fresh_process_restarts']==2 and r['complete_days']==481 and r['rejected_processes']==8 and r['typed_pair_controls']==7 and r['typed_pair_roundtrip_exact']
  assert len(r['events'])==24 and all((e['returncode']==0)==e['expected_success']for e in r['events'])
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
  if opt=='O2':assert r['results']==json.loads(f['composed-O0/RESULT.json'])['results']
  assert f[prefix+'pair.bin']==f[prefix+'roundtrip.bin']and f[prefix+'pair.bin'][:8]==b'S5PT0002'
  assert f[prefix+'pair.bin'].count(__import__('struct').pack('=dd',2.,.5))==1
  for name in ['negative-spev','negative-saev','nan-pair','wrong-tag','crc','truncated','parameter']:assert b'COMPOSED_RESTART_REJECTION_PASS'in f[prefix+'typed-'+name+'.stdout']
  for name in ['boesten','plain']:
   c=prefix+name+'/';result=r['results'][name];budget=rows(c+'full/budget.csv');assert len(budget)==481 and budget==result['budget']and budget[365:]==rows(c+'resumed/budget.csv')
   for p,h in result['files'].items():assert sha(f[c+'full/'+p])==h and f[c+'full/'+p]==f[c+'resumed/'+p]
   assert f[c+'full/restart.bin'][:8]==(b'S5PT0002'if name=='boesten'else b'S5PT0001')
   assert sum(float(x['drainage_cm'])for x in budget)>0 and sum(float(x['actual_transpiration_cm'])for x in budget)>0
   for row in budget:
    assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10 and float(row['observed_heat_residual_j_cm2'])<=1e-9
    assert abs(float(row['potential_transpiration_cm'])-float(row['actual_transpiration_cm'])-float(row['drought_reduction_cm'])-float(row['oxygen_reduction_cm']))<1e-12
    independent=float(row['water_end_cm'])-float(row['water_start_cm'])-float(row['rain_supplied_cm'])+float(row['runoff_cm'])+float(row['soil_evaporation_cm'])+float(row['pond_evaporation_cm'])+float(row['actual_transpiration_cm'])-float(row['bottom_up_cm'])+float(row['drainage_cm']);assert abs(independent)<1e-10
   if name=='boesten':assert result['committed_pairs']['full']==result['committed_pairs']['resumed']and min(result['committed_pairs']['full']+result['committed_pairs']['split'])>=0
 return dict(qualified=True,composed_heat_cases=4,days_per_case=481,exact_composed_restarts=4,typed_pair_controls=14,real_joint_rollback_retry_cases=2,source_equations_unchanged=True,fresh_preservation=dict(heat_project_cases=4,nonheat_project_cases=4,column_cases=12,exact_restarts=20),old_thermal_format_exact=True,full_original_Andelst=False,canonically_admitted=False)
def verify():
 if (ROOT/'integration/mc-sol01/drainage/SATURATION_STORAGE_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_saturation_storage_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/mc-sol01/drainage/SATURATION_STORAGE_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_saturation_storage_current.py'))['fsi35_successors']()
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path'])
 return json.loads(capsule()['composed-parent/proof.json'])['fsi35']
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/SATURATION_STORAGE_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_saturation_storage_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted composed heat corruption '+label)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_composed_heat.f90':'A'}))
 for p in ['composed-O0/RESULT.json','composed-O2/boesten/resumed/restart.bin','composed-O0/pair.bin','composed-O2/plain/full/budget.csv','rollback-O0/state.after','heat-O0/half/full/temperature.csv','column-inherited/ksatexm-O0/active/resumed/restart.bin']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
