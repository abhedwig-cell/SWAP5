"""Real original AGE/prescribed groundwater production and complete cold state."""
import argparse,json,re,subprocess,sys,time,zipfile
from pathlib import Path
import age_perstep_runtime as age
from original_output_baseline import assignment
from original_output_files import compare
from age_groundwater_output import metadata,magic,validate_candidate

m=age.m;ROOT=age.ROOT
calendar=age.calendar


def fixture(path,hysteresis,step,mode,fmt,reset,npd,drainage):
    age.fixture(path,mode,hysteresis,fmt,reset,npd,'point')
    p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    for key,value in dict(SWBOTB=1,SWBBCFILE=0,SWDRA=drainage,FLPRINTDT='.TRUE.' if step else '.FALSE.').items():text=assignment(text,key,value)
    table='2002-01-01 -95.0\n2002-01-04 -65.0\n2002-01-07 -115.0\n2002-01-10 -85.0\n2004-12-31 -85.0\n'
    text,count=re.subn(r'(?mi)^([ \t]*DATE1[ \t]+GWLEVEL[^\r\n]*\n).*?^\* End of table',lambda match:match[1]+table+'* End of table',text,count=1,flags=re.S);assert count==1
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
        validate_candidate(a.read('macro.bin'),data[end-1],project)
    outputs=compare(full/'original',out/'original',metadata(project),start,end,project.start_date);assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_original_output=outputs,seconds=seconds,origin_unchanged=True)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--hysteresis',type=int,choices=(0,1,2),required=True)
    p.add_argument('--perstep',action='store_true');p.add_argument('--mode',choices=('monthly','explicit','periodic','terminal'),default='periodic')
    p.add_argument('--format',type=int,choices=(0,1,2,3),default=3);p.add_argument('--reset',type=int,choices=(0,1),default=0);p.add_argument('--nprintday',type=int,default=1)
    p.add_argument('--drainage',type=int,choices=(0,1),default=1);p.add_argument('--phase',choices=('short','full','limit'),default='short')
    a=p.parse_args();out=a.output.resolve();out.mkdir();inputs=out/'input';fixture(inputs,a.hysteresis,a.perstep,a.mode,a.format,a.reset,a.nprintday,a.drainage)
    if a.phase=='limit':
        p=inputs/'fixed-irrigation.irg';text=p.read_text(encoding='cp1252');assert text.count('2002-01-05')==1;p.write_text(text.replace('2002-01-05','2002-01-01'),encoding='cp1252')
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),parameters={k:str(v) if isinstance(v,Path) else v for k,v in vars(a).items()},whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        project=m.e.load(inputs,original_output=True);q['original_output']=metadata(project);build=out/'build'
        cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        t=time.perf_counter();result=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);q['build']=dict(returncode=result.returncode,seconds=time.perf_counter()-t);(out/'build.stdout').write_text(result.stdout,encoding='utf8');(out/'build.stderr').write_text(result.stderr,encoding='utf8');save();result.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['conserved_original_age']['native_codec']==magic(project).decode()
        last={'short':35,'full':1096,'limit':2}[a.phase];windows=[(1,2)] if a.phase=='limit' else [(2,4),(7,9),(30,34)]
        if a.phase=='full':windows.extend([(199,201),(364,367),(530,532),(1094,1096)])
        full=out/'trajectory';q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,last,{last,*(v for pair in windows for v in pair)},180);save()
        for day in {last,*(v for pair in windows for v in pair)}:
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as z:validate_candidate(z.read('macro.bin'),data[day-1],project)
        q['cold']=[own(build,a.reference_work,project,full,data,s,t,out/f'own-{s}') for s,t in windows]
        q['actual_fixed_input_cm']=sum(row['external_flux_cm'][3]+row['external_flux_cm'][5] for row in data);assert abs(q['actual_fixed_input_cm']-2.4)<=1e-10
        q['actual_bottom_outward_range_cm']=[min(row['bottom_outward_cm'] for row in data),max(row['bottom_outward_cm'] for row in data)]
        q['maximum_age_tolerance_fraction']=max(abs(row[k])/row['age_tolerance_cm_day'] for row in data for k in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day'));assert q['maximum_age_tolerance_fraction']<=1
        q['status']='ACTUAL_ORIGINAL_AGE_GROUNDWATER_'+a.phase.upper()+'_PHYSICAL_NATIVE_OUTPUT_PASS';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
