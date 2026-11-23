"""Run the literal admitted external discard/replay/accept/recover control."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import original_output_controls as inherited


def main():
    parser=argparse.ArgumentParser()
    for name in ('profile','reference-work','output'):parser.add_argument('--'+name,type=Path,required=True)
    a=parser.parse_args();a.output.mkdir();path='tests/nomacro_scheduled_subsurface/original_output_controls.py'
    original=subprocess.check_output(['git','show','8e27dd9eb0f633050d2d82d00d28992435c313cb:'+path],cwd=ROOT)
    assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==original
    profile=json.loads((a.profile/'RESULT.json').read_text());build=Path(profile['build_root'])
    project=inherited.m.e.load(profile['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    result=inherited.transactions(build,a.reference_work,project,a.profile/'trajectory',a.output/'transactions')
    assert result==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)
    receipt=dict(status='ACTUAL_SNOW_HISTORY_CALENDAR_EXTERNAL_DISCARD_REPLAY_ACCEPT_RECOVER_PASS',actual_compiler_producer=profile['source'],actual_control_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actual_BUILD_sha256=hashlib.sha256((build/'BUILD.json').read_bytes()).hexdigest(),frozen_control_sha256=hashlib.sha256(original).hexdigest(),transactions=result,external_worker_prepares=3,external_commits=1,compiler_executions=0,canonical_admission=False)
    with (a.output/'RESULT.json').open('x') as f:json.dump(receipt,f,indent=2)
    print(receipt['status'])


if __name__=='__main__':main()
