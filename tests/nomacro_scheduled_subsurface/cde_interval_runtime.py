"""Actual CDE ordinary/Snow non-daily state, observed daily flux and cold workers."""
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
import ordinary_reset_runtime as ordinary_audit
import thermal_step_runtime as snow_audit
from original_output_baseline import assignment,controls
from original_output_files import compare,records
from cde_interval_output import metadata,selection,magic
from cde_native_receipt import decode as native_stock

m=prior.m;ROOT=prior.ROOT


def fixture(path,mode,hysteresis,fmt,reset=1,et=0,snow=0,source='point'):
    prior.fixture(path,'chemical-snow-'+source,fmt)
    p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    for key,value in dict(SWSNOW=snow,SWHYST=hysteresis,SWMONTH=int(mode=='monthly'),SWODAT=int(mode=='explicit'),PERIOD=0 if mode in ('monthly','explicit','terminal') else 5,
            SWRES=reset,SWCFBS=et,SWBOTB=8 if hysteresis==2 else 5,SWBBCFILE=0,NPRINTDAY=1).items():text=assignment(text,key,value)
    if et:text=assignment(text,'CFBS',0.8)
    if mode=='explicit':
        text,count=re.subn(r'(?mi)^([ \t]*OUTDATINT[ \t]*=[ \t]*\n).*?^\* End of table',
            lambda match:match[1]+'2002-01-04\n2002-01-08\n2002-01-31\n2003-01-01\n2003-06-15\n2004-12-31\n* End of table',text,count=1,flags=re.S);assert count==1
    text=assignment(text,'FLPRINTDT','.FALSE.') if re.search(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=',text) else text+'\nFLPRINTDT = .FALSE.\n'
    p.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,
        checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==magic(project)
        for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
    files=compare(full/'original',out/'original',selection(project),start,end,project.start_date)
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,origin_unchanged=True,seconds=seconds)



def calendar(raw,n):
    positions=[];prefix=struct.pack('<2i',1,n);start=raw.find(prefix);trailer=24+16*(20+n)
    while start>=0:
        if start+160<=len(raw):
            header=struct.unpack_from('<20i',raw,start);nreal=header[3]
            if nreal>100 and start+160+16*nreal+trailer==len(raw) and header==struct.unpack_from('<20i',raw,start+80):positions.append((start,header,nreal))
        start=raw.find(prefix,start+1)
    assert len(positions)==1,positions
    return positions[0]


def audit_daily(path,days,nodes):
    import math
    values=[];counts=[]
    for line in (path/'original/donor.stdout').read_text(encoding='utf8').splitlines():
        if line.startswith('CDE_INTERVAL_DAILY_AUDIT '):
            row=list(map(float,line.split()[1:]));assert len(row)==17 and all(map(math.isfinite,row))
            residual=math.fsum([row[1],-row[0],*(-v for v in row[2:5]),*row[5:8]])
            assert abs(residual)<=1e-10 and abs(row[8])<=1e-10 and abs(residual-row[8])<=1e-13,(row,residual)
            values.append(row)
        if line.startswith('CDE_INTERVAL_INCREMENT_COUNTS '):
            row=list(map(int,line.split()[1:]));assert len(row)==6 and all(v>0 for v in row)
            assert row[1]>=row[0] and row[3]==row[4]==row[5]==nodes*row[2],row;counts.append(row)
    assert len(values)==len(counts)==days,(len(values),len(counts),days)
    data=m.rows(path)
    for index,(value,row) in enumerate(zip(values,data)):
        ledger=row['solute_ledger_mg_cm2']
        assert value[0]==row['solute_start_mg_cm2'] and value[1]==row['solute_end_mg_cm2']
        assert value[2:8]==ledger[2:8] and value[8]==ledger[8],index
    return dict(actual_days=days,actual_rows=values,actual_increment_counts=counts)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--mode',choices=('monthly','explicit','periodic','terminal'),required=True)
    p.add_argument('--hysteresis',choices=(0,1,2),type=int,default=2)
    p.add_argument('--format',choices=(0,1,2,3),type=int,default=3)
    p.add_argument('--reset',choices=(0,1),type=int,default=1);p.add_argument('--et',choices=(0,1),type=int,default=0)
    p.add_argument('--snow',type=int,choices=(0,1),default=0);p.add_argument('--source',choices=('point','interval'),default='point')
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--phase',choices=('short','full'),default='short');p.add_argument('--reuse-build',type=Path);p.add_argument('--existing-input',type=Path)
    a=p.parse_args();out=a.output.resolve();out.mkdir();inputs=a.existing_input or out/'input'
    if not a.existing_input:fixture(inputs,a.mode,a.hysteresis,a.format,a.reset,a.et,a.snow,a.source)
    project=m.e.load(inputs,original_output=True);build=a.reuse_build or out/'build';selected=metadata(project)
    assert selected['cde_interval_output'] is True and selected['native_codec']==magic(project).decode()
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        nprintday=1,snow=a.snow,source=a.source,mode=a.mode,hysteresis=a.hysteresis,format=a.format,reset=a.reset,et=a.et,optimization=a.optimization,input_root=str(inputs),build_root=str(build),
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
        days=1096 if a.phase=='full' else 35
        windows=[(2,4),(4,8),(19,23),(30,34)] if days>=35 else [(1,days)]
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        cuts={v for pair in windows for v in pair}|{days};full=out/'trajectory'
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,days,cuts,180);save()
        assert controls((full/'original/swap.swp').read_text(encoding='cp1252'))==controls((inputs/'swap.swp').read_text(encoding='cp1252'))
        q['requested_controls_preserved']=True
        q['cold']=[own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in windows]
        q['daily_chemical_receipts']=audit_daily(full,days,project.nodes)
        for start,end in windows:audit_daily(out/('own-'+str(start)),end-start,project.nodes)
        assert abs(data[4]['solute_ledger_mg_cm2'][3]-48.)<=1e-10 and abs(data[6]['solute_ledger_mg_cm2'][3]-72.)<=1e-10
        q['actual_fixed_incoming_mg_cm2']=[data[4]['solute_ledger_mg_cm2'][3],data[6]['solute_ledger_mg_cm2'][3]]
        q['native_domains']={}
        for day in sorted({2,4,8,days}&cuts):
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as checkpoint:
                raw=checkpoint.read('macro.bin');assert raw[:8]==magic(project)
                if a.snow:
                    domain=struct.pack('<10i',1,project.nodes,0,1,a.hysteresis,1,0,1,1,2);assert raw.count(domain+domain)==1
                    snow_header=struct.pack('<4i',1,project.nodes,1,7);assert raw.count(snow_header+snow_header)==1;snow_pos=raw.index(snow_header+snow_header)
                    snow_values=struct.unpack_from('<7d',raw,snow_pos+32);assert all(v>=0 for v in snow_values)
                else:
                    snow_values=None
                    if a.hysteresis:
                        domain=struct.pack('<5i',1,project.nodes,0,a.hysteresis,1);assert raw.count(domain+domain)==1
                offset,header,_=calendar(raw,project.nodes)
                n=20+project.nodes;cp=offset+160+16*header[3]
                assert struct.unpack_from('<3i',raw,cp)==struct.unpack_from('<3i',raw,cp+12)==(2,project.nodes,n)
                first=raw[cp+24:cp+24+8*n];assert first==raw[cp+24+8*n:];values=struct.unpack('<'+str(n)+'d',first)
                import math
                assert all(map(math.isfinite,values)) and values[0]>=0 and values[-2]>=0
                actual=native_stock(raw,project.nodes);assert actual==data[day-1]['solute_end_mg_cm2'] and actual-values[-2]==values[14]
                assert (header[4],header[5],header[6],header[8],header[11],header[18],header[19])==(selected['period'],1,day,1,selected['swres'],0,0)
                q['native_domains'][str(day)]=dict(domain_bytes=80 if a.snow else 40 if a.hysteresis else 0,calendar_offset=offset,global_day=day,period_counter=header[7],
                    cde_state_offset=cp,cde_state_values=list(values),actual_native_stock_mg_cm2=actual,actual_private_interval_anchor=values[-2],actual_private_rounderr=values[-1],
                    snow_output_values=list(snow_values) if snow_values is not None else None)
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
        q['status']='ACTUAL_CDE_INTERVAL_'+a.phase.upper()+'_NATIVE_USER_OUTPUT_PASS'
        print(a.mode,a.hysteresis,a.optimization,q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
