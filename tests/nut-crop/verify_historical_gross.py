"""Source-bound admission of the explicit historical gross N forcing seam.

The previous canonical owner is executed on its unchanged Git tree. Fresh
current production must reproduce every old endpoint and qualify the new mode.
No old archive, input hash, physical assertion or baseline guard is rewritten.
"""
from pathlib import Path
import base64,hashlib,io,json,os,subprocess,tarfile,tempfile

ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
BASE='21cc80984a864b48d4344b9671d6ccd2ae5882ad'
SURFACE=['src','tests','tools','reference','.github','integration/audits/surface_age_ci/authority.py']
OWNED={
 'src/process/mod_b111_soil_n_mineral_owner.f90',
 'src/process/mod_b111_soil_n_reactive_owner.f90',
 'src/crop/mod_crop_soil_n_day.f90',
 'src/runtime/mod_fmr_crop_soil_n_joint_application.f90',
 'src/runtime/mod_fmr_crop_soil_n_material_application.f90',
 'src/runtime/mod_fmr_crop_soil_n_senescence_application.f90',
 'src/runtime/mod_fmr_crop_soil_n_calendar_application.f90',
 'tests/nut-mineral/test_mineral_owner.f90',
 'tests/nut-reactive/test_reactive_owner.f90',
 'tests/nut-crop/test_b112_retained_joint.f90',
 'tests/nut-crop/run_hist_complete.py',
 'tests/nut-crop/verify_hist_native_successor.py',
 'tests/nut-crop/verify_historical_gross.py',
 'integration/audits/surface_age_ci/authority.py'}

def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['historical_gross_top_successor']
def enabled():return 'evidence'in record()
def capsule(e):
 raw=base64.b64decode((ROOT/e['path']).read_bytes());require(sha(raw)==e['decoded_sha256'],'gross capsule integrity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();require(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'gross unsafe capsule')
  f={m.name:t.extractfile(m).read()for m in ms}
 manifest=json.loads(f.pop('MANIFEST.json'));manifest=manifest.get('files',manifest)
 require(set(f)==set(manifest),'gross capsule inventory')
 for q,h in manifest.items():require(sha(f[q])==(h['sha256']if isinstance(h,dict)else h),'gross capsule member '+q)
 return f
def source():
 s=record();require(s['base_canonical']==BASE,'gross predecessor identity')
 require(set(s['postimages'])==OWNED,'gross ownership boundary widened')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 require(not git('status','--porcelain','--',*SURFACE),'dirty gross scientific surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 require(rows=={q:v['status']for q,v in s['postimages'].items()},'foreign gross scientific delta')
 for q,v in s['postimages'].items():require(sha((ROOT/q).read_bytes())==v['sha256'],'unqualified gross postimage '+q)
 require(not git('diff',BASE,'HEAD','--','reference'),'gross reference mutation')
 return s
def inputs(r,reader):
 for q,h in r.get('input_sha256',r.get('inputs',{})).items():require(sha(reader(q))==h,'gross current input '+q)
def executions(f,prefix,events):
 objects={};links={}
 for e in events:
  c=e['command'];require(e['returncode']==0,'gross failed execution')
  for stream in ['stdout','stderr']:
   name=e.get(stream,e.get(stream+'_file'));require(name is not None and prefix+'/'+name in f,'gross missing raw '+stream)
  category=e['category']
  if category=='compiler':continue
  if '-c'in c:
   require(('-O0'in c or '-O2'in c)and '-fcheck=all'in c and '-ffpe-trap=invalid,zero,overflow'in c,'gross unchecked compilation')
   out=c[c.index('-o')+1];require(out not in objects,'gross duplicate object');objects[out]=c
  elif '-o'in c:
   oo=[x for x in c if x.endswith('.o')]
   require(oo and len(oo)==len(set(oo))and all(x in objects for x in oo),'gross link lacks checked providers')
   links[c[c.index('-o')+1]]=c
  else:require(c[0]in links,'gross native lacks current link')
 return objects
def validate(f,reader=lambda q:(ROOT/q).read_bytes()):
 result=lambda p:json.loads(f[p+'/result.json'])
 for p in ['mineral','reactive','physical','retained']:
  r=result(p);inputs(r,reader);executions(f,p,json.loads(f[p+'/events.json']))
 p=result('physical');require(p['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and p['results']['O0']==p['results']['O2'],'gross actual O0/O2')
 s=record();old=capsule(s['predecessor_physical_evidence'])
 events=json.loads(f['physical/events.json'])
 profiles=['rotation-profile','atmospheric-profile','humus-profile','gross-profile']
 for opt in ['O0','O2']:
  base='physical/'+opt+'/'
  for name in ['default','source-profile','rotation-profile','atmospheric-profile','humus-profile']:
   tail='default.endpoint'if name=='default'else name+'.endpoint'
   require(f[base+tail]==old[base+tail],'gross old physical endpoint drift '+name)
  for profile in profiles:
   end=f[base+profile+'.endpoint'];require(sha(end)==p['results'][opt]['endpoint'][profile],'gross endpoint identity')
   for day in [1,120,121,365,366,500]:
    require(f[base+profile+'-fresh-'+str(day)]==end,'gross fresh-process continuation')
    require(sum(e['category']=='restart_native'and '/'+opt+'/'in e['command'][0]and e['command'][-2:]==[profile,str(day)]for e in events)==1,'gross missing fresh process')
   for day in [120,366]:
    before=f[base+profile+'.restart.reject-before-'+str(day)]
    require(before==f[base+profile+'.restart.reject-after-'+str(day)],'gross chemical rollback')
    if profile!='rotation-profile':require(before==f[base+profile+'.restart.clean-reject-'+str(day)],'gross clean-only rollback')
    if profile=='gross-profile':require(before==f[base+profile+'.restart.water-reject-'+str(day)],'gross hydraulic rollback')
  require('HISTORICAL_GROSS_730_DAYS_SOURCE_NOT_NET_PASS'in p['results'][opt]['stdout']['gross-profile'],'gross missing long model assertion')
  mineral=result('mineral')['runs'][opt]['direct_stdout']
  reactive=result('reactive')['runs'][opt]
  require('HISTORICAL_GROSS_LITERAL_18_CASES_BALANCE_ROLLBACK_RESTART=PASS'in mineral,'gross missing literal process proof')
  require('REACTIVE_GROSS_ORIGINAL_9_CHEMISTRY_DAYS_RESTART_ROLLBACK=PASS'in str(reactive),'gross missing original chemistry proof')
 # Existing retained/thermal/TCS6 runners retain their original assertions,
 # immutable old-byte references, malformed configurations and decoder cases.
 retained=result('retained');require(retained['status']=='B112_RETAINED_JOINT_PHYSICAL_PASS_NOT_ADMITTED','gross retained qualification')
 require(retained['b112_retained']['O0']==retained['b112_retained']['O2'],'gross retained O0/O2')
 phases=result('phases');inputs(phases,reader)
 require(phases['status']=='B112_THERMAL_PHASES_AND_ORIGINAL_BYTES_PASS'and phases['runs']['O0']==phases['runs']['O2'],'gross retained thermal/empty')
 tcs=result('tcs6');inputs(tcs,reader)
 require(tcs['status']=='B112_CURRENT_TCS6_54_NATIVE_AND_ENDPOINT_BYTES_PASS'and len(tcs['runs'])==54,'gross TCS6 trajectories')
 require(sum(e['category']=='native'for e in tcs['events'])==54 and all(e['returncode']==0 for e in tcs['events']),'gross TCS6 native inventory')
 for row in tcs['runs']:
  matches=[e for e in tcs['events']if e['category']=='native'and '/o'+str(row['opt'])+'/'in e['command'][0]and Path(e['command'][0]).name=='test-'+row['driver']and e['command'][-2:]==[row['mode'],row['phase']]]
  require(len(matches)==1 and sha(f['tcs6/'+matches[0]['stdout']])==row['stdout_sha256'],'gross TCS6 raw output')
 return dict(historical_gross_top=True,qualified=True,full_capability=False,mastercoverage_promotion=False,transition_fresh_processes=48)
def predecessor():
 # Execute the unchanged original owner, not a projected version of its code.
 # Its evidence checks remain fail-closed, including source hashes and guards.
 supplied=os.environ.get('SWAP5_GROSS_PREDECESSOR_WORKTREE')
 temporary=None
 if supplied:base=Path(supplied).resolve()
 else:
  temporary=tempfile.TemporaryDirectory(prefix='swap5-gross-predecessor-');base=Path(temporary.name)/'baseline'
  subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
  subprocess.run(['git','sparse-checkout','add','research','integration/f-ross','integration/research','app','examples'],cwd=base,check=True,capture_output=True)
 try:
  require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'gross baseline worktree identity')
  require(subprocess.run(['git','diff','--quiet','HEAD'],cwd=base).returncode==0,'gross predecessor tracked state changed')
  untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=base,text=True).splitlines()
  require(not any(Path(q).suffix in ['.py','.f90','.sh']for q in untracked),'gross predecessor foreign executable source')
  env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'}
  r=subprocess.run(['python','tests/nut-crop/verify_hist_native_successor.py'],cwd=base,env=env,capture_output=True,text=True)
  require(r.returncode==0,'gross predecessor owner failed: '+r.stderr[-1500:])
  require(json.loads(r.stdout)['qualified'],'gross predecessor not qualified')
 finally:
  if temporary:
   subprocess.run(['git','worktree','remove',str(base)],cwd=ROOT,check=True,capture_output=True)
   temporary.cleanup()
 return True
def unchanged_ci_closure():
 # Current broad inventory includes uncompiled optional nutrient modules.
 # Require the original CI compiler logs to prove there is no overlap;
 # an import inventory or a general foreign-delta exemption is insufficient.
 status=json.loads(subprocess.check_output(['git','show',BASE+':integration/audits/MC_SOL01_SURFACE_AGE03_CI_STATUS.json'],cwd=ROOT))
 changed={p for p in OWNED if p.startswith('src/')};logs=0
 def walk(obj):
  nonlocal logs
  if isinstance(obj,dict):
   if 'path'in obj and 'decoded_sha256'in obj:
    data=capsule(obj)
    for name,raw in data.items():
     if name not in ['compiler-events.json','compiler.jsonl']:continue
     logs+=1
     events=[json.loads(x)for x in raw.decode().splitlines()]if name.endswith('.jsonl')else json.loads(raw)
     for e in events:
      c=e.get('args',e.get('command',[]))
      if '-c'in c:require(not any(c[c.index('-c')+1].endswith('/'+q)for q in changed),'gross changed compiled CI provider')
   else:
    for v in obj.values():walk(v)
  elif isinstance(obj,list):
   for v in obj:walk(v)
 follow=status['closure_ci_followup_20261019']
 for e in [status['evidence'],follow['evidence'],follow['remaining_compile_routes']['evidence']]:walk(e)
 require(logs==3,'gross missing independent CI compiler footprints')
 return logs
def verify_qualification():
 s=source();f=capsule(s['evidence']);r=validate(f);predecessor();logs=unchanged_ci_closure()
 return {**r,'predecessor_qualified':True,'independent_ci_compile_logs':logs,'current_source_tree':git('rev-parse','HEAD:src'),'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}
def verify_source():return {**verify_qualification(),'qualified':False}
def self_test():
 s=record();f=capsule(s['evidence']);validate(f);passed=[]
 def reject(name,mutate,reader=lambda q:(ROOT/q).read_bytes()):
  ff=dict(f);mutate(ff)
  try:validate(ff,reader)
  except(ValueError,KeyError,IndexError):passed.append(name);return
  raise AssertionError('gross accepted corruption '+name)
 reject('gross fresh-process drift',lambda x:x.__setitem__('physical/O2/gross-profile-fresh-366',b'corrupt'))
 reject('water rejected state leaked',lambda x:x.__setitem__('physical/O0/gross-profile.restart.water-reject-120',b'corrupt'))
 reject('old endpoint drift',lambda x:x.__setitem__('physical/O0/humus-profile.endpoint',b'corrupt'))
 reject('provider source drift',lambda x:None,lambda q:(ROOT/q).read_bytes()+(b'!'if q=='src/process/mod_b111_soil_n_mineral_owner.f90'else b''))
 def edit(x,path,fn):
  obj=json.loads(x[path]);fn(obj);x[path]=json.dumps(obj).encode()
 reject('missing fresh native process',lambda x:edit(x,'physical/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if e['category']!='restart_native'])))
 reject('unchecked compiler',lambda x:edit(x,'physical/events.json',lambda es:es[0]['command'].remove('-fcheck=all')))
 reject('missing source longrun',lambda x:edit(x,'physical/result.json',lambda r:r['results']['O0']['stdout'].__setitem__('gross-profile','PASS')))
 reject('missing TCS6',lambda x:edit(x,'tcs6/result.json',lambda r:r['runs'].pop()))
 return dict(gross_negative_controls=passed,count=len(passed))
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if '--self-test'in sys.argv else verify_qualification(),indent=2))
