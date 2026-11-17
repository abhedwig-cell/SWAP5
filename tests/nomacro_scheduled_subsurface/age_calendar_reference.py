"""Actual corrected original periodic output with real daily observation owner."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import time
import age_calendar as c

ROOT=c.f.ROOT
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import age_output_calendar as calendar
from original_pond_budget import render as pond_source
spec=importlib.util.spec_from_file_location('original_age',ROOT/'reference/swap-4.3.1/patches/NOMACRO-AGE-SOURCE-01/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def packets(stdout):
    current={};rows=[];initial=None
    for line in stdout.splitlines():
        if line.startswith('AGE_CUMULATIVE ') and initial is None:initial=list(map(float,line.split()[1:]))
        for tag in ('HYBRID_STOCK_FLUX','HYBRID_EXTERNAL_FLUX','HYBRID_AGE_CUMULATIVE','HYBRID_AGE_EFFLUENT'):
            if line.startswith(tag+' '):current[tag]=list(map(float,line.split()[1:]))
        if line.startswith('AGE_DAILY_RECEIPT '):
            parts=line.split();day=int(parts[1]);assert day==len(rows)+1
            assert len(current)==4
            rows.append(dict(day=day,age_effluent=current['HYBRID_AGE_EFFLUENT'],age_state_cm_day=current['HYBRID_AGE_CUMULATIVE'],stocks=current['HYBRID_STOCK_FLUX'],flow=current['HYBRID_EXTERNAL_FLUX']))
    assert len(rows)==1096 and initial is not None
    return initial,rows


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','matrix','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();provider=a.reference_work/'build';objects=provider/'swap-obj';ttutil=provider/'ttutil-obj'
    matrix=json.loads((a.matrix/'RESULT.json').read_text());project=c.m.e.load(Path(next(iter(matrix['profiles'].values()))['input_path']))
    report=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles={},builds={},events=[],whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    def call(cmd,where,label):
        t=time.monotonic();p=subprocess.run(list(map(str,cmd)),cwd=where,capture_output=True,text=True,timeout=90)
        (where/(label+'.stdout')).write_text(p.stdout);(where/(label+'.stderr')).write_text(p.stderr)
        report['events'].append(dict(command=list(map(str,cmd)),returncode=p.returncode,seconds=time.monotonic()-t));save();return p
    try:
        for opt in ('O0','O2'):
            build=a.output/opt;build.mkdir();source={
                calendar.PROVIDER+'.f90':(ROOT/'src/process'/(calendar.PROVIDER+'.f90')).read_bytes(),
                'hybrid_age_output_state.f90':calendar.state_source(project).encode('cp1252'),
                'integral.f90':calendar.render_integral((provider/'swap-selected/integral.f90').read_text(encoding='cp1252')).encode('cp1252'),
                'solute.f90':r.s.source((provider/'swap-selected/solute.f90').read_bytes(),effluent=True),
                'swap.f90':calendar.render_swap((provider/'swap-selected/swap.f90').read_text(encoding='cp1252')).encode('cp1252'),
                'age_output_calendar_probe.f90':calendar.PROBE.encode('cp1252'),
                'swap_csv_output.f90':r.s.csv_source((provider/'swap-selected/swap_csv_output.f90').read_bytes()),
                'boundtop.f90':pond_source((provider/'swap-selected/boundtop.f90').read_text(encoding='cp1252')).encode('cp1252')}
            for name in (*r.s.PROVIDERS,*r.s.OUTPUT_PROVIDERS):source[name+'.f90']=(ROOT/'src/process'/(name+'.f90')).read_bytes()
            order=[calendar.PROVIDER,'hybrid_age_output_state','integral',*r.s.PROVIDERS,*r.s.OUTPUT_PROVIDERS,'solute','age_output_calendar_probe','swap','swap_csv_output','boundtop']
            flags=['-'+opt,'-std=legacy','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=bounds','-ffp-contract=off','-march=x86-64','-mtune=generic','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(ttutil)]
            for name,raw in source.items():(build/name).write_bytes(raw)
            for name in order:
                result=call(['gfortran',*flags,'-c',build/(name+'.f90'),'-o',build/(name+'.o')],build,name+'-compile');assert result.returncode==0,result.stderr
            replaced={'integral.o','solute.o','swap.o','swap_csv_output.o','boundtop.o'};linked=[p for p in sorted(objects.glob('*.o')) if p.name not in replaced]+[build/(name+'.o') for name in order]
            exe=build/'swap_age_calendar.exe';result=call(['gfortran','-o',exe,*linked,ttutil/'libttutil.a'],build,'link');assert result.returncode==0,result.stderr
            report['builds'][opt]=dict(executable_sha256=sha(exe),generated_sha256={name:sha(build/name) for name in source},flags=flags);save()
            for name,parent in matrix['profiles'].items():
                if parent['optimization']!=opt:continue
                case=a.output/name;shutil.copytree(Path(parent['input_path']),case);inputs={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
                result=call([exe,'./swap.swp'],case,'reference');assert result.returncode in (0,100) and (case/'swap.ok').exists(),result.stderr
                initial,data=packets(result.stdout)
                age_stdout='\n'.join('AGE_CUMULATIVE '+' '.join(map(repr,v)) for v in [initial,*[row['age_state_cm_day'] for row in data]])
                budget=r.validate(age_stdout);budget['output']=c.output_values(case,data,c.m.e.load(Path(parent['input_path'])))
                errors=[]
                for row in data:
                    stock,flow=row['stocks'],row['flow'];delta=math.fsum([*stock[:6],*[-v for v in stock[6:]]]);external=math.fsum([*[flow[i] for i in (0,3,4,5,6)],*[-flow[i] for i in range(7,16)]])
                    errors.append(abs(math.fsum([delta,-external])))
                budget.update(input_sha256=inputs,executable_sha256=sha(exe),maximum_observed_water_residual_cm=max(errors),original_water_balance_status='PASS' if max(errors)<=1e-10 else 'NOT_QUALIFIED',whole_scientific_equivalence='NOT_QUALIFIED')
                (case/'daily-observation.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in data));report['profiles'][name]=budget;save();print(name,'ORIGINAL_PERIODIC_AGE_FULL_LEDGER_OUTPUT_PASS',flush=True)
        report['status']='FOURTEEN_ORIGINAL_PERIODIC_AGE_FULL_SOURCE_LEDGER_OUTPUT_EXECUTIONS_PASS'
    except Exception as error:report.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
