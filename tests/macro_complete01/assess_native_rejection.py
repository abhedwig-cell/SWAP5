"""Read-only natural active-V rejection, exact rollback and direct retry comparison."""
from pathlib import Path
import json,zipfile,hashlib,math
R=Path('integration/macro-complete01');res=json.loads((R/'RESOURCE_PATHS.json').read_text());results=[];hashes={};target=35797.862000000016
for opt in ['O0','O2']:
 b=Path(res[opt]['path']);normal=b/'REJECTION14R2_NORMAL';direct=b/'REJECTION14R2_DIRECT';n=normal/'original';d=direct/'original'
 for p in [normal,direct]:
  q=json.loads((p/'RESULT.json').read_text());assert q['status']=='OWN_RESTART_WINDOW_COMPLETE' and q['elapsed_seconds']<20 and abs(q['rows'][0]['independent_residual_cm'])<=1e-6
 ev=[x.split() for x in (n/'replay_events.txt').read_text().splitlines()];assert [int(x[0]) for x in ev]==[0,1,2,3,1,2,4]
 rejected=ev[2];assert float(rejected[2])==.002 and int(rejected[3])==31 and rejected[4:6]==['T','F'] and float(rejected[6])==1 and int(rejected[7])==0
 retry=ev[4];assert float(retry[2])==.002/3;assert ev[5][4:6]==['F','F'] and int(ev[5][3])==4
 dev=[x.split() for x in (d/'replay_events.txt').read_text().splitlines()];assert [int(x[0]) for x in dev]==[0,1,2,4] and float(dev[1][2])==.002/3
 tr=[list(map(float,l.split())) for l in (n/'jac37_trace.txt').read_text().splitlines()];active=[x for x in tr if x[0]==target and x[1]==.002 and x[3]==1 and x[4]>0 and (x[7]==1 or x[8]==1)];assert active
 for kind in ['matrix','physical']:
  assert (n/('replay_begin_'+kind+'.bin')).read_bytes()==(n/('replay_restored_'+kind+'.bin')).read_bytes()==(n/('replay_small_begin_'+kind+'.bin')).read_bytes()
 assert (n/'replay_rejected_physical.bin').read_bytes()!=(n/'replay_begin_physical.bin').read_bytes()
 names=[x.name for x in d.glob('replay_*.bin')]
 for name in names:
  assert (n/name).read_bytes()==(d/name).read_bytes(),(opt,name)
  h=hashlib.sha256((n/name).read_bytes()).hexdigest()
  if opt=='O0':hashes[name]=h
  else:assert hashes[name]==h
 for name in ['macro.bin','result.end']:
  z=[zipfile.ZipFile(p/'accepted-column-1-day-3.zip') for p in [normal,direct,b/'KINK_V13_OWN2TO3']];assert z[0].read(name)==z[1].read(name)==z[2].read(name)
  h=hashlib.sha256(z[0].read(name)).hexdigest()
  if opt=='O0':hashes[name]=h
  else:assert hashes[name]==h
 results.append(dict(opt=opt,original_time=target,rejected_dt=.002,retry_dt=.002/3,real_rejection=True,active_V_iterations=len(active),iterations_large=30,iterations_smaller=4,physical25_and_matrix_rollback_exact=True,trial_was_mutated=True,direct_smaller_trial_flux_commit_and_day3_native_exact=True,snapshots_compared=len(names),FrReduQ=1,IDecMpRat=0))
out=dict(scope='Actual selected original V13 rejection; no forced rejection/changed criterion. Direct route skips large solve and uses unchanged native TimeControl5 reduction before Drain2; same existing forcing setup as normal native retry.',results=results,hashes=hashes,models_launched=0,does_not_qualify_all_regimes_or_fullperiod=True)
(R/'BLOCK14_REJECTION_QUALIFICATION.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k!='hashes'}))
