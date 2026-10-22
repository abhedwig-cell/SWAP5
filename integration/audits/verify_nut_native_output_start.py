"""Bounded native TRUE startup successor; preserves the exact previous owner."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile,sys
ROOT=Path(__file__).resolve().parents[2]
BASE='288ba1473c478b9a2a637f0b12d624fbcc63ca4a'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
PARENT='integration/audits/verify_swp_daily.py'
SELF='integration/audits/verify_nut_native_output_start.py'
KEY='native_startup_successor_20261022'
SCIENCE=['src','app','tests','tools','reference','examples','.github','integration/audits','integration/performance','integration/diagnostics']
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['extended_output_component_20261021'][KEY]
def historical(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def projection():
 s=historical(PARENT).decode()
 condition="'postimages' in json.loads((ROOT/'"+STATUS+"').read_text())['extended_output_component_20261021'].get('"+KEY+"',{})"
 for entry,target,args in [('source','source','reader,changed'),('verify','verify',''),('self_test','self_test','include_predecessor')]:
  start=s.index('def '+entry+'(');offset=s.index('\n',start)+1
  hook="    if "+condition+":\n        return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+target+"']("+args+")\n"
  s=s[:offset]+hook+s[offset:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'evidence' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text())['swp_water_successor']['daily_meteo_successor'].get('etref_successor', {}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_etref.py'))['source'](reader,changed)
 r=record(reader);require(r['baseline']==BASE,'native startup baseline')
 for p,h in r['postimages'].items():require(sha(reader(p))==h,'native startup postimage '+p)
 for p,h in r['qualified_input_sha256'].items():require(sha(reader(p))==h,'executed native startup input '+p)
 require(reader(PARENT)==projection(),'predecessor owning assertions changed')
 prior=json.loads(historical(STATUS));current=json.loads(reader(STATUS))
 current['extended_output_component_20261021'].pop(KEY)
 require(current==prior,'unrelated NUT status changed')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty scientific source')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 actual={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}if changed is None else changed
 require(actual==r['scientific_delta'],'foreign scientific delta')
 return r

def capsule():
 r=record();index_path=ROOT/r['evidence_index'];require(sha(index_path.read_bytes())==r['evidence_index_sha256'],'index identity')
 index=json.loads(index_path.read_text());raw=base64.b64decode(b''.join((index_path.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'native capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  members=t.getmembers();require(len(members)==len({m.name for m in members}),'duplicate native members')
  require(all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members),'unsafe native members')
  f={m.name:t.extractfile(m).read()for m in members}
 require(f.keys()==index['members'].keys(),'native member inventory')
 require(all(sha(v)==index['members'][p]for p,v in f.items()),'native member identity')
 return f

def validate(f):
 def js(p):return json.loads(f[p])
 r=js('project/result.json');n=js('input/result.json');c=js('controls/result.json');o=js('original/result.json')
 require(r['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS','no actual native project success')
 require(n['status']=='NATIVE_OUTPUT_INPUT_O0_O2_PASS'and n['new_cases']==26 and n['incumbent_cases']==38,'native input coverage')
 require(c['status']=='NATIVE_OUTPUT_THREE_COMPILED_CONTROLS_PASS'and len(c['controls'])==3,'compiled controls')
 require(all(v['compiled']and v['assertions_rejected']and v['returncode']!=0 for v in c['controls'].values()),'mutant escaped')
 require(o['status']=='BOUNDED_CROP_EXT_COMPONENT_SOURCE_EXACT_PASS','original arithmetic')
 require(r['results']['O0']==r['results']['O2']and n['results']['O0']==n['results']['O2'],'optimization drift')
 require(sha(f['project/driver.f90'])==r['generated_driver_sha256'],'executed actual driver')
 for kind,report in [('project',r),('input',n),('original',o)]:
  for p,h in report['input_sha256'].items():require(sha((ROOT/p).read_bytes())==h,'actual native source '+p)
  events=js(kind+'/events.json');require(all(e['returncode']==0 for e in events),'failed final native event')
  for e in events:
   for stream in ['stdout','stderr']:require(kind+'/'+e[stream]in f,'missing native stream')
  if kind=='project':
   require(sum(e['category']=='native_output'for e in events)==2,'missing actual project runs')
   require(sum(e['category']=='native_output_restart'for e in events)==2,'missing independent project restart')
   require(sum(e['category']=='native'for e in events)==4,'missing original real owner assertions')
 for opt in ['O0','O2']:
  prefix='project/'+opt+'/'
  for endpoint in ['native.endpoint','native.fresh']:
   require(f[prefix+endpoint+'.true']==f[prefix+endpoint+'.false'],'TRUE changes physics')
   require(f[prefix+endpoint+'.initial-true']==f[prefix+endpoint+'.initial-false'],'TRUE changes native initialization')
   require(f[prefix+endpoint]==f[prefix+endpoint+'.after-rejected-start'],'failed startup leaks')
  for suffix in ['', '.csv','.true','.false']:
   require(f[prefix+'native.endpoint'+suffix]==f[prefix+'native.fresh'+suffix],'fresh native endpoint drift')
  require(sha(f[prefix+'native.endpoint'])==r['results'][opt]['native_endpoint'],'report endpoint identity')
  require(sha(f[prefix+'native.endpoint.csv'])==r['results'][opt]['native_csv'],'report CSV identity')
  require(f[prefix+'default.endpoint']==f[prefix+'default.fresh']==f[prefix+'default.endpoint.opaque'],'original physical continuation')
  require(sha(f[prefix+'default.endpoint'])==js('preservation.json')['incumbent_default_sha256'][opt],'prior accepted endpoint changed')
 predecessor=js('PREDECESSOR.json');require(predecessor['baseline']==BASE,'predecessor ref')
 require(predecessor['owner']['status']=='NATIVE_DAILY_MET_O0_O2_PASS'and len(predecessor['controls'])==39,'predecessor production controls')
 require(predecessor['research_observation']['status']=='PREEXISTING_FAILURE','research failure relabelled')
 return dict(status='NATIVE_OUTPUT_START_SOURCE_EVIDENCE_PASS',qualified=True,native_cases_per_opt=26,old_cases_per_opt=38,compiled_controls=3,actual_native_runs=4,full_migration=False)
def verify():
 if 'evidence' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text())['swp_water_successor']['daily_meteo_successor'].get('etref_successor', {}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_etref.py'))['verify']()
 source();return validate(capsule())
def self_test(include_predecessor=True):
 if 'evidence' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text())['swp_water_successor']['daily_meteo_successor'].get('etref_successor', {}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_etref.py'))['self_test']()
 source();f=capsule();validate(f);controls=[]
 def reject(name,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError,UnicodeError):controls.append(name);return
  raise ValueError('corruption accepted '+name)
 for p in ['src/process/mod_soil_n_historical_named_input.f90','src/process/mod_soil_n_unified_input.f90','src/crop/mod_crop_soil_n_historical_project_binding.f90','src/runtime/mod_fmr_b111_reactive_n_route.f90','src/adapter/mod_crop_soil_n_native_output_start.f90',PARENT,'tests/nut-crop/test_b112_retained_joint.f90']:
  reject('source '+p,lambda p=p:source(lambda x:(ROOT/x).read_bytes()+(b'!'if x==p else b'')))
 for p in ['project/result.json','input/result.json','controls/result.json','original/result.json','project/driver.f90','project/O0/native.endpoint','project/O2/native.fresh.csv','PREDECESSOR.json']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['project/O0/native.endpoint.false','project/O2/native.endpoint.initial-true','project/O0/native.endpoint.after-rejected-start','project/O2/default.fresh']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 bad=dict(record()['scientific_delta']);bad['src/unregistered_native_output.f90']='A';reject('foreign science',lambda:source(changed=bad))
 return dict(status='NATIVE_OUTPUT_START_CONTROLS_PASS',count=len(controls),controls=controls,predecessor_controls=39)
if __name__=='__main__':print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
