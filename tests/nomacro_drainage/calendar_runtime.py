"""Actual original output/calendar composed with extended drainage state."""
import argparse
import json
import re
from pathlib import Path
import subprocess
import sys
import time
import zipfile

import extended_runtime as previous
from original_output_baseline import assignment
from original_output_files import compare
import original_output
from extended_drainage import validate_candidate

m=previous.m
ROOT=previous.ROOT


def fixture(case,output,mode,fmt,nprint):
    info=previous.fixture(case,output)
    path=output/'swap.swp';text=path.read_text(encoding='cp1252')
    values=dict(SWCSV=fmt,NPRINTDAY=nprint,SWMONTH=int(mode=='monthly'),
                SWODAT=0,SWRES=0 if mode in ('terminal','perstep') else 1,
                PERIOD=0 if mode=='terminal' else 1,INLIST_CSV="'WATBAL,GWL'",NUM_DECIMALS=12)
    for key,value in values.items():
        text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
    text+='\nFLPRINTDT = '+('.TRUE.' if mode=='perstep' else '.FALSE.')+'\n'
    path.write_text(text,encoding='cp1252')
    return info


def own(build,reference,project,full,data,start,end,out):
    result=m.own(build,reference,project,full,data,start,end,out)
    result['exact_original_output']=compare(full/'original',out/'original',original_output.selection(project),start,end,project.start_date)
    with zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as z:
        validate_candidate(z.read('macro.bin'),data[end-1],project)
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case',choices=previous.CASES,required=True)
    p.add_argument('--mode',choices=('daily','subdaily','monthly','terminal','perstep'),required=True)
    p.add_argument('--format',type=int,choices=(1,2,3),default=3)
    p.add_argument('--days',type=int,choices=(5,35,1096),default=5)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
           parameters={key:str(value) if isinstance(value,Path) else value for key,value in vars(a).items()},
           functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',public_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        q['fixture']=fixture(a.case,a.output/'input',a.mode,a.format,3 if a.mode=='subdaily' else 1)
        project=m.e.load(a.output/'input',original_output=True);build=a.build_root/a.case
        q.update(input_root=str(a.output/'input'),build_root=str(build),output_selection=original_output.selection(project));save()
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,
                 '--experimental-project',project.input_directory,'--original-output','--reference-work',str(a.reference_work),
                 '--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        start=time.monotonic();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
        (a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr)
        q['build']=dict(command=command,returncode=r.returncode,seconds=time.monotonic()-start);save();r.check_returncode()
        windows=[(2,4)]
        if a.days>=35:windows += [(14,17),(30,35)]
        if a.days==1096:windows += [(363,367),(530,532),(1094,1096)]
        full=a.output/'trajectory'
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,a.days,{a.days,*(x for pair in windows for x in pair)},240)
        q['cold']=[];save()
        for low,high in windows:
            q['cold'].append(own(build,a.reference_work,project,full,data,low,high,a.output/f'cold-{low}'));save()
        q.update(status='ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS',
                 maximum_surface_cm=max(abs(row['surfacewater']['independent_surface_residual_cm']) for row in data),
                 maximum_combined_cm=max(abs(row['surfacewater']['independent_combined_residual_cm']) for row in data))
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],a.case,a.mode,a.optimization,a.days,flush=True)


if __name__=='__main__':main()
