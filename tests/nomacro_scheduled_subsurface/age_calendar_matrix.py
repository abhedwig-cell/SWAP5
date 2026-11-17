"""Selected periodic-age local/portable cohorts, separated short/full phases."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import age_calendar as c


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--phase',choices=('short','full'),required=True);a=p.parse_args()
    if a.phase=='short':a.output.mkdir()
    record=a.output/'RESULT.json';q=json.loads(record.read_text()) if record.exists() else dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles={},whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10,chemical_mass_guard_changed=False)
    def save():record.write_text(json.dumps(q,indent=2)+'\n')
    specs=[(kind,period,0,opt) for kind in ('plain','surface','subsurface-interval') for period in (3,7) for opt in ('O0','O2')]
    specs += [('plain',7,1,opt) for opt in ('O0','O2')]
    try:
        for kind,period,reset,opt in specs:
            name=f'p{period}-{kind}-r{reset}-{opt}';out=a.output/name
            cmd=[sys.executable,'-B',str(Path(__file__).with_name('age_calendar.py')),'--reference-work',str(a.reference_work),'--output',str(out),'--kind',kind,'--period',str(period),'--swres',str(reset),'--optimization',opt,'--phase',a.phase]
            r=subprocess.run(cmd,capture_output=True,text=True,timeout=240);(a.output/(name+'-'+a.phase+'.log')).write_text(r.stdout+r.stderr)
            if (out/'RESULT.json').exists():q['profiles'][name]=json.loads((out/'RESULT.json').read_text());save()
            assert r.returncode==0,(name,r.stderr)
            print(name,a.phase,'PERIODIC_AGE_SOURCE_STATE_OUTPUT_PASS',flush=True)
        q['status']='FOURTEEN_PERIODIC_AGE_'+a.phase.upper()+'_O0_O2_SOURCE_OUTPUT_NATIVE_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
