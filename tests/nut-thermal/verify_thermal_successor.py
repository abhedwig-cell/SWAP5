"""Exact thermal owner successor plus bounded, source-exact default preservation."""
from pathlib import Path
from functools import lru_cache
import argparse,hashlib,json,os,subprocess,sys
import verify_thermal_evidence as v
from thermal_default_projection import PROJECTORS,validate as project,project_moving
ROOT=v.ROOT;BASE=v.BASE
def check(ok,label):v.check(ok,label)
def git(*a):return v.git(*a)
@lru_cache(None)
def baseline_command(path,*args):
 root=ROOT.parent/('thermal-baseline-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,capture_output=True,check=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'baseline moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'dirty historical owner')
 r=subprocess.run([sys.executable,'-B',str(root/path),*args],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 check(r.returncode==0,'historical owner failed: '+path+' '+r.stderr[-600:]);return json.loads(r.stdout)
def compatibility():
 current={p:(ROOT/p).read_text()for p in PROJECTORS}
 baseline={p:subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True)for p in PROJECTORS}
 check(project(current,baseline),'default projection failed')
 moving='tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'
 check(project_moving((ROOT/moving).read_text())==subprocess.check_output(['git','show',('a6404e1f7fcf28b7faf9b46d210bc3d5b7098e04'if (ROOT/'src/runtime/mod_fmr_biomass_root_uptake_input.f90').exists()else BASE)+':'+moving],cwd=ROOT,text=True),'moving scientific body changed')
 return {p:hashlib.sha256(b.encode()).hexdigest()for p,b in baseline.items()}
def verify_source(git_reader=None):
 s=v.source(git_reader);compatibility()
 return dict(baseline=BASE,source_tree=s['source_tree'],current_source_tree=s['source_tree'],thermal_successor=True,
  input_successor=True,calendar_successor=True,senescence_successor=True,qualified=False,admitted=False)
def verify_qualification():
 if (ROOT/'src/runtime/mod_fmr_biomass_root_uptake_input.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/root-growth'));import verify_swrd3_successor as swrd3
  return swrd3.verify_qualification()
 source=verify_source();s=json.loads((ROOT/v.STATUS).read_text());v.validate(v.read(s),s)
 prior=baseline_command('tests/nut-input/verify_input_successor.py');check(prior['qualified'],'historical NUT owner not qualified')
 return {**source,'qualified':True,'preservation':'EXACT_DEFAULT_PROJECTION_AND_BASE_NATIVE_BYTES',
  'historical_input_source_tree':prior['source_tree'],'full_fci':'NOT_SELECTED','highest':'NOT_SELECTED_POLICY'}
def compatible_dependency(path,expected):
 """Only the modified shared production files may use reviewed baseline bytes."""
 if path not in PROJECTORS:return False
 verify_qualification()
 old=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
 check(hashlib.sha256(old).hexdigest()==expected,'foreign baseline dependency '+path)
 return True
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');a=p.parse_args()
 print(json.dumps(verify_source()if a.source_only else verify_qualification(),indent=2))
