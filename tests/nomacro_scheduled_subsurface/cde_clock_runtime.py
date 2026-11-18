"""Actual original CDE clock/private-state and independent chemical cold workers."""
import argparse,json,math,struct,subprocess,sys,time,zipfile
from datetime import date,datetime,timedelta
from pathlib import Path
import cde_interval_runtime as interval
from cde_clock_output import metadata,selection,magic
from cde_native_receipt import decode as native_stock
from original_output_files import compare,records
from thermal_step_runtime import audit_soil

m=interval.m;ROOT=interval.ROOT;calendar=interval.calendar;audit_daily=interval.audit_daily


def fixture(path,mode,hysteresis,fmt,reset,et,snow,source,rain,nprintday,perstep):
    interval.fixture(path,mode,hysteresis,fmt,reset,et,snow,source,rain)
    p=path/'swap.swp';s=interval.assignment(p.read_text(encoding='cp1252'),'NPRINTDAY',nprintday)
    p.write_text(interval.assignment(s,'FLPRINTDT','.TRUE.' if perstep else '.FALSE.'),encoding='cp1252')


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
    audit_daily(out,end-start,project.nodes)
    if selection(project)['swsnow']:audit_soil(out,end-start)
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,origin_unchanged=True,seconds=seconds)


def timestamp(stamp):
    d,t=stamp.split();hour,minute,second=map(int,t.split(':'));assert 0<=hour<24 and 0<=minute<60 and 0<=second<=60
    return datetime.fromisoformat(d)+timedelta(hours=hour,minutes=minute,seconds=second)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--mode',choices=('monthly','explicit','periodic','terminal'),required=True)
    p.add_argument('--hysteresis',choices=(0,1,2),type=int,default=2);p.add_argument('--format',choices=(0,1,2,3),type=int,default=3)
    p.add_argument('--reset',choices=(0,1),type=int,default=1);p.add_argument('--et',choices=(0,1),type=int,default=0)
    p.add_argument('--snow',choices=(0,1),type=int,default=0);p.add_argument('--source',choices=('point','interval','sprinkler','surface'),default='point');p.add_argument('--rain',type=float)
    p.add_argument('--nprintday',type=int,default=2);p.add_argument('--perstep',action='store_true')
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--phase',choices=('short','full','limit'),default='short')
    p.add_argument('--reuse-build',type=Path);p.add_argument('--existing-input',type=Path)
    a=p.parse_args();out=a.output.resolve();out.mkdir();inputs=a.existing_input or out/'input'
    if not a.existing_input:
        fixture(inputs,a.mode,a.hysteresis,a.format,a.reset,a.et,a.snow,a.source,a.rain,a.nprintday,a.perstep)
        if a.phase=='limit':
            p=inputs/'fixed-irrigation.irg';s=p.read_text(encoding='cp1252');assert s.count('2002-01-05')==s.count('2002-01-07')==1
            p.write_text(s.replace('2002-01-05','2002-01-01').replace('2002-01-07','2002-01-02'),encoding='cp1252')
    project=m.e.load(inputs,original_output=True);build=a.reuse_build or out/'build';selected=metadata(project)
    assert selected['cde_clock_output'] is True and selected['native_codec']==magic(project).decode()
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        nprintday=a.nprintday,perstep=a.perstep,snow=a.snow,source=a.source,rain=a.rain,mode=a.mode,hysteresis=a.hysteresis,format=a.format,reset=a.reset,et=a.et,optimization=a.optimization,input_root=str(inputs),build_root=str(build),
        original_output=selected,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--original-output',
            '--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
        if not a.reuse_build:
            start=time.perf_counter();r=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180)
            (out/'build.stdout').write_text(r.stdout,encoding='utf8');(out/'build.stderr').write_text(r.stderr,encoding='utf8');q['build']=dict(returncode=r.returncode,seconds=time.perf_counter()-start);save();r.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project)
        assert meta['identity']['original_output']==selected and all('-'+a.optimization in meta['identity'][key] for key in ('donor_flags','kernel_flags'))
        days={'short':35,'full':1096,'limit':2}[a.phase];windows=[(1,2)] if days==2 else [(2,4),(4,8),(19,23),(30,34)]
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        cuts={v for pair in windows for v in pair}|{days};full=out/'trajectory'
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,days,cuts,180);save()
        assert interval.controls((full/'original/swap.swp').read_text(encoding='cp1252'))==interval.controls((inputs/'swap.swp').read_text(encoding='cp1252'));q['requested_controls_preserved']=True
        q['daily_chemical_receipts']=audit_daily(full,days,project.nodes)
        if a.snow:q['soil_receipts']=audit_soil(full,days)
        q['cold']=[own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in windows]
        source_days=(0,1) if days==2 else (4,6);q['actual_fixed_incoming_mg_cm2']=[data[d]['solute_ledger_mg_cm2'][3] for d in source_days]
        assert all(abs(x-y)<=1e-10 for x,y in zip(q['actual_fixed_incoming_mg_cm2'],[48.,72.]))
        q['actual_rain_chemical_mg_cm2']=sum(row['solute_ledger_mg_cm2'][2] for row in data)
        if a.rain is not None and a.rain>0:assert q['actual_rain_chemical_mg_cm2']>0
        q['native_domains']={}
        for day in sorted(cuts):
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as cp:
                raw=cp.read('macro.bin');assert raw[:8]==magic(project);pos,h,nr=calendar(raw,project.nodes);size=20+project.nodes;offset=pos+160+16*nr
                assert struct.unpack_from('<3i',raw,offset)==struct.unpack_from('<3i',raw,offset+12)==(2,project.nodes,size)
                first=raw[offset+24:offset+24+8*size];assert first==raw[offset+24+8*size:];values=struct.unpack('<'+str(size)+'d',first)
                assert all(map(math.isfinite,values)) and values[0]>=0 and values[-2]>=0;actual=native_stock(raw,project.nodes)
                assert actual==data[day-1]['solute_end_mg_cm2'] and actual-values[-2]==values[14]
                assert (h[4],h[5],h[6],h[11],h[18],h[19])==(1,a.nprintday,day,selected['swres'],1,int(a.perstep))
                q['native_domains'][str(day)]=dict(calendar_offset=pos,calendar_header=list(h),cde_state_offset=offset,cde_state_values=list(values),actual_native_stock_mg_cm2=actual,actual_private_interval_anchor=values[-2],actual_private_rounderr=values[-1])
        files=sorted((full/'original').glob('result_output.*'));q['user_output']={}
        for path in files:
            values=records(path);stamps=[row[:19].decode('ascii').strip() if isinstance(row,bytes) else row.split(',')[0].strip() for row in values]
            decoded=[timestamp(stamp) for stamp in stamps];assert decoded==sorted(decoded) and decoded[0]==datetime.fromisoformat(project.start_date)
            assert decoded[-1]<=datetime.fromisoformat(project.start_date)+timedelta(days=days)
            if a.phase=='full':assert decoded[-1]==datetime.fromisoformat(project.end_date)+timedelta(days=1)
            q['user_output'][path.name]=dict(records=len(values),stamps=stamps)
        if not a.format:assert not files
        q['status']='ACTUAL_CDE_CLOCK_'+a.phase.upper()+'_NATIVE_USER_OUTPUT_PASS';print(q['status'],a.optimization,a.nprintday,a.perstep,flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
