"""Retained actual counterfactual failures are observations, never old PASS."""
import hashlib,json,subprocess,zipfile
from pathlib import Path
from native_n_production_baseline import BASE
ROOT=Path(__file__).resolve().parents[2]
DIGEST='fd8fab7924aa7d266cd2d8dd790be9bccd49b66ceaf0843276095f2175d3c0e6'
SIGNALS={'performance':'AssertionError: unreviewed delta','reference-vq':'"status": "FAIL"','d1':'D1 workunit changed production/reference source','d3':'D3 changed production/reference source','p2e06':'reference tree differs from P2E05 canonical base','p2e07':'P2E07 mutated src or reference','p2e08':'P2E08 mutated src or reference relative to reconciled canonical','p2e09':'PUB_P2E09_GATE_FAIL admitted P2E08 Reference replay','p2e10':'PUB_P2E10_GATE_FAIL solver contract drift','p2e02':'Cannot open module file','p2e04':'Cannot open module file','census':'Cannot open module file','thermal-owner':"splitlines())==PATHS",'logical-owner':"splitlines())=={SOURCE}",'native-layout':'AssertionError: unreviewed production paths'}
def main():
 path=ROOT/'integration/dataqual15_hupsel/NATIVE_N_PRODUCTION_BASELINE_POSIX_20261105.zip';assert hashlib.sha256(path.read_bytes()).hexdigest()==DIGEST
 with zipfile.ZipFile(path)as z:
  assert len(z.namelist())==len(set(z.namelist()));r=json.loads(z.read('RESULT.json'));assert r['baseline']==BASE and r['tree']=='b18e71e79de61b482e1b2ff7779f1c1ee995d9d3'
  assert r['old_gate_pass_claim']is False and r['current_scientific_promotion']is False
  assert [e['case']for e in r['events']]==list(SIGNALS)
  for e in r['events']:
   assert e['returncode']not in(0,None)and e['censored']is False
   raw=b''
   for stream in ('stdout','stderr'):
    data=z.read(e['case']+'.'+stream);assert hashlib.sha256(data).hexdigest()==e[stream+'_sha256'];raw+=data
   assert SIGNALS[e['case']]in raw.decode(errors='replace'),e['case']
   script=next(a for a in e['command']if a.endswith(('.py','.sh')))
   assert subprocess.check_output(['git','show',BASE+':'+script],cwd=ROOT)==(ROOT/script).read_bytes().replace(b'\r\n',b'\n')
 print('FIFTEEN_ACTUAL_PREDECESSOR_FAILURES_VERIFIED_OLD_VERDICTS_STAY_FAILED')
if __name__=='__main__':main()
