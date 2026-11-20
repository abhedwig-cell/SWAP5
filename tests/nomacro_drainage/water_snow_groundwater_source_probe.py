"""Build bounded actual water Snow groundwater forms before model qualification."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from original_output_baseline import assignment

CASES=(('explicit-h0-daily',0,0,False,'daily',1,0,1,4),
    ('explicit-h2-clock',0,2,False,'periodic',3,1,1,4),
    ('explicit-h1-step-off',0,1,True,'explicit',3,0,0,6),
    ('explicit-h1-interval-off',0,1,False,'monthly',1,0,0,3),
    ('implicit-h0-interval-off',1,0,False,'monthly',1,0,0,3),
    ('implicit-h1-step-reset',1,1,True,'explicit',3,1,1,6),
    ('implicit-h2-clock',1,2,False,'periodic',3,1,1,4),
    ('implicit-h2-daily',1,2,False,'daily',1,0,1,4),
    ('implicit-h2-clock-plant-et',1,2,False,'periodic',3,1,1,4))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--only-labels',nargs='+',choices=[c[0] for c in CASES]);a=p.parse_args();a.output.mkdir()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        cases={},model_executions=0,scientific_qualification=False)
    try:
        for label,implicit,hys,step,mode,npd,reset,drain,mean in CASES:
            if a.only_labels and label not in a.only_labels:continue
            out=a.output/label;out.mkdir();inputs=out/'input';build=a.build_root/label/'bundle'
            original.fixture(inputs,0,hys,1,step,mean,mode,3,reset,npd)
            path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
            for key,value in (('SWSNOW',1),('SWKIMPL',implicit),('SWDRA',drain)):text=assignment(text,key,value)
            if label.endswith('-plant-et'):text=assignment(text,'SWCFBS',1)
            path.write_text(text,encoding='cp1252');project=original.m.e.load(inputs,original_output=True)
            sys.path.insert(0,str(original.ROOT/'app/hybrid_water'))
            from snow_water_groundwater import selection
            selected=selection(project);assert selected and selected['swbotb']==1 and selected['swkimpl']==implicit
            command=[sys.executable,'-B',str(original.ROOT/'tools/solute/run_water.py'),'--model',project.model,
                '--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),
                '--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            with (out/'build.stdout').open('x') as stdout,(out/'build.stderr').open('x') as stderr:
                r=subprocess.run(command,cwd=original.ROOT,stdout=stdout,stderr=stderr,timeout=180)
            item=q['cases'][label]=dict(input_root=str(inputs),build_root=str(build),command=command,
                returncode=r.returncode,actual_selected_domain=selected,optimization=a.optimization)
            if (build/'BUILD.json').exists():item['actual_BUILD_sha256']=hashlib.sha256((build/'BUILD.json').read_bytes()).hexdigest()
            (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
            r.check_returncode();original.m.validate_bundle(build,a.reference_work,project)
            assert not list(out.rglob('accepted-*.zip'))
            print(label,'ACTUAL_COMPILED_SOURCE_CLOSURE_PASS',flush=True)
        q['status']='ACTUAL_WATER_SNOW_GROUNDWATER_SOURCE_FORMS_PASS_NOT_SCIENTIFICALLY_QUALIFIED'
    except Exception as error:q.update(status='SOURCE_PROBE_FAILED_NOT_QUALIFIED',error=repr(error));raise
    finally:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')


if __name__=='__main__':main()
