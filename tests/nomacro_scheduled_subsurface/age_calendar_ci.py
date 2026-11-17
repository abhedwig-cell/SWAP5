"""Selected portable regular-age output/calendar qualification, no broad F-CI."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
import user_prepare


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir()
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work)
    def run(script,*args):subprocess.run([sys.executable,'-B',str(ROOT/script),*map(str,args)],cwd=ROOT,check=True)
    run('tests/modularity/run_modular_tests.py','--case','original_output_receipt','--output',a.output/'component')
    for phase in ('short','full'):
        run('tests/nomacro_scheduled_subsurface/age_calendar_matrix.py','--reference-work',a.reference_work,'--output',a.output/'matrix','--phase',phase)
    run('tests/nomacro_scheduled_subsurface/age_calendar_reference.py','--reference-work',a.reference_work,'--matrix',a.output/'matrix','--output',a.output/'reference')
    run('tests/nomacro_scheduled_subsurface/age_calendar_controls.py','--reference-work',a.reference_work,'--matrix',a.output/'matrix','--output',a.output/'controls')
    run('tests/nomacro_scheduled_subsurface/age_fixed_inactive.py','--reference-work',a.reference_work,'--platform','Ubuntu','--output',a.output/'inactive')
    run('tests/nomacro_scheduled_subsurface/age_calendar_preserve.py','--reference-work',a.reference_work,'--platform','Ubuntu','--output',a.output/'daily-fixed-preserve')


if __name__=='__main__':main()
