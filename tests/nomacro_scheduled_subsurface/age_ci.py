"""Selected portable original-age qualification and existing owner preservation."""
import argparse
import importlib.util
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
import user_prepare
spec=importlib.util.spec_from_file_location('age_inputs',Path(__file__).with_name('age_reference.py'))
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True)
    p.add_argument('--reference-work',type=Path,required=True);a=p.parse_args();a.output.mkdir()
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work)
    inputs=a.output/'inputs';inputs.mkdir()
    for initial in (0.,100.):f.fixture(inputs/str(int(initial)),initial)
    def run(script,*args,env=None):subprocess.run([sys.executable,'-B',str(script),*map(str,args)],cwd=ROOT,env=env,check=True)
    run(ROOT/'tests/modularity/run_modular_tests.py','--case','original_age_clock','--case','surface_age_budget','--output',a.output/'component')
    run(ROOT/'tests/nut-sol/run_age.py',env={**os.environ,'AGE_RESULT_DIR':str(a.output/'existing-owner')})
    run(ROOT/'reference/swap-4.3.1/patches/NOMACRO-AGE-SOURCE-01/run.py','--reference-work',a.reference_work,'--output',a.output/'reference')
    run(Path(__file__).with_name('age_runtime.py'),'--input-root',inputs,'--reference-work',a.reference_work,'--output',a.output/'runtime')
    run(Path(__file__).with_name('age_controls.py'),'--input-root',inputs,'--reference-work',a.reference_work,
        '--evidence',a.output/'runtime','--output',a.output/'controls')


if __name__=='__main__':main()
