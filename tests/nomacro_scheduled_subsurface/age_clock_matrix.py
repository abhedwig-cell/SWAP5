"""Dependency-selected output005 matrix; reuse only validated exact pilot builds."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import age_clock as c


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--phase',choices=('short','full'),required=True)
    a=p.parse_args()
    if a.phase=='short':a.output.mkdir()
    path=a.output/'RESULT.json';q=json.loads(path.read_text()) if path.exists() else dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles={},whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10)
    def save():path.write_text(json.dumps(q,indent=2)+'\n')
    try:
        cohort=[('subdaily',n,k) for n in (2,3) for k in ('plain','surface','subsurface-interval')]+[('annual',1,k) for k in ('plain','subsurface-interval')]
        for mode,nprint,kind in cohort:
            name=f'{mode}{nprint}-{kind}-{a.optimization}';out=a.output/name
            cmd=[sys.executable,'-B',str(Path(__file__).with_name('age_clock.py')),'--reference-work',str(a.reference_work),'--output',str(out),'--kind',kind,'--mode',mode,'--nprint',str(nprint),'--optimization',a.optimization,'--phase',a.phase]
            r=subprocess.run(cmd,capture_output=True,text=True,timeout=240);(a.output/(name+'-'+a.phase+'.log')).write_text(r.stdout+r.stderr)
            if (out/'RESULT.json').exists():q['profiles'][name]=json.loads((out/'RESULT.json').read_text());save()
            assert r.returncode==0,(name,r.stderr);print(name,a.phase,'ORIGINAL_AGE_CLOCK_PASS',flush=True)
        q['status']='EIGHT_ORIGINAL_AGE_CLOCK_'+a.phase.upper()+'_'+a.optimization+'_SOURCE_OUTPUT_NATIVE_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
