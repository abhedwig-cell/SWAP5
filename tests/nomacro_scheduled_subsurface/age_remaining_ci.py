"""Fresh selected wetting/pulse preservation after the accepted dry-end repair."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/solute'))
import user_prepare


def main():
    p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work)
    def run(script,*args):subprocess.run([sys.executable,'-B',str(ROOT/script),*map(str,args)],cwd=ROOT,check=True)
    run('tests/nomacro_scheduled_subsurface/age_wetting_preserve.py','--platform','Ubuntu','--reference-work',a.reference_work,'--output',a.output/'wetting')
    for phase in ('short','full'):
        run('tests/irrigation_pulse/run.py','--reference-work',a.reference_work,'--output',a.output/'pulse','--phase',phase)


if __name__=='__main__':main()
