"""Actual original prescribed groundwater CDE and complete native cold workers."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import original_output_matrix as original
from original_output_baseline import assignment

m=original.m;ROOT=original.ROOT


def fixture(path,kind):
    original.fixture(path,'cde-solbal-csv3')
    control=path/'swap.swp';text=control.read_text(encoding='cp1252')
    for key,value in dict(SWBOTB=1,SWBBCFILE=0,SWHYST=0,SWSNOW=0,SWFROST=0,SWBR=0,SWBOTBC=1).items():
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
    args=parser.parse_args();out=args.output.resolve();out.mkdir();inputs=out/'input'
    fixture(inputs,args.kind)
    project=m.e.load(inputs,original_output=True);build=out/'build'
    record=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                kind=args.kind,optimization=args.optimization,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    save()
    try:
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,
                 '--original-output','--reference-work',args.reference_work,'--build-only','--donor-opt',args.optimization,
                 '--kernel-opt',args.optimization,'--output',build]
        start=time.perf_counter();compiled=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180)
        (out/'build.stdout').write_text(compiled.stdout,encoding='utf8');(out/'build.stderr').write_text(compiled.stderr,encoding='utf8')
        record['build']=dict(returncode=compiled.returncode,seconds=time.perf_counter()-start);save();compiled.check_returncode()
        days=1096 if args.phase=='full' else 10
        windows=[(2,4),(7,9)]
        if args.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        cuts={i for pair in windows for i in pair}|{days}
        full=out/'trajectory';record['trajectory'],data=m.trajectory(build,args.reference_work,project,full,days,cuts,180);save()
        record['cold']=[original.own(build,args.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in windows]
        record['status']='ACTUAL_PRESCRIBED_GROUNDWATER_CDE_'+args.phase.upper()+'_NATIVE_USER_FILES_PASS'
        print(args.kind,args.optimization,record['status'],flush=True)
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
