"""Actual groundwater water calendar/carry composition and complete cold state."""
import argparse,json,subprocess,sys,time,zipfile
from pathlib import Path
import implicit_conductivity_runtime as previous
from original_output_baseline import assignment
from original_output_files import compare
from groundwater_water_output import metadata
from implicit_groundwater_state import validate_candidate,domain

m=previous.m;ROOT=previous.ROOT


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source);origin=out.with_name(out.name+'-origin')
    receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        for name in ('result.end','macro.bin'):assert a.read(name)==b.read(name),name
        validate_candidate(a.read('macro.bin'),data[end-1],project)
    outputs=compare(full/'original',out/'original',metadata(project),start,end,project.start_date);assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_original_output=outputs,seconds=seconds,origin_unchanged=True)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--implicit',type=int,choices=(0,1),required=True)
    p.add_argument('--hysteresis',type=int,choices=(0,1,2),required=True);p.add_argument('--perstep',action='store_true')
    p.add_argument('--mode',choices=('explicit','periodic','monthly','terminal'),default='periodic');p.add_argument('--format',type=int,choices=(0,1,2,3),default=3)
    p.add_argument('--reset',type=int,choices=(0,1),default=1);p.add_argument('--nprintday',type=int,default=1);p.add_argument('--drainage',type=int,choices=(0,1),default=1)
    p.add_argument('--phase',choices=('short','full','limit'),default='short');p.add_argument('--reuse-build',type=Path);p.add_argument('--existing-input',type=Path)
    a=p.parse_args();out=a.output.resolve();out.mkdir();inputs=a.existing_input or out/'input'
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),parameters={k:str(v) if isinstance(v,Path) else v for k,v in vars(a).items()},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        if not a.existing_input:
            previous.fixture(inputs,0,a.hysteresis,1,a.perstep,2,a.mode,a.format,a.reset,a.nprintday)
            path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
            for key,value in dict(SWKIMPL=a.implicit,SWDRA=a.drainage).items():text=assignment(text,key,value)
            path.write_text(text,encoding='cp1252')
        project=m.e.load(inputs,original_output=True);build=a.reuse_build or out/'build';q.update(input_root=str(inputs),build_root=str(build),native_domain=domain(project))
        if not a.reuse_build:
            cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            t=time.monotonic();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);q['build']=dict(returncode=r.returncode,seconds=time.monotonic()-t)
            (out/'build.stdout').write_text(r.stdout,encoding='utf8');(out/'build.stderr').write_text(r.stderr,encoding='utf8');save();r.check_returncode()
        m.validate_bundle(build,a.reference_work,project)
        days={'short':35,'full':1096,'limit':2}[a.phase];windows=[(1,2)] if a.phase=='limit' else [(2,4),(7,9),(30,34)]
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        full=out/'trajectory';q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,days,{days,*(v for pair in windows for v in pair)},180);save();q['cold']=[]
        for start,end in windows:q['cold'].append(own(build,a.reference_work,project,full,data,start,end,out/f'own-{start}'));save()
        q['status']='ACTUAL_GROUNDWATER_WATER_'+a.phase.upper()+'_COMPLETE_CALENDAR_NATIVE_PASS';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
