"""Actual exact pre-S5PT diagnostic verdicts; no old red gate is relabelled PASS."""
import argparse,json,os,subprocess
import pond_thermal_production as owner
from pathlib import Path
from rotation_native_baseline import CASES

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert os.name=='posix';owner.guard();out=a.output.resolve();view=owner.prepare(out);events=[]
 commands={name:cmd for name,(cmd,_) in CASES.items()}
 commands.update({'thermal-owner':['python3','-B','tests/dataqual15/thermal_profile_production.py','--output',str(out/'thermal')],'logical-owner':['python3','-B','tests/dataqual15_hupsel/rotation_native_admission.py','--prepare-only','--output',str(out/'logical')],'native-layout':['python3','-B','tests/dataqual15/verify_native_restart_admission.py','--prepare-only','--output',str(out/'layout')],'mc-source':['python3','-B','integration/audits/verify_matrix_thermal.py']})
 for name,cmd in commands.items():
  try:
   cp=subprocess.run(cmd,cwd=view,capture_output=True,timeout=240,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',OMP_NUM_THREADS='1'));stdout,stderr,code=cp.stdout,cp.stderr,cp.returncode;censored=False
  except subprocess.TimeoutExpired as e:stdout=e.stdout or b'';stderr=e.stderr or b'';code=None;censored=True
  for stream,data in [('stdout',stdout),('stderr',stderr)]:(out/(name+'.'+stream)).write_bytes(data)
  events.append(dict(case=name,command=cmd,returncode=code,censored=censored,stdout_sha256=owner.sha(stdout),stderr_sha256=owner.sha(stderr)))
  (out/'RESULT.json').write_text(json.dumps(dict(baseline=owner.BASE,tree=subprocess.check_output(['git','rev-parse','HEAD^{tree}'],cwd=view,text=True).strip(),events=events,old_gate_pass_claim=False,whole_scientific_admission=False),indent=2)+'\n');print(name,code,'CENSORED' if censored else 'UNCENSORED',flush=True)
 assert len(events)==16 and not subprocess.check_output(['git','diff','HEAD','--'],cwd=view)

if __name__=='__main__':main()
