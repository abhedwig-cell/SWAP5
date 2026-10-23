"""Application caller qualification with all incumbent assertion bodies retained."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='710b41736214bcec80f0fe9bea6660cafa449024'
PARENT='integration/audits/verify_nut_saved_calendar_output.py'
SELF='integration/audits/verify_nut_historical_output_caller.py'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
KEY='historical_caller_successor_20261023'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def require(ok,why):
 if not ok:raise AssertionError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def before(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['extended_output_component_20261021'][KEY]
def projection():
 text=before(PARENT).decode();condition="'postimages' in json.loads((ROOT/'"+STATUS+"').read_text())['extended_output_component_20261021'].get('"+KEY+"',{})"
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  at=text.index('\n',text.index('def '+name+'('))+1;indent=text[at:at+len(text[at:])-len(text[at:].lstrip(' '))]
  text=text[:at]+indent+"if "+condition+":return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[at:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'source_successor' in json.loads((ROOT/'benchmarks/performance/PERF01_NATIVE_431_WEATHER_20261023_STATUS.json').read_text()):return __import__('runpy').run_path(str(ROOT/'integration/performance/verify_saturated_flux_successor.py'))['source'](reader,changed)
 r=record(reader);require(r['baseline']==BASE,'historical caller baseline')
 for path,h in {**r['incumbent_input_sha256'],**r['postimages']}.items():require(sha(reader(path))==h,'historical caller source '+path)
 require(reader(PARENT)==projection(),'incumbent147 assertion bodies')
 current=json.loads(reader(STATUS));current['extended_output_component_20261021'].pop(KEY)
 require(current==json.loads(before(STATUS)),'unrelated NUT authority')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty historical caller science')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={row.split('\t')[1]:row.split('\t')[0]for row in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta==r['scientific_delta']and all(code=='A'or path==PARENT for path,code in delta.items()),'foreign historical caller science')
 if changed is not None:
  for path in changed:
   if path not in delta:require(subprocess.run(['git','cat-file','-e',BASE+':'+path],cwd=ROOT,capture_output=True).returncode==0,'unknown historical caller source '+path)
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def legacy():
 ns={'__file__':str(ROOT/PARENT),'__name__':'immutable_saved_calendar_owner'}
 exec(compile(before(PARENT),PARENT,'exec'),ns);ns['source']=source;return ns
def capsule():
 r=record();path=ROOT/r['evidence_index'];require(sha(path.read_bytes())==r['evidence_index_sha256'],'historical caller index')
 index=json.loads(path.read_text());raw=base64.b64decode(b''.join((path.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'historical caller capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as archive:
  members=archive.getmembers();require(len(members)==len({m.name for m in members})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members),'historical caller member safety')
  files={m.name:archive.extractfile(m).read()for m in members}
 require(set(files)==set(index['members'])and all(sha(raw)==index['members'][path]for path,raw in files.items()),'historical caller inventory')
 return files
def validate(files):
 r=json.loads(files['qualified/result.json']);prior=json.loads(files['CALENDAR.json'])
 require(r['status']=='HISTORICAL_SAVED_OUTPUT_CALLER_O0_O2_PASS'and not r['full_mc_nut01_closed'],'historical caller terminal/scope')
 require(sha(files['CALENDAR.json'])==r['calendar_result_sha256']and r['results']==prior['results'],'complete incumbent calendar generations')
 require(r['native']['O0']==r['native']['O2'],'native optimization drift')
 for path,h in r['generated'].items():require(sha(files['qualified/'+path])==h,'historical caller generated '+path)
 events=json.loads(files['qualified/events.json']);require(events==r['events']and all(e['returncode']==0 for e in events),'historical caller execution')
 for category,count in [('provider_compile',2),('driver_compile',4),('actual_native',4),('roundtrip',64),('fresh',64),('old_identity',64),('crash_fresh',16),('native_startup',2),('native_restart',2)]:
  require(sum(e['category']==category for e in events)==count,'historical caller census '+category)
 for e in events:
  for stream in ['stdout','stderr']:require('qualified/'+e[stream]in files,'missing historical caller stream')
 for opt in ['O0','O2']:
  native='qualified/'+opt+'/native/'
  for suffix,h in r['native'][opt].items():
   require(sha(files[native+'endpoint'+suffix])==h and files[native+'endpoint'+suffix]==files[native+'fresh'+suffix],'native fresh generation '+suffix)
  for end in ['endpoint','fresh']:
   require(files[native+end+'.true']==files[native+end+'.false'],'native TRUE physical drift')
   require(files[native+end+'.initial-true']==files[native+end+'.initial-false'],'native startup physical drift')
   require(files[native+end]==files[native+end+'.after-rejected-start'],'native startup rejection drift')
  for kind in ['cold','heat']:
   base='qualified/'+opt+'/'+kind+'/';seeds=sorted(p for p in files if p.startswith(base)and p.endswith('.cycle.seed')and'.opaque-stages.'not in p)
   require(len(seeds)==2,'historical caller schedules')
   for seed in seeds:
    prefix=seed[:-5];stem=Path(prefix).name;schedule='deferred'if'deferred'in stem else'saved'
    for label in ['seed','day-5','day-6','phase-1','phase-2','phase-3','day-7','day-8']:
     actual=files[prefix+'.'+label]
     require(sha(actual)==r['results'][kind+'-'+opt][schedule][label],'historical caller incumbent identity')
     require(actual==files[prefix+'.manual-'+label]==files[base+stem+'-rt-'+label],'historical caller manual/roundtrip')
     if label!='day-8':require(files[base+stem+'-fresh-'+label+'.day-8']==files[prefix+'.day-8'],'historical caller phase-free fresh continuation')
    for phase in '123':require(files[prefix+'.before-phase-'+phase]==files[prefix+'.rejected-dispatch-phase-'+phase],'historical caller boundary rejection')
   prefix=seeds[0][:-5]
   for point,before,after in [('active','seed','day-5'),('fallow','phase-3','day-7')]:
    for phase in ['before','after']:
     crash=base+'crash-'+point+'-'+phase+'/';receipt=json.loads(files[crash+'result.json'])
     require(receipt['returncode']==-9 and receipt['complete'],'historical caller process crash')
     require(files[crash+'run.'+after]==files[prefix+'.'+(before if phase=='before'else after)],'historical caller crash authority')
     require(files[crash+'recovered.day-8']==files[prefix+'.day-8'],'historical caller crash continuation')
 frozen=json.loads(files['PREDECESSOR.json']);require(frozen['baseline']==BASE and frozen['owner']['qualified']and len(frozen['controls'])==147,'complete147 predecessor')
 return dict(qualified=True,status='HISTORICAL_SAVED_OUTPUT_CALLER_QUALIFIED',optimizations=2,roundtrips=64,fresh_progressions=64,crash_recoveries=16,native_startup_and_restart=4,complete_incumbent_generations_exact=True,full_mc_nut01_closed=False)
def verify():
 if 'source_successor' in json.loads((ROOT/'benchmarks/performance/PERF01_NATIVE_431_WEATHER_20261023_STATUS.json').read_text()):return __import__('runpy').run_path(str(ROOT/'integration/performance/verify_saturated_flux_successor.py'))['nut_verify']()
 source();prior=legacy()['verify']();result=validate(capsule())
 return {**prior,'qualified':True,'historical_output_caller':result,'qualification_scope':'EXPLICIT_HISTORICAL_SAVED_OUTPUT_APPLICATION_CALLER_WITH_INCUMBENT_PRESERVATION'}
def self_test():
 if 'source_successor' in json.loads((ROOT/'benchmarks/performance/PERF01_NATIVE_431_WEATHER_20261023_STATUS.json').read_text()):return __import__('runpy').run_path(str(ROOT/'integration/performance/verify_saturated_flux_successor.py'))['self_test']()
 source();prior=legacy()['self_test']();require(len(prior)==147,'incumbent147 controls lost')
 controls=['incumbent:'+label for label in prior];files=capsule();validate(files)
 def reject(label,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError):controls.append(label);return
  raise AssertionError('accepted historical caller corruption '+label)
 for path in ['src/adapter/mod_crop_soil_n_historical_output_application.f90','tests/nut-output/run_historical_output_caller.py',SELF,PARENT]:
  reject('source '+path,lambda path=path:source(lambda p:(ROOT/p).read_bytes()+(b'!'if p==path else b'')))
 for path in ['qualified/result.json','qualified/cold/driver.f90','qualified/native_output_project.inc','CALENDAR.json','PREDECESSOR.json']:
  bad=dict(files);bad.pop(path);reject('missing '+path,lambda bad=bad:validate(bad))
 for path in ['qualified/O0/native/endpoint.false','qualified/O2/native/endpoint.after-rejected-start']+sorted(p for p in files if p.startswith('qualified/')and'.cycle.manual-phase-'in p and'.opaque-stages.'not in p)[:4]:
  bad=dict(files);bad[path]+=b'!';reject('changed '+path,lambda bad=bad:validate(bad))
 reject('foreign historical caller source',lambda:source(changed={'src/foreign_historical_caller.f90':'A'}))
 require(len(controls)==163,'historical caller control census')
 return controls
if __name__=='__main__':print(json.dumps(verify(),indent=2))
