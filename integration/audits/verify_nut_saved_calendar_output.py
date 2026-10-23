"""Saved calendar/crop/harvest/fallow qualification over the full incumbent owner."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='c2363394a77d9e0f289c7db2f4fcd6f57ff47bc0'
PARENT='integration/audits/verify_nut_thermal_calendar_output.py'
SELF='integration/audits/verify_nut_saved_calendar_output.py'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
KEY='saved_calendar_successor_20261023'
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
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('historical_caller_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_historical_output_caller.py'))['source'](reader,changed)
 r=record(reader);require(r['baseline']==BASE,'saved calendar baseline')
 for path,h in {**r['incumbent_input_sha256'],**r['postimages']}.items():require(sha(reader(path))==h,'saved calendar source '+path)
 require(reader(PARENT)==projection(),'incumbent calendar assertion bodies')
 current=json.loads(reader(STATUS));current['extended_output_component_20261021'].pop(KEY)
 require(current==json.loads(before(STATUS)),'unrelated NUT authority')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty saved calendar science')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={row.split('\t')[1]:row.split('\t')[0]for row in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta==r['scientific_delta']and all(code=='A'or path==PARENT for path,code in delta.items()),'foreign saved calendar science')
 if changed is not None:
  for path in changed:
   if path not in delta:require(subprocess.run(['git','cat-file','-e',BASE+':'+path],cwd=ROOT,capture_output=True).returncode==0,'unknown saved calendar source '+path)
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def legacy():
 ns={'__file__':str(ROOT/PARENT),'__name__':'immutable_thermal_calendar_owner'}
 exec(compile(before(PARENT),PARENT,'exec'),ns);ns['source']=source;return ns
def capsule():
 r=record();path=ROOT/r['evidence_index'];require(sha(path.read_bytes())==r['evidence_index_sha256'],'saved calendar index')
 index=json.loads(path.read_text());raw=base64.b64decode(b''.join((path.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'saved calendar capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as archive:
  members=archive.getmembers();require(len(members)==len({m.name for m in members})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members),'saved calendar member safety')
  files={m.name:archive.extractfile(m).read()for m in members}
 require(set(files)==set(index['members'])and all(sha(raw)==index['members'][path]for path,raw in files.items()),'saved calendar inventory')
 return files
def validate(files):
 r=json.loads(files['qualified/result.json']);cold=json.loads(files['cold/result.json'])
 require(r['status']=='COLD_HEAT_SAVED_CALENDAR_HARVEST_FALLOW_O0_O2_FRESH_PASS','saved calendar terminal')
 require(cold['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'and sha(files['cold/result.json'])==r['cold_result_sha256'],'fresh cold source chain')
 require(cold['results']==r['cold_results'],'complete unchanged cold physical results')
 require(r['base_providers']==331 and r['additional_providers']==9 and not r['full_mc_nut01_closed'],'saved calendar scope')
 require(r['results']['cold-O0']==r['results']['cold-O2']and r['results']['heat-O0']==r['results']['heat-O2'],'saved calendar optimization drift')
 for path,h in r['generated'].items():require(sha(files['qualified/'+path])==h,'saved calendar generated '+path)
 require(sha(files['cold/driver.f90'])==cold['generated_driver_sha256'],'fresh cold driver')
 events=json.loads(files['qualified/events.json']);require(events==r['events']and all(e['returncode']==0 for e in events),'saved calendar native failure')
 for label,count in [('compiler',1),('hook_build',1),('provider_compile',18),('driver_compile',4),('link',4),('actual_native',4),('roundtrip',64),('old_identity',64),('fresh',64),('physical_endpoint',8),('crash_fresh',16)]:
  require(sum(e['category']==label for e in events)==count,'saved calendar process census '+label)
 cold_events=json.loads(files['cold/events.json']);require(len(cold_events)==680 and all(e['returncode']==0 for e in cold_events),'complete fresh cold execution')
 for prefix,rows in [('qualified/',events),('cold/',cold_events)]:
  for event in rows:
   for stream in ['stdout','stderr']:require(prefix+event[stream]in files,'missing raw execution stream')
 for opt in ['O0','O2']:
  for kind in ['cold','heat']:
   base='qualified/'+opt+'/'+kind+'/';row=r['results'][kind+'-'+opt];seeds=sorted(p for p in files if p.startswith(base)and p.endswith('.cycle.seed')and'.opaque-stages.'not in p)
   require(len(seeds)==2,'saved calendar schedule census')
   for seed in seeds:
    prefix=seed[:-5];stem=Path(prefix).name;schedule='deferred'if'deferred'in stem else'saved'
    for label in ['seed','day-5','day-6','phase-1','phase-2','phase-3','day-7','day-8']:
     actual=prefix+'.'+label;require(sha(files[actual])==row[schedule][label],'saved calendar generation identity')
     require(files[actual]==files[prefix+'.manual-'+label]==files[base+stem+'-rt-'+label],'independent saved calendar physical/output/roundtrip')
     if label!='day-8':require(files[base+stem+'-fresh-'+label+'.day-8']==files[prefix+'.day-8'],'saved calendar fresh continuation')
    for before,after in [('before-seed','bad-seed'),('before-seed','failed-seed')]+[(a+'-'+tag,b+'-'+tag)for tag in ['1','2','3']for a,b in [('before-phase','failed-phase')]]:
     require(files[prefix+'.'+before]==files[prefix+'.'+after],'saved calendar rejected boundary')
    require(sha(files[base+schedule+'.physical'])==row[schedule]['physical'],'saved calendar physical endpoint identity')
   require(files[base+'saved.physical']==files[base+'deferred.physical'],'report schedule physical drift')
   prefix=seeds[0][:-5]
   for point,before,after in [('active','seed','day-5'),('fallow','phase-3','day-7')]:
    for phase in ['before','after']:
     crash=base+'crash-'+point+'-'+phase+'/';receipt=json.loads(files[crash+'result.json']);target=crash+'run.'+after
     require(receipt['returncode']==-9 and receipt['complete']and sha(files[target])==receipt['sha256'],'saved calendar crash receipt')
     require(files[target]==files[prefix+'.'+(before if phase=='before'else after)],'saved calendar crash partial authority')
     require(files[crash+'recovered.day-8']==files[prefix+'.day-8'],'saved calendar crash fresh continuation')
 rejected=0;replayed=0
 for path,raw in files.items():
  if not path.startswith('qualified/')or'.before-day-'not in path or path[-1]not in'5678':continue
  prefix,tag=path.rsplit('.before-day-',1)
  for label in ['failed-day','invalid-day','offgrid-day','physical-reject-day']+(['environment-day']if'/heat/'in path else[]):
   require(raw==files[prefix+'.'+label+'-'+tag],'saved calendar rejected day publication');rejected+=1
  if prefix+'.replay-day-'+tag in files:
   actual=files[prefix+'.day-'+tag]
   for label in ['manual-day','replay-day','view-day','view-memory']:require(actual==files[prefix+'.'+label+'-'+tag],'saved calendar manual/replay/view publication')
   replayed+=1
 require(rejected==r['rejected_trials']and replayed==r['replay_rejections']and rejected>100 and replayed>30,'saved calendar rejection census')
 frozen=json.loads(files['PREDECESSOR.json']);require(frozen['baseline']==BASE and frozen['owner']['qualified']and len(frozen['controls'])==130,'complete saved calendar predecessor')
 return dict(qualified=True,status='COLD_HEAT_SAVED_CALENDAR_HARVEST_FALLOW_QUALIFIED',roundtrips=64,fresh_progressions=64,old_identity_rejections=64,crash_recoveries=16,crash_fresh_progressions=16,report_schedules=2,rejected_trials=rejected,replay_rejections=replayed,manual_generations_exact=True,full_mc_nut01_closed=False)
def verify():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('historical_caller_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_historical_output_caller.py'))['verify']()
 source();old=legacy();prior=old['verify']();result=validate(capsule())
 return {**prior,'qualified':True,'saved_calendar_output':result,'qualification_scope':'EXPLICIT_SAVED_CALENDAR_CROP_HARVEST_FALLOW_WITH_COMPLETE_CURRENT_INCUMBENT_PRESERVATION'}
def self_test():
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('historical_caller_successor_20261023',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_historical_output_caller.py'))['self_test']()
 source();old=legacy();prior=old['self_test']();require(len(prior)==130,'incumbent130 controls lost')
 controls=['incumbent:'+label for label in prior];files=capsule();validate(files)
 def reject(label,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError):controls.append(label);return
  raise AssertionError('accepted saved calendar corruption '+label)
 for path in ['src/adapter/mod_crop_soil_n_saved_calendar_output.f90','tests/nut-output/run_saved_calendar_output.py','tests/nut-output/saved_calendar_fixture.inc',SELF,PARENT]:
  reject('source '+path,lambda path=path:source(lambda p:(ROOT/p).read_bytes()+(b'!'if p==path else b'')))
 for path in ['qualified/result.json','qualified/cold/driver.f90','qualified/heat/cycle_proof.inc','cold/result.json','PREDECESSOR.json']:
  bad=dict(files);bad.pop(path);reject('missing '+path,lambda bad=bad:validate(bad))
 for path in sorted(p for p in files if p.startswith('qualified/')and'.cycle.manual-'in p and'.opaque-stages.'not in p)[:6]:
  bad=dict(files);bad[path]+=b'!';reject('changed '+path,lambda bad=bad:validate(bad))
 reject('foreign saved calendar source',lambda:source(changed={'src/foreign_saved_calendar.f90':'A'}))
 require(len(controls)==147,'saved calendar control census')
 return controls
if __name__=='__main__':print(json.dumps(verify(),indent=2))
