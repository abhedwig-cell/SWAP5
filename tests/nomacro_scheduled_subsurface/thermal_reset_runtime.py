"""Real original Snow FLPRINTDT date-gated output, soil receipts and cold workers."""
import argparse
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
import zipfile
import output_thermal_runtime as prior
from original_output_baseline import assignment,controls
from original_output_files import compare,records
from thermal_output_reset import metadata,selection,MAGIC

m=prior.m;ROOT=prior.ROOT


def fixture(path,mode,hysteresis,fmt,reset=0,et=0,nprintday=1):
    prior.fixture(path,('water-snow','water-hys1','water-hys2')[hysteresis],fmt)
    p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    for key,value in dict(SWMONTH=int(mode=='monthly'),SWODAT=int(mode=='explicit'),PERIOD=0 if mode in ('monthly','explicit','terminal') else 5,SWRES=reset,SWCFBS=et,
            SWBOTB=8 if hysteresis==2 else 5,SWBBCFILE=0,NPRINTDAY=nprintday).items():
        text=assignment(text,key,value)
    if et:text=assignment(text,'CFBS',0.8)
    if mode=='explicit':
        text,count=re.subn(r'(?mi)^([ \t]*OUTDATINT[ \t]*=[ \t]*\n).*?^\* End of table',
            lambda match:match[1]+'2002-01-04\n2002-01-08\n2002-01-31\n2003-01-01\n2003-06-15\n2004-12-31\n* End of table',text,count=1,flags=re.S)
        assert count==1
    text=assignment(text,'FLPRINTDT','.TRUE.') if re.search(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=',text) else text+'\nFLPRINTDT = .TRUE.\n'
    p.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,
        checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==MAGIC
        for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
    files=compare(full/'original',out/'original',selection(project),start,end,project.start_date)
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,origin_unchanged=True,seconds=seconds)


def audit_soil(path,days):
    import math
    values=[]
    for line in (path/'original/donor.stdout').read_text(encoding='utf8').splitlines():
        if not line.startswith('HYBRID_SNOW_SOIL_RECEIPT '):continue
        row=list(map(float,line.split()[1:]));assert len(row)==29 and all(map(math.isfinite,row))
        residual=math.fsum(row[12:19]+[-x for x in row[19:28]]+row[6:12]+[-x for x in row[:6]])
        assert abs(residual)<=1e-10 and abs(row[-1])<=1e-10,(residual,row)
        assert row[2:6]==[0.0]*4 and row[8:12]==[0.0]*4
        values.append(row)
    assert len(values)==days,(path,len(values),days)
    return dict(actual_days=len(values),maximum_absolute_residual_cm=max(abs(v[-1]) for v in values),actual_rows=values)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--mode',choices=('monthly','explicit','periodic','terminal'),required=True)
    p.add_argument('--hysteresis',choices=(0,1,2),type=int,default=2)
    p.add_argument('--format',choices=(0,1,2,3),type=int,default=3)
    p.add_argument('--reset',choices=(1,),type=int,default=1);p.add_argument('--et',choices=(0,1),type=int,default=0)
    p.add_argument('--nprintday',type=int,choices=(1,),default=1)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--phase',choices=('short','full'),default='short');p.add_argument('--reuse-build',type=Path);p.add_argument('--existing-input',type=Path)
    a=p.parse_args();out=a.output.resolve();out.mkdir();inputs=a.existing_input or out/'input'
    if not a.existing_input:fixture(inputs,a.mode,a.hysteresis,a.format,a.reset,a.et,a.nprintday)
    project=m.e.load(inputs,original_output=True);build=a.reuse_build or out/'build';selected=metadata(project)
    assert selected['thermal_calendar'] is True and selected['native_codec']=='S5SRW001'
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        nprintday=a.nprintday,mode=a.mode,hysteresis=a.hysteresis,format=a.format,reset=a.reset,et=a.et,optimization=a.optimization,input_root=str(inputs),build_root=str(build),
        original_output=selected,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--original-output',
            '--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
        if not a.reuse_build:
            start=time.perf_counter();r=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180)
            (out/'build.stdout').write_text(r.stdout,encoding='utf8');(out/'build.stderr').write_text(r.stderr,encoding='utf8')
            q['build']=dict(returncode=r.returncode,seconds=time.perf_counter()-start);save();r.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project)
        assert meta['identity']['original_output']==selected and all('-'+a.optimization in meta['identity'][key] for key in ('donor_flags','kernel_flags'))
        days=1096 if a.phase=='full' else 35;windows=[(2,4),(4,8),(19,23),(30,34)]
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        cuts={v for pair in windows for v in pair}|{days};full=out/'trajectory'
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,days,cuts,180);save()
        assert controls((full/'original/swap.swp').read_text(encoding='cp1252'))==controls((inputs/'swap.swp').read_text(encoding='cp1252'))
        q['requested_controls_preserved']=True
        q['cold']=[own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in windows]
        q['soil_receipts']=audit_soil(full,days)
        for start,end in windows:audit_soil(out/('own-'+str(start)),end-start)
        q['snow']=dict(maximum_stock_cm=max(r['stock_end_cm'][2] for r in data),sublimation_cm=sum(r['external_flux_cm'][12] for r in data))
        assert q['snow']['maximum_stock_cm']>0 and q['snow']['sublimation_cm']>0
        header=struct.pack('<10i',1,project.nodes,0,0,a.hysteresis,1,0,1,1,2);q['native_domains']={}
        for day in (2,4,8,days):
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as z:
                raw=z.read('macro.bin');assert raw[:8]==MAGIC and raw.count(header+header)==1
                snow_header=struct.pack('<4i',1,project.nodes,0,7);assert raw.count(snow_header+snow_header)==1
                snow_offset=raw.index(snow_header+snow_header)+32;values=struct.unpack_from('<7d',raw,snow_offset)
                assert all(v>=0 for v in values)
                q['native_domains'][str(day)]=dict(bytes=80,actual_domain=True,offset=raw.index(header+header),snow_output_domain_bytes=32,snow_output_values=list(values))
        files=sorted((full/'original').glob('result_output.*'));q['user_output']={}
        for path in files:
            values=records(path)
            stamps=[row[:19].decode('ascii').strip() if isinstance(row,bytes) else row.split(',')[0].strip() for row in values]
            q['user_output'][path.name]=dict(records=len(values),stamps=stamps)
            from datetime import datetime,timedelta
            decoded=[]
            for stamp in stamps:
                day,clock=stamp.split();hour,minute,second=map(int,clock.split(':'))
                assert 0<=hour<24 and 0<=minute<60 and 0<=second<=60,stamp
                decoded.append(datetime.fromisoformat(day)+timedelta(hours=hour,minutes=minute,seconds=second))
            assert decoded==sorted(decoded) and decoded[0]==datetime.fromisoformat(project.start_date)
            if a.phase=='full':assert decoded[-1]==datetime(2005,1,1)
            if a.mode=='monthly':assert len(values)>1,'No actual selected monthly FLPRINTDT record'

        if not a.format:assert not files
        q['status']='ACTUAL_WATER_SNOW_FLPRINTDT_RESET_'+a.phase.upper()+'_NATIVE_USER_OUTPUT_PASS'
        print(a.mode,a.hysteresis,a.optimization,q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
