"""Actual direct soil age source across calendar/output/hysteresis domains."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import time
import zipfile
import re
import age_fixed as fixed
from original_output_files import compare
from age_direct_soil_source import metadata,magic,output_metadata
from age_irrigation_source import base_magic,LAYOUTS
from direct_soil_age import ledger as direct_ledger

m=fixed.m
ROOT=fixed.ROOT


def fixture(path,kind,age,calendar,fmt,hysteresis,events='single',inline=False):
    fixed.fixture(path,kind,inline=inline);p=path/'swap.swp' if inline else path/'fixed-irrigation.irg';text=p.read_text(encoding='cp1252');assert '2002-01-05 24.0 0.0' in text
    text=text.replace('2002-01-05 24.0 0.0','2002-01-05 24.0 '+str(age))
    if events=='varying':
        code=2 if kind.startswith('subsurface') else 1 if kind=='surface' else 0
        first='2002-01-05 24.0 '+str(age)+' '+str(code)+' 12.0'
        assert text.count(first)==1
        extra='\n'.join(date+' '+str(depth)+' '+str(value)+' '+str(code)+' '+str(rate) for date,depth,value,rate in [('2002-01-07',12.,60.,12.),('2003-01-01',8.,10.,4.),('2003-06-15',6.,100.,6.),('2004-12-30',4.,35.,4.)])
        text=text.replace(first,first+'\n'+extra,1)
    p.write_text(text,encoding='cp1252')
    p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    from original_output_baseline import assignment
    for key,value in [('SWCSV',fmt),('SWHYST',hysteresis),('PERIOD',7 if calendar=='regular' else 0 if calendar=='annual' else 1),('NPRINTDAY',3 if calendar=='np3' else 1),('SWMONTH',int('monthly' in calendar)),('SWRES',0)]:text=assignment(text,key,value)
    if calendar=='perstep-monthly':text+='\nFLPRINTDT = .TRUE.\n'
    p.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out,resume=False):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    if resume and out.exists():
        assert len(m.rows(out))==end-start;seconds=None
    else:
        origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
        result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project));assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as x,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as y:
        assert x.read('macro.bin')[:8]==magic(project)
        for member in ('result.end','macro.bin'):assert x.read(member)==y.read(member),member
    selected=output_metadata(project)
    if selected is None:
        values=re.findall(r'(?mi)^\s*NPRINTDAY\s*=\s*(\d+)\s*(?:!.*)?$',(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252'));assert len(values)==1
        selected=dict(nprintday=int(values[0]),flprintdt=False)
    files=compare(full/'original',out/'original',selected,start,end,project.start_date);assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,origin_unchanged=True,seconds=seconds)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--kind',choices=('surface','sprinkler','subsurface','subsurface-interval'),required=True);p.add_argument('--age-day',type=float,default=20.)
    p.add_argument('--calendar',choices=('daily','regular','monthly','np3','annual','perstep-monthly'),default='daily');p.add_argument('--format',choices=(0,1,2,3),type=int,default=1);p.add_argument('--hysteresis',choices=(0,1,2),type=int,default=0);p.add_argument('--original-output',action='store_true')
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--phase',choices=('short','full'),default='short');p.add_argument('--existing-input',type=Path);p.add_argument('--reuse-build',type=Path)
    p.add_argument('--events',choices=('single','varying'),default='single');p.add_argument('--inline',action='store_true')
    p.add_argument('--resume',action='store_true')
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume);inputs=a.existing_input or a.output/'input'
    if not a.existing_input and not a.resume:fixture(inputs,a.kind,a.age_day,a.calendar,a.format,a.hysteresis,a.events,a.inline)
    project=m.e.load(inputs,original_output=a.original_output,age_direct_soil_source=True);build=a.reuse_build or a.output/'build'
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),kind=a.kind,age_day=a.age_day,calendar=a.calendar,output_format=a.format,hysteresis=a.hysteresis,original_output=a.original_output,optimization=a.optimization,events=a.events,inline=a.inline,age_direct_soil_source=metadata(project),functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    q.update(build_root=str(build),input_root=str(inputs))
    if a.resume:q['retained_previous_report']=json.loads((a.output/'RESULT.json').read_text())
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        if not a.reuse_build and not a.resume:
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--age-direct-soil-source','--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
            if a.original_output:command+=['--original-output']
            t=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(returncode=r.returncode,seconds=time.monotonic()-t);save();assert r.returncode==0,r.stderr
        meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['original_age_fixed_irrigation']==metadata(project)
        days=1096 if a.phase=='full' else 35 if 'monthly' in a.calendar else 10;windows=[(2,4),(4,8),(6,10)]
        if 'monthly' in a.calendar:windows.append((30,34))
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        full=a.output/'trajectory'
        if a.resume:
            data=m.rows(full);assert len(data)==days;report=q['retained_previous_report']['trajectory'];assert report['build_sha256']==m.sha(build/'BUILD.json');m.check(data)
        else:report,data=m.trajectory(build,a.reference_work,project,full,days,{2,4,8,days}|{n for w in windows for n in w},150)
        q['trajectory']=report;save()
        previous=[data[0]['age_start_cm_day'],0.,data[0]['age_start_cm_day']]+[0.]*9
        for row in data:
            measured=direct_ledger(previous,row['age_state_cm_day'])
            assert all(row[k]==v for k,v in measured.items())
            if a.kind.startswith('subsurface'):assert row['age_state_cm_day'][5]==0.,'Direct input leaked into pond ledger'
            else:assert row['age_state_cm_day'][11]==0.,'Surface input leaked into direct ledger'
            previous=row['age_state_cm_day']
        index=11 if a.kind.startswith('subsurface') else 5
        actual=data[4]['age_state_cm_day'][index]-data[3]['age_state_cm_day'][index];assert abs(actual-2.4*a.age_day)<=1e-10
        q['actual_event_age_cm_day']=actual;q['age_units']='cm day';domains={}
        if a.events=='varying':
            second=data[6]['age_state_cm_day'][index]-data[5]['age_state_cm_day'][index];assert abs(second-72.)<=1e-10
            q['actual_second_age_cm_day']=second
        header=struct.pack('<7i',1,34,0,2,1,a.hysteresis,LAYOUTS[base_magic(project)])
        for day in (2,4,8,days):
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as z:
                raw=z.read('macro.bin');assert raw[:8]==magic(project) and raw[-80:-24]==header+header
                left,cumulative,right=struct.unpack('<2id2i',raw[-24:])[:2],struct.unpack_from('<d',raw,-16)[0],struct.unpack_from('<2i',raw,-8)
                assert left==right==(1,34) and cumulative==data[day-1]['age_state_cm_day'][11]
                domains[str(day)]=dict(exact_actual_flags=True,bytes=80,offset=len(raw)-80,direct_cumulative_cm_day=cumulative)
        q['native_domains']=domains;q['own']=[own(build,a.reference_work,project,full,data,s,e,a.output/('own-'+str(s)),a.resume) for s,e in windows]
        q['status']='DIRECT_SOIL_AGE_SOURCE_'+a.phase.upper()+'_CURRENT_FORCING_NATIVE_OUTPUT_PASS';save();print(q['status'],a.kind,a.age_day,a.calendar,a.optimization,flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
