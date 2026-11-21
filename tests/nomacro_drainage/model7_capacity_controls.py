"""Reuse unchanged original-output compiled native and transaction controls."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import original_output_controls as inherited
m=inherited.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir()
    q=json.loads((a.profile/'RESULT.json').read_text());build=Path(q['build_root'])
    project=m.e.load(q['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    meta,_=m.validate_bundle(build,a.reference_work,project)
    result=dict(status='RUNNING',producer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        actual_BUILD_sha256=hashlib.sha256((build/'BUILD.json').read_bytes()).hexdigest(),public_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    try:
        result['native_refusals']=inherited.native(build,a.reference_work,project,a.profile/'trajectory',a.output/'native');save()
        result['transactions']=inherited.transactions(build,a.reference_work,project,a.profile/'trajectory',a.output/'transactions');save()
        assert len(result['native_refusals'])==24+5*int(project.solute)
        result['status']='ACTUAL_MODEL7_EXISTING_NATIVE_COMPILED_REFUSALS_ACTIVE_TRANSACTIONS_PASS_NOT_ADMITTED'
        print(result['status'],len(result['native_refusals']),flush=True)
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
