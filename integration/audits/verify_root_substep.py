"""Opt-in trial-beginning roots: current raw execution and frozen predecessor."""
import base64,csv,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='f7c6041096a0cc1a7a71fbe9e37b390d976744ac'
CONCURRENT='75877297daffcd50084d3705f91459a4f1272af7'
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
PARENT='integration/audits/verify_crop_root_joint.py'
SELF='integration/audits/verify_root_substep.py'
NUT='integration/audits/verify_nut_thermal_output.py'
CALENDAR='integration/audits/verify_nut_calendar_output.py'
CAL_PROVIDER='src/adapter/mod_crop_soil_n_calendar_output_day.f90'
BACKEND='src/runtime/mod_fmr_serialized_reference_backend.f90'
FROZEN={BACKEND,'app/solute_crop/main.f90','tools/solute/run_crop_daily.py'}
SCIENCE=['src','app','tools','tests','examples','.github','reference','integration/audits','integration/performance','integration/diagnostics']
def sha(raw):return hashlib.sha256(raw).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def historical(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def parent_record(reader=lambda p:(ROOT/p).read_bytes()):
 return json.loads(reader(STATUS))['swp_water_successor']['daily_meteo_successor']['etref_successor']['simple_crop_preparation_successor']['root_joint_successor']
def record(reader=lambda p:(ROOT/p).read_bytes()):return parent_record(reader)['substep_feedback_work']
def projection(path=PARENT):
 text=subprocess.check_output(['git','show',CONCURRENT+':'+path],cwd=ROOT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  offset=text.index('\n',text.index('def '+name+'('))+1
  condition="'evidence' in record().get('substep_feedback_work',{})" if path==PARENT else "'evidence' in __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['record']()"
  call="__import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")"
  hook=' if '+condition+':\n'
  if path==PARENT or name=='self_test':hook+='  return '+call+'\n'
  elif name=='source':hook+='  '+call+'\n  return record(reader)\n'
  else:hook+="  composed="+call+"\n  return dict(composed['current_calendar_nut'],current_concurrent_nut=composed['current_concurrent_nut'],incumbent_root_science=composed['frozen_daily_predecessor'],composed_owner=composed)\n"
  text=text[:offset]+hook+text[offset:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader);require(r['baseline']==BASE,'substep baseline')
 before=json.loads(historical(STATUS));current=json.loads(reader(STATUS))
 current['swp_water_successor']['daily_meteo_successor']['etref_successor']['simple_crop_preparation_successor']['root_joint_successor'].pop('substep_feedback_work')
 require(current==before,'unrelated root/recovery authority drift')
 for p in [PARENT,CALENDAR]:require(reader(p)==projection(p),'predecessor assertion body changed '+p)
 require(r['concurrent_ref']==CONCURRENT,'concurrent authority')
 concurrent=git('diff','--name-only',BASE,CONCURRENT).splitlines()
 for p in concurrent:
  if p in [PARENT,CALENDAR]:continue
  require(reader(p)==subprocess.check_output(['git','show',CONCURRENT+':'+p],cwd=ROOT),'concurrent admitted source '+p)
 for p,h in r['qualified_input_sha256'].items():require(sha(reader(p))==h,'current executed input '+p)
 paths=set(git('diff','--name-only',BASE,'HEAD').splitlines())-{STATUS}
 require(paths==set(r['postimages']),'substep postimage census')
 for p,h in r['postimages'].items():require(sha(reader(p))==h,'substep postimage '+p)
 delta={line.split('\t')[1]:line.split('\t')[0] for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta==r['scientific_delta'],'unregistered substep science')
 require(git('diff','--name-only',BASE,'HEAD','--','src').splitlines()==[CAL_PROVIDER,BACKEND],'foreign production change')
 require(all(k=='A' or p in FROZEN|{STATUS,PARENT} for p,k in delta.items()),'unexplained incumbent mutation')
 require(not git('status','--porcelain','--','src','app','tools','tests'),'dirty executable source')
 require(not git('diff','--name-only','--',*SCIENCE),'dirty scientific evidence')
 if changed is not None:
  inherited=set(parent_record()['source_delta'])|set(parent_record()['inherited_science_paths'])
  require(not any(p not in delta and p not in inherited for p in changed),'foreign caller science')
 return json.loads(reader(STATUS))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=base64.b64decode(b''.join((ROOT/e['path']).read_bytes().split()),validate=True)
 require(sha(raw)==e['decoded_sha256'] and len(raw)==e['decoded_bytes'],'substep capsule bytes')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
  members=t.getmembers();require(len(members)==e['members'] and len({m.name for m in members})==len(members),'substep member census')
  require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe substep member')
  f={m.name:t.extractfile(m).read() for m in members}
 manifest=json.loads(f.pop('MANIFEST.json'));require(set(f)==set(manifest),'substep inventory')
 require(all(sha(f[p])==h for p,h in manifest.items()),'substep member hash')
 return f
def validate(f,reader=lambda p:(ROOT/p).read_bytes()):
 def js(p):return json.loads(f[p])
 def rows(p):return [{k:float(v) for k,v in row.items()} for row in csv.DictReader(io.StringIO(f[p].decode()))]
 def inputs(mapping,label):
  for p,h in mapping.items():require(sha(reader(p))==h,label+' '+p)
 d=js('daily/result.json');tx=js('transaction/result.json')
 require(d['status']=='ROOT_SUBSTEP_DAILY_O0_O2_MASS_RESTART_DEFAULT_EXACT_PASS','daily execution missing')
 require(len(d['cases'])==16 and len(d['events'])==66 and d['fresh_restarts']==16 and d['mode_restart_rejections']==2 and d['exact_default_files']==64,'daily inventory')
 require(tx['status']=='ROOT_SUBSTEP_REAL_TRACE_REJECT_RETRY_ABA_O0_O2_PASS' and len(tx['events'])==4,'substep transaction inventory')
 inputs(d['inputs'],'daily input');inputs(tx['inputs'],'transaction input')
 for event in d['events']:require((event['returncode']==0)==event['expected_success'],'daily process failed')
 require(all(e['returncode']==0 for e in tx['events']),'transaction process failed')
 parent=runpy.run_path(str(ROOT/PARENT));old=parent['capsule']()
 require(d['baseline_capsule_sha256']==parent_record()['evidence']['decoded_sha256'],'daily frozen proof identity')
 count=0
 for opt in ['O0','O2']:
  for kind,b in d['builds'][opt].items():
   inputs(b['input_sha256'],'current '+kind)
   require(b['status']=='BUILT' and all(e['returncode']==0 for e in b['events']),'current compile failed')
   prefix={'column':'column-','crop-reader':'crop-','root-reader':'root-'}[kind]+opt+'/'
   require(js(prefix+'build-complete.json')==b,'current build report')
   for p,h in b['generated_input_sha256'].items():require(sha(f[prefix+p])==h,'current native generated input '+p)
   if kind=='column':require(b['provider_count']==194 and '-fcheck=all' in b['flags'] and '-'+opt in b['flags'],'checked current closure')
  require(tx['builds'][opt]==d['builds'][opt]['column'],'transaction build handoff')
  b='transaction/'+opt+'/'
  for a,c in [('original.bin','rejected.bin'),('retry.bin','fresh.bin'),('retry.bin','again.bin'),('original.bin','invalid.bin'),('absent.bin','absent-fresh.bin')]:
   require(f[b+a]==f[b+c],'root state ownership '+a+' '+c)
  require(tx['cases'][opt]['reused_provider_objects']==193,'transaction physical closure')
  require(sha(f[b+'retry.bin'])==tx['cases'][opt]['retry_fresh_sha256'],'transaction endpoint receipt')
  stdout=f['transaction/'+('0001' if opt=='O0' else '0003')+'.stdout'].decode()
  require('ROOT_SUBSTEP_FEEDBACK_TRACE_REJECTION_RETRY_ABA_ABSENT_PASS' in stdout,'missing production trace assertions')
  require(stdout.rstrip().endswith('ROOT_SUBSTEP_FEEDBACK_TRACE_REJECTION_RETRY_ABA_ABSENT_PASS'),'trailing transaction corruption')
  line=next((line for line in stdout.splitlines() if 'ACCEPTED_ROOT_TRACE' in line),'').split()
  require(len(line)==6 and int(line[1])>1 and float(line[5])>1e-8,'no discriminating within-window feedback')
  require(0<float(line[2])<float(line[3]) and abs(float(line[3])-float(line[2])-float(line[4]))<1e-14,'trace integrated stress mass')
  for name in ['dry','drought','oxygen','ponded','rain','no-salt-uptake','linear','maturity']:
   prefix='daily/'+opt+'/'+name+'/';base='qualified/'+opt+'/'+name+'/'
   for p in ['input.swp','crop.crp','weather.met']:require(f[prefix+p]==old[base+p],'changed admitted native forcing')
   for p in ['state.csv','endpoint.csv','restart.bin','budget.csv']:require(f[prefix+'daily/'+p]==old[base+'full/'+p],'daily default changed '+p)
   for p in ['state.csv','endpoint.csv','restart.bin']:require(f[prefix+'full/'+p]==f[prefix+'resumed/'+p],'substep fresh restart '+p)
   budget=rows(prefix+'full/budget.csv');item=d['cases'][opt+'-'+name]
   require(budget==item['budget'] and len(budget)==8 and rows(prefix+'resumed/budget.csv')==budget[3:],'substep continuation budget')
   require(sha(f[prefix+'full/restart.bin'])==item['restart_sha256'],'substep endpoint receipt')
   require('substep_root_stress=.true.' in f[prefix+'full/input.nml'].decode(),'missing explicit mode')
   for i,r in enumerate(budget):
    count+=1
    for substance,unit in [('water','cm'),('solute','mg_cm2')]:
     residual=r[f'{substance}_end_{unit}']-r[f'{substance}_start_{unit}']-r[f'{substance}_in_{unit}']+r[f'{substance}_out_{unit}']
     require(abs(residual)<1e-10 and abs(r[f'{substance}_residual_{unit}'])<1e-10,'hard accepted '+substance+' mass')
    gross=r['water_end_cm']-r['water_start_cm']-item['rain_cm'][i]+r['soil_evaporation_cm']+r['pond_evaporation_cm']+r['runoff_cm']+r['actual_transpiration_cm']
    require(abs(gross)<1e-10,'gross root water accounting')
    require(-1e-15<=r['actual_transpiration_cm']<=r['potential_transpiration_cm']+1e-12,'root demand bound')
    require(abs(r['potential_transpiration_cm']-r['actual_transpiration_cm']-r['drought_reduction_cm']-r['oxygen_reduction_cm'])<1e-12,'accepted stress accounting')
   require(sum(r['actual_transpiration_cm'] for r in budget)>0,'missing real root uptake')
   if name=='drought':require(sum(r['drought_reduction_cm'] for r in budget)>0,'missing drought')
   if name=='oxygen':require(sum(r['oxygen_reduction_cm'] for r in budget)>0,'missing empirical oxygen')
   if name=='no-salt-uptake':require(abs(budget[-1]['solute_end_mg_cm2']-budget[0]['solute_start_mg_cm2'])<1e-10,'zero TSCF loses salt')
   require(budget[0]['actual_transpiration_cm']==budget[-1]['actual_transpiration_cm']==0,'fallow sink')
   if name=='maturity':require(all(r['actual_transpiration_cm']==0 for r in budget[2:]),'harvest sink')
 # Preserve all original predecessor raw assertions against explicitly frozen inputs.
 def frozen(p):return historical(p) if p in FROZEN else reader(p)
 predecessor=parent['validate'](old,reader=frozen)
 prep=runpy.run_path(str(ROOT/'integration/audits/verify_native_simple_crop.py'))
 preparation=prep['validate'](prep['capsule']())
 old_physics=runpy.run_path(str(ROOT/'integration/audits/verify_swp_etref.py'))
 def frozen_physics(p):
  if p in parent_record()['concurrent_production']:
   return subprocess.check_output(['git','show','636760624e930f11517a42707fd16d885902c045:'+p],cwd=ROOT)
  return frozen(p)
 original_physics=old_physics['validate'](old_physics['capsule'](),reader=frozen_physics)
 # Current NUT executes the changed backend; never label its previous raw PASS current.
 nut=runpy.run_path(str(ROOT/NUT));current_nut=nut['validate']({p[len('nut/'):]:v for p,v in f.items() if p.startswith('nut/')})
 inputs(js('nut/cold/result.json')['input_sha256'],'current NUT full closure')
 calendar=runpy.run_path(str(ROOT/CALENDAR))
 calendar_files={p[len('calendar-nut/'):]:v for p,v in f.items() if p.startswith('calendar-nut/')}
 current_calendar=calendar['validate'](calendar_files)
 current_calendar_result=js('calendar-nut/calendar/result.json')
 inputs(current_calendar_result['cold_input_sha256'],'current calendar cold providers')
 inputs(current_calendar_result['input_sha256'],'current calendar production')
 require(calendar_files['cold/result.json']==f['nut/cold/result.json'],'calendar same-build provider handoff')
 require(count==128,'daily mass census')
 return dict(qualified=True,status='TRIAL_BEGINNING_ROOT_SUBSTEP_O0_O2_QUALIFIED',substep_stress_feedback=True,
             physical_cases=16,daily_balance_observations=count,fresh_restarts=16,exact_default_files=64,
             transaction='O0_O2_EXACT_REJECT_RETRY_ABA_ABSENT',mode_restart_rejections=2,
             frozen_daily_predecessor=predecessor,current_preparation=preparation,
             frozen_original_physics=original_physics,current_concurrent_nut=current_nut,current_calendar_nut=current_calendar,full_historical_migration=False)
def self_test():
 controls=[]
 for path in record()['postimages']:
  def altered(p):return (ROOT/p).read_bytes()+(b'corrupt' if p==path else b'')
  try:source(altered)
  except ValueError:controls.append('source:'+path)
  else:raise AssertionError('stale substep source accepted '+path)
 f=capsule()
 for path in ['daily/result.json','daily/O0/drought/full/budget.csv','daily/O2/oxygen/resumed/restart.bin',
              'daily/O2/dry/daily/endpoint.csv','transaction/O0/again.bin','transaction/O2/absent.bin',
              'transaction/0001.stdout','column-O0/build-complete.json','nut/cold/result.json',
              'nut/thermal/O0/output.endpoint.generation','nut/thermal/O2/output.restart.environment-after',
              'calendar-nut/calendar/O0/1/endpoint.false','calendar-nut/calendar/O2/2/fresh.true']:
  bad=dict(f);bad[path]+=b'corrupt'
  try:validate(bad)
  except (ValueError,KeyError,AssertionError,StopIteration):controls.append('raw:'+path)
  else:raise AssertionError('corrupt substep proof accepted '+path)
 try:source(changed={'src/foreign_substep.f90':'A'})
 except ValueError:controls.append('foreign science')
 else:raise AssertionError('foreign science accepted')
 return controls
def verify():
 source();result=validate(capsule());result['controls']=len(self_test());result['current_source_tree']=git('rev-parse','HEAD:src')
 return result
if __name__=='__main__':print(json.dumps(verify(),indent=2))
