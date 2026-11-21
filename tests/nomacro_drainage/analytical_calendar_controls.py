"""Use unchanged qualified native and transaction controls on actual clock code."""
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import original_output_controls as inherited


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();profile=json.loads((a.profile/'RESULT.json').read_text());build=Path(profile['build_root'])
 path='tests/nomacro_scheduled_subsurface/original_output_controls.py'
 assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','bd9426711347a1bd7694d39e5c65345db0e25406:'+path],cwd=ROOT)
 project=inherited.m.e.load(profile['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actual_BUILD_sha256=inherited.m.sha(build/'BUILD.json'),native_refusals=[],transactions=None,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  q['native_refusals']=inherited.native(build,a.reference_work,project,a.profile/'trajectory',a.output/'native');assert len(q['native_refusals'])==24;save()
  q['transactions']=inherited.transactions(build,a.reference_work,project,a.profile/'trajectory',a.output/'transactions')
  q['status']='ACTUAL_ANALYTICAL_OUTPUT_24_NATIVE_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],flush=True)


if __name__=='__main__':main()
