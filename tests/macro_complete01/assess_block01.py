"""Read-only assessment of real baseline/candidate kernel and process evidence."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
res=json.loads((R/'RESOURCE_PATHS.json').read_text());head=ROOT/'src/legacy/b1_10_port/headcalc.f90'
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])
 for profile in ['CHECKED_BASELINE','CHECKED_CANDIDATE']:
  q=json.loads((b/profile/'RESULT.json').read_text());assert q['compile_returncode']==0 and not q.get('censored',False)
  assert all(x['seconds']<20 for x in q['runs'])
  assert [x['returncode'] for x in q['runs']]==([1,0,0] if profile=='CHECKED_BASELINE' else [0,0,0])
  line=(b/profile/'fresh.stdout').read_text().splitlines()[0].split();fmax=abs(float(line[3]));total=abs(float(line[4]))
  if profile=='CHECKED_BASELINE':assert fmax>1e-10 and total>1e-10 and abs(float(line[5]))<1e-10
  else:
   assert fmax<1e-10 and total<1e-10
   assert next(v for k,v in q['source_sha256'].items() if Path(k).name=='headcalc.f90')==hashlib.sha256(head.read_bytes()).hexdigest()
  for mode in ['no-macro','dtmin-refusal']:
   assert (b/profile/(mode+'.stdout')).read_bytes()==(b/'CHECKED_BASELINE'/(mode+'.stdout')).read_bytes()
 for mode in ['fresh','no-macro','dtmin-refusal']:
  assert (b/'CHECKED_CANDIDATE'/(mode+'.stdout')).read_bytes()==(Path(res['O0']['path'])/'CHECKED_CANDIDATE'/(mode+'.stdout')).read_bytes()
 baseline='PROCESS_BASELINE' if opt=='O0' else 'PROCESS_RESUMED_BASELINE'
 x=(b/baseline/'fresh.stdout').read_bytes();y=(b/'PROCESS_CANDIDATE/fresh.stdout').read_bytes();assert x==y
 for label in [baseline,'PROCESS_CANDIDATE']:
  q=json.loads((b/label/'RESULT.json').read_text());assert q['compile_returncode']==0 and q['runs'][0]['returncode']==0 and not q.get('censored',False)
 for marker in [b'PPA_WU05_PERCH20_TRANSACTION_CONTINUATION_GATE=PASS',b'PPA_WU05A17_INNER_RESTART=PASS',b'PPA_WU05_PERCH20_REJECT_ISOLATION=PASS']:assert marker in y
b=Path(res['O0']['path']);assert (b/'NO_MACRO_RETRY_BASELINE/fresh.stdout').read_bytes()==(b/'NO_MACRO_RETRY_CANDIDATE/fresh.stdout').read_bytes()
for profile in ['NO_MACRO_RETRY_BASELINE','NO_MACRO_RETRY_CANDIDATE']:
 q=json.loads((b/profile/'RESULT.json').read_text());assert q['runs'][0]['returncode']!=0
 assert b'smaller trial did not converge' in (b/profile/'fresh.stderr').read_bytes()
print('BLOCK01_FRESH_KERNEL_PROCESS_STATE_RESTART_O0_O2_AND_POSITIVE_NO_MACRO_PRESERVATION=PASS')
print('EXTRA_NO_MACRO_RETRY=UNCHANGED_BASELINE_FAILURE_NOT_A_PASS')
