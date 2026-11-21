"""Qualify the original explicit analytical family as one portable campaign."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
    a.output.mkdir();a.build_root.mkdir();logs=a.output/'commands';logs.mkdir()
    result=dict(status='RUNNING',producer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=a.optimization,steps=[],canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    def run(label,script,arguments,cap=360):
        command=[sys.executable,'-B',str(HERE/script),*map(str,arguments)]
        step=dict(label=label,command=command,status='RUNNING');result['steps'].append(step);save();start=time.monotonic()
        try:
            with (logs/(label+'.stdout')).open('x') as out,(logs/(label+'.stderr')).open('x') as err:
                r=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=cap)
            step['returncode']=r.returncode;r.check_returncode();step['status']='PASS'
        except Exception as error:step.update(status='FAILED_OR_CENSORED',error=repr(error));raise
        finally:step['seconds']=time.monotonic()-start;save()
    common=['--reference-work',a.reference_work];opt=['--optimization',a.optimization]
    try:
        from analytical_hydraulic_science import CASES
        from hydraulic_mixed_analytical_read import audit as mixed_audit
        for corrected in (False,True):
            name='mixed-capacity-'+str(int(corrected))
            run(name,'hydraulic_constitutive_component.py',[*common,*opt,'--build-root',a.build_root/name,
                '--output',a.output/name,'--mixed-layer',*(['--correct-model7-capacity'] if corrected else [])],180)
        (a.output/'MIXED_INDEPENDENT.json').write_text(json.dumps(mixed_audit(a.output/'mixed-capacity-0',a.output/'mixed-capacity-1'),indent=2)+'\n')
        for label,models,oxygen in CASES:
            extra=['--hydraulic-model',str(models[0] if len(models)==1 else 7),'--oxygen-policy',oxygen]
            if len(models)>1:extra+=['--layer-models',*map(str,models)]
            for kind in ('water','cde'):
                name=label+'-'+kind;build=a.build_root/name;short=a.output/(name+'-short')
                for phase in ('short','full'):
                    profile=a.output/(name+'-'+phase)
                    reuse=[] if phase=='short' else ['--reuse-build',build/'bundle','--existing-input',short/'input']
                    run(name+'-'+phase,'analytical_hydraulic_runtime.py',
                        [*common,*opt,*extra,'--kind',kind,'--phase',phase,'--build-root',build,'--output',profile,*reuse],600)
                    run(name+'-'+phase+'-independent','analytical_hydraulic_forensics.py',
                        [*common,'--profile',profile,'--output',a.output/(name+'-'+phase+'-INDEPENDENT.json')],90)
        result['status']='ACTUAL_ANALYTICAL_PORTABLE_20FULL_20SHORT_200COLD_MIXED_COMPONENTS_INDEPENDENT_PASS_NOT_ADMITTED'
        print(result['status'],flush=True)
    except Exception as error:result.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
