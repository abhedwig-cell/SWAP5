"""Observe original reader/output controls through the unchanged public route."""
import argparse
from datetime import date,timedelta
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import age_schedule as schedule

ROOT=schedule.c.f.ROOT


def assignment(text,key,value):
    text,count=re.subn(r'(?mi)^([ \t]*'+key+r'[ \t]*=)[^\r\n!]*',lambda match:match[1]+' '+str(value),text)
    assert count==1,key
    return text


def fixture(path,name):
    mode='monthly' if name in ('water-monthly','age-perstep-monthly') else 'explicit' if name=='age-perstep-explicit' else None
    if mode:schedule.fixture(path,'plain',mode)
    else:schedule.c.fixture(path,'plain',1,0)
    p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    if not name.startswith('age-'):text=assignment(text,'SWSOLU',0)
    if name.startswith('water-csv'):text=assignment(text,'SWCSV',int(name[-1]))
    if name=='water-nprint2':text=assignment(text,'NPRINTDAY',2)
    if name=='water-custom-csv5':
        text=assignment(text,'INLIST_CSV',"'GWL'");text=assignment(text,'NUM_DECIMALS',5)
    if 'perstep' in name:text+='\nFLPRINTDT = .TRUE.\n'
    p.write_text(text,encoding='cp1252')


def controls(text):
    keys=('SWSOLU','SWCSV','SWMONTH','SWODAT','PERIOD','NPRINTDAY','NUM_DECIMALS','INLIST_CSV','FLPRINTDT')
    return {key:re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^!\r\n]+)',text) for key in keys}


def outputs(folder):
    result={}
    for p in sorted(folder.glob('*.csv')):
        text=p.read_text(encoding='cp1252');lines=[s.strip() for s in text.splitlines() if s.strip() and not s.lstrip().startswith('*')]
        rows=[s for s in lines if re.match(r'\d{4}-\d{2}-\d{2}',s)]
        result[p.name]=dict(sha256=hashlib.sha256(p.read_bytes()).hexdigest(),rows=len(rows),first_headers=lines[:2],first_data=rows[:2])
    return result


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    q=dict(status='RUNNING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),optimization=a.optimization,cases={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def invoke(cmd,cwd,label,out):
        start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=180)
        (out/(label+'.stdout')).write_text(r.stdout);(out/(label+'.stderr')).write_text(r.stderr)
        return dict(returncode=r.returncode,seconds=time.monotonic()-start,stdout=r.stdout,stderr=r.stderr)
    try:
        for name in ('water-csv0','water-csv2','water-csv3','water-nprint2','water-monthly','water-custom-csv5','age-perstep-monthly','age-perstep-explicit'):
            case=a.output/name;case.mkdir();inputs=case/'input';fixture(inputs,name)
            long=name in ('water-monthly','age-perstep-monthly','age-perstep-explicit');days=35 if long else 4;cut=30 if long else 2;end=34 if long else 4
            r=dict(input_sha256={p.relative_to(inputs).as_posix():sha(p) for p in inputs.rglob('*') if p.is_file()},requested=controls((inputs/'swap.swp').read_text(encoding='cp1252')));q['cases'][name]=r;save()
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model','HYBRID_NOMACRO_WATER','--experimental-project',inputs,'--reference-work',a.reference_work,'--days',str(days),'--checkpoint-at',str(cut),'--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',case/'warm']
            r['public_warm']=invoke(command,ROOT,'public-warm',case)
            actual=case/'warm/original/swap.swp'
            if actual.exists():r['actual_runtime_controls']=controls(actual.read_text(encoding='cp1252'));r['public_outputs']=outputs(actual.parent)
            checkpoint=case/f'warm/accepted-column-1-day-{cut}.zip'
            if r['public_warm']['returncode']==0 and checkpoint.exists():
                cold=command.copy();cold[cold.index('--days')+1]=str(end);cold[cold.index('--checkpoint-at')+1]=str(end);cold[cold.index('--output')+1]=case/'cold'
                cold+=['--build-bundle',case/'warm','--restart',checkpoint,'--restart-day',str(cut)]
                # Public self-build output is its validated bundle; discover its
                # actual location rather than inventing a metadata binding.
                candidates=[p.parent for p in (case/'warm').rglob('BUILD.json') if (p.parent/'day_donor.exe').exists() or (p.parent/'day_donor').exists()]
                if len(candidates)==1:cold[cold.index('--build-bundle')+1]=candidates[0]
                r['public_cold']=invoke(cold,ROOT,'public-cold',case)
            # An unmodified original executable supplies reader/header/cadence
            # observations only. It is not a physical or mass-balance oracle.
            original=case/'original';shutil.copytree(inputs,original);control=original/'swap.swp';text=control.read_text(encoding='cp1252')
            last=str(date(2002,1,1)+timedelta(days=days-1));text,count=re.subn(r'(?mi)^([ \t]*TEND[ \t]*=)[^!\r\n]*',lambda match:match[1]+' '+last,text);assert count==1
            control.write_text(text,encoding='cp1252');exe=a.reference_work/'build/swap_b0_gfortran.exe';r['original_executable_sha256']=sha(exe)
            r['original']=invoke([exe,'./swap.swp'],original,'original',case);r['original']['swap_ok']=(original/'swap.ok').exists();r['original_outputs']=outputs(original);r['original_claim']='READER_AND_OUTPUT_OBSERVATION_ONLY_NOT_SCIENCE'
            save();print(name,a.optimization,'BASELINE_OBSERVED',r['public_warm']['returncode'],r['original']['returncode'],flush=True)
        q['status']='ORIGINAL_OUTPUT_SELECTOR_BASELINE_OBSERVED_NO_NEW_ADMISSION'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
