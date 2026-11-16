"""Replay the preserved 481 auditor at its explicitly pinned dependency boundary.

Current canonical's later no-macro host is NOT the original macropore donor.
Only Git HEAD reads are redirected to the immutable original research boundary.
No model executes and no evidence or acceptance assertion is changed.
"""
import argparse,subprocess,runpy,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[3];real=subprocess.check_output

def frozen(cmd,*args,**kwargs):
 if isinstance(cmd,list) and cmd[:2]==['git','show'] and cmd[2].startswith('HEAD:'):
  cmd=cmd.copy();cmd[2]='84e297af23b2b6e90c927b958fecb5e24228b975:'+cmd[2][5:]
 return real(cmd,*args,**kwargs)
subprocess.check_output=frozen
sys.argv=['audit_original_macro_481.py','--qualified',str(a.workspace/'proof/qualified/artifact.zip'),'--segments',*[str(a.workspace/f'proof/segments/{i}/artifact.zip') for i in range(1,6)],'--output',str(a.workspace/'independent481')]
runpy.run_path(str(root/'research/hybrid-water01/audit_original_macro_481.py'),run_name='__main__')
