"""Target the changed model7 derivative/search surface; retain original native owner."""
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
        for corrected in (False,True):
            name='capacity-grid-'+str(int(corrected))
            run(name,'hydraulic_constitutive_component.py',[*common,*opt,'--build-root',a.build_root/name,
                '--output',a.output/name,'--model7-grid',*(['--correct-model7-capacity'] if corrected else [])],180)
        run('saturation','hydraulic_saturation_component.py',[*common,*opt,'--build-root',a.build_root/'saturation','--output',a.output/'saturation'],180)
        from hydraulic_saturation_read import inspect
        (a.output/'SATURATION_INDEPENDENT.json').write_text(json.dumps(inspect(a.output/'saturation'),indent=2)+'\n')
        for kind in ('water','cde'):
            build=a.build_root/kind;short=a.output/(kind+'-short');full=a.output/(kind+'-full')
            run(kind+'-short','model7_capacity_runtime.py',[*common,*opt,'--kind',kind,'--build-root',build,'--output',short])
            run(kind+'-full','model7_capacity_runtime.py',[*common,*opt,'--kind',kind,'--build-root',build,'--reuse-build',build/'bundle','--existing-input',short/'input','--phase','full','--output',full])
            for phase,profile in (('short',short),('full',full)):
                run(kind+'-'+phase+'-independent','model7_capacity_forensics.py',[*common,'--profile',profile,'--output',a.output/(kind+'-'+phase+'-INDEPENDENT.json')],60)
            run(kind+'-controls','model7_capacity_controls.py',[*common,'--profile',short,'--output',a.output/(kind+'-controls')],180)
        result['status']='ACTUAL_MODEL7_PORTABLE_COMPONENT_FULL_MODELS_NATIVE_CONTROLS_PASS_NOT_ADMITTED'
        print(result['status'],flush=True)
    except Exception as error:result.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
