"""Targeted existing ordinary-drainage implicit zero-flux boundary composition."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as previous
m=previous.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--solute',type=int,choices=(0,1),required=True)
    p.add_argument('--hysteresis',type=int,choices=(0,1,2),required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),parameters={key:str(value) if isinstance(value,Path) else value for key,value in vars(a).items()},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',public_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        inputs=a.output/'input';previous.fixture(inputs,a.solute,a.hysteresis,6,False,kmean=2,mode='daily',fmt=3,reset=1,npd=1)
        project=m.e.load(inputs,original_output=True);report=m.e.inspect(inputs,original_output=True)
        assert report['selectors']['SWDRA']==1 and report['boundary']['SWBOTB']==6 and not report.get('extended_drainage')
        q.update(input_root=str(inputs),build_root=str(a.build_root),numerical_policy=report['implicit_conductivity']);save()
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(a.build_root)]
        r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(command=command,returncode=r.returncode);save();r.check_returncode()
        full=a.output/'trajectory';windows=[(2,4),(7,9),(30,34)]
        q['trajectory'],data=m.trajectory(a.build_root,a.reference_work,project,full,35,{35,*(day for pair in windows for day in pair)},180);q['cold']=[];save()
        for low,high in windows:q['cold'].append(previous.previous.own(a.build_root,a.reference_work,project,full,data,low,high,a.output/f'own-{low}'));save()
        q.update(status='ACTUAL_ORDINARY_DRAINAGE_IMPLICIT_ZERO_BOUNDARY_NATIVE_OUTPUT_PASS',native_codec=m.e.auxiliary_magic(project).decode());save();print(q['status'],a.solute,a.hysteresis,a.optimization)
    except Exception as error:q.update(status='FAILED',error=repr(error));save();raise


if __name__=='__main__':main()
