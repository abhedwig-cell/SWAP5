"""Verify raw counterfactual failures; never convert an old red check to PASS."""
import hashlib,json,subprocess,zipfile
from pathlib import Path
from production_crop_logical_baseline import BASE,CASES
ROOT=Path(__file__).resolve().parents[2]
DIGEST='279943e96eb9d72bce3f7b967804949b7e597ba2c33fee3f01875ca619f6c53a'

def main():
 path=ROOT/'integration/dataqual15_hupsel/PRODUCTION_CROP_LOGICAL_BASELINE_POSIX_20261105.zip'
 assert hashlib.sha256(path.read_bytes()).hexdigest()==DIGEST
 with zipfile.ZipFile(path)as z:
  assert len(z.namelist())==len(set(z.namelist()))
  r=json.loads(z.read('RESULT.json'));assert r['baseline']==BASE and r['tree']=='eef474d9edfc0f7d8b80a6f4cc5c464337ea1a7c'
  assert r['old_gate_pass_claim']is False and r['current_scientific_promotion']is False
  assert [e['case']for e in r['events']]==list(CASES)
  for e in r['events']:
   name=e['case'];command,signature=CASES[name]
   assert e['command']==command and e['signature']==signature and e['returncode']!=0
   for stream in ('stdout','stderr'):
    assert hashlib.sha256(z.read(name+'.'+stream)).hexdigest()==e[stream+'_sha256']
   raw=(z.read(name+'.stdout')+z.read(name+'.stderr')).decode(errors='replace')
   assert e['signature_observed']==(signature in raw)
   if name=='p2e09':assert 'PUB_P2E09_GATE_FAIL admitted P2E08 Reference replay'in raw
   elif name=='p2e10':assert 'PUB_P2E10_GATE_FAIL solver contract drift'in raw
   else:assert e['signature_observed']
   # Original test/controller bodies remain unchanged, including their no-src
   # governance restrictions and failed compiler lists.
   assert subprocess.check_output(['git','show',BASE+':'+command[-1]],cwd=ROOT)==(ROOT/command[-1]).read_bytes().replace(b'\r\n',b'\n')
 print('TWELVE_BASELINE_FAILURES_VERIFIED_OLD_VERDICTS_UNCHANGED_NO_SCIENTIFIC_PROMOTION')

if __name__=='__main__':main()
