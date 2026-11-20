"""Generate actual implicit/Snow source forms without starting a model."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from original_output_baseline import assignment

m=original.m
CASES=(('water-head',0,0,8,False,'daily',1,0,4),
       ('cde-groundwater-clock',1,2,1,False,'periodic',3,1,4),
       ('water-flux-interval',0,2,5,False,'monthly',1,0,3),
       ('water-head-clock',0,1,8,False,'periodic',3,1,6),
       ('water-flux-step',0,2,5,True,'explicit',1,1,5),
       ('cde-groundwater-interval',1,0,1,False,'monthly',1,0,3),
       ('cde-head-step',1,1,8,True,'explicit',3,1,6),
       ('cde-flux-interval',1,2,5,False,'explicit',1,1,5),
       ('cde-groundwater-step-off',1,1,1,True,'explicit',3,1,6))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    parser.add_argument('--only-labels',nargs='+',choices=[case[0] for case in CASES])
    args=parser.parse_args();args.output.mkdir()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
           model_executions=0,cases={},scientific_qualification=False)
    def save():(args.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for label,solute,hys,bottom,step,mode,npd,reset,mean in CASES:
            if args.only_labels and label not in args.only_labels:continue
            out=args.output/label;out.mkdir();inputs=out/'input';build=args.build_root/label/'bundle'
            original.fixture(inputs,solute,hys,bottom,step,mean,mode,3,reset,npd)
            path=inputs/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWSNOW',1),encoding='cp1252')
            if label.endswith('-off'):
                path.write_text(assignment(path.read_text(encoding='cp1252'),'SWDRA',0),encoding='cp1252')
            project=m.e.load(inputs,original_output=True);policy=m.e.inspect(inputs)['implicit_conductivity']
            assert policy['implicit_snow_composition'] is True
            command=[sys.executable,'-B',str(original.ROOT/'tools/solute/run_water.py'),'--model',project.model,
                     '--experimental-project',str(inputs),'--original-output','--reference-work',str(args.reference_work),
                     '--build-only','--donor-opt',args.optimization,'--kernel-opt',args.optimization,'--output',str(build)]
            start=time.perf_counter()
            with (out/'build.stdout').open('x') as stdout,(out/'build.stderr').open('x') as stderr:
                run=subprocess.run(command,cwd=original.ROOT,stdout=stdout,stderr=stderr,timeout=180)
            q['cases'][label]=dict(input_root=str(inputs),build_root=str(build),command=command,
                returncode=run.returncode,build_seconds=time.perf_counter()-start,
                actual_implicit_policy=policy,
                source_files={p.name:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
                              for p in sorted(build.glob('*.f90'))})
            assert not list(out.rglob('donor.stdout')) and not list(out.rglob('accepted-*.zip'))
            save()
        q['status']='ACTUAL_SELECTED_IMPLICIT_SNOW_SOURCE_FORMS_OBSERVED_NOT_QUALIFIED'
    except Exception as error:q.update(status='SOURCE_PROBE_FAILED_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],[(name,item['returncode']) for name,item in q['cases'].items()])


if __name__=='__main__':main()
