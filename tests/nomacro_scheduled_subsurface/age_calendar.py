"""Real non-daily age output, daily source receipts and exact calendar restart."""
import argparse
from datetime import date,timedelta
import csv
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import zipfile
import age_fixed as f
from age_reference import fixture as plain_fixture

m=f.m


def fixture(path,kind,period,swres):
    if kind=='plain':plain_fixture(path,100.)
    else:f.fixture(path,kind,initial=100.)
    control=path/'swap.swp';text=control.read_text(encoding='cp1252')
    for key,value in [('PERIOD',period),('NPRINTDAY',1),('SWRES',swres)]:
        text,n=re.subn(r'(?mi)^([ \t]*'+key+r'[ \t]*=)[^\r\n!]*',lambda match:match[1]+' '+str(value),text);assert n==1,key
    control.write_text(text,encoding='cp1252')


def records(path):
    return [line for line in m.csvlines(path) if re.match(r'\d{4}-\d{2}-\d{2}',line.strip())]


def output_values(directory,data,project):
    first=date.fromisoformat(project.start_date);profiles=records(directory/'result.ageProfile.csv');means=records(directory/'result.ageeffluent.csv');water=records(directory/'result.ageeffluentwater.csv');drain=records(directory/'result.ageeffluentqdrain.csv')
    dates=lambda lines:[r.split(',')[0].strip() for r in lines]
    assert dates(profiles)==dates(means)==dates(water)==dates(drain)
    assert 0<len(profiles)<len(data),'original output cadence was forced to daily'
    rounded=lambda value:float(format(value,'.3E'))
    for age_line,water_line,drain_line in zip(means,water,drain):
        a,w,d=[next(csv.reader([line])) for line in (age_line,water_line,drain_line)]
        day=(date.fromisoformat(a[0].strip())-first).days+1;row=data[day-1];values=row['age_effluent']
        assert int(a[2])==day,'original global output day clock differs'
        assert list(map(float,a[4:]))==list(map(rounded,values[16:])),('age means',day)
        assert list(map(float,w[3:]))==list(map(rounded,values[:8])),('age export volumes',day)
        assert list(map(float,d[3:]))==list(map(rounded,values[3:8])),('drain volumes',day)
    return dict(actual_dates=dates(profiles),original_sparse_cadence_retained=True,all_means_and_volumes_match_actual_daily_probe=True)


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    def cold():return m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project)
    result,seconds=m.bounded(45,cold);assert result['first_refusal'] is None
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    first=date.fromisoformat(project.start_date);lo=str(first+timedelta(days=start));hi=str(first+timedelta(days=end))
    for name in ('result_output.csv','result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv','result.ageeffluentwater.csv'):
        selected=lambda path:[line for line in records(path) if lo<=line.split(',')[0].strip()<hi]
        assert selected(out/'original'/name)==selected(full/'original'/name),name
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==b'S5AGE003'
        for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_sparse_five_csv=True,exact_complete_native=True,origin_unchanged=True,seconds=seconds)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--kind',choices=('plain','surface','subsurface-interval'),required=True);p.add_argument('--period',type=int,choices=(3,7),required=True)
    p.add_argument('--swres',type=int,choices=(0,1),default=0);p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--phase',choices=('short','full'),required=True);p.add_argument('--reuse-build',type=Path);p.add_argument('--existing-input',type=Path)
    a=p.parse_args();out=a.output
    if a.phase=='short':out.mkdir()
    inputs=a.existing_input or out/'input'
    if a.phase=='short' and not a.existing_input:fixture(inputs,a.kind,a.period,a.swres)
    project=m.e.load(inputs);build=a.reuse_build or out/'build';path=out/'RESULT.json'
    report=json.loads(path.read_text()) if path.exists() else dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),kind=a.kind,period=a.period,swres=a.swres,optimization=a.optimization,input_path=str(inputs),whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10)
    def save():path.write_text(json.dumps(report,indent=2)+'\n')
    try:
        if a.phase=='short' and not a.reuse_build:
            cmd=[sys.executable,'-B',str(f.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            t=time.monotonic();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/'build.log').write_text(r.stdout+r.stderr);report['build_seconds']=time.monotonic()-t;save();assert r.returncode==0,r.stderr
        meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['conserved_original_age']['native_codec']=='S5AGE003'
        last=10 if a.phase=='short' else 1096;cuts={1,2,3,4,6,7,8,9,10}
        if a.phase=='full':cuts|={199,201,364,365,366,367,530,532,1094,1096}
        full=out/a.phase;result,data=m.trajectory(build,a.reference_work,project,full,last,cuts,90)
        result['output']=output_values(full/'original',data,project)
        windows=((1,4),(3,6),(4,8)) if a.phase=='short' else ((1,4),(3,6),(4,8),(199,201),(364,367),(530,532),(1094,1096))
        result['own']=[own(build,a.reference_work,project,full,data,s,e,out/(a.phase+'-own'+str(s))) for s,e in windows]
        result['maximum_age_tolerance_fraction']=max(abs(row[k])/row['age_tolerance_cm_day'] for row in data for k in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day'))
        assert result['maximum_age_tolerance_fraction']<=1
        report[a.phase]=result;report['status']='REGULAR_AGE_CALENDAR_'+a.phase.upper()+'_SOURCE_OUTPUT_NATIVE_PASS';save();print(report['status'],a.kind,a.period,a.swres,a.optimization,flush=True)
    except Exception as error:report.update(status='FAILED',error=repr(error));save();raise


if __name__=='__main__':main()
