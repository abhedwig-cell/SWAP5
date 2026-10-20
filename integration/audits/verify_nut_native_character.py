"""Exact native CHARACTER successor; original complete authority runs unchanged.

No archived source projection: the predecessor is executed on its own exact
tree. Current changed parsers require fresh direct/original/physical evidence.
"""
from pathlib import Path
import copy, hashlib, json, os, runpy, subprocess, tempfile

ROOT=Path(__file__).resolve().parents[2]
BASE='f6d5ffed068efcc8cc2b14d0b68bb508b7a25f52'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
SCIENCE=['src','tests','tools','reference','.github','app','examples']
CHANGED={'src/process/mod_soil_n_unified_input.f90','src/process/mod_soil_n_historical_named_input.f90'}
OWNED=CHANGED|{'tests/nut-crop/test_b112_retained_joint.f90','tests/nut-crop/verify_accepted_atmosphere.py',
 'integration/audits/run_nut_native_character.py','integration/audits/verify_nut_native_character.py'}
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['native_character_successor']
def helpers():return runpy.run_path(str(ROOT/'tests/nut-crop/verify_historical_gross.py'),run_name='character_gross_helpers')
def source():
 s=record();require(s['base_canonical']==BASE,'character predecessor')
 require(set(s['postimages'])==OWNED,'character ownership')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 require(not git('status','--porcelain','--',*SCIENCE,*OWNED),'dirty character source')
 rows={r.split('\t')[1]:r.split('\t')[0] for r in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(rows=={q:'M' for q in OWNED if q.startswith(('src/','tests/'))},'foreign character source')
 for q,h in s['postimages'].items():require(sha((ROOT/q).read_bytes())==h,'character postimage '+q)
 old=subprocess.check_output(['git','show',BASE+':tests/nut-crop/verify_accepted_atmosphere.py'],cwd=ROOT,text=True)
 hook=""" current=json.loads((ROOT/STATUS).read_text()).get('native_character_successor',{})
 if 'evidence'in current:
  return runpy.run_path(str(ROOT/'integration/audits/verify_nut_native_character.py'),run_name='registered_native_character')['verify_qualification']()
"""
 controls=hook.replace("run_name='registered_native_character'","run_name='registered_native_character_controls'").replace("['verify_qualification']()","['self_test']()")
 expected=old.replace('def verify_qualification():\n','def verify_qualification():\n'+hook,1).replace('def self_test():\n','def self_test():\n'+controls,1)
 require((ROOT/'tests/nut-crop/verify_accepted_atmosphere.py').read_text()==expected,'character exact owning handoff')
 return s

def validate(f,reader=lambda q:(ROOT/q).read_bytes()):
 g=helpers();result=lambda p:json.loads(f[p+'/result.json'])
 for prefix in ['native','modern','character','physical']:
  g['inputs'](result(prefix),reader)
 for prefix in ['native','modern','physical']:
  ee=json.loads(f[prefix+'/events.json'])
  if prefix=='native':
   # Incumbent runner names raw files by event index, without path fields.
   # Bind those actual files; do not rewrite its original event inventory.
   ee=[{**e,'stdout':str(i)+'.stdout','stderr':str(i)+'.stderr'} for i,e in enumerate(ee)]
  g['executions'](f,prefix,ee)
 n=result('native');m=result('modern');c=result('character');p=result('physical')
 require(n['status']=='PASS' and len(n['fixtures'])==38 and n['outputs']['O0']==n['outputs']['O2'],'incumbent native38')
 require(m['status']=='PASS' and m['fixture_count']==53 and m['date_cases']==3075 and m['runs']['O0']==m['runs']['O2'],'incumbent modern/date preservation')
 require(c['status']=='NATIVE_CHARACTER_O0_O2_PASS' and len(c['fixtures'])==18 and c['outputs']['O0']==c['outputs']['O2'],'new character matrix')
 require(c['original_results']['O0']==c['original_results']['O2'],'original character optimization')
 require(sha(f['character/management_soil.original.f90'])=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b','original management authority')
 for marker in ['ORIGINAL_DAILY_FRACTIONAL_EVENT_BLOCKS_QUEUE=PASS','ORIGINAL_DAILY_INTEGER_EVENT_POSITIVE_CONTROL=PASS']:
  require(marker in c['original_results']['O0']['clock'],'missing literal daily calendar control')
 require(c['live_reuse']['native_result_sha256']==sha(f['native/result.json']) and c['live_reuse']['native_events_sha256']==sha(f['native/events.json']),'live native build identity')
 for opt in ['O0','O2']:require(c['live_reuse']['artifacts_before_after'][opt+'/test']==c['live_reuse']['executables'][opt],'live executable identity')
 for name,e in c['fixtures'].items():require(sha(f['character/'+name+'.snm'])==e['sha256'],'character fixture '+name)
 require(c['original_zip_sha256']=='ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193','original TTUTIL identity')
 for q,h in c['original_source_sha256'].items():require(sha(f['character/original/TTUTIL/'+q])==h,'original TTUTIL source '+q)
 events=json.loads(f['character/events.json']);original_objects={};original_links=set()
 require(sum(e['category']=='native' for e in events)==36 and sum(e['category']=='original_native' for e in events)==26,'character original/native execution count')
 for e in events:
  command=e['command'];cat=e['category']
  for stream in ['stdout','stderr']:require(sha(f['character/'+e[stream]])==e[stream+'_sha256'],'character raw '+stream)
  if cat=='native':
   require(e['returncode']==0,'character current native failure')
   opt=Path(command[0]).parent.name;name=Path(command[1]).stem
   require(f['character/'+e['stdout']].decode()==c['outputs'][opt][name],'character current raw output')
  elif cat=='original_compile':
   require(e['returncode']==0 and '-std=legacy' in command and '-fallow-argument-mismatch' in command,'original compile flags')
   require('-O0' in command or '-O2' in command,'original optimization flags')
   original_objects[command[command.index('-o')+1]]=command
  elif cat=='original_link':
   require(e['returncode']==0 and all(q in original_objects for q in command if q.endswith('.o')),'original linked closure')
   original_links.add(command[-1])
   opt=Path(command[-1]).parent.name
   require(sha(f['character/'+opt+'/original.f90'])==c['original_driver_sha256'],'original driver identity')
  elif cat=='original_native':
   require(command[0] in original_links,'original native without link')
   name=Path(command[1]).stem;opt=Path(command[0]).parent.name
   rejection=c['original_results'][opt][name]=='REJECTED_ORIGINAL_SYNTAX_TYPE'
   require((e['returncode']!=0)==rejection,'original syntax/type outcome')
   if not rejection:require(f['character/'+e['stdout']].decode()==c['original_results'][opt][name],'original raw output')
  else:require(False,'foreign character event')
 old_record=json.loads((ROOT/STATUS).read_text())['accepted_atmosphere_successor']
 old=g['capsule'](old_record['evidence']);prior=json.loads(old['physical/result.json'])
 require(p['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION' and p['results']==prior['results'],'physical endpoints/observables preservation')
 require(set(p['input_sha256'])==set(prior['input_sha256']),'physical provider closure changed')
 allowed=CHANGED|{'tests/nut-crop/test_b112_retained_joint.f90'}
 for q,h in prior['input_sha256'].items():
  if q not in allowed:require(sha(reader(q))==h,'unchanged physical dependency '+q)
 require(p['literal_sha256']==prior['literal_sha256'] and p['authority_sha256']==prior['authority_sha256'],'physical original oracle identity')
 ee=json.loads(f['physical/events.json'])
 require(sum(e['category']=='restart_native' for e in ee)==52,'physical52 fresh processes')
 for opt in ['O0','O2']:
  for profile in ['default','source-profile','rotation-profile','atmospheric-profile','humus-profile','gross-profile','surface-profile']:
   base='physical/'+opt+'/'+profile
   endpoint=f[base+'.endpoint'];require(endpoint==old[base+'.endpoint'],'prior exact endpoint '+profile)
   if profile=='default':require(endpoint==f[base+'.fresh']==f[base+'.endpoint.opaque'],'default process restart')
   elif profile=='source-profile':require(endpoint==f[base+'.fresh'],'source process restart')
   else:
    for day in ([1,6] if profile=='surface-profile' else [1,120,121,365,366,500]):
     require(endpoint==f[base+'-fresh-'+str(day)],'character fresh process '+profile)
     require(sum(e['category']=='restart_native' and '/'+opt+'/' in e['command'][0] and e['command'][-2:]==[profile,str(day)] for e in ee)==1,'character missing native continuation')
    for day in ([6] if profile=='surface-profile' else [120,366]):
     before=f[base+'.restart.reject-before-'+str(day)]
     require(before==f[base+'.restart.reject-after-'+str(day)],'character nutrient rollback')
     if profile!='rotation-profile':require(before==f[base+'.restart.clean-reject-'+str(day)],'character clean rollback')
     if profile in ['gross-profile','surface-profile']:require(before==f[base+'.restart.water-reject-'+str(day)],'character water rollback')
 return {'status':'NATIVE_CHARACTER_QUALIFICATION_PASS','old_endpoints_exact':14,'fresh_transition_processes':52,'new_native_cases_per_optimization':18,'full_capability':False}

def predecessor():
 supplied=os.environ.get('SWAP5_CHARACTER_PREDECESSOR_WORKTREE');temporary=None
 if supplied:base=Path(supplied).resolve()
 else:
  temporary=tempfile.TemporaryDirectory(prefix='swap5-character-predecessor-');base=Path(temporary.name)/'baseline'
  subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
  if subprocess.run(['git','config','--bool','core.sparseCheckout'],cwd=base,capture_output=True,text=True).stdout.strip()=='true':
   subprocess.run(['git','sparse-checkout','add','research','integration/f-ross','integration/research','app','examples'],cwd=base,check=True,capture_output=True)
 try:
  require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'character predecessor checkout')
  require(subprocess.run(['git','diff','--quiet','HEAD'],cwd=base).returncode==0,'dirty character predecessor')
  require(not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*SCIENCE],cwd=base,text=True).strip(),'foreign character predecessor')
  for args in [[],['--self-test']]:
   r=subprocess.run(['python',str(base/'tests/nut-crop/verify_accepted_atmosphere.py'),*args],cwd=base,capture_output=True,text=True)
   require(r.returncode==0,'unchanged original predecessor authority: '+r.stdout[-1500:]+r.stderr[-1500:])
   if args:require(json.loads(r.stdout)['count']==9,'original9 atmosphere controls')
   else:require(json.loads(r.stdout)['qualified'],'original predecessor not qualified')
 finally:
  if temporary:
   subprocess.run(['git','worktree','remove',str(base)],cwd=ROOT,check=True,capture_output=True);temporary.cleanup()

def ci_preservation():
 g=helpers();s=json.loads(subprocess.check_output(['git','show',g['BASE']+':integration/audits/MC_SOL01_SURFACE_AGE03_CI_STATUS.json'],cwd=ROOT))
 follow=s['closure_ci_followup_20261019'];logs=0
 for e in [s['evidence'],follow['evidence'],follow['remaining_compile_routes']['evidence']]:
  for q,b in g['capsule'](e).items():
   if q not in ['compiler-events.json','compiler.jsonl']:continue
   logs+=1;events=[json.loads(x)for x in b.decode().splitlines()]if q.endswith('.jsonl')else json.loads(b)
   for event in events:
    c=event.get('args',event.get('command',[]))
    if '-c' in c:require(not any(c[c.index('-c')+1].endswith('/'+p)for p in CHANGED),'character changed CI provider')
 require(logs==3,'missing character CI footprints')
 return logs

def verify_qualification():
 current=json.loads((ROOT/STATUS).read_text()).get('gash_interception_successor',{})
 if 'evidence'in current:
  return runpy.run_path(str(ROOT/'integration/audits/verify_nut_gash_successor.py'),run_name='registered_nut_gash')['verify_qualification']()
 s=source();r=validate(helpers()['capsule'](s['evidence']));predecessor()
 grid=runpy.run_path(str(ROOT/'tests/nut-crop/verify_accepted_atmosphere.py'),run_name='character_grid_helpers')['grid_preservation']()
 return {**r,**grid,'qualified':True,'predecessor_qualified':True,'accepted_atmosphere':True,'historical_gross_top':True,'full_migration_qualified':False,'mastercoverage_promotion':False,'source_tree':git('rev-parse','HEAD:src'),'current_source_tree':git('rev-parse','HEAD:src'),'independent_ci_compile_logs':ci_preservation(),'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}

def self_test():
 current=json.loads((ROOT/STATUS).read_text()).get('gash_interception_successor',{})
 if 'evidence'in current:
  return runpy.run_path(str(ROOT/'integration/audits/verify_nut_gash_successor.py'),run_name='registered_nut_gash_controls')['self_test']()
 f=helpers()['capsule'](record()['evidence']);validate(f);passed=[]
 def reject(name,mutate,reader=lambda q:(ROOT/q).read_bytes()):
  ff=dict(f);mutate(ff)
  try:validate(ff,reader)
  except(ValueError,KeyError,IndexError):passed.append(name);return
  raise AssertionError('accepted character corruption '+name)
 for path in CHANGED:reject('source '+path,lambda x:None,lambda q,p=path:(ROOT/q).read_bytes()+(b'!' if q==p else b''))
 for path in ['physical/O0/surface-profile-fresh-6','physical/O2/gross-profile.restart.water-reject-120','physical/O0/humus-profile.restart.reject-after-366','physical/O0/surface-profile.endpoint','character/concat.snm','character/O0/original.f90']:
  reject(path,lambda x,p=path:x.__setitem__(p,b'corrupt'))
 def edit(x,path,fn):
  d=json.loads(x[path]);fn(d);x[path]=json.dumps(d).encode()
 reject('missing original native',lambda x:edit(x,'character/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if e['category']!='original_native'])))
 reject('missing physical restart',lambda x:edit(x,'physical/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if e['category']!='restart_native'])))
 reject('unchecked physical compilation',lambda x:edit(x,'physical/events.json',lambda es:es[0]['command'].remove('-fcheck=all')))
 return {'character_negative_controls':passed,'count':len(passed)}

if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if '--self-test' in sys.argv else verify_qualification(),indent=2))
