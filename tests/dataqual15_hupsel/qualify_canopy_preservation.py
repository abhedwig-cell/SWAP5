"""Exact old authority remains historical; current physical proof stays separate."""
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/dataqual15'))
from verify_native_restart_admission import prepare,blob,git
from verify_canopy_endpoint_evidence import verify

p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir()
r=json.loads((ROOT/'integration/dataqual15_hupsel/CANOPY_ENDPOINT_EVENT_SCOPE_20261103.json').read_text())
assert not r['whole_scientific_admission']and r['physical_correction']
assert set(git('diff','--name-only',r['predecessor'],'HEAD','--','src','app','reference').splitlines())==set(r['production_delta'])
assert not git('diff','HEAD','--','src','app','reference')
assert not git('ls-files','--others','--exclude-standard','--','src','app','reference')
for name,pins in r['production_delta'].items():
 assert blob(r['predecessor'],name)==pins['before']and blob('HEAD',name)==pins['after'],name
verify()
r['preservation_restore']=r['production_delta']
view,projection=prepare(r,out)
events=[]
try:
 for label,args in [('boundary-controls',['tests/dataqual15/test_native_restart_admission.py']),
                    ('historical-seven-legs',['tests/dataqual15/verify_native_restart_admission.py','--output',str(out/'historical-admission')])]:
  command=[sys.executable,'-B',*args];cp=subprocess.run(command,cwd=view,capture_output=True)
  (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
  events.append(dict(label=label,command=command,returncode=cp.returncode))
  assert cp.returncode==0,(label,cp.stderr.decode(errors='replace')[-3000:])
 result=dict(status='EXACT_PREDECESSOR_AUTHORITY_AND_SEPARATE_CURRENT_CANOPY_PROOF_PASS',candidate=git('rev-parse','HEAD'),projection=projection,events=events,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
finally:
 assert view.parent==out
 subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,check=True)
