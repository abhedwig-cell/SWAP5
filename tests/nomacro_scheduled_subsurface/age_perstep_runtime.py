"""Actual original AGE per-step composition and independent cold processes."""
import argparse,csv,json,re,struct,subprocess,sys,time,zipfile
from pathlib import Path
from datetime import date,datetime,timedelta
import age_fixed as fixed
from age_clock import original_timestamp
from original_output_baseline import assignment
from original_output_files import records,compare
from age_perstep_output import metadata,magic

m=fixed.m;ROOT=fixed.ROOT


def calendar(raw,n):
    candidates=[];start=raw.find(struct.pack('<3i',1,n,1))
    while start>=0:
        if start+160<=len(raw):
            h=struct.unpack_from('<20i',raw,start);nr=h[3]
            if nr>100 and start+160+16*nr<len(raw) and h==struct.unpack_from('<20i',raw,start+80):candidates.append((start,h,nr))
        start=raw.find(struct.pack('<3i',1,n,1),start+1)
    assert len(candidates)==1,candidates
    return candidates[0]


def age_outputs(full,data,project):
    # Original FLPRINTDT selects SoilWaterOutput short events; Solute(3) is
    # reached only through flOutput, including the actual final TEND event.
    names=('result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv','result.ageeffluentwater.csv')
    lines={name:records(full/'original'/name) for name in names}
    days={name:[int(next(csv.reader([v]))[2]) for v in values] for name,values in lines.items()}
    expected=[len(data)] if date.fromisoformat(project.start_date)+timedelta(days=len(data)-1)==date.fromisoformat(project.end_date) else []
    assert all(values==expected for values in days.values()),days
    rounded=lambda v:float(format(v,'.3E'))
    for index,day in enumerate(expected):
        a,w,d=[next(csv.reader([lines[name][index]])) for name in names[1:]];values=data[day-1]['age_effluent']
        assert list(map(float,a[4:]))==list(map(rounded,values[16:]))
        assert list(map(float,w[3:]))==list(map(rounded,values[:8]))
        assert list(map(float,d[3:]))==list(map(rounded,values[3:8]))
    return dict(actual_global_days=days,original_floutput_tend_age_cadence_retained=True,actual_written_means_and_volumes_match_full_precision_probe=True)


def fixture(path,mode,hysteresis,fmt,reset,npd,source):
    fixed.fixture(path,{'point':'subsurface','interval':'subsurface-interval'}.get(source,source),initial=100.)
    p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    if not re.search(r'(?mi)^\s*FLPRINTDT\s*=',text):text+='\nFLPRINTDT = .FALSE.\n'
    for key,value in dict(SWHYST=hysteresis,SWHEA=1,SWCALT=2,SWBOTB=8 if hysteresis==2 else 5,SWBBCFILE=0,SWMONTH=int(mode=='monthly'),SWODAT=int(mode=='explicit'),PERIOD=0 if mode in ('monthly','explicit','terminal') else 5,SWRES=reset,NPRINTDAY=npd,SWCSV=fmt,FLPRINTDT='.TRUE.').items():text=assignment(text,key,value)
    if mode=='explicit':
        text,count=re.subn(r'(?mi)^([ \t]*OUTDATINT[ \t]*=[ \t]*\n).*?^\* End of table',lambda match:match[1]+'2002-01-04\n2002-01-08\n2002-01-31\n2003-01-01\n2003-06-15\n2004-12-31\n* End of table',text,count=1,flags=re.S);assert count==1
    p.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source);origin=out.with_name(out.name+'-origin')
    receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==magic(project)
        for name in ('result.end','macro.bin'):assert a.read(name)==b.read(name),name
    output=compare(full/'original',out/'original',metadata(project),start,end,project.start_date)
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=output,origin_unchanged=True,seconds=seconds)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--mode',choices=('monthly','explicit','periodic','terminal'),default='explicit');p.add_argument('--hysteresis',type=int,choices=(0,1,2),default=0)
    p.add_argument('--format',type=int,choices=(0,1,2,3),default=3);p.add_argument('--reset',type=int,choices=(0,1),default=1);p.add_argument('--nprintday',type=int,default=1)
    p.add_argument('--source',choices=('point','interval','surface','sprinkler'),default='point');p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--phase',choices=('short','full','limit'),default='short');p.add_argument('--reuse-build',type=Path);p.add_argument('--existing-input',type=Path)
    a=p.parse_args();out=a.output.resolve();out.mkdir();inputs=a.existing_input or out/'input'
    if not a.existing_input:
        fixture(inputs,a.mode,a.hysteresis,a.format,a.reset,a.nprintday,a.source)
        if a.phase=='limit':
            path=inputs/'fixed-irrigation.irg';s=path.read_text(encoding='cp1252');assert s.count('2002-01-05')==1;path.write_text(s.replace('2002-01-05','2002-01-01'),encoding='cp1252')
    project=m.e.load(inputs,original_output=True);build=a.reuse_build or out/'build';q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),parameters={k:str(v) if isinstance(v,Path) else v for k,v in vars(a).items()},input_root=str(inputs),build_root=str(build),original_output=metadata(project),whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        if not a.reuse_build:
            t=time.perf_counter();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);q.update(build_returncode=r.returncode,build_seconds=time.perf_counter()-t);(out/'build.stdout').write_text(r.stdout,encoding='utf8');(out/'build.stderr').write_text(r.stderr,encoding='utf8');save();r.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['conserved_original_age']['native_codec']==magic(project).decode()
        last={'short':35,'full':1096,'limit':2}[a.phase];windows=[(1,2)] if a.phase=='limit' else [(2,4),(4,8),(19,23),(30,34)]
        if a.phase=='full':windows.extend([(199,201),(364,367),(530,532),(1094,1096)])
        cuts={last,*(v for pair in windows for v in pair)};full=out/'trajectory';q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,last,cuts,120);save()
        q['age_output']=age_outputs(full,data,project);q['cold']=[own(build,a.reference_work,project,full,data,s,e,out/f'own-{s}') for s,e in windows];save()
        q['actual_fixed_input_cm']=sum(row['external_flux_cm'][3]+row['external_flux_cm'][5] for row in data);assert abs(q['actual_fixed_input_cm']-2.4)<=1e-10;save()
        q['maximum_age_tolerance_fraction']=max(abs(row[k])/row['age_tolerance_cm_day'] for row in data for k in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day'));assert q['maximum_age_tolerance_fraction']<=1
        assert all(row['age_state_cm_day'][5]==0 for row in data)
        q['status']='ACTUAL_AGE_PERSTEP_'+a.phase.upper()+'_SOURCE_NATIVE_OUTPUT_PASS';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
