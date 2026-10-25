"""Source-bound native heat/crop admission with fresh affected caller proof."""
import base64,csv,datetime,hashlib,io,json,math,re,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='3ebf19fad6027e174341302d64c22585d47b91bc';STATUS='integration/mc-sol01/drainage/PROJECT_HEAT_STATUS.json';SELF='integration/audits/verify_project_heat_current.py';PARENT='integration/audits/verify_project_hydraulics_current.py';RUNTIME='src/runtime/mod_fmr_serialized_reference_backend.f90';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  start=re.search(r'^def '+name+r'\(',t,re.M).start();at=t.index(':',t.index(')',start))+1
  if t[at:at+1]!='\n':t=t[:at]+'\n '+t[at:]
  at=t.index('\n',start)+1;t=t[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[at:]
 assert t.count("old['validate'](old['capsule']())")==1
 return t.replace("old['validate'](old['capsule']())","old['validate']({**f,**{p[len('column-inherited/'):]:b for p,b in f.items()if p.startswith('column-inherited/')}})").encode()
def runtime_projection():
 t=subprocess.check_output(['git','show',BASE+':'+RUNTIME],cwd=ROOT,text=True);before='        if (self%soil_temperature_active.or.self%frost_active.or.self%rutter_active.or.self%snow_active) return'
 after='''        ! Numeric heat uses the same hydraulic Feddes trial-beginning view.
        ! Admit it only on the joint accepted-trace route, with chemistry
        ! outside the water state and no alternate conductivity iteration.
        if (self%soil_temperature_active) then
          if (.not.self%accepted_water_flux_trace_enabled.or. &
              self%solute_state_layout_id/=FMR_SOLUTE_STATE_LAYOUT_NONE.or. &
              self%picard_conductivity_iteration) return
          if(self%soil_temperature_parameters%solution_mode/=SOIL_TEMP_SOLUTION_NUMERIC)return
        end if
        if (self%frost_active.or.self%rutter_active.or.self%snow_active) return'''
 assert t.count(before)==1;return t.replace(before,after).encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if (ROOT/'integration/mc-sol01/drainage/COMPOSED_HEAT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_composed_heat_current.py'))['source'](reader,changed)
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta']
 assert {p for p in delta if p.startswith('src/')}=={RUNTIME};assert not git('status','--porcelain','--',*SCIENCE)
 assert reader(PARENT)==projection()and reader(RUNTIME)==runtime_projection()
 for p,h in s['postimages'].items():assert sha(reader(p))==h,('native project heat',p)
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
 parent=json.loads(f['heat-parent/proof.json']);assert parent['owner']['qualified']and len(parent['controls'])==11
 raw=f['heat-parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 rows=lambda p:list(csv.DictReader(io.StringIO(f[p].decode())))
 for opt in ['O0','O2']:
  prefix='heat-'+opt+'/';r=json.loads(f[prefix+'RESULT.json']);assert r['status']=='NATIVE_PROJECT_HEAT_CROP481_RESTART_PASS';assert r['complete_days']==481 and r['coupled_cases']==r['fresh_process_restarts']==2 and r['rejected_processes']==8
  assert len(r['events'])==14 and all((e['returncode']==0)==e['expected_success']for e in r['events'])
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
  if opt=='O2':assert r['results']==json.loads(f['heat-O0/RESULT.json'])['results']
  expected={}
  for name in ['History.998','History.999']:
   for line in f[prefix+'project/weather data/'+name].decode().splitlines():
    if line.startswith("'ANDE-M'"):
     x=line.split();expected[datetime.date(int(x[3]),int(x[2]),int(x[1]))]=.5*(float(x[5])+float(x[6]))
  expected=[v for d,v in sorted(expected.items())if datetime.date(1998,1,1)<=d<=datetime.date(1999,4,26)];assert len(expected)==481
  for name in ['half','double']:
   c=prefix+name+'/';result=r['results'][name];budget=rows(c+'full/budget.csv');assert len(budget)==481 and budget==result['budget']and budget[365:]==rows(c+'resumed/budget.csv')
   assert sum(float(x['actual_transpiration_cm'])for x in budget)>0 and sum(float(x['soil_evaporation_cm'])for x in budget)>0
   for p,h in result['files'].items():assert sha(f[c+'full/'+p])==h and f[c+'full/'+p]==f[c+'resumed/'+p]
   assert len(rows(c+'full/temperature.csv'))==12
   air=[float(x)for x in re.search(r'^ air_temperature_c=(.*)$',f[c+'full/input.nml'].decode(),re.M)[1].split(',')];assert air==result['air_temperature_c']and len(air)==481
   assert all(abs(x-y)<=4*math.ulp(max(1.,abs(x),abs(y)))for x,y in zip(air,expected))
   for row in budget:
    assert abs(float(row['water_residual_cm']))<1e-10 and abs(float(row['solute_residual_mg_cm2']))<1e-10 and float(row['observed_heat_residual_j_cm2'])<=1e-9
    assert abs(float(row['potential_transpiration_cm'])-float(row['actual_transpiration_cm'])-float(row['drought_reduction_cm'])-float(row['oxygen_reduction_cm']))<1e-12
    independent=float(row['water_end_cm'])-float(row['water_start_cm'])-float(row['rain_supplied_cm'])+float(row['runoff_cm'])+float(row['soil_evaporation_cm'])+float(row['pond_evaporation_cm'])+float(row['actual_transpiration_cm']);assert abs(independent)<1e-10
 return dict(qualified=True,heat_crop_cases=4,days_per_case=481,exact_heat_process_restarts=4,rejected_heat_processes=16,fresh_affected_preservation=dict(project_cases=4,project_restarts=4,column_cases=12,column_restarts=12,all_original_scientific_assertions_pass=True),runtime_change='EXACT_NUMERIC_HEAT_SUBSTEP_FEDDES_GUARD_ONLY',physical_equations_unchanged=True,full_original_Andelst=False,canonically_admitted=False)
def verify():
 if (ROOT/'integration/mc-sol01/drainage/COMPOSED_HEAT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_composed_heat_current.py'))['verify']()
 source();return validate(capsule())
def fsi35_successors():
 if (ROOT/'integration/mc-sol01/drainage/COMPOSED_HEAT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_composed_heat_current.py'))['fsi35_successors']()
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path'])
 return json.loads(capsule()['heat-parent/proof.json'])['fsi35']
def self_test():
 if (ROOT/'integration/mc-sol01/drainage/COMPOSED_HEAT_STATUS.json').is_file():return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_composed_heat_current.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(label);return
  raise AssertionError('accepted native project heat corruption '+label)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_heat.f90':'A'}))
 for p in ['heat-O0/RESULT.json','heat-O2/half/resumed/restart.bin','heat-O0/double/full/temperature.csv','heat-O2/project/weather data/History.998','project-O2/default/state.csv','column-inherited/ksatexm-O0/active/resumed/restart.bin']:
  bad=dict(f);bad[p]=bad[p].replace(b'10.1',b'11.1',1)if p.endswith('History.998')else bad[p]+b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(verify(),indent=2))
