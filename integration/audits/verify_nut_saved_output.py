"""Source-bound saved previous-day diagnostics, physical composition and restart."""
from pathlib import Path
import base64,hashlib,io,json,runpy,struct,subprocess,tarfile,zlib
ROOT=Path(__file__).resolve().parents[2]
BASE='0be6037b670fdd3cb004ff616b0925291ae56728'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
PARENT='integration/audits/verify_nut_harvest_output.py'
SELF='integration/audits/verify_nut_saved_output.py'
KEY='saved_residue_successor_20261022'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def historical(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['extended_output_component_20261021'][KEY]
def projection():
 text=historical(PARENT).decode();condition="'postimages' in json.loads((ROOT/'"+STATUS+"').read_text())['extended_output_component_20261021'].get('"+KEY+"',{})"
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  offset=text.index('\n',text.index('def '+name+'('))+1
  text=text[:offset]+" if "+condition+":return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[offset:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'evidence' in json.loads((ROOT/'benchmarks/performance/PERF01_WARM_START_20261022_STATUS.json').read_text()).get('source_composition_80db',{}):
  return runpy.run_path(str(ROOT/'integration/performance/verify_weather_composed_successor.py'))['source'](reader,changed)
 r=record(reader);require(r['baseline']==BASE,'saved baseline')
 for p,h in {**r['qualified_input_sha256'],**r['postimages']}.items():require(sha(reader(p))==h,'saved postimage '+p)
 require(reader(PARENT)==projection(),'original harvest owner assertions')
 current=json.loads(reader(STATUS));current['extended_output_component_20261021'].pop(KEY)
 require(current==json.loads(historical(STATUS)),'unrelated NUT authority')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty saved-output science')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}if changed is None else changed
 require(delta==r['scientific_delta'],'foreign saved-output science')
 require(all(k=='A'or p==PARENT for p,k in delta.items()),'changed incumbent physical implementation')
 return r
def capsule():
 r=record();p=ROOT/r['evidence_index'];require(sha(p.read_bytes())==r['evidence_index_sha256'],'saved index')
 index=json.loads(p.read_text());raw=base64.b64decode(b''.join((p.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'saved capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as a:
  ms=a.getmembers();require(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'saved member safety')
  f={m.name:a.extractfile(m).read()for m in ms}
 require(f.keys()==index['members'].keys()and all(sha(v)==index['members'][p]for p,v in f.items()),'saved member inventory')
 return f
def validate(f):
 def js(p):return json.loads(f[p])
 def envelope(raw):
  require(raw[:8]==b'S5NS0001','saved envelope magic')
  n=struct.unpack_from('<i',raw,8)[0]
  require(n+88==len(raw)and zlib.crc32(raw[:-4])==struct.unpack_from('<I',raw,len(raw)-4)[0],'saved envelope length crc')
  return struct.unpack_from('<9d',raw,12),raw[84:-4]
 r=js('physical/result.json');c=js('component/result.json');prior=js('PREDECESSOR.json')
 require(r['status']=='SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_ATOMIC_FRESH_PASS','saved actual proof')
 require(c['status']=='SAVED_RESIDUE_COMPONENT_SOURCE_EXACT_O0_O2_PASS','saved source oracle')
 require(r['results']['O0']==r['results']['O2']and c['results']['O0']==c['results']['O2'],'saved optimization drift')
 require('checks=6808 reports=234'in c['results']['O0'],'source-exact case census')
 require(sha(f['physical/driver.f90'])==r['generated_driver_sha256'],'saved generated driver')
 require(r['original_wofostnut_sha256']=='071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2','source harvest authority')
 for name,h in r['original_fragment_sha256'].items():require(sha(f['physical/'+name])==h,'literal harvest addition fragment')
 for prefix in ['component','physical']:
  es=js(prefix+'/events.json');require(all(e['returncode']==0 for e in es),'failed saved execution')
  for e in es:
   for stream in ['stdout','stderr']:require(prefix+'/'+e[stream]in f,'missing saved raw stream')
 es=js('physical/events.json')
 for category,count in [('provider_compile',10),('actual_native',2),('original_fresh',2),('phase_roundtrip',12),('phase_fresh_fallow',12),('fallow_fresh',4),('invalid_generation',36),('invalid_live_generation',36),('invalid_identity',4),('crash_reconstruction',4)]:
  require(sum(e['category']==category for e in es)==count,'saved process census '+category)
 for opt in ['O0','O2']:
  b='physical/'+opt+'/'
  require(f[b+'endpoint']==f[b+'fresh'],'saved incumbent restart drift')
  require(sha(f[b+'endpoint'])==r['incumbent_default_sha256'][opt],'saved incumbent endpoint receipt')
  for label,delayed in [('saved',False),('deferred',True)]:
   p=b+'endpoint.stages.'+label
   require(f[p+'.before-stage']==f[p+'.failed-stage'],'failed initial capture published')
   memory=None
   for phase in ['1','2','3']:
    stage=f[p+'.phase-'+phase];v,inner=envelope(stage)
    require(v[0]==2.0 and any(x>0 for x in v[1:5]),'nontrivial harvest diagnostic memory')
    if memory is None:memory=v
    require(v==memory,'harvest phase changes saved values')
    require(stage==f[p+'.replay-'+phase]==f[b+label+'-roundtrip-'+phase],'saved phase replay/roundtrip leak')
    require(f[p+'.actual-'+phase]==f[p+'.manual-'+phase],'saved phase changes physical owner')
    if phase!='1':require(f[p+'.failed-'+phase]==f[p+'.phase-'+str(int(phase)-1)],'failed phase publication')
    for day in ['3','4']:
     require(f[b+label+'-continue-'+phase+'.day-'+day]==f[p+'.day-'+day],'fresh phase/fallow continuation drift')
   for day in ['3','4']:
    before=f[p+'.before-day-'+day];after=f[p+'.day-'+day];v,inner=envelope(after)
    require(v[0]==float(day)and all(x==0 for x in v[1:]),'fallow does not replace saved values')
    for fail in ['failed-day-','bad-roots-','nan-day-']:require(before==f[p+'.'+fail+day],'failed day publication '+fail)
    for label2 in ['replay-day-','view-day-','view-memory-']:require(after==f[p+'.'+label2+day],'saved fallback/view state leak')
    require(f[p+'.actual-day-'+day]==f[p+'.manual-day-'+day],'saved reporting changes physical fallow')
    require(sha(after)==r['results'][opt]['generations'][label][day],'saved generation receipt')
   require(f[b+label+'-day3-continue.day-4']==f[p+'.day-4'],'fresh accepted fallow continuation drift')
   require(f[p+'.phase-3']==f[p+'.phase-3.before-invalid']==f[p+'.phase-3.after-invalid'],'invalid read alters live authority')
  for day in ['3','4']:
   require(f[b+'endpoint.stages.saved.actual-day-'+day]==f[b+'endpoint.stages.deferred.actual-day-'+day],'report cadence changes physics')
  for phase,wanted in [('before','2'),('after','3')]:
   p=b+'crash-'+phase+'/'
   require(f[p+'generation']==f[p+'recovered']==f[b+'endpoint.stages.saved.phase-'+wanted],'partial crash generation')
   crash=js(p+'result.json');require(crash['returncode']==-9 and crash['complete'],'saved crash did not execute')
   require(sha(f[p+'generation'])==r['results'][opt]['crashes'][phase]['sha256'],'saved crash receipt')
 require(prior['qualified']and prior['controls']==18 and prior['source_tree']==git('rev-parse',BASE+':src'),'exact admitted predecessor')
 require(not r['thermal_selected']and r['crash_selected']and not r['full_work_unit_closed'],'saved scope')
 return dict(qualified=True,status='SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_QUALIFIED',literal_checks_per_optimization=6808,literal_reports_per_optimization=234,independent_phase_roundtrips=12,independent_phase_fallow_progressions=12,fresh_fallow_progressions=4,invalid_generations=36,invalid_live_generations=36,identity_rejections=4,process_crashes=4,incumbent_physics_unchanged=True,full_mc_nut01_closed=False)
def verify():
 if 'evidence' in json.loads((ROOT/'benchmarks/performance/PERF01_WARM_START_20261022_STATUS.json').read_text()).get('source_composition_80db',{}):
  return runpy.run_path(str(ROOT/'integration/performance/verify_weather_composed_successor.py'))['verify']()
 source();r=validate(capsule());old=runpy.run_path(str(ROOT/PARENT));r['incumbent_harvest']=old['validate'](old['capsule']())
 root=runpy.run_path(str(ROOT/'integration/audits/verify_root_substep.py'));prior=root['validate'](root['capsule']())
 r['incumbent_root_substep']=prior
 for key in ['current_calendar_nut','current_concurrent_nut','frozen_daily_predecessor']:r[key]=prior[key]
 return r
def self_test():
 if 'evidence' in json.loads((ROOT/'benchmarks/performance/PERF01_WARM_START_20261022_STATUS.json').read_text()).get('source_composition_80db',{}):
  return runpy.run_path(str(ROOT/'integration/performance/verify_weather_composed_successor.py'))['self_test']()
 source();f=capsule();validate(f);controls=[]
 def reject(name,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError,UnicodeError,struct.error):controls.append(name);return
  raise ValueError('saved corruption accepted '+name)
 for p in ['src/adapter/mod_crop_ext_saved_residue.f90','src/adapter/mod_crop_n_saved_generation.f90','src/adapter/mod_crop_soil_n_saved_harvest.f90','src/adapter/mod_crop_soil_n_saved_output.f90','src/crop/mod_crop_soil_n_day.f90','src/runtime/mod_fmr_serialized_reference_backend.f90',PARENT]:
  reject('source '+p,lambda p=p:source(lambda x:(ROOT/x).read_bytes()+(b'!'if x==p else b'')))
 for p in ['component/result.json','physical/result.json','physical/driver.f90','physical/O0/saved-roundtrip-1','physical/O2/deferred-continue-3.day-4','PREDECESSOR.json']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['physical/O0/endpoint.stages.saved.failed-stage','physical/O2/endpoint.stages.deferred.manual-day-3','physical/O0/endpoint.stages.saved.view-memory-4','physical/O2/endpoint.stages.saved.phase-3.after-invalid','physical/O0/crash-after/recovered']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 bad=dict(record()['scientific_delta']);bad['src/foreign_saved.f90']='A';reject('foreign science',lambda:source(changed=bad))
 return controls
if __name__=='__main__':print(json.dumps(verify(),indent=2))
