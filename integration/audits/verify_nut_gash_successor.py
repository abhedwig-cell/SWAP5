"""Bounded Gash/N composition with exact predecessor and source preservation."""
from pathlib import Path
import hashlib,json,os,runpy,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
BASE='9a3a15197adbf37dba340f4f9acbbb44fe76a989'
GASH_ORIGINAL='5ce0f1115a5ea89be54aacaae02ed61ab2ca2696'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
SCIENCE=['src','tests','tools','reference','.github','app','examples']
GASH='src/process/mod_gash_interception_process.f90'
ADDED={GASH,'src/process/mod_gash_daily_application.f90'}
OWNED={GASH,'tests/fpm/test_f_mig431_int12_d_gash.f90','tests/nut-crop/test_b112_retained_joint.f90',
 'tests/nut-crop/run_hist_complete.py','integration/audits/run_nut_gash_authority.py',
 'integration/audits/verify_nut_gash_successor.py','integration/audits/verify_nut_native_character.py','integration/performance/authority.py'}
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['gash_interception_successor']
def helpers():return runpy.run_path(str(ROOT/'tests/nut-crop/verify_historical_gross.py'),run_name='gash_gross_helpers')
def source():
 s=record();require(s['base_canonical']==BASE,'Gash predecessor identity')
 require(set(s['postimages'])==OWNED,'Gash ownership boundary')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 require(not git('status','--porcelain','--',*SCIENCE,*OWNED),'dirty Gash source')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(rows=={q:'M'for q in OWNED if q.startswith(('src/','tests/'))},'foreign Gash scientific delta')
 for q,h in s['postimages'].items():require(sha((ROOT/q).read_bytes())==h,'Gash postimage '+q)
 old=subprocess.check_output(['git','show',BASE+':'+GASH],cwd=ROOT,text=True)
 require((ROOT/GASH).read_text()==old.replace('if(input%gross_rain_cm<psatcan)then','if(rpd<psatcan)then',1),'Gash original rpd repair scope')
 path='integration/audits/verify_nut_native_character.py'
 old=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
 hook=""" current=json.loads((ROOT/STATUS).read_text()).get('gash_interception_successor',{})
 if 'evidence'in current:
  return runpy.run_path(str(ROOT/'integration/audits/verify_nut_gash_successor.py'),run_name='registered_nut_gash')['verify_qualification']()
"""
 controls=hook.replace("run_name='registered_nut_gash'","run_name='registered_nut_gash_controls'").replace("['verify_qualification']()","['self_test']()")
 expected=old.replace('def verify_qualification():\n','def verify_qualification():\n'+hook,1).replace('def self_test():\n','def self_test():\n'+controls,1)
 require((ROOT/path).read_text()==expected,'Gash exact owning handoff')
 path='integration/performance/authority.py'
 old=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
 phook=''.join('   '+l for l in hook.splitlines(True)).replace('ROOT/STATUS',"ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'")
 pcontrols=''.join('   '+l for l in controls.splitlines(True)).replace('ROOT/STATUS',"ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'")
 expected=old.replace('def verify_qualification():\n','def verify_qualification():\n'+phook,1).replace('def self_test():\n','def self_test():\n'+pcontrols,1)
 expected=expected.replace("    source()\n    path = 'src/legacy/b1_10_port/headcalc.f90'", """    current=json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text()).get('gash_interception_successor',{})
    if 'evidence' in current:
        runpy.run_path(str(ROOT/'integration/audits/verify_nut_gash_successor.py'),run_name='registered_gash_fsi35')['source']()
    else:
        source()
    path = 'src/legacy/b1_10_port/headcalc.f90'""")
 require((ROOT/path).read_text()==expected,'Gash exact PERF01 owning handoff')
 return s

def validate(f,reader=lambda q:(ROOT/q).read_bytes()):
 g=helpers();p=json.loads(f['physical/result.json']);a=json.loads(f['authority/result.json'])
 for r in [p,a]:g['inputs'](r,reader)
 g['executions'](f,'physical',json.loads(f['physical/events.json']))
 require(a['status']=='ORIGINAL_GASH_54_CASES_AND_OWNERS_O0_O2_PASS' and a['results']['O0']==a['results']['O2'],'Gash original/owner optimization')
 require(a['archive_sha256']=='18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c','Gash original archive')
 require(sha(f['authority/literal.f90'])==a['literal_sha256'] and sha(f['authority/authority.f90'])==a['driver_sha256'],'Gash literal/driver identity')
 require(sha(f['authority/preimage.f90'])==a['preimage_sha256']==sha(subprocess.check_output(['git','show',BASE+':'+GASH],cwd=ROOT)),'Gash preimage source identity')
 for q,h in a['original_source_sha256'].items():require(sha(f['authority/'+q+'.original.f90'])==h,'Gash original member '+q)
 ee=json.loads(f['authority/events.json']);linked=set()
 require(len(ee)==24,'Gash authority/owner event count')
 for event in ee:
  require(event['returncode']==0,'Gash authority execution failure');c=event['command'];cat=event['category']
  for stream in ['stdout','stderr']:require(sha(f['authority/'+event[stream]])==event[stream+'_sha256'],'Gash raw '+stream)
  if cat in ['compile_link','owner_compile_link']:
   require('-fcheck=all'in c and '-ffpe-trap=invalid,zero,overflow'in c and ('-O0'in c or '-O2'in c),'Gash checked compilation')
   linked.add(c[c.index('-o')+1])
  else:
   require(cat in ['native','owner_native'] and c[0]in linked,'Gash native without current link')
   if cat=='native':
    version='preimage'if c[-1]=='1'else'current';opt=Path(c[0]).parent.name.split('-')[0]
    require(f['authority/'+event['stdout']].decode()==a['results'][opt][version],'Gash raw original control')
 for opt in ['O0','O2']:
  require('ORIGINAL_GASH_CASES=54:MISMATCHES=0:MAX_ABS_CM=   0.0000000000000000E+00'in a['results'][opt]['current'],'Gash original exact54')
  require('MISMATCHES=6:'in a['results'][opt]['preimage'],'missing six-case old Gash defect')
 old= g['capsule'](json.loads((ROOT/STATUS).read_text())['native_character_successor']['evidence'])
 prior=json.loads(old['physical/result.json'])
 require(set(p['input_sha256'])-set(prior['input_sha256'])==ADDED and not(set(prior['input_sha256'])-set(p['input_sha256'])),'Gash physical closure extension')
 changed_tests={'tests/nut-crop/test_b112_retained_joint.f90','tests/nut-crop/run_hist_complete.py'}
 for q,h in prior['input_sha256'].items():
  if q not in changed_tests:
   expected=sha(subprocess.check_output(['git','show',BASE+':'+q],cwd=ROOT))
   require(sha(reader(q))==expected,'Gash changed current canonical physical provider '+q)
   if h!=expected:require(q in {'src/legacy/b1_10_port/headcalc.f90','src/runtime/mod_fmr_serialized_reference_backend.f90'},'foreign PERF01 physical delta '+q)
 require(p['literal_sha256']==prior['literal_sha256'] and p['authority_sha256']==prior['authority_sha256'],'Gash prior scientific authority')
 require(p['results']['O0']==p['results']['O2'],'Gash physical O0/O2')
 events=json.loads(f['physical/events.json'])
 require(sum(e['category']=='restart_native'for e in events)==56,'Gash56 transition processes')
 for opt in ['O0','O2']:
  current=p['results'][opt];previous=prior['results'][opt]
  require(current['default_endpoint']==previous['default_endpoint'] and current['default_stdout']==previous['default_stdout'],'Gash prior default observables')
  require(current['providers']==previous['providers']+2,'Gash two added providers')
  for profile in ['default',*previous['endpoint']]:
   prefix='physical/'+opt+'/'+profile;endpoint=f[prefix+'.endpoint']
   require(endpoint==old[prefix+'.endpoint'],'Gash previous14 endpoint bytes')
   if profile=='default':require(endpoint==f[prefix+'.fresh']==f[prefix+'.endpoint.opaque'],'Gash default fresh')
   elif profile=='source-profile':require(endpoint==f[prefix+'.fresh'],'Gash source fresh')
   else:
    for day in ([1,6]if profile=='surface-profile'else[1,120,121,365,366,500]):require(endpoint==f[prefix+'-fresh-'+str(day)],'Gash prior transition bytes')
   if profile!='default':
    require(current['endpoint'][profile]==previous['endpoint'][profile] and current['stdout'][profile]==previous['stdout'][profile],'Gash prior reported observables')
  for profile in ['rotation-profile','atmospheric-profile','humus-profile','gross-profile','surface-profile','gash-profile']:
   prefix='physical/'+opt+'/'+profile
   for day in ([6]if profile in ['surface-profile','gash-profile']else[120,366]):
    before=f[prefix+'.restart.reject-before-'+str(day)];require(before==f[prefix+'.restart.reject-after-'+str(day)],'Gash nutrient rollback')
    if profile!='rotation-profile':require(before==f[prefix+'.restart.clean-reject-'+str(day)],'Gash clean rollback')
    if profile in ['gross-profile','surface-profile','gash-profile']:require(before==f[prefix+'.restart.water-reject-'+str(day)],'Gash water rollback')
  prefix='physical/'+opt+'/gash-profile';endpoint=f[prefix+'.endpoint'];ledger=f[prefix+'.endpoint.ledger']
  require(sha(endpoint)==current['endpoint']['gash-profile'] and len(ledger)==64,'Gash endpoint/diagnostic ledger')
  require(endpoint==f['physical/O0/gash-profile.endpoint'] and ledger==f['physical/O0/gash-profile.endpoint.ledger'],'Gash endpoint/ledger optimization bytes')
  for day in [1,6]:
   require(endpoint==f[prefix+'-fresh-'+str(day)] and ledger==f[prefix+'-fresh-'+str(day)+'.ledger'],'Gash native cumulative continuation')
   require(sum(e['category']=='restart_native'and '/'+opt+'/'in e['command'][0]and e['command'][-2:]==['gash-profile',str(day)]for e in events)==1,'missing Gash native restart')
  text=current['stdout']['gash-profile'];require('HISTORICAL_GASH_CROP_RICHARDS_N_12_DAYS_PASS'in text,'missing actual Gash coupled science')
  values=[float(x)for x in next(l for l in text.splitlines()if 'ROTATION_BUDGET'in l).split()[1:]]
  require(abs(values[4])<=1e-10 and abs(values[0]+values[1]-values[2]-values[3])<=1e-10,'Gash whole N mass')
  native=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and e['command'][-1]=='gash-profile']
  require(len(native)==1 and f['physical/'+native[0]['stdout']].decode()==text,'Gash actual raw model output')
 return {'status':'GASH_ORIGINAL_SOURCE_AND_ACTUAL_N_COMPOSITION_PASS','old_endpoints_exact':14,'fresh_transition_processes':56,'new_gash_process_cases_per_optimization':54,'original_mismatches_corrected_per_optimization':6,'full_capability':False}

def predecessor():
 supplied=os.environ.get('SWAP5_GASH_PREDECESSOR_WORKTREE');temporary=None
 if supplied:base=Path(supplied).resolve()
 else:
  temporary=tempfile.TemporaryDirectory(prefix='swap5-gash-predecessor-');base=Path(temporary.name)/'baseline'
  subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
  if subprocess.run(['git','config','--bool','core.sparseCheckout'],cwd=base,capture_output=True,text=True).stdout.strip()=='true':subprocess.run(['git','sparse-checkout','add','research','integration/f-ross','integration/research','app','examples'],cwd=base,check=True,capture_output=True)
 try:
  require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'Gash predecessor checkout')
  require(subprocess.run(['git','diff','--quiet','HEAD'],cwd=base).returncode==0,'dirty Gash predecessor')
  require(not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*SCIENCE],cwd=base,text=True).strip(),'foreign Gash predecessor')
  for args in [[],['--self-test']]:
   r=subprocess.run(['python',str(base/'integration/performance/authority.py'),*args],cwd=base,capture_output=True,text=True)
   require(r.returncode==0,'original Gash predecessor owner: '+r.stdout[-1500:]+r.stderr[-1500:])
   require(json.loads(r.stdout).get('count',0)==13 if args else json.loads(r.stdout)['qualified'],'Gash predecessor qualification/controls')
 finally:
  if temporary:subprocess.run(['git','worktree','remove',str(base)],cwd=ROOT,check=True,capture_output=True);temporary.cleanup()

def ci_preservation():
 g=helpers();s=json.loads(subprocess.check_output(['git','show',g['BASE']+':integration/audits/MC_SOL01_SURFACE_AGE03_CI_STATUS.json'],cwd=ROOT));follow=s['closure_ci_followup_20261019'];logs=0
 for e in [s['evidence'],follow['evidence'],follow['remaining_compile_routes']['evidence']]:
  for q,b in g['capsule'](e).items():
   if q not in ['compiler-events.json','compiler.jsonl']:continue
   logs+=1;events=[json.loads(x)for x in b.decode().splitlines()]if q.endswith('.jsonl')else json.loads(b)
   for event in events:
    c=event.get('args',event.get('command',[]))
    if '-c'in c:require(not c[c.index('-c')+1].endswith('/'+GASH),'Gash changed CI provider')
 require(logs==3,'Gash missing CI footprints');return logs

def verify_qualification():
 s=source();r=validate(helpers()['capsule'](s['evidence']));predecessor()
 perf=runpy.run_path(str(ROOT/'integration/performance/authority.py'),run_name='gash_perf_helpers')
 gridfiles=perf['capsule']()
 for opt in ['O0','O2']:
  build=json.loads(gridfiles['arena-'+opt+'/build-complete.json'])
  require(build['provider_count']==178,'Gash current178 grid providers')
  for q,h in build['input_sha256'].items():require(sha((ROOT/q).read_bytes())==h,'Gash current PERF01 grid provider '+q)
 grid={'current_column_grid_providers':178,'prior_grid_process_observations':86,'current_grid_providers_unchanged':True}
 return {**r,**grid,'qualified':True,'predecessor_qualified':True,'accepted_atmosphere':True,'historical_gross_top':True,'full_migration_qualified':False,'mastercoverage_promotion':False,'source_tree':git('rev-parse','HEAD:src'),'current_source_tree':git('rev-parse','HEAD:src'),'independent_ci_compile_logs':ci_preservation(),'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}

def self_test():
 f=helpers()['capsule'](record()['evidence']);validate(f);passed=[]
 def reject(name,fn,reader=lambda q:(ROOT/q).read_bytes()):
  ff=dict(f);fn(ff)
  try:validate(ff,reader)
  except(ValueError,KeyError,IndexError):passed.append(name);return
  raise AssertionError('accepted Gash corruption '+name)
 reject('Gash process drift',lambda x:None,lambda q:(ROOT/q).read_bytes()+(b'!'if q==GASH else b''))
 for q in ['physical/O0/gash-profile-fresh-6','physical/O2/gash-profile-fresh-1.ledger','physical/O0/gash-profile.restart.water-reject-6','physical/O0/gash-profile.restart.reject-after-6','physical/O0/gash-profile.restart.clean-reject-6','physical/O2/surface-profile.endpoint','authority/literal.f90','authority/preimage.f90']:
  reject(q,lambda x,p=q:x.__setitem__(p,b'corrupt'))
 def edit(x,path,fn):
  d=json.loads(x[path]);fn(d);x[path]=json.dumps(d).encode()
 reject('missing original native',lambda x:edit(x,'authority/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if e['category']!='native'])))
 reject('missing fresh process',lambda x:edit(x,'physical/events.json',lambda es:es.__setitem__(slice(None),[e for e in es if e['category']!='restart_native'])))
 reject('unchecked physical compiler',lambda x:edit(x,'physical/events.json',lambda es:es[0]['command'].remove('-fcheck=all')))
 return {'gash_negative_controls':passed,'count':len(passed)}
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if '--self-test'in sys.argv else verify_qualification(),indent=2))
