"""Actual original prescribed groundwater CDE and complete native cold workers."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import zipfile
import original_output_matrix as original
from original_output_baseline import assignment
from original_output_files import compare

m=original.m;ROOT=original.ROOT


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project)
    source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    origin=out.with_name(out.name+'-origin')
    receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,
        checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,
        checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    from groundwater_native import magic
    from original_output import selection
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==magic(project)
        for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
    files=compare(full/'original',out/'original',selection(project) or dict(flprintdt=False,nprintday=1),start,end,project.start_date)
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,
                origin_unchanged=True,seconds=seconds)


def fixture(path,kind,fmt=3):
    original.fixture(path,'cde-solbal-csv3')
    control=path/'swap.swp';text=control.read_text(encoding='cp1252')
    for key,value in dict(SWBOTB=1,SWBBCFILE=0,SWHYST=0,SWSNOW=0,SWFROST=0,SWBR=0,SWBOTBC=1,SWCSV=fmt).items():
        text=assignment(text,key,value)
    levels={'within':[("2002-01-01",-95.),("2004-12-31",-95.)],
            'below':[("2002-01-01",-1000.),("2004-12-31",-1000.)],
            'crossing':[("2002-01-01",-95.),("2002-01-04",-65.),("2002-01-07",-115.),
                        ("2002-01-10",-85.),("2004-12-31",-85.)]}[kind]
    table=''.join(f'{day} {level:.8f}\n' for day,level in levels)
    text,count=re.subn(r'(?mi)^([ \t]*DATE1[ \t]+GWLEVEL[^\r\n]*\n).*?^\* End of table',
                       lambda match:match[1]+table+'* End of table',text,count=1,flags=re.S)
    assert count==1
    control.write_text(text,encoding='cp1252')


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    parser.add_argument('--kind',choices=('within','below','crossing'),required=True)
    parser.add_argument('--phase',choices=('short','full'),default='short')
    parser.add_argument('--reuse-build',type=Path)
    parser.add_argument('--existing-input',type=Path)
    parser.add_argument('--format',choices=(0,1,2,3),type=int,default=3)
    parser.add_argument('--compatibility-output',action='store_true')
    args=parser.parse_args();out=args.output.resolve();out.mkdir();inputs=out/'input'
    inputs=args.existing_input or inputs
    if not args.existing_input:fixture(inputs,args.kind,args.format)
    project=m.e.load(inputs,original_output=not args.compatibility_output);build=args.reuse_build or out/'build'
    record=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                kind=args.kind,optimization=args.optimization,build_root=str(build),input_root=str(inputs),
                original_output=project.original_output,format=args.format,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    save()
    try:
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,
                 '--reference-work',args.reference_work,'--build-only','--donor-opt',args.optimization,
                 '--kernel-opt',args.optimization,'--output',build]
        if project.original_output:command+=['--original-output']
        if not args.reuse_build:
            start=time.perf_counter();compiled=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180)
            (out/'build.stdout').write_text(compiled.stdout,encoding='utf8');(out/'build.stderr').write_text(compiled.stderr,encoding='utf8')
            record['build']=dict(returncode=compiled.returncode,seconds=time.perf_counter()-start);save();compiled.check_returncode()
        else:m.validate_bundle(build,args.reference_work,project)
        days=1096 if args.phase=='full' else 10
        windows=[(2,4),(7,9)]
        if args.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        cuts={i for pair in windows for i in pair}|{days}
        full=out/'trajectory';record['trajectory'],data=m.trajectory(build,args.reference_work,project,full,days,cuts,180);save()
        record['cold']=[own(build,args.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in windows]
        record['status']='ACTUAL_PRESCRIBED_GROUNDWATER_CDE_'+args.phase.upper()+'_NATIVE_USER_FILES_PASS'
        print(args.kind,args.optimization,record['status'],flush=True)
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
