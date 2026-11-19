"""Actual original output/calendar composed with extended drainage state."""
import argparse
import json
import hashlib
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


def fixture(case,output,mode,fmt,nprint,age=False):
    info=previous.fixture(case,output)
    path=output/'swap.swp';text=path.read_text(encoding='cp1252')
    values=dict(SWCSV=fmt,NPRINTDAY=nprint,SWMONTH=int(mode=='monthly'),
                SWODAT=int(mode in ('explicit','combined')),SWRES=0 if mode in ('terminal','perstep') else 1,
                PERIOD=0 if mode in ('terminal','explicit') else 7 if mode=='combined' else 1,INLIST_CSV="'WATBAL,GWL'",NUM_DECIMALS=12)
    for key,value in values.items():
        text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
    if mode in ('explicit','combined'):
        text,count=re.subn(r'(?mi)^([ \t]*OUTDATINT[ \t]*=[ \t]*\n).*?^\* End of table',
            lambda match:match[1]+'2002-01-04\n2002-01-08\n2002-01-31\n2003-01-01\n2003-06-15\n2004-12-31\n* End of table',text,count=1,flags=re.S)
        assert count==1,'Missing original explicit output date table'
    if age:
        text=assignment(text,'SWSOLU',2)
        def young_water(match):
            names=match[1].split();rows=[]
            for line in match[2].splitlines():
                fields=line.split();assert len(fields)==len(names)
                fields[names.index('IRCONC')]='0.0';rows.append(' '.join(fields))
            return match[1]+'\n'.join(rows)+'\n* End of table'
        text,count=re.subn(r'(?mi)^([ \t]*IRDATE[ \t]+IRDEPTH[^\r\n]*\n)(.*?)^\* End of table',young_water,text,count=1,flags=re.S)
        assert count==1,'Missing original fixed irrigation age boundary'
        text+='\nAGEMLTB =\n -10.0 100.0\n -95.0 100.0\n* End of table\n'
        for crop in output.glob('*.crp'):
            crop.write_text(assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',0),encoding='cp1252')
    text+='\nFLPRINTDT = '+('.TRUE.' if mode=='perstep' else '.FALSE.')+'\n'
    path.write_text(text,encoding='cp1252')
    info['pre_output_input_inventory']=info['inputs']
    info['inputs']={file.name:hashlib.sha256(file.read_bytes()).hexdigest() for file in sorted(output.iterdir()) if file.is_file()}
    return info


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project)
    source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin)
    out.mkdir()
    result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,
        checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,
        checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        for name in ('result.end','macro.bin'):assert a.read(name)==b.read(name),name
    assert m.sha(source)==digest
    result=dict(start=start,end=end,exact_physical=True,exact_complete_native=True,origin_unchanged=True,seconds=seconds)
    result['exact_original_output']=compare(full/'original',out/'original',original_output.selection(project),start,end,project.start_date)
    with zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as z:
        validate_candidate(z.read('macro.bin'),data[end-1],project)
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case',choices=previous.CASES,required=True)
    p.add_argument('--mode',choices=('daily','subdaily','monthly','terminal','perstep','explicit','combined'),required=True)
    p.add_argument('--age',action='store_true')
    p.add_argument('--reuse-build',type=Path)
    p.add_argument('--nprintday',type=int)
    p.add_argument('--format',type=int,choices=(0,1,2,3),default=3)
    p.add_argument('--days',type=int,choices=(2,5,35,1096),default=5)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
           parameters={key:str(value) if isinstance(value,Path) else value for key,value in vars(a).items()},
           functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',public_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        q['fixture']=fixture(a.case,a.output/'input',a.mode,a.format,a.nprintday if a.nprintday is not None else (3 if a.mode=='subdaily' else 1),a.age)
        project=m.e.load(a.output/'input',original_output=True);build=a.reuse_build or a.build_root/a.case
        q.update(input_root=str(a.output/'input'),build_root=str(build),output_selection=original_output.selection(project));save()
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,
                 '--experimental-project',project.input_directory,'--original-output','--reference-work',str(a.reference_work),
                 '--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        if a.reuse_build:
            m.validate_bundle(build,a.reference_work,project)
            q['build']=dict(mode='REUSED_UNCHANGED_ACTUAL_SOURCE_INPUT_BOUND_BUILD',original_build_sha256=m.sha(build/'BUILD.json'),original_build_root=str(build));save()
        else:
            start=time.monotonic();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
            (a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr)
            q['build']=dict(command=command,returncode=r.returncode,seconds=time.monotonic()-start);save();r.check_returncode()
        windows=[(1,2)] if a.days==2 else [(2,4)]
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
