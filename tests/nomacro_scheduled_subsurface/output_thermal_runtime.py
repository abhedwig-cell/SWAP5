"""Actual original snow/thermal output, daily receipt and complete native restart."""
import argparse
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import time
import zipfile
import original_output_matrix as original
from original_output_files import compare
from original_output_thermal import metadata,selection,magic
from original_output_baseline import assignment

m=original.m;ROOT=original.ROOT
KINDS=('water-snow','water-hys1','water-hys2','chemical-snow','water-frost-free','water-frost-drained')


def fixture(path,kind,fmt,groups=None,precision=12):
    if 'frost' in kind:
        import frost_cases;frost_cases.create(path,kind)
    else:
        shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',path)
    p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    changes=dict(SWMACRO=0,SWSOLU=int(kind=='chemical-snow'),SWSNOW=1,SWHEA=1,SWCALT=2,SWBR=0,SWCSV=fmt,NPRINTDAY=1,SWMONTH=0,PERIOD=1,SWODAT=0,SWRES=1)
    if 'frost' not in kind:changes.update(SWFROST=0,SWHYST=1 if kind=='water-hys1' else 2 if kind in ('water-hys2','chemical-snow') else 0)
    if kind in ('water-hys2','chemical-snow'):changes.update(SWBOTB=8,SWBBCFILE=0)
    for key,value in changes.items():text=assignment(text,key,value)
    if kind in ('water-hys2','chemical-snow'):text+='\nHPLATE = -50.0\n'
    text=assignment(text,'INLIST_CSV',repr(groups or 'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'))
    if re.search(r'(?mi)^\s*NUM_DECIMALS\s*=',text):text=assignment(text,'NUM_DECIMALS',precision)
    else:text+='\nNUM_DECIMALS = '+str(precision)+'\n'
    p.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out,resume=False):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    if resume and out.exists():
        seconds=None
    else:
        origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
        result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project))
        assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==magic(project)
        for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
    files=compare(full/'original',out/'original',selection(project),start,end,project.start_date);assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,origin_unchanged=True,seconds=seconds)



def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','output'):ap.add_argument('--'+key,type=Path,required=True)
    ap.add_argument('--kind',choices=KINDS,required=True);ap.add_argument('--format',choices=(0,1,2,3),type=int,default=3)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True);ap.add_argument('--phase',choices=('short','full'),default='short');ap.add_argument('--resume',action='store_true')
    ap.add_argument('--reuse-build',type=Path);ap.add_argument('--existing-input',type=Path);ap.add_argument('--groups');ap.add_argument('--precision',type=int,default=12)
    a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume);inputs=a.existing_input or a.output/'input'
    if not a.resume and not a.existing_input:fixture(inputs,a.kind,a.format,a.groups,a.precision)
    policy='original-adaptive-event-closure-v1' if a.kind=='water-frost-drained' else 'original-adaptive-day-seed-v1'
    project=m.e.load(inputs,original_output=True,time_step_policy=policy);build=a.reuse_build or a.output/'build'
    q=dict(status='RUNNING',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),kind=a.kind,output_format=a.format,optimization=a.optimization,groups=a.groups,precision=a.precision,build_root=str(build),input_root=str(inputs),output=metadata(project),whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    if a.resume:q['retained_previous_report']=json.loads((a.output/'RESULT.json').read_text())
    save()
    try:
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--original-output','--experimental-time-step-policy',policy,'--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
        if not a.resume and not a.reuse_build:
            t=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(returncode=r.returncode,seconds=time.monotonic()-t);save();assert r.returncode==0,r.stderr
        else:m.validate_bundle(build,a.reference_work,project)
        days=1096 if a.phase=='full' else 35;windows=[(2,4),(4,8),(19,23),(30,34)]
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        full=a.output/'trajectory';cuts={2,4,8,days}|{i for w in windows for i in w}
        if a.resume:
            data=m.rows(full);assert len(data)==days;m.check(data);q['trajectory']=q['retained_previous_report']['trajectory'];assert q['trajectory']['build_sha256']==m.sha(build/'BUILD.json')
        else:q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,days,cuts,180)
        q['snow_observation']=dict(maximum_stock_cm=max(row['stock_end_cm'][2] for row in data),snow_rain_cm=sum(row['external_flux_cm'][1] for row in data),gross_snow_cm=sum(row['external_flux_cm'][2] for row in data),sublimation_cm=sum(row['external_flux_cm'][12] for row in data))
        save();q['own']=[own(build,a.reference_work,project,full,data,s,e,a.output/('own-'+str(s)),a.resume) for s,e in windows]
        selected=selection(project);header=struct.pack('<10i',1,project.nodes,0,int(project.solute),selected['swhyst'],1,selected['swfrost'],selected['swdra'],1,2);q['native_domains']={}
        for day in (2,4,8,days):
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as z:
                raw=z.read('macro.bin');assert raw[:8]==magic(project) and raw.count(header+header)==1
                q['native_domains'][str(day)]=dict(bytes=80,actual_domain=True,offset=raw.index(header+header),thermal_history='literalcompleteheacon/heacap/tetop/tebot',placement='aftercompletephysicalbeforecalendar')
        q['status']='ORIGINAL_OUTPUT_THERMAL_'+a.phase.upper()+'_SNOW_COMPOUND_NATIVE_USER_FILES_PASS'
        print(a.kind,a.optimization,q['status'],q['snow_observation'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
