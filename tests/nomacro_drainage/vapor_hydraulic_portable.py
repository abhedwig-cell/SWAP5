"""One coupled campaign for original per-layer vapor and complete lookup carry."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
CASES=(('8',[8],[1,1]),('11',[11],[1,1]),
       ('mixed-8-11',[8,11],[1,0]),('mixed-11-8',[11,8],[0,1]),
       ('mixed-7-8',[7,8],[1,1]),('mixed-8-7',[8,7],[1,1]),
       ('mixed-9-10',[9,10],[1,1]),('mixed-10-9',[10,9],[1,1]))


def main():
    parser=argparse.ArgumentParser()
    for name in ('reference-work','build-root','output'):parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--reuse-initial-proof',type=Path)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True);a=parser.parse_args()
    a.output.mkdir();a.build_root.mkdir();logs=a.output/'commands';logs.mkdir()
    result=dict(status='RUNNING',producer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=a.optimization,steps=[],canonical_admission=False,
        strategy='One full1096 period includes all seven exact cold windows; no duplicate short periods for the same unchanged build/input.')
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    def run(label,script,arguments,cap=600):
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
        from vapor_mixed_component_forensics import audit
        if a.reuse_initial_proof:
            from vapor_hydraulic_resume import read_initial
            result['reused_initial']=read_initial(a.reuse_initial_proof,a.optimization)
            (a.output/'MIXED_COMPONENT_INDEPENDENT.json').write_text(json.dumps(audit(a.reuse_initial_proof/'vapor-hydraulic-family',(a.optimization,)),indent=2)+'\n')
            save()
        else:
            for corrected in (False,True):
                name='hydraulic-vapor-mixed-'+('corrected' if corrected else 'original')+'-'+a.optimization+'-v1'
                run(name,'hydraulic_vapor_component.py',[*common,*opt,'--build-root',a.build_root/name,'--output',a.output/name,
                    '--mixed-grid','--correct-model7-capacity',*(['--correct-vapor-sign'] if corrected else [])],180)
            (a.output/'MIXED_COMPONENT_INDEPENDENT.json').write_text(json.dumps(audit(a.output,(a.optimization,)),indent=2)+'\n')
        for label,models,flags in CASES:
            if a.reuse_initial_proof and label=='8':continue
            extra=['--hydraulic-model',str(models[0]),'--layer-models',*map(str,models),'--vapor-flags',*map(str,flags)]
            for kind in ('water','cde'):
                name=label+'-'+kind;build=a.build_root/name;profile=a.output/(name+'-full')
                run(name+'-full','vapor_hydraulic_runtime.py',[*common,*opt,*extra,'--kind',kind,'--phase','full','--build-root',build,'--output',profile])
                run(name+'-independent','vapor_hydraulic_forensics.py',[*common,'--profile',profile,'--output',a.output/(name+'-INDEPENDENT.json')],90)
                if label in ('8','mixed-7-8'):
                    run(name+'-controls','vapor_native_controls.py',[*common,'--profile',profile,'--output',a.output/(name+'-controls')],600)
        result['status']='ACTUAL_VAPOR_PORTABLE_16FULL_112COLD_MIXED_COMPONENTS_COMPILED_NATIVE_TRANSACTIONS_INDEPENDENT_PASS_NOT_ADMITTED'
        print(result['status'],flush=True)
    except Exception as error:result.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
