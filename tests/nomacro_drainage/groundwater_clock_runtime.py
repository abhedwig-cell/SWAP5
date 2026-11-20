"""One coherent existing groundwater/CDE clock composition cohort."""
import argparse
from datetime import date,timedelta
import json
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from original_output_baseline import assignment

m=original.m;ROOT=original.ROOT
CASES=(
    ('h2-periodic',2,False,'periodic',3,1,3,4,1,None),
    ('h1-step-explicit',1,True,'explicit',3,1,1,6,1,None),
    ('h0-step-periodic',0,True,'periodic',2,0,1,3,1,None),
    ('h1-explicit-monthly',1,False,'monthly',2,1,2,2,0,None),
    ('h2-subdaily-terminal',2,False,'terminal',3,0,2,5,1,None),
    ('h2-step-year',2,True,'explicit',3,1,1,4,1,'2002-12-15'))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--reuse-first',type=Path)
    p.add_argument('--only-labels',nargs='+',choices=[c[0] for c in CASES])
    a=p.parse_args();a.output.mkdir()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
           parameters={k:str(v) if isinstance(v,Path) else v for k,v in vars(a).items()},cases={},
           functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for label,hys,step,mode,fmt,reset,npd,mean,implicit,epoch in CASES:
            if a.only_labels and label not in a.only_labels:continue
            if label=='h2-periodic' and a.reuse_first:
                record=__import__('json').loads((a.reuse_first/'RESULT.json').read_text())
                build=Path(record['build_root']);inputs=Path(record['input_root']);project=m.e.load(inputs,original_output=True)
                m.validate_bundle(build,a.reference_work,project)
                assert record['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS' and record['parameters']['optimization']==a.optimization
                assert tuple(record['parameters'][k] for k in ('solute','hysteresis','bottom','kmean','perstep','mode','format','reset','nprintday'))==(1,2,1,4,False,'periodic',3,1,3)
                q['cases'][label]=dict(actual_case_root=str(a.reuse_first),actual_receipt_sha256=m.sha(a.reuse_first/'RESULT.json'),fresh_compilations=0,fresh_models=0)
                save();continue
            out=a.output/label;out.mkdir();inputs=out/'input';build=a.build_root/label/'bundle'
            original.fixture(inputs,1,hys,1,step,mean,mode,fmt,reset,npd)
            if not implicit:
                path=inputs/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWKIMPL',0),encoding='cp1252')
            if epoch:
                path=inputs/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),'TSTART',epoch),encoding='cp1252')
                path=inputs/'fixed-irrigation.irg';text=path.read_text(encoding='cp1252');assert text.count('2002-01-05')==1
                path.write_text(text.replace('2002-01-05',str(date.fromisoformat(epoch)+timedelta(days=4))),encoding='cp1252')
            project=m.e.load(inputs,original_output=True)
            item=dict(status='RUNNING',source_commit=q['source'],parameters=dict(optimization=a.optimization,solute=1,hysteresis=hys,bottom=1,kmean=mean,perstep=step,mode=mode,format=fmt,reset=reset,nprintday=npd,implicit=implicit,epoch=epoch),build_root=str(build),input_root=str(inputs),functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
            q['cases'][label]=dict(actual_case_root=str(out));save()
            def save_case():(out/'RESULT.json').write_text(json.dumps(item,indent=2)+'\n')
            save_case()
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            start=time.monotonic()
            with (out/'build.stdout').open('w') as stdout,(out/'build.stderr').open('w') as stderr:
                run=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=180)
            item['build']=dict(command=command,returncode=run.returncode,seconds=time.monotonic()-start);save_case();run.check_returncode()
            m.validate_bundle(build,a.reference_work,project)
            windows=[(2,4),(7,9),(30,34)]+([(17,20)] if epoch else [])
            item['trajectory'],data=m.trajectory(build,a.reference_work,project,out/'trajectory',35,{35,*(d for pair in windows for d in pair)},180)
            item['cold']=[];save_case()
            for low,high in windows:
                item['cold'].append(original.previous.own(build,a.reference_work,project,out/'trajectory',data,low,high,out/f'own-{low}'));save_case()
            item['status']='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS';save_case()
        q['status']='ACTUAL_GROUNDWATER_CDE_CLOCK_COMPOSITION_COHORT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
