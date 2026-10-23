"""Exact failed-solve refinement; historical evidence is not a new current run.

Every predecessor assertion body remains immutable. The old physical proof is
retained for the unchanged successful solve path; new application, rejection,
excluded-provider and original FSI35 native executions qualify the added path.
This does not promote whole MC-SOL01/MC-NUT01 or equivalent-accuracy performance.
"""
import csv,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='188f75ef04cd64a5a78ace0aa4b8977e7a130537'
STATUS='benchmarks/performance/PERF01_NATIVE_431_WEATHER_20261023_STATUS.json'
SELF='integration/performance/verify_saturated_flux_successor.py'
NATIVE='integration/audits/native_project_admission.py'
NUT='integration/audits/verify_nut_saved_calendar_output.py'
HIST='integration/audits/verify_nut_historical_output_caller.py'
HEAD='src/legacy/b1_10_port/headcalc.f90'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def require(ok,why):
 if not ok:raise AssertionError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def before(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['source_successor']
def projection(path):
 text=before(path).decode();names=['source','verify','self_test']+(['fsi35_successors']if path==NATIVE else[])
 for name in names:
  offset=text.index('\n',text.index('def '+name+'('))+1
  target='nut_verify'if path in [NUT,HIST]and name=='verify'else name
  args='reader,changed'if name=='source'else''
  hook=" if 'source_successor' in json.loads((ROOT/'"+STATUS+"').read_text()):return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+target+"']("+args+")\n"
  text=text[:offset]+hook+text[offset:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'historical_integration01_20261023' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_seasonal_bottom.py'))['source'](reader,changed)
 r=record(reader);require(r['baseline']==BASE,'saturated flux baseline')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta=={HEAD:'M',NATIVE:'M',NUT:'M',HIST:'M',SELF:'A'},'foreign saturated flux scientific delta')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty saturated flux science')
 for p,h in {**r['incumbent_input_sha256'],**r['postimages']}.items():require(sha(reader(p))==h,'saturated flux source '+p)
 for p in [NATIVE,NUT,HIST]:require(reader(p)==projection(p),'original owner assertion bodies changed '+p)
 # Exact insertion-only refinement. No old equation, gate or return is edited.
 counts=git('diff','--numstat',BASE,'HEAD','--',HEAD).split()
 require(counts[:2]==['103','0'],'ordinary solver body changed')
 require(git('rev-parse','HEAD:src')==r['source_tree'],'unqualified production tree')
 if changed is not None:
  for p in changed:
   if p not in delta:require(subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'unknown saturated flux caller '+p)
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=(ROOT/e['path']).read_bytes();require(sha(raw)==e['sha256']and len(raw)==e['bytes'],'saturated flux capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as archive:
  ms=archive.getmembers();require(len(ms)==e['members']==len({m.name for m in ms}),'saturated flux census')
  require(all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'unsafe saturated flux archive')
  files={m.name:archive.extractfile(m).read()for m in ms}
 require(json.loads(files['MANIFEST.json'])=={p:sha(v)for p,v in files.items()if p!='MANIFEST.json'},'saturated flux complete inventory')
 return files
def validate(f,reader=lambda p:(ROOT/p).read_bytes()):
 def js(p):return json.loads(f[p])
 def inputs(rows):
  for p,h in rows.items():require(sha(reader(p))==h,'executed source '+p)
 def rows(p):return list(csv.DictReader(io.StringIO(f[p].decode())))
 old=js('predecessor/owner.stdout');controls=js('predecessor/controls.stdout')
 require(old['qualified']and len(controls)==147 and len(set(controls))==147,'complete actual predecessor147 controls')
 require(not f['predecessor/owner.stderr']and not f['predecessor/controls.stderr'],'predecessor execution failed')
 composed=js('predecessor-composed/owner.stdout');composed_controls=js('predecessor-composed/controls.stdout')
 require(composed['qualified']and len(composed_controls)==163 and len(set(composed_controls))==163,'complete concurrent predecessor163 controls')
 require(not f['predecessor-composed/owner.stderr']and not f['predecessor-composed/controls.stderr'],'concurrent predecessor execution failed')
 current=js('raw/perf01-native-fixed-study/RESULT.json');debug=js('raw/perf01-native-fixed-O0-study/RESULT.json')
 for study,count in [(current,12),(debug,4)]:
  require(study['status']=='COMPLETE_ACTUAL_COMMON_INPUT_APPLICATION_OBSERVATIONS'and len(study['runs'])==count and study['days']==97,'incomplete paired native applications')
  require(study['surface_exfiltration']=='historical_zero'and study['source_tree']==record()['executed_source_tree'],'application source/convention')
  for event in study['runs']:
   label=event['label'];prefix=('raw/perf01-native-fixed-study/'if count==12 else'raw/perf01-native-fixed-O0-study/')+label+'/'
   require(event['returncode']==(100 if event['arm']=='legacy'else 0),'native application failure')
   for stream in ['stdout','stderr']:require(prefix[:-1]+'.'+stream in f,'missing raw paired execution')
   if event['arm']=='current':
    data=rows(prefix+'budget.csv');require(len(data)==97,'complete current budget')
    require(max(abs(float(r['water_residual_cm']))for r in data)<1e-10,'hard daily water balance')
    require(all(float(r['solute_start_mg_cm2'])==float(r['solute_end_mg_cm2'])==0 for r in data),'zero tracer changed')
   else:require(prefix+'swap.ok'in f,'original application did not finish')
  for rain in ['1','4']:
   c=study['cases'][rain];require(c['current_max_independent_gross_balance_mm']<1e-9,'independent gross water')
   require(c['max_daily_total_evaporation_difference_mm']<1e-9,'total evaporation disagreement')
   require(c['max_daily_difference_mm']['runoff']<.01,'material runoff discrepancy')
   require(c['max_daily_difference_mm']['actual_transpiration']<1e-9,'uptake disagreement')
 for opt in ['O0','O2']:
  m=js('raw/perf01-native-fixed-'+opt+'/shared/build-complete.json');require(m['status']=='BUILT'and '-'+opt in m['flags']and'-fcheck=all'in m['flags'],'fresh checked project build')
  inputs(m['input_sha256']);require(all(e['returncode']==0 for e in m['events']),'failed project build event')
 for rain in ['1','4']:
  full='raw/perf01-native-fixed-study/'+rain+'x-0-current/'
  require(current['cases'][rain]['totals_mm']==debug['cases'][rain]['totals_mm'],'O0/O2 physical drift')
  for repetition in [1,2]:require(f[full+'budget.csv']==f['raw/perf01-native-fixed-study/'+rain+'x-'+str(repetition)+'-current/budget.csv'],'repeat physical nondeterminism')
  resumed='raw/perf01-native-fixed-resume'+rain+'/'
  for name in ['restart.bin','state.csv','endpoint.csv']:require(f[full+name]==f[resumed+name],'midpoint restart endpoint '+name)
  require(rows(full+'budget.csv')[48:]==rows(resumed+'budget.csv'),'midpoint restart daily trajectory')
 contract=js('raw/perf01-native-fixed-contract-v2/RESULT.json');inputs(contract['input_sha256'])
 require(contract['status']=='SATURATED_FLUX_CURRENT_PREDECESSOR_AND_FSI35_NATIVE_COMPLETE'and all(e['returncode']==0 for e in contract['events']),'new production contract/native FSI35 incomplete')
 for opt in ['O0','O2']:
  o=contract['outputs'];require(o[opt+'-old-unsupported']==o[opt+'-current-unsupported'],'excluded provider drift')
  require([int(line.split()[2])for line in o[opt+'-current'].splitlines()]==[1,2,1],'new accepted/rejected matrix')
  require([int(line.split()[2])for line in o[opt+'-old'].splitlines()]==[2,2,1],'original failure discriminator')
 for e in contract['events']:
  for stream in ['stdout','stderr']:require('raw/perf01-native-fixed-contract-v2/'+e[stream]in f,'missing actual native contract stream')
 require(any(b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in raw for p,raw in f.items()if p.startswith('raw/perf01-native-fixed-contract-v2/')and p.endswith('.stdout')),'original native FSI35 terminal absent')
 full=f['raw/perf01-native-fixed-original-full-fsi35-v2.stdout']
 for marker in [b'FCI93_EXACT_TRANSITIVE_COMPILE_DEPENDENCIES=PASS',b'FCI93_FIXED_K_EXACT_BOUNDED_POSTIMAGE=PASS',b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS']:
  require(marker in full,'complete original FSI35 source/native gate')
 direct=js('raw/perf01-native-fixed-direct/RESULT.json');inputs(direct['input_sha256'])
 require(direct['status']=='TYPED_LINE_SEARCH_OFF_ON_UNSUPPORTED_AND_ORIGINAL_O0_O2_PASS'and len(direct['events'])==66 and all(e['returncode']==0 for e in direct['events']),'original typed controls incomplete')
 rejects=[raw for p,raw in f.items()if'perf01-native-fixed-default-exfiltration.pending-'in p and p.endswith('/stdout')]
 require(len(rejects)==1 and b'joint status/water/chemical:            3           0           2'in rejects[0],'default exfiltration rejection weakened')
 return dict(qualified=True,status='BOUNDED_SATURATED_FLUX_RESTART_O0_O2_AND_COMMON_ORIGINAL_INPUT_APPLICATIONS_PASS',
  full_application_processes=16,days=97,midpoint_restart_cases=2,typed_control_processes=12,
  fsi35_native='ORIGINAL_NATIVE_ORACLES_O0_O2_PASS',predecessor_controls=147,concurrent_predecessor_controls=163,
  predecessor_scope='Actually rerun at exact710b baseline, not relabelled as new-current native execution',
  inheritance='Insertion-only failed-solve refinement; successful original path and excluded provider remain exact; new path independently exercised',
  measured_current_O2_seconds={rain:current['cases'][rain]['timing']['current']['wall_seconds']for rain in ['1','4']},
  equivalent_accuracy_performance=False,full_mc_sol01_closed=False,full_mc_nut01_closed=False)
def verify():
 if 'historical_integration01_20261023' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_seasonal_bottom.py'))['verify']()
 source();result=validate(capsule());return{**result,'source_tree':git('rev-parse','HEAD:src'),'current_source_tree':git('rev-parse','HEAD:src'),'qualification_scope':'EXACT_FAILED_SOLVE_REFINEMENT_WITH_UNCHANGED_SUCCESS_PATH_INHERITANCE','canonically_admitted':False}
def nut_verify():
 result=verify();old=json.loads(capsule()['predecessor-composed/owner.stdout'])
 return{**old,**result,'incumbent_native_proof_scope':'Historical exact710b/188f owners and147/163 controls; unchanged-success-path inheritance, not a fresh whole NUT run'}
def fsi35_successors():
 source();rows=json.loads(capsule()['predecessor/fsi35.json'])
 for p,row in rows.items():row['canonical_blob']=git('rev-parse','HEAD:'+p)
 return rows
def self_test():
 if 'historical_integration01_20261023' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_native_seasonal_bottom.py'))['self_test']()
 source();f=capsule();validate(f);passed=[]
 def reject(label,fn):
  try:fn()
  except(AssertionError,ValueError,KeyError):passed.append(label);return
  raise AssertionError('accepted corruption '+label)
 for p in [HEAD,NATIVE,NUT,HIST,SELF,'src/crop/mod_crop_soil_n_day.f90']:
  reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if p==q else b'')))
 reject('foreign scientific source',lambda:source(changed={'src/foreign_saturated_flux.f90':'A'}))
 for p in ['predecessor/owner.stdout','predecessor/controls.stdout','predecessor-composed/owner.stdout','predecessor-composed/controls.stdout','raw/perf01-native-fixed-study/RESULT.json','raw/perf01-native-fixed-O0-study/RESULT.json','raw/perf01-native-fixed-contract-v2/RESULT.json','raw/perf01-native-fixed-direct/RESULT.json','raw/perf01-native-fixed-original-full-fsi35-v2.stdout']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['raw/perf01-native-fixed-resume4/restart.bin','raw/perf01-native-fixed-resume1/budget.csv']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
