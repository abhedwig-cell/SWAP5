"""Accepted thermal output successor, bound to real current model execution."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='636760624e930f11517a42707fd16d885902c045'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
PARENT='integration/audits/verify_native_simple_crop.py'
SELF='integration/audits/verify_nut_thermal_output.py'
KEY='thermal_output_successor_20261022'
SCIENCE=['src','app','tests','tools','reference','examples','.github','integration/audits','integration/performance','integration/diagnostics']
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def historical(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['extended_output_component_20261021'][KEY]
def projection():
 text=historical(PARENT).decode()
 condition="'postimages' in json.loads((ROOT/'"+STATUS+"').read_text())['extended_output_component_20261021'].get('"+KEY+"',{})"
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  offset=text.index('\n',text.index('def '+name+'('))+1
  hook="    if "+condition+":\n        return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"
  text=text[:offset]+hook+text[offset:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record(reader);require(r['baseline']==BASE,'thermal baseline')
 for p,h in r['postimages'].items():require(sha(reader(p))==h,'thermal postimage '+p)
 for p,h in r['qualified_input_sha256'].items():require(sha(reader(p))==h,'executed thermal input '+p)
 require(reader(PARENT)==projection(),'predecessor owning assertions changed')
 before=json.loads(historical(STATUS));current=json.loads(reader(STATUS))
 current['extended_output_component_20261021'].pop(KEY)
 require(before==current,'unrelated NUT authority changed')
 p='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
 require(reader(p)==historical(p),'concurrent SOL authority changed')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty thermal science')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}if changed is None else changed
 require(delta==r['scientific_delta'],'foreign thermal science')
 return r
def capsule():
 r=record();path=ROOT/r['evidence_index'];require(sha(path.read_bytes())==r['evidence_index_sha256'],'thermal index')
 index=json.loads(path.read_text());raw=base64.b64decode(b''.join((path.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'thermal capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as archive:
  members=archive.getmembers();require(len(members)==len({m.name for m in members}),'duplicate thermal member')
  require(all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members),'unsafe thermal member')
  f={m.name:archive.extractfile(m).read()for m in members}
 require(f.keys()==index['members'].keys(),'thermal inventory')
 require(all(sha(v)==index['members'][p]for p,v in f.items()),'thermal member bytes')
 return f
def validate(f):
 def js(p):return json.loads(f[p])
 t=js('thermal/result.json');c=js('cold/result.json')
 require(t['status']=='THERMAL_OUTPUT_ACTUAL_O0_O2_RESTART_ATOMIC_PASS','missing thermal actual proof')
 require(c['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS','cold application preservation')
 require(t['cold_proof_sha256']==sha(f['cold/result.json']),'provider proof handoff')
 require(t['results']['O0']==t['results']['O2']and c['results']['O0']==c['results']['O2'],'optimization drift')
 require(sha(f['thermal/driver.f90'])==t['generated_driver_sha256'],'actual thermal driver')
 for p,h in {**t['cold_input_sha256'],**t['input_sha256']}.items():require(sha((ROOT/p).read_bytes())==h,'actual thermal source '+p)
 for prefix in ['cold','thermal']:
  events=js(prefix+'/events.json');require(all(e['returncode']==0 for e in events),'failed final thermal event')
  for e in events:
   for stream in ['stdout','stderr']:require(prefix+'/'+e[stream]in f,'missing execution stream')
 events=js('thermal/events.json')
 counts={k:sum(e['category']==k for e in events)for k in ['original_native','original_fresh','output_native','output_fresh','invalid_generation','invalid_identity','crash_reconstruction']}
 require(counts==dict(original_native=2,original_fresh=2,output_native=2,output_fresh=2,invalid_generation=26,invalid_identity=8,crash_reconstruction=4),'thermal execution inventory')
 for opt in ['O0','O2']:
  b='thermal/'+opt+'/'
  require(t['results'][opt]['invalids']==17,'thermal negative inventory')
  require(set(t['results'][opt]['crashes'])=={'before','after'},'crash phases')
  require(f[b+'output.endpoint']==f[b+'output.fresh']==f[b+'output.endpoint.opaque']==f[b+'original.endpoint'],'thermal original physical drift')
  for suffix in ['.generation','.csv','.automatic-inner','.ordinary-inner']:
   require(f[b+'output.endpoint'+suffix]==f[b+'output.fresh'+suffix],'thermal fresh drift')
  for prefix in ['output.restart','output.endpoint']:
   require(f[b+prefix+'.automatic-inner']==f[b+prefix+'.ordinary-inner'],'thermal output changes physics')
  for suffix in ['.environment-after','.material-after','.save-failed-after']:
   require(f[b+'output.restart'+suffix]==f[b+'output.restart.generation.zero'],'thermal failed day leaks')
  for suffix in ['.replay-after','.view-failed','.view-failed-memory']:
   require(f[b+'output.restart'+suffix]==f[b+'output.restart.generation'],'thermal saved authority drift')
  for phase in ['before','after']:
   p=b+'crash-'+phase+'/'
   want=f[p+'model.restart.generation.zero']if phase=='before'else f[b+'output.restart.generation']
   require(f[p+'model.restart.generation']==f[p+'recovered']==want,'thermal partial crash generation')
   require(t['results'][opt]['crashes'][phase]['returncode']==-9,'thermal process not killed')
  require(sha(f[b+'output.endpoint.generation'])==t['results'][opt]['generation'],'thermal endpoint receipt')
  require(sha(f[b+'output.endpoint.csv'])==t['results'][opt]['csv'],'thermal CSV receipt')
  prior=js('preservation.json')['cold_previous_results'][opt]
  require(c['results'][opt]==prior,'previous cold model/report bytes changed')
 frozen=js('preservation.json')['retained_thermal_frozen_artifacts']
 require(len(frozen)==12,'frozen thermal inventory')
 for key,h in frozen.items():
  opt,suffix=key[:2],key[2:]
  require(sha(f['thermal/'+opt+'/original.endpoint'+suffix])==h,'frozen thermal physical drift '+key)
 original=js('original/result.json')
 require(original['status']=='BOUNDED_CROP_EXT_COMPONENT_SOURCE_EXACT_PASS','original arithmetic proof')
 require(original['results']==dict(O0='CROP_EXT_SOURCE_EXACT_PASS checks=2721 reports=216',O2='CROP_EXT_SOURCE_EXACT_PASS checks=2721 reports=216'),'original arithmetic inventory')
 for p,h in original['input_sha256'].items():require(sha((ROOT/p).read_bytes())==h,'original arithmetic source '+p)
 predecessor=js('PREDECESSOR.json')
 require(predecessor['status']=='NATIVE_SIMPLE_CROP_PREPARATION_O0_O2_QUALIFIED'and predecessor['controls']==27,'complete predecessor qualification')
 return dict(status='THERMAL_OUTPUT_SOURCE_EVIDENCE_PASS',qualified=True,invalids_per_opt=17,crash_boundaries=4,old_cold_exact=True,full_mc_nut01_closed=False)
def verify():
 source();return validate(capsule())
def self_test():
 source();f=capsule();validate(f);controls=[]
 def reject(name,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError,UnicodeError):controls.append(name);return
  raise ValueError('corruption accepted '+name)
 for p in ['src/adapter/mod_crop_n_output_generation.f90','src/adapter/mod_crop_soil_n_output_day.f90','src/adapter/mod_crop_soil_n_output_observation.f90',PARENT,'src/runtime/mod_fmr_crop_soil_n_thermal_application.f90','src/runtime/mod_fmr_serialized_reference_backend.f90']:
  reject('source '+p,lambda p=p:source(lambda x:(ROOT/x).read_bytes()+(b'!'if x==p else b'')))
 for p in ['thermal/result.json','cold/result.json','thermal/driver.f90','PREDECESSOR.json','original/result.json','thermal/O0/output.endpoint.generation','thermal/O2/output.fresh.csv','thermal/O0/crash-before/recovered','thermal/O2/output.restart.save-failed-after']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['thermal/O0/output.endpoint.ordinary-inner','thermal/O2/output.restart.environment-after','thermal/O0/output.restart.view-failed-memory','thermal/O2/crash-after/model.restart.generation','thermal/O0/original.endpoint.stages.consumed']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 bad=dict(record()['scientific_delta']);bad['src/unregistered_thermal_output.f90']='A';reject('foreign thermal source',lambda:source(changed=bad))
 return dict(status='THERMAL_OUTPUT_GUARD_CONTROLS_PASS',count=len(controls),controls=controls,predecessor_controls=27)
if __name__=='__main__':print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
