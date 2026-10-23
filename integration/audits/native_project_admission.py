"""Bounded native project admission over the complete frozen canonical owner."""
import base64,csv,hashlib,io,json,math,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='d3986e2642ede0dc4ce2acd0194fc38807bf0adb'
PHYSICAL_BASE='53010691c79d3e132914ce372059cf873d88b96d'
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
SELF='integration/audits/native_project_admission.py'
PARENT='integration/performance/verify_weather_line_search_successor.py'
NUT_PARENT='integration/audits/verify_nut_thermal_fallow_output.py'
CYCLE_PARENT='integration/audits/verify_nut_cycle_output.py'
CODEC='src/adapter/mod_crop_n_saved_generation.f90'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
PRODUCTION={'src/adapter/mod_reference_richards_legacy_binding.f90','src/legacy/b1_10_port/headcalc.f90',
 'src/process/mod_b111_persistent_pond.f90','src/process/mod_b111_reactive_solute_substep.f90',
 'src/runtime/mod_fmr_b111_matrix_solute_route.f90','src/runtime/mod_fmr_serialized_reference_backend.f90',
 'src/solver/mod_soil_water_solver_contract.f90'}
CANONICAL_PROOF='benchmarks/performance/PERF01_LINE_SEARCH_COMPOSITION_20261022_EVIDENCE.tar.xz'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def child(document):
 for key in ['swp_water_successor','daily_meteo_successor','etref_successor','simple_crop_preparation_successor',
             'root_joint_successor','substep_feedback_work','native_project_successor','positive_transport_successor',
             'saturation_surface_continuation_20261022','day65_continuation_20261023']:document=document[key]
 return document
def record(reader=lambda p:(ROOT/p).read_bytes()):return child(json.loads(reader(STATUS)))['source_admission']
def enabled():
 try:return 'source_admission'in child(json.loads((ROOT/STATUS).read_text()))
 except KeyError:return False
def projection(path=PARENT):
 text=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
 names=[('source','reader,changed'),('verify',''),('self_test','')]
 if path!=CYCLE_PARENT:names.append(('fsi35_successors',''))
 for name,args in names:
  offset=text.index('\n',text.index('def '+name+'('))+1
  indent='    'if path==PARENT else' '
  target='nut_source'if path!=PARENT and name=='source'else name
  hook=indent+"native=ROOT/'"+SELF+"'\n"+indent+"if native.is_file():\n"+indent*2+"successor=runpy.run_path(str(native))\n"+indent*2+"if successor['enabled']():return successor['"+target+"']("+args+")\n"
  text=text[:offset]+hook+text[offset:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_calendar_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_calendar_output.py'))['source'](reader,changed)
 r=record(reader);assert r['baseline']==BASE
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 assert delta==r['source_delta']and set(delta)==set(r['postimages'])|{STATUS},'unregistered native scientific delta'
 assert {p for p in delta if p.startswith('src/')}==PRODUCTION,'native production boundary'
 assert not any(p.startswith(('reference/','examples/','.github/'))for p in delta),'foreign reference/workflow/example change'
 for p,h in {**r['postimages'],**r['source_inputs']}.items():assert sha(reader(p))==h,('native current input',p)
 for path in [PARENT,NUT_PARENT,CYCLE_PARENT]:assert reader(path)==projection(path),'original canonical owner assertion bodies changed'
 current=json.loads(reader(STATUS));p=current
 for key in ['swp_water_successor','daily_meteo_successor','etref_successor','simple_crop_preparation_successor','root_joint_successor','substep_feedback_work']:p=p[key]
 p.pop('native_project_successor')
 assert current==json.loads(subprocess.check_output(['git','show',BASE+':'+STATUS],cwd=ROOT)),'unrelated SOL authority changed'
 assert not git('status','--porcelain','--',*SCIENCE),'dirty native scientific surface'
 if changed is not None:
  for p in changed:
   assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign native caller'
 return json.loads(reader(STATUS))['swp_water_successor']
def nut_source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 source(reader,changed)
 return runpy.run_path(str(ROOT/NUT_PARENT))['record'](reader)
def unpack(raw):
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f['MANIFEST.json'])=={p:sha(v)for p,v in f.items()if p!='MANIFEST.json'}
 return f
def evidence():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes())
 assert sha(raw)==e['decoded_sha256']and len(raw)==e['decoded_bytes']
 return unpack(raw)
def inherited():
 e=child(json.loads((ROOT/STATUS).read_text()))['evidence']
 g=runpy.run_path(str(ROOT/'integration/audits/verify_sol_day65_continuation.py'))
 raw,f=g['capsule'](ROOT/e['path']);assert sha(raw)==e['decoded_sha256']
 # The old execution retains its exact codec preimage. A separate fresh current
 # cold/thermal/saved/fallow composition qualifies the admitted codec successor.
 def physical_reader(p):
  if p==CODEC:
   assert (ROOT/p).read_bytes()==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
   return subprocess.check_output(['git','show',PHYSICAL_BASE+':'+p],cwd=ROOT)
  return(ROOT/p).read_bytes()
 return f,g['validate'](f,physical_reader)
def independent_policies(reader=lambda p:(ROOT/p).read_bytes()):
 results={}
 for path,digest,member,field,expected in [
  ('integration/audits/evidence/MC_SOL01_POSITIVE_TRANSPORT_RESEARCH_20261022.tar.xz.b64','afbe6ddbc158e968431bdcbf2eb5d6020e9ad56cd710e12aeaf8d7856ec91962',
   'implicit-conservative-process/result.json','inputs','TRANSPORT_IMPLICIT_POSITIVE_MASS_ORACLE_REFERENCE_REJECTION_O0_O2_PASS'),
  ('integration/audits/evidence/MC_SOL01_SURFACE_CONTINUATION_20261022.tar.xz.b64','824e3f7c8a0ae371ccf0b25bf3b11bc6bb5a1903db8e029b205624ee6bfbe744',
   'proof/pond-contract/result.json','input_sha256','LEAF_PASS_NOT_RUNTIME_ADMISSION')]:
  raw=base64.b64decode(reader(path))
  if digest is not None:assert sha(raw)==digest
  f=unpack(raw);r=json.loads(f[member]);assert r['status']==expected
  for p,h in r[field].items():assert sha(reader(p))==h,('independent policy input changed',p)
  if field=='inputs':
   assert r['providers']==6 and len(r['events'])==4 and all(e['returncode']==0 for e in r['events'])
   for i in [1,3]:
    output=f['implicit-conservative-process/'+f'{i:04d}.stdout']
    assert b'TRANSPORT_IMPLICIT_POSITIVE_MASS_ORACLE_REFERENCE_REJECTION_PASS'in output
  else:
   assert r['providers']==2 and 'HISTORICAL_ZERO_UPWARD_240_ORACLE_REJECTION_RESTORE_REMOBILIZE_RUNOFF=PASS'in r['stdout']
  results[member]=dict(status=expected,providers=r['providers'],decoded_sha256=sha(raw),inheritance='Exact independent production/caller/oracle inputs and unchanged checked O0/O2 closure')
 return results
def validate(f,reader=lambda p:(ROOT/p).read_bytes()):
 def js(p):return json.loads(f[p])
 report=js('ASSESSMENT.json');assert report['baseline']==BASE and not report['canonically_admitted']
 # The concurrent performance research adds an unused optional caller profile.
 # Retain the actual old execution recipe and admit only this exact additive
 # forwarding change; all selected weather commands use the original profile.
 recipe='benchmarks/performance/run_perf01_warm_weather.py'
 before=subprocess.check_output(['git','show',PHYSICAL_BASE+':'+recipe],cwd=ROOT,text=True)
 after=before.replace("args = ap.parse_args()","ap.add_argument('--profile', choices=['original', 'sensitive'], default='original')\nargs = ap.parse_args()")
 after=after.replace('if args.restart:',"cmd += ['--profile', args.profile]\nif args.restart:")
 assert reader(recipe)==after.encode(),'foreign warm weather recipe successor'
 assert f['execution-recipes/warm-weather.py']==before.encode()
 for p,h in report['current_inputs'].items():assert sha(reader(p))==h,('compiled/current assertion input',p)
 frozen=js('frozen-owner.json');controls=js('frozen-controls.json')
 assert frozen['qualified']and frozen['source_tree']==git('rev-parse',PHYSICAL_BASE+':src')and len(controls)==15,'frozen canonical authority'
 prior_raw=reader(CANONICAL_PROOF);assert sha(prior_raw)=='bcf446368a5cc8a1cfe41deac4718bc3f66f05712abe05972a17446c2fd16f3d'
 with tarfile.open(fileobj=io.BytesIO(prior_raw),mode='r:xz')as t:prior={m.name:t.extractfile(m).read()for m in t.getmembers()}
 prior_manifest=json.loads(prior['MANIFEST.json']);assert all(sha(prior[p])==h for p,h in prior_manifest.items())
 statuses={'incumbent-final':('PASS',86),'chemistry':('ORIGINAL_SWP_CHEMISTRY_O0_O2_MAPPING_BALANCE_RESTART_REJECTION_PASS',172),
  'water':('PASS',110),'daily-proof':('PASS',72),'etref-final':('PASS',44),'crop-joint-final':('NATIVE_CROP_ROOT_JOINT_O0_O2_PASS',86),
  'crop-transaction':('CROP_ROOT_REAL_REJECT_RETRY_O0_O2_PASS',4),'trace':('CANONICAL_WEATHER_TRACE_AND_REJECT_RETRY_O0_O2_PASS',4)}
 for label,(status,count)in statuses.items():
  r=js(label+('/RESULT.json'if label=='trace'else'/result.json'));assert r['status']==status and len(r['events'])==count,(label,'incomplete current native body')
 direct=js('direct-line-search/RESULT.json')
 assert direct['status']=='TYPED_LINE_SEARCH_OFF_ON_UNSUPPORTED_AND_ORIGINAL_O0_O2_PASS'and direct['provider_count']==21 and len(direct['events'])==66
 assert all(e['returncode']==0 for e in direct['events'])
 assert sha(f['direct-line-search/driver.f90'])==direct['generated_driver_sha256']
 for p,h in direct['input_sha256'].items():assert sha(reader(p))==h
 for e in direct['events']:
  for k in ['stdout','stderr']:assert'direct-line-search/'+e[k]in f
 for opt in ['O0','O2']:
  for label in ['column-','project-']:
   p=label+opt+('/shared'if label=='project-'else'')+'/build-complete.json';b=js(p)
   assert b['status']=='BUILT'and '-'+opt in b['flags']and '-fcheck=all'in b['flags']
   assert all(e['returncode']==0 for e in b['events'])
   for p,h in b['input_sha256'].items():assert sha(reader(p))==h
  b=js('weather-'+opt+'/BUILD.json');assert b['status']=='BUILT'and all(e['returncode']==0 for e in b['events'])
  for p,h in b['sources'].items():
   if p=='tests/fsi/fsi04_real_headcalc_stubs.f90':assert sha(f['weather-'+opt+'/grid_stubs.f90'])==h
   elif p=='src/runtime/mod_fmr_serialized_multiswap_runtime.f90':assert sha(f['weather-'+opt+'/observed_serial_runtime.f90'])==h and sha(reader(p))==b['observer_original_sha256']
   elif p=='src/runtime/mod_fmr_production_application_bootstrap.f90':assert sha(f['weather-'+opt+'/observed_bootstrap.f90'])==h and sha(reader(p))==b['surface_observer_original_sha256']
   else:assert sha(reader(p))==h,(opt,p)
  assert sha(reader('src/legacy/b1_10_port/headcalc.f90'))==b['headcalc_sha256']
  assert sha(f['weather-'+opt+'/driver.f90'])==b['generated_driver_sha256']
  for label,status in [('focused','WARM_START_AND_ORIGINAL_CORNER_CONTROLS_PASS'),('original-weather','WEATHER_SURFACE_NATIVE_PRESERVATION_PASS'),('default','DEFAULT_REAL_SOLVER_BEFORE_AFTER_BYTE_EXACT')]:
   r=js(label+'-'+opt+'/RESULT.json');assert r['status']==status and all(e['returncode']==0 for e in r['events'])
  for mode in ['season','on-season','warm-season']:
   for rain in [1,4]:
    prefix=mode+'-'+opt+'-'+str(rain)+'x/native/';r=js(prefix+'RESULT.json')
    assert r['status']=='COMPLETE_NATIVE_OBSERVATION'and r['completed_days']==97 and r['returncode']==0 and not r['timed_out']and r['head_budget_cm']==.001
    for p,h in r['raw_sha256'].items():assert sha(f[prefix+p])==h
    # Existing program assertions include actual runoff and gross balance.
    assert b'PERF01_LIVE_WEATHER_COMPLETE'in f[prefix+'stdout']
 retained,retained_result=inherited()
 nut=runpy.run_path(str(ROOT/'integration/audits/validate_native_nut_composition.py'))['validate'](f,reader)
 latest=js('latest-canonical.json')['owner']
 for label,season in [('restart-native','season-O2-4x'),('on-restart-native','on-season-O2-4x')]:
  r=js(label+'/RESULT.json');assert r['status']=='COMPLETE_NATIVE_OBSERVATION'and r['completed_days']==97 and r['returncode']==0
  assert f[label+'/stdout']==f[season+'/native/stdout'],'current day35 reconstruction drift'
 for label in ['off-rollback-native','rollback-native']:
  r=js(label+'/RESULT.json');assert r['status']=='PASS'and r['returncode']==0 and b'WEATHER_SURFACE_ROLLBACK_PASS'in f[label+'/stdout']
  assert sha(f[label+'/stdout'])==r['raw_sha256']['stdout']
 aliases={'nut-owner/cold/':'proof/composite-nut-final/','nut-owner/thermal/':'proof/composite-nut-thermal/',
  'calendar-owner/calendar/':'proof/composite-nut-calendar/','nut-harvest/':'proof/composite-nut-harvest/',
  'saved-owner/physical/':'proof/composite-nut-saved/','root-substep-daily/':'proof/composite-default-daily/',
  'root-substep-transaction/':'proof/composite-default-transaction/'}
 current_prefixes=list(statuses)+[q+'-'+o for o in ['O0','O2']for q in ['focused','original-weather','default']]+[
  mode+'-'+o+'-'+str(rain)+'x'for o in ['O0','O2']for mode in ['season','on-season','warm-season']for rain in [1,4]]
 exact=[];timed_csv=[]
 for p,old in prior.items():
  if any('.pending-'in part for part in Path(p).parts):continue
  if Path(p).suffix not in ['.csv','.bin','.generation','.endpoint']:continue
  if any(p.startswith(prefix+'/')for prefix in current_prefixes):
   assert p in f,('missing current physical file',p)
   if p.endswith('/native/daily.csv'):
    before=list(csv.DictReader(io.StringIO(old.decode())));after=list(csv.DictReader(io.StringIO(f[p].decode())))
    for rows in [before,after]:
     for row in rows:
      cpu=float(row.pop('core_cpu_s'));assert math.isfinite(cpu)and cpu>=0
    assert before==after,('current timed CSV physical drift',p);timed_csv.append(p)
   else:assert f[p]==old,('current incumbent physical drift',p);exact.append(p)
  for prefix,target in aliases.items():
   if p.startswith(prefix):
    key=target+p[len(prefix):];assert key in retained and retained[key]==old,('retained current physical drift',p);exact.append(p)
 assert len(exact)>=300,'incomplete incumbent physical comparison'
 for prefix,target in aliases.items():
  if 'nut'in prefix or 'calendar'in prefix or 'saved'in prefix:
   old=json.loads(prior[prefix+'result.json']);new=json.loads(retained[target+'result.json'])
   assert old['results']==new['results'],('NUT result drift',prefix)
 return dict(**{k:v for k,v in latest.items()if k not in ['qualified','current_source_tree','source_tree','canonically_admitted','full_historical_migration','qualification_scope']},qualified=True,
  native_project_status='BOUNDED_NATIVE_PROJECT_CURRENT_COMPOSITION_QUALIFIED',qualification_scope='BOUNDED_NATIVE_PROJECT_AND_EXPLICIT_POLICIES_WITH_CURRENT_INCUMBENT_PRESERVATION',
  current_source_tree=git('rev-parse','HEAD:src'),source_tree=git('rev-parse','HEAD:src'),
  current_native_processes={p:n for p,(_,n)in statuses.items()},exact_incumbent_physical_files=len(exact),
  timed_csv_physical_fields_exact=len(timed_csv),timing_column_excluded='core_cpu_s only; all state, flux, mass and solver-count fields exact',
  current_weather_97day_cases=12,current_NUT_families=7,current_thermal_fallow_composition=nut,retained_current_native=retained_result,
  independent_policy_contracts=independent_policies(reader),
  frozen_predecessor=frozen,full_historical_migration=False,canonically_admitted=False)
def fsi35_successors():
 source();rows={p:dict(v)for p,v in record()['frozen_fsi35_successors'].items()}
 for p,row in rows.items():
  expected=git('rev-parse',BASE+':'+p);current=git('rev-parse','HEAD:'+p)
  assert row['canonical_blob']==expected,'foreign frozen FSI35 table'
  if current!=expected:assert p in PRODUCTION;row['canonical_blob']=current
 return rows
def verify():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_calendar_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_calendar_output.py'))['verify']()
 source();r=validate(evidence());native=record().get('native_fsi35')
 if native:
  raw=(ROOT/native['path']).read_bytes();assert sha(raw)==native['sha256']
  with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
   result=json.load(t.extractfile('RESULT.json'));stdout=t.extractfile('stdout').read()
   assert result['returncode']==0 and result['status']=='PASS'and sha(stdout)==result['raw_sha256']['stdout']and b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in stdout
   for p,h in result['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h
 r['fsi35_native']='PASS'if native else'PENDING_SEPARATE_ORIGINAL_NATIVE_GATE'
 r['current_source_controls']=record().get('source_controls','PENDING_SEPARATE_CONTROLS')
 return r
def self_test():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_calendar_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_calendar_output.py'))['self_test']()
 source();controls=[]
 for p in set(record()['postimages'])|{'src/crop/mod_crop_soil_n_day.f90','tests/fci/run_fci93_non_m1_fixed_k_qualification.sh'}:
  try:source(lambda q:(ROOT/q).read_bytes()+(b'corrupt'if p==q else b''))
  except(AssertionError,KeyError):controls.append('source:'+p)
  else:raise AssertionError('source corruption accepted '+p)
 try:source(changed={'src/foreign_native_project.f90':'A'})
 except AssertionError:controls.append('foreign caller')
 else:raise AssertionError('foreign caller accepted')
 f=evidence()
 for p in ['chemistry/O0/dry/full/budget.csv','season-O2-4x/native/stdout','frozen-owner.json','nut-current/fallow/result.json','latest-canonical.json']:
  # Pick an actual raw chemistry member, independently of fixture label spelling.
  if p.startswith('chemistry/')and p not in f:p=next(q for q in f if q.startswith('chemistry/')and q.endswith('/budget.csv'))
  bad=dict(f);bad.pop(p)
  try:validate(bad)
  except(AssertionError,KeyError):controls.append('missing:'+p)
  else:raise AssertionError('missing raw accepted '+p)
 return controls
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
