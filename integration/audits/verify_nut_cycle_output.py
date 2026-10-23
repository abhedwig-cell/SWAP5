"""Source-bound explicit two-crop diagnostic continuation; incumbent owners retained."""
from pathlib import Path
import base64,hashlib,io,json,runpy,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='ead21ff0a325f4d5a96be889c1fec083e7c8ba4d'
PARENT='integration/audits/verify_nut_thermal_fallow_output.py'
SELF='integration/audits/verify_nut_cycle_output.py'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
KEY='cycle_successor_20261023'
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
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
 native=ROOT/'integration/audits/native_project_admission.py'
 if native.is_file():
  successor=runpy.run_path(str(native))
  if successor['enabled']():return successor['nut_source'](reader,changed)
 r=record(reader);require(r['baseline']==BASE,'cycle baseline')
 for p,h in {**r['incumbent_input_sha256'],**r['postimages']}.items():require(sha(reader(p))==h,'cycle source '+p)
 require(reader(PARENT)==projection(),'original thermal owner bodies')
 current=json.loads(reader(STATUS));current['extended_output_component_20261021'].pop(KEY)
 require(current==json.loads(before(STATUS)),'unrelated NUT authority')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty cycle science')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={line.split('\t')[1]:line.split('\t')[0]for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta==r['scientific_delta'] and all(k=='A'or p==PARENT for p,k in delta.items()),'foreign cycle science')
 if changed is not None:
  for p in changed:
   if p not in delta:require(subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'unknown cycle source '+p)
 # Preserve the exact existing public source-return shape.
 return json.loads(reader(STATUS))['extended_output_component_20261021']['thermal_fallow_successor_20261022']
def legacy():
 ns={'__file__':str(ROOT/PARENT),'__name__':'immutable_thermal_owner'}
 exec(compile(before(PARENT),PARENT,'exec'),ns);ns['source']=source;return ns
def capsule():
 r=record();p=ROOT/r['evidence_index'];require(sha(p.read_bytes())==r['evidence_index_sha256'],'cycle index')
 index=json.loads(p.read_text());raw=base64.b64decode(b''.join((p.parent/'evidence.tar.xz.b64').read_bytes().split()),validate=True)
 require(sha(raw)==index['decoded_sha256'],'cycle capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as a:
  ms=a.getmembers();require(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'cycle member safety')
  f={m.name:a.extractfile(m).read()for m in ms}
 require(set(f)==set(index['members'])and all(sha(v)==index['members'][p]for p,v in f.items()),'cycle inventory')
 return f
def validate(f):
 r=json.loads(f['qualified/result.json']);require(r['status']=='COLD_HEAT_TWO_CROP_SAVED_OUTPUT_O0_O2_FRESH_PASS','actual cycle terminal')
 require(r['results']['cold-O0']==r['results']['cold-O2']and r['results']['heat-O0']==r['results']['heat-O2'],'cycle optimization drift')
 require(r['shared_base_provider_count']==331 and r['additive_provider_count']==1 and not r['full_mc_nut01_closed'],'cycle scope')
 for p,h in r['generated'].items():require(sha(f['qualified/'+p])==h,'cycle generated '+p)
 events=json.loads(f['qualified/events.json']);require(events==r['events']and all(e['returncode']==0 for e in events),'cycle native failure')
 for label,count in [('provider_compile',4),('driver_compile',4),('link',4),('actual_native',4),('cycle_roundtrip',64),('old_identity',64),('cycle_fresh',64),('crash_reconstruction',8)]:require(sum(e['category']==label for e in events)==count,'cycle process census '+label)
 for e in events:
  for stream in ['stdout','stderr']:require('qualified/'+e[stream]in f,'cycle missing raw stream')
 for kind in ['cold','heat']:
  for opt in ['O0','O2']:
   b='qualified/'+kind+'/'+opt+'/';row=r['results'][kind+'-'+opt]
   for name in ['saved','deferred']:
    candidates=[p for p in f if p.startswith(b)and p.endswith('.'+name+'.cycle.seed')and'.opaque-stages.'not in p]
    require(len(candidates)==1,'cycle seed census');prefix=candidates[0][:-5];stem=Path(prefix).name
    for label in ['seed','day-5','day-6','phase-1','phase-2','phase-3','day-7','day-8']:
     actual=prefix+'.'+label
     require(sha(f[actual])==row[name][label],'cycle generation identity')
     require(f[actual]==f[prefix+'.manual-'+label]==f[b+stem+'-rt-'+label],'cycle independent physical/output/roundtrip')
     if label!='day-8':require(f[b+stem+'-fresh-'+label+'.day-8']==f[prefix+'.day-8'],'cycle fresh progression')
    for a,c in [('before-seed','bad-seed'),('before-seed','failed-seed')]+[(a+'-'+tag,c+'-'+tag)for tag in ['5','6']for a,c in [('before-day','failed-day'),('before-day','invalid-day')]]+[(a+'-'+tag,c+'-'+tag)for tag in ['1','2','3']for a,c in [('before-phase','failed-phase')]]:
     require(f[prefix+'.'+a]==f[prefix+'.'+c],'cycle failed publication')
    for tag in ['5','6']:require(f[prefix+'.view-day-'+tag]==f[prefix+'.view-memory-'+tag]==f[prefix+'.day-'+tag],'cycle CSV-only saved authority')
   seed=sorted(p for p in f if p.startswith(b)and p.endswith('.cycle.seed')and'.opaque-stages.'not in p)[0];prefix=seed[:-5]
   for phase,label in [('before','seed'),('after','day-5')]:
    p=b+'crash-'+phase+'/';cr=json.loads(f[p+'result.json'])
    require(cr['returncode']==-9 and cr['complete']and f[p+'generation']==f[p+'recovered']==f[prefix+'.'+label],'cycle partial crash generation')
    require(sha(f[p+'generation'])==row['crashes'][phase]['sha256'],'cycle crash receipt')
 frozen=json.loads(f['PREDECESSOR.json']);require(frozen['baseline']==BASE and frozen['owner']['qualified']and len(frozen['controls'])==36,'complete exact cycle predecessor')
 return dict(qualified=True,status='COLD_HEAT_TWO_CROP_SAVED_OUTPUT_QUALIFIED',physical_modes=4,report_schedules=2,roundtrips=64,fresh_progressions=64,old_identity_rejections=64,crash_recoveries=8,manual_generations_exact=True,full_mc_nut01_closed=False)
def verify():
 native=ROOT/'integration/audits/native_project_admission.py'
 if native.is_file():
  successor=runpy.run_path(str(native))
  if successor['enabled']():return successor['verify']()
 source();old=legacy();prior=old['verify']();v=validate(capsule())
 return {**prior,'qualified':True,'cycle_output':v,'qualification_scope':'EXPLICIT_COLD_HEAT_TWO_CROP_SAVED_OUTPUT_WITH_INCUMBENT_RAW_PRESERVATION'}
def self_test():
 native=ROOT/'integration/audits/native_project_admission.py'
 if native.is_file():
  successor=runpy.run_path(str(native))
  if successor['enabled']():return successor['self_test']()
 source();old=legacy();prior=old['self_test']();require(len(prior)==36,'incumbent controls lost');controls=['incumbent:'+p for p in prior];f=capsule();validate(f)
 def reject(label,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError):controls.append(label);return
  raise ValueError('accepted cycle corruption '+label)
 for p in ['src/adapter/mod_crop_soil_n_saved_cycle_output.f90','tests/nut-output/run_cycle_output.py','tests/nut-output/cycle_output_proof.inc',SELF,PARENT]:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 for p in ['qualified/result.json','qualified/cold/driver.f90','qualified/heat/cycle_proof.inc','qualified/0003.stdout','PREDECESSOR.json']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in [q for q in f if q.startswith('qualified/')and'.opaque-stages.'not in q and('.cycle.manual-'in q or'.cycle.view-memory-'in q)and(q.endswith('.manual-seed')or q.endswith('.manual-phase-1')or q.endswith('.view-memory-5'))][:6]:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 reject('foreign cycle science',lambda:source(changed={'src/foreign_cycle.f90':'A'}))
 return controls
if __name__=='__main__':print(json.dumps(verify(),indent=2))
