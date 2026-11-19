"""Actual original AGE per-step composition and independent cold processes."""
import argparse,json,re,subprocess,sys,time,zipfile
from pathlib import Path
from datetime import date,datetime,timedelta
import age_fixed as fixed
from age_runtime import output_values as age_outputs
from age_clock import original_timestamp
from original_output_baseline import assignment
from original_output_files import records
from age_perstep_output import metadata,magic

m=fixed.m;ROOT=fixed.ROOT


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
    low=datetime.fromisoformat(project.start_date)+timedelta(days=start);high=datetime.fromisoformat(project.start_date)+timedelta(days=end)
    selected=metadata(project);output={}
    if selected['swcsv']:
        name={1:'result_output.csv',2:'result_output.csv',3:'result_output.bin'}[selected['swcsv']]
        warm=records(full/'original'/name);cold=records(out/'original'/name)
        def stamp(v):return original_timestamp(v[:19].decode('ascii').strip() if isinstance(v,bytes) else v.split(',')[0].strip())
        expected=[v for v in warm[1:] if low<stamp(v)<=high];assert cold[1:]==expected,name
        output[name]=dict(exact=True,continuation_records=len(expected))
    lo=low.date().isoformat();hi=high.date().isoformat()
    for name in ('result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv','result.ageeffluentwater.csv'):
        def selected_lines(path):return [v for v in m.csvlines(path) if lo<=v.split(',')[0].strip()[:10]<hi]
        assert selected_lines(out/'original'/name)==selected_lines(full/'original'/name),name
        output[name]=dict(exact=True,continuation_records=len(selected_lines(out/'original'/name)))
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=output,origin_unchanged=True,seconds=seconds)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--mode',choices=('monthly','explicit','periodic','terminal'),default='explicit');p.add_argument('--hysteresis',type=int,choices=(0,1,2),default=0)
    p.add_argument('--format',type=int,choices=(0,1,2,3),default=3);p.add_argument('--reset',type=int,choices=(0,1),default=1);p.add_argument('--nprintday',type=int,default=1)
    p.add_argument('--source',choices=('point','interval','surface','sprinkler'),default='point');p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir();inputs=out/'input';fixture(inputs,a.mode,a.hysteresis,a.format,a.reset,a.nprintday,a.source)
    project=m.e.load(inputs,original_output=True);build=out/'build';q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),parameters=vars(a)|dict(output=str(out),reference_work=str(a.reference_work)),original_output=metadata(project),whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        t=time.perf_counter();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);q.update(build_returncode=r.returncode,build_seconds=time.perf_counter()-t);(out/'build.stdout').write_text(r.stdout,encoding='utf8');(out/'build.stderr').write_text(r.stderr,encoding='utf8');save();r.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['conserved_original_age']['native_codec']==magic(project).decode()
        full=out/'trajectory';q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,35,{2,4,8,30,34,35},90);save()
        q['age_output']=age_outputs(full,data);q['cold']=[own(build,a.reference_work,project,full,data,s,e,out/f'own-{s}') for s,e in ((2,4),(4,8),(30,34))]
        q['maximum_age_tolerance_fraction']=max(abs(row[k])/row['age_tolerance_cm_day'] for row in data for k in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day'));assert q['maximum_age_tolerance_fraction']<=1
        assert all(row['age_state_cm_day'][5]==0 for row in data)
        q['status']='ACTUAL_AGE_PERSTEP_SHORT_SOURCE_NATIVE_OUTPUT_PASS';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
