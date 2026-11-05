"""Exact pre-successor counterfactual diagnostics; old red verdicts stay red."""
import argparse,hashlib,json,subprocess
from pathlib import Path
from rotation_native_baseline import CASES
BASE='b41e1cda439a370a7e1966387412bdf55ca1b096'
def main():
 p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();root=a.baseline.resolve();out=a.output.resolve();out.mkdir(parents=True)
 git=lambda *s:subprocess.check_output(['git',*s],cwd=root,text=True).strip()
 assert git('rev-parse','HEAD')==BASE and not git('diff','HEAD','--')
 cases={n:c for n,(c,_)in CASES.items()}
 cases.update({'thermal-owner':['python3','-B','tests/dataqual15/thermal_profile_production.py','--output',str(out/'thermal')],'logical-owner':['python3','-B','tests/dataqual15_hupsel/rotation_native_admission.py','--prepare-only','--output',str(out/'logical')],'native-layout':['python3','-B','tests/dataqual15/verify_native_restart_admission.py','--prepare-only','--output',str(out/'layout')]})
 events=[]
 for name,command in cases.items():
  try:
   run=subprocess.run(command,cwd=root,capture_output=True,timeout=180);stdout,stderr=run.stdout,run.stderr;rc=run.returncode;censored=False
  except subprocess.TimeoutExpired as e:stdout=e.stdout or b'';stderr=e.stderr or b'';rc=None;censored=True
  (out/(name+'.stdout')).write_bytes(stdout);(out/(name+'.stderr')).write_bytes(stderr)
  event=dict(case=name,command=command,returncode=rc,censored=censored,stdout_sha256=hashlib.sha256(stdout).hexdigest(),stderr_sha256=hashlib.sha256(stderr).hexdigest());events.append(event);print(json.dumps(event),flush=True)
  (out/'RESULT.json').write_text(json.dumps(dict(baseline=BASE,tree=git('rev-parse','HEAD^{tree}'),events=events,old_gate_pass_claim=False,current_scientific_promotion=False),indent=2)+'\n')
 assert len(events)==15 and not git('diff','HEAD','--')
 print('EXACT_PREDECESSOR_OUTCOMES_RECORDED_NO_OLD_GATE_PASS_CLAIM')
if __name__=='__main__':main()
