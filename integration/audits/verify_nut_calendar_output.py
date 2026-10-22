"""Immutable-calendar output successor; incumbent science and bodies preserved."""
from pathlib import Path
import base64,hashlib,io,json,runpy,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='f7c6041096a0cc1a7a71fbe9e37b390d976744ac'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
SOL='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
PARENT='integration/audits/verify_crop_root_joint.py'
SELF='integration/audits/verify_nut_calendar_output.py'
KEY='calendar_output_successor_20261022'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
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
  text=text[:offset]+" if "+condition+":return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+text[offset:]
 return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'evidence' in __import__('runpy').run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['record']():
  __import__('runpy').run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['source'](reader,changed)
  return record(reader)
 r=record(reader);require(r['baseline']==BASE,'calendar baseline')
 for p,h in {**r['qualified_input_sha256'],**r['postimages']}.items():require(sha(reader(p))==h,'calendar executed postimage '+p)
 require(reader(PARENT)==projection(),'incumbent root assertion bodies')
 require(reader(SOL)==historical(SOL),'unrelated SOL record')
 current=json.loads(reader(STATUS));current['extended_output_component_20261021'].pop(KEY)
 require(current==json.loads(historical(STATUS)),'unrelated NUT record')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty calendar science')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}if changed is None else changed
 require(delta==r['scientific_delta'],'foreign calendar scientific delta')
 require(all(k=='A' or p==PARENT for p,k in delta.items()),'changed incumbent production or assertions')
 return r
def capsule():
 r=record();p=ROOT/r['evidence_index'];require(sha(p.read_bytes())==r['evidence_index_sha256'],'calendar evidence index')
 index=json.loads(p.read_text());raw=base64.b64decode(b''.join((p.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'calendar evidence bytes')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as a:
  ms=a.getmembers();require(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'calendar member safety')
  f={m.name:a.extractfile(m).read()for m in ms}
 require(f.keys()==index['members'].keys()and all(sha(v)==index['members'][p]for p,v in f.items()),'calendar member inventory')
 return f
def validate(f):
 def js(p):return json.loads(f[p])
 r=js('calendar/result.json');cold=js('cold/result.json');before=js('PREDECESSOR.json')
 require(r['status']=='NATIVE_CALENDAR_OUTPUT_ACTUAL_O0_O2_FRESH_PASS','calendar actual qualification')
 require(cold['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS','current cold preservation')
 require(r['cold_proof_sha256']==sha(f['cold/result.json']),'calendar provider handoff')
 require(r['results']['O0']==r['results']['O2']and cold['results']['O0']==cold['results']['O2'],'optimization drift')
 for p,k in [('driver.f90','generated_driver_sha256'),('calendar_output_project.inc','generated_include_sha256')]:require(sha(f['calendar/'+p])==r[k],'calendar generated driver')
 for prefix in ['cold','calendar']:
  es=js(prefix+'/events.json');require(all(e['returncode']==0 for e in es),'failed final calendar execution')
  for e in es:
   for k in ['stdout','stderr']:require(prefix+'/'+e[k]in f,'missing calendar execution stream')
 es=js('calendar/events.json')
 require(len(es)==14 and sum(e['category']=='calendar_native'for e in es)==4 and sum(e['category']=='calendar_fresh'for e in es)==4,'calendar actual process census')
 for opt in ['O0','O2']:
  require(cold['results'][opt]==js('preservation.json')['cold_previous_results'][opt],'prior native model/output drift')
  for schedule in ['1','2']:
   b='calendar/'+opt+'/'+schedule+'/'
   require(f[b+'endpoint.true']==f[b+'endpoint.false']==f[b+'fresh.true']==f[b+'fresh.false'],'calendar changes physical model')
   for suffix in ['', '.csv','.true','.false']:require(f[b+'endpoint'+suffix]==f[b+'fresh'+suffix],'calendar fresh-process drift')
   for end,start_day in [('endpoint',0),('fresh',1)]:
    require(f[b+end]==f[b+end+'.after-rejected-start'],'calendar replay or startup leaked')
    for day in range(start_day,3):require(f[b+end+'.before-'+str(day)]==f[b+end+'.after-'+str(day)],'calendar rejected day leaked')
   for k,suffix in [('physical','.true'),('generation',''),('csv','.csv')]:require(sha(f[b+'endpoint'+suffix])==r['results'][opt][schedule][k],'calendar endpoint receipt')
  require(f['calendar/'+opt+'/1/endpoint.true']==f['calendar/'+opt+'/2/endpoint.true'],'report schedule changes physics')
 require(before['qualified']and before['status']=='NATIVE_DAILY_CROP_ROOT_JOINT_O0_O2_QUALIFIED'and before['controls']==40,'incumbent root qualification')
 require(r['days_per_execution']==3 and r['processes']==8 and r['rejection_trials']==80,'calendar assertion census')
 return dict(qualified=True,status='NATIVE_CALENDAR_OUTPUT_O0_O2_QUALIFIED',actual_processes=8,rejected_day_trials=80,replay_trials=8,simultaneous_gifts=True,report_schedules=2,cold_exact=True,full_mc_nut01_closed=False)
def verify():
 if 'evidence' in __import__('runpy').run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['record']():
  composed=__import__('runpy').run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['verify']()
  return dict(composed['current_calendar_nut'],current_concurrent_nut=composed['current_concurrent_nut'],incumbent_root_science=composed['frozen_daily_predecessor'],composed_owner=composed)
 source();r=validate(capsule())
 # All incumbent equations/callers/inputs are unchanged. Re-evaluate their raw
 # scientific evidence, not their now-superseded exact-delta source inventory.
 owner=runpy.run_path(str(ROOT/PARENT));r['incumbent_root_science']=owner['validate'](owner['capsule']())
 nut=runpy.run_path(str(ROOT/'integration/audits/verify_nut_thermal_output.py'))
 r['current_concurrent_nut']=nut['validate'](nut['capsule']())
 return r
def self_test():
 if 'evidence' in __import__('runpy').run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['record']():
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['self_test']()
 source();f=capsule();validate(f);controls=[]
 def reject(name,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError,UnicodeError):controls.append(name);return
  raise ValueError('calendar corruption accepted '+name)
 for p in ['src/adapter/mod_crop_soil_n_calendar_output_day.f90','src/crop/mod_crop_soil_n_calendar_day.f90','src/process/mod_soil_n_amendment_calendar.f90','src/adapter/mod_crop_soil_n_output_day.f90','app/solute_crop/main.f90',PARENT]:
  reject('source '+p,lambda p=p:source(lambda x:(ROOT/x).read_bytes()+(b'!'if x==p else b'')))
 for p in ['calendar/result.json','cold/result.json','PREDECESSOR.json','calendar/driver.f90','calendar/calendar_output_project.inc','calendar/O0/1/endpoint.csv','calendar/O2/2/fresh.true']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['calendar/O0/1/endpoint.false','calendar/O2/2/fresh','calendar/O0/2/endpoint.after-2','calendar/O2/1/endpoint.after-rejected-start','calendar/O0/1/endpoint.csv']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 bad=dict(record()['scientific_delta']);bad['src/foreign_calendar.f90']='A';reject('foreign calendar science',lambda:source(changed=bad))
 return controls
if __name__=='__main__':print(json.dumps(verify(),indent=2))
