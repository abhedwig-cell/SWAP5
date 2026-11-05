"""Execute unchanged red-check commands at the exact pre-codec canonical tree.

Diagnostic attribution only. Expected failures are not reported as old gate PASS.
"""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
BASE='5a4d47df19de2fa529878a7b92a7925f52daf819'
CASES={
 'performance':(['python3','-B','integration/performance/authority.py'],'AssertionError: unreviewed delta'),
 'reference-vq':(['python3','tools/vq/b1_11_admission_gate.py'],'"status": "FAIL"'),
 'd1':(['bash','tests/publication/run_pub_me_d1_transition_authority.sh'],'D1 workunit changed production/reference source'),
 'd3':(['bash','tests/publication/run_pub_me_d3_origin_authority.sh'],'D3 changed production/reference source'),
 'p2e06':(['bash','tests/publication/run_pub_p2e06_reference_local_balance_scaling.sh'],'reference tree differs from P2E05 canonical base'),
 'p2e07':(['bash','tests/publication/run_pub_p2e07_reference_cancellation_floor.sh'],'P2E07 mutated src or reference'),
 'p2e08':(['bash','tests/publication/run_pub_p2e08_reference_valid_calibration_domain.sh'],'P2E08 mutated src or reference relative to reconciled canonical'),
 'p2e09':(['bash','tests/publication/run_pub_p2e09_reference_threshold_freeze.sh'],'P2E09 mutated src or reference relative to current canonical merge-base'),
 'p2e10':(['bash','tests/publication/run_pub_p2e10_e0_broad_paired_matrix.sh'],'P2E10 mutated src or reference'),
 'p2e02':(['bash','tests/publication/run_pub_p2e02_reference_uncertainty_pilot.sh'],'Cannot open module file'),
 'p2e04':(['bash','tests/publication/run_pub_p2e04_reference_bc_sweeps.sh'],'Cannot open module file'),
 'census':(['bash','tests/publication/run_pub_p2e04_reference_failure_census.sh'],'Cannot open module file'),
}

def main():
 p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 root=a.baseline.resolve();out=a.output.resolve();out.mkdir(parents=True)
 git=lambda *args:subprocess.check_output(['git',*args],cwd=root,text=True).strip()
 assert git('rev-parse','HEAD')==BASE and not git('diff','HEAD','--')
 events=[]
 for name,(command,signature) in CASES.items():
  run=subprocess.run(command,cwd=root,capture_output=True);raw=run.stdout+run.stderr
  (out/(name+'.stdout')).write_bytes(run.stdout);(out/(name+'.stderr')).write_bytes(run.stderr)
  event=dict(case=name,command=command,returncode=run.returncode,signature=signature,signature_observed=signature in raw.decode(errors='replace'),stdout_sha256=hashlib.sha256(run.stdout).hexdigest(),stderr_sha256=hashlib.sha256(run.stderr).hexdigest())
  events.append(event);print(json.dumps(event),flush=True)
  (out/'RESULT.json').write_text(json.dumps(dict(baseline=BASE,tree=git('rev-parse','HEAD^{tree}'),events=events,old_gate_pass_claim=False,current_scientific_promotion=False),indent=2)+'\n')
  # Record different baseline outcomes explicitly; no legacy verdict is changed.
 assert len(events)==12 and not git('diff','HEAD','--')
 print('TWELVE_EXACT_BASELINE_OUTCOMES_RECORDED_DIAGNOSTICS_ONLY')

if __name__=='__main__':main()
