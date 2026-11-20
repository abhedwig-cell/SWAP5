"""Actual external prepare/discard/replay/accept and recovered next-day checks."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from cde_clock_controls import transactions


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();receipt=a.profile/'RESULT.json';before=original.m.sha(receipt)
    profile=json.loads(receipt.read_text());build=Path(profile['build_root'])
    project=original.m.e.load(profile['input_root'],original_output=True)
    original.m.validate_bundle(build,a.reference_work,project)
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        actual_BUILD_sha256=original.m.sha(build/'BUILD.json'),actual_profile_sha256=before)
    try:
        q['checks']=transactions(build,a.reference_work,project,a.profile/'trajectory',a.output/'actual')
        assert all(value is True for value in q['checks'].values())
        assert original.m.sha(receipt)==before
        q['status']='ACTUAL_IMPLICIT_SNOW_EXTERNAL_TRANSACTION_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    print(q['status'])


if __name__=='__main__':main()
