"""Actual explicit event policy, reference and generated-source refusal gates."""
import argparse, hashlib, json, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
import experimental_project as e
from daily_coupling import validate_bundle
from frost_cases import create
from time_event_closure import POLICY,source
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);records=[]
 for name,key,policy in [('default-drained','water-frost-drained',None),('old-dtmax','water-frost-drained','configured-dtmax-daily-v1'),('old-growth','water-frost-drained','configured-dtmax-physical-growth-v2'),('free-policy','water-frost-free',POLICY),('chemical-drained','chemical-frost-drained',POLICY),('chemical-free-policy','chemical-frost-free',POLICY)]:
  case=out/name;create(case,key)
  try:e.load(case,time_step_policy=policy)
  except ValueError as error:message=str(error)
  else:raise AssertionError('Unsupported policy accepted '+name)
  record=dict(name=name,error=message)
  if name in ('default-drained','old-dtmax','free-policy','chemical-drained'):
   target=out/(name+'-refused-build');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',e.MODEL,'--experimental-project',str(case),'--reference-work',str(a.reference_work),'--build-only','--output',str(target)]
   if policy:cmd.extend(['--experimental-time-step-policy',policy])
   r=subprocess.run(cmd,capture_output=True,text=True,timeout=30);assert r.returncode!=0 and not target.exists();record.update(command=cmd,returncode=r.returncode,stderr=r.stderr,no_output=True)
  records.append(record)
 case=out/'positive';create(case,'water-frost-drained');project=e.load(case,time_step_policy=POLICY);validate_bundle(a.bundle,a.reference_work,project)
 for name in ('foreign-policy','foreign-time-source','foreign-terminal-source'):
  target=out/name;target.mkdir();meta=json.loads((a.bundle/'BUILD.json').read_text())
  if name=='foreign-policy':meta['identity']['time_event_closure']['policy']='foreign'
  else:
   for file in ('timecontrol.f90','terminal_water_receipt.f90'):shutil.copyfile(a.bundle/file,target/file)
   altered=target/('timecontrol.f90' if name=='foreign-time-source' else 'terminal_water_receipt.f90');altered.write_bytes(altered.read_bytes()+b'\n! foreign\n')
  (target/'BUILD.json').write_text(json.dumps(meta))
  try:validate_bundle(target,a.reference_work,project)
  except ValueError as error:
   message=str(error);assert ('Foreign original TimeControl event-closure policy' if name=='foreign-policy' else 'Foreign actual corrected TimeControl source' if name=='foreign-time-source' else 'Foreign actual terminal water receipt source') in message
  else:raise AssertionError('Foreign source accepted '+name)
  records.append(dict(name=name,error=message))
 try:source((a.reference_work/'build/swap-selected/timecontrol.f90').read_bytes()+b'foreign')
 except ValueError:records.append(dict(name='foreign-original-reference',refused=True))
 else:raise AssertionError('Foreign original reference accepted')
 q=dict(status='EXPLICIT_EVENT_CLOSURE_POLICY_AND_ACTUAL_SOURCE_REFUSALS_PASS',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),driver_sha256=sha(Path(__file__)),negative_controls=records,validated_actual_bundle_sha256=sha(a.bundle/'BUILD.json'),science='NOT_QUALIFIED');(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'])


if __name__=='__main__':main()
