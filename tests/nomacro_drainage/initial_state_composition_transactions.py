"""Exercise literal admitted discard/replay/recovery on the actual new root codec."""
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import original_output_controls as old
BASE='e4dfd5fd0274c51e56ac30baf247cea51a304321'
PATH='tests/nomacro_scheduled_subsurface/original_output_controls.py'


def main():
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=json.loads((a.profile/'RESULT.json').read_text())
 assert q['status']=='ACTUAL_ORIGINAL_INITIAL_STATE_COMPOSITION_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and q['native_codec']=='S5IRC003'
 assert (ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',BASE+':'+PATH],cwd=ROOT)
 build=Path(q['build_root']);project=old.m.e.load(Path(q['input_root']),original_output=True)
 actual=old.transactions(build,a.reference_work,project,a.profile/'trajectory',a.output)
 result=dict(status='ACTUAL_DENSE_DAILY_CDE_ROOT_NATIVE3_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profile_producer=q['source'],initial_selector=q['initial_selector'],optimization=q['optimization'],actual_BUILD_sha256=old.m.sha(build/'BUILD.json'),native_codec=q['native_codec'],observations=actual,actual_prepared_days=3,actual_committed_days=1,actual_discarded_days=2,compiler_executions=0,canonical_admission=False)
 with (a.output/'RESULT.json').open('x') as f:json.dump(result,f,indent=2);f.write('\n')
 print(result['status'],q['optimization'])


if __name__=='__main__':main()
