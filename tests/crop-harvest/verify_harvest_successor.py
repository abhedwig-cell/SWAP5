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
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--physical-only',action='store_true');a=p.parse_args()
 print(json.dumps(verify_source()if a.source_only else verify_physical()if a.physical_only else verify_qualification(),indent=2))
