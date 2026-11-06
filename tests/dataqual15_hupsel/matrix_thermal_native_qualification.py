"""Run the unmodified full POSIX qualifier in its exact matched private context."""
import argparse,json,os,subprocess,sys
from pathlib import Path
import matrix_thermal_native_policy as policy

def main():
 p=argparse.ArgumentParser();p.add_argument('--models',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert os.name=='posix';policy.guard();out=a.output.resolve();out.mkdir(parents=True);events=[]
 for role in ('incumbent-v2','candidate-v2'):
  view=out/(role+'-tree');subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),policy.BASE],cwd=policy.ROOT,check=True,capture_output=True)
  try:
   if role=='candidate-v2':(view/policy.SOURCE).write_text(policy.candidate(),encoding='utf-8',newline='\n')
   physical=a.models.resolve()/role/'physical';report=json.loads((physical/'result.json').read_text())
   assert all(policy.sha((view/n).read_bytes())==h for n,h in report['inputs'].items())
   cmd=[sys.executable,'-B',str(view/'integration/audits/qualify_matrix_thermal.py'),'--physical',str(physical),'--output',str(out/role)];cp=subprocess.run(cmd,cwd=view,capture_output=True,env=dict(os.environ,OMP_NUM_THREADS='1'),timeout=900)
   for stream in ('stdout','stderr'):(out/(role+'.'+stream)).write_bytes(getattr(cp,stream))
   events.append(dict(role=role,command=cmd,returncode=cp.returncode));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert cp.returncode==0,cp.stderr[-4000:]
  finally:
   assert view.parent==out and view.name==role+'-tree';subprocess.run(['git','worktree','remove','--force',str(view)],cwd=policy.ROOT,check=True,capture_output=True)
 (out/'RESULT.json').write_text(json.dumps(dict(status='ORIGINAL_POSIX_FULL_MATRIX_THERMAL_QUALIFICATION_BOTH_ROLES_PASS',events=events,production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
if __name__=='__main__':main()
