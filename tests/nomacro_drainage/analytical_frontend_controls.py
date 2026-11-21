"""Check the original model3 oxygen2 boundary before any compiler/model starts."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import experimental_project as e
from original_output_baseline import assignment
from analytical_hydraulic_science import CASES


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('evidence','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();checks=[]
    def load(path):return e.load(path,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    def refused(label,path):
        try:load(path)
        except ValueError as error:
            assert 'Original hydraulic model3 with physical oxygen stress2 is explicitly not implemented' in str(error)
            checks.append(dict(role=label,status='REFUSED_BEFORE_BUILD',diagnostic=str(error),input_inventory=e.inventory(path)))
        else:raise AssertionError('Original explicit nonimplementation was admitted')
    for opt in ('O0','O2'):
        for label,models,oxygen in CASES:
            version='v2' if label in ('8','9') else 'v1'
            q=json.loads((a.evidence/f'analytical-{label}-daily-cde-short-{opt}-{version}/RESULT.json').read_text())
            project=load(Path(q['input_root']));assert project.solute and not project.macro
            checks.append(dict(role=label+'-'+opt,status='SUPPORTED_COHORT_UNCHANGED',nodes=project.nodes,input_inventory=e.inventory(q['input_root'])))
        q=json.loads((a.evidence/f'analytical-3-daily-cde-short-{opt}-v1/RESULT.json').read_text());refused('original-oxygen2-'+opt,Path(q['input_root']))
    valid=json.loads((a.evidence/'analytical-3-feddes-daily-cde-short-O0-v1/RESULT.json').read_text())
    unused=a.output/'input-unused-oxygen2';shutil.copytree(valid['input_root'],unused)
    original=json.loads((a.evidence/'analytical-3-daily-cde-short-O0-v1/RESULT.json').read_text())
    shutil.copyfile(Path(original['input_root'])/'potato.crp',unused/'unused-oxygen2.crp');load(unused)
    checks.append(dict(role='unreferenced-oxygen2-file',status='IGNORED_AS_PROCESS_HASH_BOUND_AS_DATA',input_inventory=e.inventory(unused)))
    future=a.output/'input-future-oxygen2';shutil.copytree(valid['input_root'],future)
    path=future/'potato.crp';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWOXYGEN',2),encoding='cp1252')
    refused('future-potato-oxygen2',future)
    q=dict(status='ORIGINAL_MODEL3_OXYGEN2_EARLY_FUTURE_ROTATION_REFUSAL_AND_VALID_SCOPES_PASS',checks=checks,
        source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        actual_frontend_sha256=hashlib.sha256((ROOT/'app/hybrid_water/experimental_project.py').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        compiler_executions=0,model_executions=0,original_523day_prefix_and_stop_unchanged=True,public_admission=False)
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],len(checks))


if __name__=='__main__':main()
