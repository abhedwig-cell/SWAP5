"""Selected original monthly/explicit/combined age cohorts, short before full."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import age_schedule as s


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--phase',choices=('short','full'),required=True)
    for mode in ('monthly','explicit'):p.add_argument('--'+mode+'-plain-pilot-prefix',type=Path)
    a=p.parse_args()
    if a.phase=='short':a.output.mkdir()
    path=a.output/'RESULT.json';q=json.loads(path.read_text()) if path.exists() else dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles={},whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10,chemical_mass_guard_changed=False)
    def save():path.write_text(json.dumps(q,indent=2)+'\n')
    try:
        for kind in ('plain','surface','subsurface-interval'):
            for mode in ('monthly','explicit','combined'):
                for opt in ('O0','O2'):
                    name=mode+'-'+kind+'-'+opt;out=a.output/name
                    prefix=getattr(a,mode+'_plain_pilot_prefix',None)
                    if kind=='plain' and prefix:
                        out=Path(str(prefix)+opt);completed=json.loads((out/'RESULT.json').read_text())
                        assert (completed['kind'],completed['mode'],completed['optimization'])==(kind,mode,opt)
                        s.m.validate_bundle(out/'build',a.reference_work,s.m.e.load(out/'input'))
                        if a.phase in completed and completed['status']!='FAILED':
                            q['profiles'][name]=completed;save();print(name,a.phase,'EXACT_SOURCE_BOUND_PILOT_REUSED',flush=True);continue
                    cmd=[sys.executable,'-B',str(Path(__file__).with_name('age_schedule.py')),'--reference-work',str(a.reference_work),'--output',str(out),'--kind',kind,'--mode',mode,'--optimization',opt,'--phase',a.phase]
                    r=subprocess.run(cmd,capture_output=True,text=True,timeout=240);(a.output/(name+'-'+a.phase+'.log')).write_text(r.stdout+r.stderr)
                    if (out/'RESULT.json').exists():q['profiles'][name]=json.loads((out/'RESULT.json').read_text());save()
                    assert r.returncode==0,(name,r.stderr);print(name,a.phase,'ORIGINAL_AGE_SCHEDULE_PASS',flush=True)
        q['status']='EIGHTEEN_ORIGINAL_AGE_SCHEDULE_'+a.phase.upper()+'_O0_O2_SOURCE_OUTPUT_NATIVE_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
