"""Bounded SWRD2 current science; predecessor proof remains at its executed tree."""
from pathlib import Path
import argparse,hashlib,json,math,os,subprocess,sys
from functools import lru_cache
import verify_swrd3_successor as prior
ROOT=prior.ROOT
BASE='451e35ccd1797aa96fb4354dabc465cceff18635'
STATUS='integration/audits/MC_CROP01_TRAJECTORY4_SWRD2_STATUS.json'
PRODUCTION={prior.BOOT,'src/runtime/mod_fmr_wofost_crop_transaction.f90'}
MARKERS={'weather':b'CROP_FILE_WEATHER_PRODUCTION=PASS','swrd3':b'SWRD3_ACTUAL_RICHARDS_GROWTH_OXYGEN_JOINT_RESTART=PASS',
 **{k:b'SWRD2_ACTUAL_RICHARDS_DEPTH_OXYGEN_JOINT_RESTART=PASS'for k in ['swrd2','swrd2_off','swrd2_unscaled']}}
check=prior.check;git=prior.git;sha=prior.sha
def status():return json.loads((ROOT/STATUS).read_text())
def project_moving(text):
 addition="""      src/runtime/mod_fmr_wofost_crop_transaction.f90 )
        python3 -B tests/root-growth/verify_swrd2_successor.py || fail 'unqualified persistent SWRD2 crop transaction'
        ;;
"""
 check(text.count(addition)==1,'unknown SWRD2 moving admission change')
 return text.replace(addition,'')
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;s=status()
 check(s['baseline']==BASE,'foreign SWRD2 baseline');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty science')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected=s['postimages'];check(rows=={p:r['status']for p,r in expected.items()},'foreign SWRD2 delta')
 check({p for p in expected if p.startswith('src/')}==PRODUCTION,'production scope widened')
 for p,r in expected.items():check(g('rev-parse','HEAD:'+p)==r['blob']==prior.blob((ROOT/p).read_bytes()),'postimage drift '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'immutable reference changed')
 check(g('rev-parse','HEAD:src')==s['production_source_tree'],'source tree mismatch')
 return dict(baseline=BASE,source_tree=s['production_source_tree'],swrd2_successor=True,swrd3_successor=True,
   co2_successor=True,calendar_successor=True,input_successor=True,thermal_successor=True,qualified=False,admitted=False)
def read_evidence():return prior.capsule(status()['science_evidence'])
def dependencies(inputs):
 for p,h in inputs.items():
  check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe input')
  check(sha((ROOT/p).read_bytes())==h,'stale scientific input '+p)
def native(data,digest):
 raw=[b for p,b in data.items()if p.endswith('.stdout')and sha(b)==digest]
 check(bool(raw),'raw output missing');return raw[0]
def validate(data,source):
 provenance=json.loads(data['execution-provenance.json'])
 check(provenance['source_tree']==source['source_tree']and sha(data['executed.bundle'])==provenance['bundle_sha256'],'execution source/bundle drift')
 d=json.loads(data['direct/result.json']);de=json.loads(data['direct/events.json'])
 check(d['status']=='PASS'and len(d['runs'])==30,'incomplete direct contracts');dependencies(d['inputs'])
 check(PRODUCTION- {prior.BOOT}<=d['inputs'].keys(),'depth owner not compiled')
 dk=[(r['opt'],r['driver'],r['profile'])for r in d['runs']]
 check(len(set(dk))==30,'duplicate direct native')
 check({(o,k)for o,n,k in dk if n=='test_swrd2_transaction.f90'}=={(o,k)for o in (0,2)for k in range(5)},'SWRD2 direct coverage')
 for r in d['runs']:check(b'PASS'in native(data,r['stdout_sha256']),'direct assertions absent')
 check(len([e for e in de if e['category']=='native'])==30,'direct native commands missing')
 for e in de:
  check(e['returncode']==0 and math.isfinite(e['seconds'])and e['seconds']>=0,'failed direct event')
  for stream in ['stdout','stderr']:check(sha(data['direct/'+e[stream]])==e[stream+'_sha256'],'direct raw drift')
  if e['category']=='compile':check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked direct compilation')
 r=json.loads(data['physical/RESULTS.json']);i=json.loads(data['physical/INPUTS.json'])
 check(r['status']=='PASS'and r['source_inputs']==i['inputs'],'unfinished physical science');dependencies(i['inputs'])
 check(PRODUCTION<=i['inputs'].keys(),'untested shared production');check(i['flags']==prior.FLAGS,'physical flags drift')
 providers=subprocess.check_output([sys.executable,'-B',str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all',
   'tests/fsi/fsi04_real_headcalc_stubs.f90',prior.BOOT,'src/kernel/mod_kernel_committed_persistence.f90'],cwd=ROOT,text=True).splitlines()
 check(providers==i['providers'],'provider closure drift')
 for p,h in i['generated'].items():check(sha(data['physical/'+p])==h,'generated driver/oracle drift '+p)
 wanted={(o,n,mo,mode)for o in (0,2)for n in MARKERS for mo in (['neutral','dry','hydraulic']if n=='weather'else['neutral'])for mode in ['continuous','restart']}
 keys=[(x['opt'],x['driver'],x['moisture'],x['mode'])for x in r['results']]
 check(len(keys)==28 and len(set(keys))==28 and set(keys)==wanted,'physical coverage incomplete')
 hashes={}
 for row,key in zip(r['results'],keys):
  check(row['returncode']==0 and math.isfinite(row['wall_seconds'])and row['wall_seconds']>0,'failed native')
  check(MARKERS[row['driver']]in native(data,row['stdout_sha256']),'physical assertions missing');hashes[key]=row['stdout_sha256']
 for o,n,mo,m in wanted:check(hashes[(o,n,mo,m)]==hashes[(2-o,n,mo,m)]==hashes[(o,n,mo,'continuous')],'optimization/restart drift')
 events=[e for e in r['events']if Path(e['command'][0]).name.startswith('test-')]
 check(len(events)==28,'missing physical native commands')
 for index,e in enumerate(r['events']):
  check(e['returncode']==0 and math.isfinite(e['wall_seconds'])and e['wall_seconds']>=0,'failed physical event')
  # Match both raw streams even when a successful process emitted diagnostics.
  for stream in ['stdout','stderr']:
   candidates=[b for p,b in data.items()if p.startswith('physical/'+f'{index:05d}-')and p.endswith('.'+stream)]
   check(len(candidates)==1,'physical raw stream missing')
   if stream+'_sha256'in e:check(sha(candidates[0])==e[stream+'_sha256'],'physical raw event drift')
  if '-c'in e['command']:check(e['command'][1:1+len(prior.FLAGS)]==prior.FLAGS,'unchecked physical compile')
 for e in events:
  cmd=e['command'];key=(int(Path(cmd[0]).parent.name[1:]),Path(cmd[0]).name.removeprefix('test-'),cmd[-1],cmd[-2])
  check(len(cmd)==7 and key in hashes and e['stdout_sha256']==hashes[key],'native/result identity drift')
 return {**source,'science_scope':'SWRD2_0_1_STATIC_DENSITY_ACCEPTED_WATER_OXYGEN_OPAQUE_RESTART',
  'direct_native_executions':30,'physical_programs':28,'highest':'NOT_SELECTED_POLICY'}
@lru_cache(None)
def baseline_command(path,*args):
 root=ROOT.parent/'swrd2-incumbent-451e35cc'
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'predecessor moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'predecessor dirty')
 r=subprocess.run([sys.executable,'-B',str(root/path),*args],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 check(r.returncode==0,'predecessor authority failed '+path+' '+r.stderr[-1000:])
 return json.loads(r.stdout)
def verify_physical():return validate(read_evidence(),verify_source())
def predecessor_controls(path):
 allowed={'tests/nut-input/check_input_controls.py','tests/nut-thermal/check_thermal_successor_controls.py',
   'tests/nut-thermal/check_evidence_controls.py','tests/root-growth/check_combined_admission_controls.py'}
 check(path in allowed,'unknown historical control entry')
 verify_physical()
 old=baseline_command(path);check(old['status']=='PASS','historical controls failed')
 current=json.loads(subprocess.check_output([sys.executable,'-B',str(ROOT/'tests/root-growth/check_swrd2_controls.py')],cwd=ROOT))
 check(current['status']=='PASS'and current['negative_count']==16,'current controls missing')
 return {**old,'predecessor_controls_at':BASE,'current_depth_controls':current,'current_source_tree':status()['production_source_tree']}
def verify_qualification():
 result=verify_physical()
 old=baseline_command('tests/root-growth/verify_swrd3_thermal_preservation.py')
 check(old['status']=='PASS'and old['current_source_tree']=='b8ac1c1c12096bc40478a58c5c8ac36ba687e3e0','unverified predecessor')
 s=status();owner=prior.capsule(s['owner_evidence']);o=json.loads(owner['RESULTS.json'])
 check(o['status']=='PASS'and o['source']['source_tree']==result['source_tree'],'current shared owner proof absent')
 dependencies(json.loads(owner['INPUTS.json']))
 sys.path.insert(0,str(ROOT/'tests/mc-met01'));from run_joint_owner_additional import STEPS
 check([(x['name'],x['command'])for x in o['steps']]==STEPS,'shared owner matrix incomplete')
 for row in o['steps']:
  check(row['exit']==0 and sha(owner[row['name']+'.stdout'])==row['stdout_sha256'],'shared owner failed/raw drift')
 # Old default proof stays bound to b8ac. New depth semantics are established
 # only by fresh current-source contracts/real Richards, never an old PASS.
 return {**result,'qualified':True,'predecessor_preserved_at_tree':old['current_source_tree'],
   'preserved':False,'shared_owner_gates':10,'full_fci':'PENDING_CURRENT_SOURCE_EXECUTION','swdmi2rd2':'OPEN_NOT_ADMITTED'}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--physical-only',action='store_true');a=p.parse_args()
 print(json.dumps(verify_source()if a.source_only else verify_physical()if a.physical_only else verify_qualification(),indent=2))
