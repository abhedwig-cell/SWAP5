"""Replay the immutable typed owner in isolation with its recorded build root.

FCT classifies absolute compiler source paths relative to ROOT. The owner runs
in an exact detached worktree; only that classifier uses the recorded original
build root. Original FCT assertions still verify every current input hash.
"""
import argparse,json,runpy
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--worktree',type=Path,required=True);p.add_argument('--self-test',action='store_true');a=p.parse_args()
original_run=runpy.run_path
def run(path,*args,**kwargs):
 n=original_run(path,*args,**kwargs)
 if str(path).endswith('/integration/mc-sol01/fct_joint_acceptance/verify.py'):
  n['assess'].__globals__['ROOT']=Path('/workspace/scratch/413315cd3a86/SWAP5')
 return n
runpy.run_path=run
n=run(a.worktree/'integration/audits/verify_perf01_typed_water_flux.py')
print(json.dumps(n['self_test'if a.self_test else'verify'](),indent=2))
