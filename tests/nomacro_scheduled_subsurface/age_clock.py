"""Real annual/subdaily age clocks, original file cadence and exact native005."""
import argparse
from datetime import date,datetime,timedelta
import csv
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
import zipfile
import age_calendar as c
from age_runtime import output_values as daily_age_values

m=c.m


def fixture(path,kind,mode,nprint):
    c.fixture(path,kind,1 if mode=='subdaily' else 0,0)
    control=path/'swap.swp';text=control.read_text(encoding='cp1252')
    text,count=re.subn(r'(?mi)^([ \t]*NPRINTDAY[ \t]*=)[^!\r\n]*',lambda match:match[1]+' '+str(nprint),text);assert count==1
    control.write_text(text,encoding='cp1252')


def output_values(full,data,project,mode,nprint):
    if mode=='annual':return c.output_values(full/'original',data,project)
    result=daily_age_values(full,data);first=date.fromisoformat(project.start_date)
    profiles=c.records(full/'original/result.ageProfile.csv');assert len(profiles)==len(data)
    assert [line.split(',')[0].strip() for line in profiles]==[str(first+timedelta(days=i)) for i in range(len(data))]
    primary=c.records(full/'original/result_output.csv');assert len(primary)==nprint*len(data)+1
    stamps=[datetime.fromisoformat(next(csv.reader([line]))[0].strip()) for line in primary]
    start=datetime.combine(first,datetime.min.time())
    assert stamps==[start+timedelta(hours=24*i/nprint) for i in range(len(primary))]
    final=full/f"accepted-column-1-day-{data[-1]['day']}.zip"
    with zipfile.ZipFile(final) as z:
        raw=z.read('macro.bin');assert raw[:8]==b'S5AGE005'
        saved_output_period=struct.unpack_from('<d',raw,len(raw)-16)[0]
        assert saved_output_period==1./nprint
    result.update(original_primary_subdaily_and_age_daily_cadences_retained=True,primary_rows=len(primary),
                  age_profile_rows=len(profiles),actual_final_age_output_interval_days=saved_output_period,
                  age_output_interval='original output interval sampled by the actual age writer at day end')
    return result


def own(build,reference,project,full,data,start,end,out,mode):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    def cold():return m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project)
    result,seconds=m.bounded(45,cold);assert result['first_refusal'] is None
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    first=date.fromisoformat(project.start_date);lo=first+timedelta(days=start);hi=first+timedelta(days=end)
    for name in ('result_output.csv','result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv','result.ageeffluentwater.csv'):
        def selected(path):
            lines=c.records(path)
            if name=='result_output.csv' and mode=='subdaily':
                low=datetime.combine(lo,datetime.min.time());high=datetime.combine(hi,datetime.min.time())
                return [line for line in lines if low<datetime.fromisoformat(next(csv.reader([line]))[0].strip())<=high]
            return [line for line in lines if str(lo)<=line.split(',')[0].strip()[:10]<str(hi)]
        assert selected(out/'original'/name)==selected(full/'original'/name),name
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==b'S5AGE005'
        for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_original_five_csv=True,exact_complete_native=True,origin_unchanged=True,seconds=seconds)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--mode',choices=('subdaily','annual'),required=True);p.add_argument('--nprint',type=int,choices=(1,2,3),required=True)
    p.add_argument('--kind',choices=('plain','surface','subsurface-interval'),required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--phase',choices=('short','full'),required=True)
    a=p.parse_args();assert (a.nprint==1)==(a.mode=='annual');out=a.output
    if a.phase=='short':out.mkdir();fixture(out/'input',a.kind,a.mode,a.nprint)
    project=m.e.load(out/'input');build=out/'build';path=out/'RESULT.json'
    report=json.loads(path.read_text()) if path.exists() else dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),kind=a.kind,mode=a.mode,nprint=a.nprint,optimization=a.optimization,input_path=str(out/'input'),whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10)
    def save():path.write_text(json.dumps(report,indent=2)+'\n')
    try:
        if a.phase=='short':
            cmd=[sys.executable,'-B',str(c.f.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(out/'input'),'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            t=time.monotonic();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/'build.log').write_text(r.stdout+r.stderr);report['build_seconds']=time.monotonic()-t;save();assert r.returncode==0,r.stderr
        meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['conserved_original_age']['native_codec']=='S5AGE005'
        last=(10 if a.mode=='subdaily' else 371) if a.phase=='short' else 1096
        windows=[(1,4),(3,6),(4,8)]
        if a.mode=='annual' or a.phase=='full':windows += [(364,367)]
        if a.phase=='full':windows += [(30,34),(199,201),(530,532),(1094,1096)]
        cuts={1,2,3,4,6,7,8,9,10,last}|{v for w in windows for v in w}
        full=out/a.phase;result,data=m.trajectory(build,a.reference_work,project,full,last,cuts,90)
        result['output']=output_values(full,data,project,a.mode,a.nprint)
        result['own']=[own(build,a.reference_work,project,full,data,s,e,out/(a.phase+'-own'+str(s)),a.mode) for s,e in windows]
        result['maximum_age_tolerance_fraction']=max(abs(row[k])/row['age_tolerance_cm_day'] for row in data for k in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day'))
        assert result['maximum_age_tolerance_fraction']<=1
        report[a.phase]=result;report['status']='ORIGINAL_AGE_OUTPUT_CLOCK_'+a.phase.upper()+'_SOURCE_OUTPUT_NATIVE_PASS';save();print(report['status'],a.mode,a.nprint,a.kind,a.optimization,flush=True)
    except Exception as error:report.update(status='FAILED',error=repr(error));save();raise
    finally:save()


if __name__=='__main__':main()
