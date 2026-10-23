"""Source-bound accepted-temperature calendar composition; incumbent assertions retained."""
from pathlib import Path
import base64,hashlib,io,json,runpy,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='335e3fc51ea8e5627043c2a75adbbc1008c35a3b'
NATIVE_BASE='76d2ab9db8c20e976a25bb4c7414f176dd02c5cb'
HIST_BASE='d3986e2642ede0dc4ce2acd0194fc38807bf0adb'
PARENT='integration/audits/native_project_admission.py'
SELF='integration/audits/verify_nut_thermal_calendar_output.py'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
KEY='thermal_calendar_successor_20261023'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise AssertionError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['extended_output_component_20261021'][KEY]
def projection():
 text=before(PARENT).decode();condition="'postimages' in json.loads((ROOT/'"+STATUS+"').read_text())['extended_output_component_20261021'].get('"+KEY+"',{})"
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  at=text.index('\n',text.index('def '+name+'('))+1;indent=text[at:at+len(text[at:])-len(text[at:].lstrip(' '))]
  text=text[:at]+indent+"if "+condition+":return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[at:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('saved_calendar_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_saved_calendar_output.py'))['source'](reader,changed)
 r=record(reader);require(r['baseline']==BASE,'heat-calendar baseline')
 for p,h in {**r['incumbent_input_sha256'],**r['postimages']}.items():require(sha(reader(p))==h,'heat-calendar source '+p)
 require(reader(PARENT)==projection(),'original native owner bodies')
 current=json.loads(reader(STATUS));current['extended_output_component_20261021'].pop(KEY)
 require(current==json.loads(before(STATUS)),'unrelated NUT authority')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty heat-calendar science')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta==r['scientific_delta'] and all(k=='A'or p==PARENT for p,k in delta.items()),'foreign heat-calendar science')
 if changed is not None:
  for p in changed:
   if p not in delta:require(subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'unknown heat-calendar source '+p)
 # Preserve the exact existing public source-return shape.
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def legacy():
 ns={'__file__':str(ROOT/PARENT),'__name__':'immutable_native_owner'}
 exec(compile(before(PARENT),PARENT,'exec'),ns);ns['source']=source
 validate_native=ns['validate']
 def reader(p):
  # The compiled proof also hashes its assertion-controller text. Only these
  # exact three forwarding hooks differ; projection() checks their full bytes.
  return before(p)if p==PARENT else(ROOT/p).read_bytes()
 ns['validate']=lambda f:validate_native(f,reader)
 return ns
def historical():
 path='integration/audits/verify_nut_cycle_output.py'
 text=subprocess.check_output(['git','show',HIST_BASE+':'+path],cwd=ROOT)
 ns={'__file__':str(ROOT/path),'__name__':'immutable_cycle_owner'}
 exec(compile(text,path,'exec'),ns);ns['source']=source;return ns
def capsule():
 r=record();p=ROOT/r['evidence_index'];require(sha(p.read_bytes())==r['evidence_index_sha256'],'heat-calendar index')
 index=json.loads(p.read_text());raw=base64.b64decode(b''.join((p.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'heat-calendar capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as a:
  ms=a.getmembers();require(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'heat-calendar member safety')
  f={m.name:a.extractfile(m).read()for m in ms}
 require(set(f)==set(index['members'])and all(sha(v)==index['members'][p]for p,v in f.items()),'heat-calendar inventory')
 return f
def validate(f):
 r=json.loads(f['qualified/result.json'])
 require(r['status']=='THERMAL_CALENDAR_OUTPUT_O0_O2_FRESH_ATOMIC_PASS','calendar terminal')
 require(r['results']['O0']==r['results']['O2'],'calendar optimization drift')
 require(r['shared_base_provider_count']==331 and not r['full_mc_nut01_closed'],'calendar scope')
 require(r['rejection_trials']==170 and r['replay_trials']==30,'calendar rejection census')
 for p,h in r['generated'].items():require(sha(f['qualified/'+p])==h,'calendar generated '+p)
 events=json.loads(f['qualified/events.json']);require(events==r['events']and all(e['returncode']==0 for e in events),'calendar native failure')
 for label,count in [('provider_compile',2),('driver_compile',2),('link',2),('calendar_native',4),('calendar_roundtrip',12),('calendar_fresh',8),('crash_fresh',4)]:
  require(sum(e['category']==label for e in events)==count,'calendar process census '+label)
 for e in events:
  for stream in ['stdout','stderr']:require('qualified/'+e[stream]in f,'calendar missing raw stream')
 for opt in ['O0','O2']:
  b='qualified/'+opt+'/'
  for schedule in ['1','2']:
   p=b+schedule+'/';end=p+'endpoint';row=r['results'][opt]['schedules'][schedule]
   for suffix,h in row.items():require(sha(f[end+suffix])==h,'calendar endpoint identity')
   for day in range(3):
    tag=str(day);require(f[end+'.before-'+tag]==f[end+'.after-'+tag],'calendar rejected publication')
    require(f[end+'.day-'+tag]==f[end+'.manual-'+tag]==f[end+'.replay-'+tag]==f[p+'roundtrip-'+tag],'calendar independent physical/output/roundtrip')
    if day<2:
     fresh=p+'fresh-'+tag
     for suffix in ['', '.csv','.physical']:require(f[fresh+suffix]==f[end+suffix],'calendar fresh endpoint')
     for d in range(day+1,3):
      k=str(d);require(f[fresh+'.before-'+k]==f[fresh+'.after-'+k],'fresh calendar rejected publication')
      require(f[fresh+'.day-'+k]==f[fresh+'.manual-'+k]==f[fresh+'.replay-'+k],'fresh calendar physical/output')
  require(f[b+'1/endpoint.physical']==f[b+'2/endpoint.physical'],'calendar report schedule physical drift')
  for phase,day in [('before','0'),('after','1')]:
   p=b+'crash-'+phase+'/';cr=json.loads(f[p+'result.json'])
   require(cr['returncode']==-9 and cr['complete'] and sha(f[p+'generation'])==cr['sha256'],'calendar crash receipt')
   require(f[p+'generation']==f[b+'1/endpoint.day-'+day],'calendar crash partial generation')
   for suffix in ['', '.csv','.physical']:require(f[p+'recovered'+suffix]==f[b+'1/endpoint'+suffix],'calendar crash fresh endpoint')
 frozen=json.loads(f['PREDECESSOR.json']);require(frozen['baseline']==HIST_BASE and frozen['owner']['qualified']and len(frozen['controls'])==53,'complete calendar predecessor')
 native=json.loads(f['NATIVE_PREDECESSOR.json']);require(native['baseline']==NATIVE_BASE and native['owner']['qualified']and len(native['controls'])==60,'complete native predecessor')
 return dict(qualified=True,status='ACCEPTED_TEMPERATURE_CALENDAR_OUTPUT_QUALIFIED',optimizations=2,report_schedules=2,days_per_trajectory=3,roundtrips=12,fresh_progressions=8,crash_fresh_progressions=4,crash_recoveries=4,rejected_trials=170,replay_rejections=30,manual_generations_exact=True,production_sources_unchanged=True,full_mc_nut01_closed=False)
def verify():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('saved_calendar_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_saved_calendar_output.py'))['verify']()
 source();old=legacy();prior=old['verify']();f=capsule();v=validate(f)
 frozen=dict(at=HIST_BASE,status='FROZEN_PREDECESSOR',owner=json.loads(f['PREDECESSOR.json'])['owner'])
 return {**prior,'qualified':True,'thermal_calendar_output':v,'historical_cycle_authority':frozen,'qualification_scope':'EXPLICIT_ACCEPTED_TEMPERATURE_CALENDAR_OUTPUT_WITH_CURRENT_NATIVE_AND_COMPLETE_INCUMBENT_PRESERVATION'}
def self_test():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('saved_calendar_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_saved_calendar_output.py'))['self_test']()
 source();old=legacy();native=old['self_test']();require(len(native)==60,'native controls lost')
 prior=historical()['self_test']();require(len(prior)==53,'incumbent controls lost')
 controls=['native:'+p for p in native]+['incumbent:'+p for p in prior];f=capsule();validate(f)
 def reject(label,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError):controls.append(label);return
  raise ValueError('accepted calendar corruption '+label)
 for p in ['src/adapter/mod_crop_soil_n_calendar_output_day.f90','tests/nut-output/run_thermal_calendar_output.py','tests/nut-output/thermal_calendar_proof.inc',SELF,PARENT]:
  reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 for p in ['qualified/result.json','qualified/driver.f90','qualified/events.json','qualified/0003.stdout','PREDECESSOR.json']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in sorted(q for q in f if q.startswith('qualified/')and'.manual-'in q)[:6]:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 reject('foreign calendar science',lambda:source(changed={'src/foreign_thermal_calendar.f90':'A'}))
 require(len(controls)==130,'calendar complete corruption census')
 return controls
if __name__=='__main__':print(json.dumps(verify(),indent=2))
