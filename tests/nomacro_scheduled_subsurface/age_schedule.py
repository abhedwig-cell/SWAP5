"""Actual original monthly/explicit-date age output and complete native004."""
import argparse
from datetime import date,timedelta
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import zipfile
import age_calendar as c

m=c.m


def fixture(path,kind,mode):
    c.fixture(path,kind,3,0)
    control=path/'swap.swp';text=control.read_text(encoding='cp1252')
    for key,value in [('SWMONTH',int(mode=='monthly')),('PERIOD',7 if mode=='combined' else 0),('SWODAT',int(mode!='monthly'))]:
        text,n=re.subn(r'(?mi)^([ \t]*'+key+r'[ \t]*=)[^!\r\n]*',lambda match:match[1]+' '+str(value),text);assert n==1
    if mode!='monthly':
        text,n=re.subn(r'(?mi)^([ \t]*OUTDATINT[ \t]*=[ \t]*\n).*?^\* End of table',
            lambda match:match[1]+'2002-01-04\n2002-01-08\n2002-01-31\n2003-01-01\n2003-06-15\n2004-12-31\n* End of table',text,count=1,flags=re.S);assert n==1
    control.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    def cold():return m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project)
    result,seconds=m.bounded(45,cold);assert result['first_refusal'] is None
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    first=date.fromisoformat(project.start_date);lo=str(first+timedelta(days=start));hi=str(first+timedelta(days=end))
    for name in ('result_output.csv','result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv','result.ageeffluentwater.csv'):
        selected=lambda path:[line for line in c.records(path) if lo<=line.split(',')[0].strip()<hi]
        assert selected(out/'original'/name)==selected(full/'original'/name),name
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==b'S5AGE004'
        for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_sparse_five_csv=True,exact_complete_native=True,origin_unchanged=True,seconds=seconds)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--mode',choices=('monthly','explicit','combined'),required=True)
    p.add_argument('--kind',choices=('plain','surface','subsurface-interval'),required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--phase',choices=('short','full'),required=True)
    a=p.parse_args();out=a.output
    if a.phase=='short':out.mkdir();fixture(out/'input',a.kind,a.mode)
    project=m.e.load(out/'input');build=out/'build';path=out/'RESULT.json'
    report=json.loads(path.read_text()) if path.exists() else dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),kind=a.kind,mode=a.mode,optimization=a.optimization,input_path=str(out/'input'),whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10)
    def save():path.write_text(json.dumps(report,indent=2)+'\n')
    try:
        if a.phase=='short':
            cmd=[sys.executable,'-B',str(c.f.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(out/'input'),'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            t=time.monotonic();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/'build.log').write_text(r.stdout+r.stderr);report['build_seconds']=time.monotonic()-t;save();assert r.returncode==0,r.stderr
        meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['conserved_original_age']['native_codec']=='S5AGE004'
        last=45 if a.phase=='short' else 1096;windows=[(1,4),(3,6),(4,8),(30,34)]
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        cuts={1,2,3,4,6,7,8,9,10,30,31,32,34,40,45}|{v for w in windows for v in w}
        full=out/a.phase;result,data=m.trajectory(build,a.reference_work,project,full,last,cuts,90)
        result['output']=c.output_values(full/'original',data,project)
        result['own']=[own(build,a.reference_work,project,full,data,s,e,out/(a.phase+'-own'+str(s))) for s,e in windows]
        result['maximum_age_tolerance_fraction']=max(abs(row[k])/row['age_tolerance_cm_day'] for row in data for k in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day'))
        assert result['maximum_age_tolerance_fraction']<=1
        report[a.phase]=result;report['status']='ORIGINAL_AGE_SCHEDULE_'+a.phase.upper()+'_SOURCE_OUTPUT_NATIVE_PASS';save();print(report['status'],a.mode,a.kind,a.optimization,flush=True)
    except Exception as error:report.update(status='FAILED',error=repr(error));save();raise


if __name__=='__main__':main()
