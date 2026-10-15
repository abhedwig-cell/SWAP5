"""Exact explicit harvest successor plus preserved admitted owning assertions."""
from pathlib import Path
from functools import lru_cache
import argparse,hashlib,json,os,subprocess,sys
from default_projection import BASE,PROJECTORS,validate,replace
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/F_KT_BOUNDARY_EVENT_STATUS_20261015.json'
SOURCE_TREE='c9299e4d33b062a705418a0baeb835a8c835237e'
MOVING='tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'
GUARDS={'tests/root-growth/verify_swrd3_successor.py','tests/nut-thermal/verify_thermal_successor.py',MOVING}
TESTS={ 'tests/crop-harvest/'+name for name in ['README.md','mod_harvest_oracle.f90','preserve_thermal.py','repair_finite.py','resume_build.py','run_harvest.py','run_joint.py','test_harvest_chemical.f90','test_harvest_joint.f90','test_harvest_owner.f90','test_rotation_joint.f90','verify_evidence.py','default_projection.py','verify_harvest_successor.py','check_admission_controls.py'] }|{'tests/fkt-boundary/README.md'}
PRODUCER='src/crop/mod_wofost81_harvest_materials.f90'
OWNER_OPTION='''# Explicit harvest owner qualification only; never a full moving PASS.
if [[ "${1:-}" == --crop-harvest-owner-only ]]; then
  python3 -B tests/crop-harvest/verify_harvest_successor.py
  echo 'FCI_CROP_HARVEST_OWNER_RECONCILIATION=PASS'
  exit 0
fi

'''
OWNER_CASE='''      src/crop/mod_wofost81_crop_owner_state.f90|src/crop/mod_wofost81_one_day_candidate.f90|src/crop/mod_wofost81_harvest_materials.f90 )
        python3 -B tests/crop-harvest/verify_harvest_successor.py || fail "unqualified explicit harvest successor: $candidate_path"
        ;;
'''
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def project_moving(s):return replace(replace(s,OWNER_OPTION),OWNER_CASE)
def metadata():return json.loads((ROOT/STATUS).read_text())['admission_reconciliation']
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;m=metadata()
 check(m['scientific_baseline']==BASE and m['production_source_frozen']==SOURCE_TREE,'unknown baseline/source')
 g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty scientific surface')
 expected={**{p:'M'for p in PROJECTORS},PRODUCER:'A',**{p:'M'for p in GUARDS},**{p:'A'for p in TESTS}}
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 check(rows==expected,'foreign or incomplete harvest successor delta')
 check(set(m['postimages'])==set(expected),'incomplete exact postimage binding')
 check(g('rev-parse','HEAD:src')==SOURCE_TREE,'unqualified production source tree')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'reference mutation')
 for path,entry in m['postimages'].items():
  check(entry['status']==expected[path],'foreign path status '+path)
  check(g('rev-parse','HEAD:'+path)==entry['blob']==blob((ROOT/path).read_bytes()),'postimage drift '+path)
 current={p:(ROOT/p).read_text()for p in PROJECTORS}
 baseline={p:subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True)for p in PROJECTORS}
 validate(current,baseline)
 check(project_moving((ROOT/MOVING).read_text())==subprocess.check_output(['git','show',BASE+':'+MOVING],cwd=ROOT,text=True),'moving scientific body changed')
 return dict(baseline=BASE,source_tree=SOURCE_TREE,current_source_tree=SOURCE_TREE,harvest_successor=True,co2_successor=True,swrd3_successor=True,calendar_successor=True,input_successor=True,thermal_successor=True,senescence_successor=True,qualified=False,admitted=False)
def scientific_proof():
 r=subprocess.run([sys.executable,'-B',str(ROOT/'tests/crop-harvest/verify_evidence.py')],cwd=ROOT,capture_output=True,text=True)
 check(r.returncode==0,'current harvest scientific evidence rejected '+r.stderr[-400:])
 result=json.loads(r.stdout)
 check(result['retirement_fallow_successor_native_identity']and result['nonfinite_decoder_negatives_per_optimization']==51,'incomplete harvest native proof')
 return result
@lru_cache(None)
def baseline_qualification():
 root=ROOT.parent/('harvest-owner-baseline-'+BASE[:8])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,capture_output=True,check=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'baseline moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'dirty historical owner')
 r=subprocess.run([sys.executable,'-B','tests/root-growth/verify_swrd3_successor.py'],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 check(r.returncode==0,'original admitted owner rejected '+r.stderr[-500:]);result=json.loads(r.stdout)
 check(result['qualified']and result['swrd3_successor']and result['thermal_successor']and result['calendar_successor']and result['input_successor'],'original owner proof incomplete')
 return result

def verify_physical():
 source=verify_source();proof=scientific_proof()
 return {**source,'explicit_science':proof,'preservation':'EXACT_DEFAULT_BRANCH_PROJECTION_AND_FRESH_NATIVE_BYTES'}
def verify_qualification():
 source=verify_physical();baseline=baseline_qualification()
 return {**source,'qualified':True,'historical_baseline_owner':baseline,'full_fci':'NOT_SELECTED','highest':'NOT_SELECTED_POLICY','canonical_admission':False}
# Canonical composition is a separately pinned successor, never an expanded
# allowlist for the original harvest source. Keep its proof executable unchanged.
_original_verify_source=verify_source
_original_scientific_proof=scientific_proof
_original_baseline_qualification=baseline_qualification
COMPOSITION_BASE='f56a82b37bc1c3df7a6cb305990ab31e97818969'
HARVEST_PROOF='9113b0eef7832c7170097fc7443becfb31d06902'
SWRD2_PROOF='56aa2ba52fc4980053d712df85660a2facdfb0f4'
def composition():return json.loads((ROOT/STATUS).read_text()).get('canonical_composition')
def immutable_command(ref,path):
 root=ROOT.parent/('harvest-composition-'+ref[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),ref],cwd=ROOT,capture_output=True,check=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==ref,'immutable proof moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'immutable proof dirty')
 r=subprocess.run([sys.executable,'-B',path],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 check(r.returncode==0,'immutable proof rejected '+path+' '+r.stderr[-1000:])
 return json.loads(r.stdout)
def verify_source(git_reader=None):
 m=composition()
 if m is None:return _original_verify_source(git_reader)
 g=git if git_reader is None else git_reader
 check(m['canonical']==COMPOSITION_BASE and m['harvest_proof']==HARVEST_PROOF and m['swrd2_proof']==SWRD2_PROOF,'foreign composition baseline')
 g('merge-base','--is-ancestor',COMPOSITION_BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty composed science')
 expected=m['postimages']
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',COMPOSITION_BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 check(rows=={p:r['status']for p,r in expected.items()},'foreign composition delta')
 check({p for p in expected if p.startswith('src/')}==set(PROJECTORS)|{PRODUCER},'production composition widened')
 for p,r in expected.items():check(g('rev-parse','HEAD:'+p)==r['blob']==blob((ROOT/p).read_bytes()),'composition postimage drift '+p)
 check(g('rev-parse','HEAD:src')==m['source_tree'],'unqualified composition tree')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',COMPOSITION_BASE+':reference'),'composition reference changed')
 # All incumbent equations/default paths project to the already admitted SWRD2
 # source. New harvest science must independently pass below.
 current={p:(ROOT/p).read_text()for p in PROJECTORS}
 baseline={p:subprocess.check_output(['git','show',COMPOSITION_BASE+':'+p],cwd=ROOT,text=True)for p in PROJECTORS}
 validate(current,baseline)
 check(project_moving((ROOT/MOVING).read_text())==subprocess.check_output(['git','show',COMPOSITION_BASE+':'+MOVING],cwd=ROOT,text=True),'composed moving body drift')
 return dict(baseline=COMPOSITION_BASE,source_tree=m['source_tree'],current_source_tree=m['source_tree'],harvest_successor=True,swrd2_successor=True,swrd3_successor=True,co2_successor=True,calendar_successor=True,input_successor=True,thermal_successor=True,senescence_successor=True,qualified=False,admitted=False)
def scientific_proof():
 m=composition()
 if m is None:return _original_scientific_proof()
 # The original complete assertions run against their immutable postimages.
 original=immutable_command(HARVEST_PROOF,'tests/crop-harvest/verify_evidence.py')
 check(original['nonfinite_decoder_negatives_per_optimization']==51,'original malformed continuation proof absent')
 import base64,io,tarfile,math
 e=m['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes());check(sha(raw)==e['decoded_sha256'],'composed capsule corruption')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  members=a.getmembers();check(all(x.isfile()and not Path(x.name).is_absolute()and '..'not in Path(x.name).parts for x in members),'unsafe composed evidence')
  check(len(set(x.name for x in members))==len(members),'duplicate composed evidence');d={x.name:a.extractfile(x).read()for x in members}
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(d)==set(manifest),'incomplete composed manifest')
 for p,h in manifest.items():check(sha(d[p])==h,'composed raw corruption '+p)
 physical=json.loads(d['physical/result.json']);thermal=json.loads(d['thermal/result.json'])
 check(physical['status']=='PASS'and physical['incumbent_endpoints_identical'],'current physical assertions incomplete')
 check(thermal['status']=='ORIGINAL_THERMAL_NATIVE_FRESH_EXECUTION_BYTE_PRESERVED','current thermal assertions incomplete')
 for result,key in [(physical,'input_sha256'),(thermal,'inputs')]:
  for p,h in result[key].items():check(sha((ROOT/p).read_bytes())==h,'composed input drift '+p)
 pe=json.loads(d['physical/events.json'])
 for e in pe:
  check(e['returncode']==0 and math.isfinite(e['seconds'])and e['seconds']>=0,'failed current native/build')
  for stream in ['stdout','stderr']:check(sha(d['physical/'+e[stream+'_file']])==e[stream+'_sha256'],'current event drift')
  if e['category']=='compile':check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'current compile checks removed')
 for e in thermal['events']:check(e['exit']==0 and math.isfinite(e['seconds'])and e['seconds']>=0,'current thermal failure')
 for opt in ['O0','O2']:
  row=physical['runs'][opt]['drivers'];check(len(row)==10,'current physical driver omission')
  check(len(row['test_harvest_joint']['decoder_negatives'])==6 and row['test_harvest_joint']['water_record_unchanged'],'current harvest budgets/negatives absent')
  check(len(row['test_rotation_joint']['compact_decoder_negatives'])==12 and row['test_rotation_joint']['fresh_compact_and_successor_identity'],'current fallow/restart negatives absent')
  for prefix in ['harvest-','rotation-']:
   end=d['physical/'+opt+'/'+prefix+'expected.bin']
   check(end==d['physical/'+opt+'/'+prefix+'fresh.bin']==d['physical/'+opt+'/'+prefix+'expected.bin.opaque']==d['physical/O0/'+prefix+'expected.bin'],'current native endpoint drift')
  for phase in ['retired','fallow']:check(d['physical/'+opt+'/rotation-from-'+phase+'.bin']==d['physical/'+opt+'/rotation-expected.bin'],'current compact continuation drift')
 return {**original,'current_composition_science':True,'source_tree':m['source_tree'],'fresh_physical_drivers_per_optimization':10,'fresh_thermal_profiles_per_optimization':2}
@lru_cache(None)
def baseline_qualification():
 if composition()is None:return _original_baseline_qualification()
 old=immutable_command(HARVEST_PROOF,'tests/crop-harvest/verify_harvest_successor.py')
 depth=immutable_command(SWRD2_PROOF,'tests/root-growth/verify_swrd2_successor.py')
 check(old['qualified']and depth['qualified']and depth['shared_owner_gates']==10,'original owner qualification missing')
 import base64,io,tarfile
 st=json.loads(subprocess.check_output(['git','show',SWRD2_PROOF+':integration/audits/MC_CROP01_TRAJECTORY4_SWRD2_STATUS.json'],cwd=ROOT))
 e=st['full_admission_identity']['full_evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes())
 check(sha(raw)==e['decoded_sha256']=='c4205ab2152c91215ab5bd9b3f16610a326152b1ef5a37da853ef61b17fba864','admitted full capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as archive:d={m.name:archive.extractfile(m).read()for m in archive if m.isfile()}
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(d)==set(manifest),'incomplete admitted full capsule')
 for p,h in manifest.items():check(sha(d[p])==h,'admitted full raw corruption '+p)
 full=json.loads(d['RESULT.json']);check(full['status']=='PASS'and full['returncode']==0 and full['terminal_marker']and not full['changed_inputs'],'admitted full did not complete')
 check(full['source_tree']==depth['source_tree']and sha(d['moving.stdout'])==full['stdout_sha256'],'admitted full source/output mismatch')
 return dict(harvest=old,swrd2=depth,shared_owner_gates=10,full_preservation_at_immutable_swrd2=full['execution_commit'])
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--physical-only',action='store_true');a=p.parse_args()
 print(json.dumps(verify_source()if a.source_only else verify_physical()if a.physical_only else verify_qualification(),indent=2))
