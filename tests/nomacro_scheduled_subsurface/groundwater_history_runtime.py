"""Actual prescribed groundwater CDE hydraulic/snow history composition."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import time
import zipfile
import groundwater_chemical_runtime as prior
from original_output_baseline import assignment
from original_output_files import compare
from groundwater_history_native import metadata,domain,magic

m=prior.m;ROOT=prior.ROOT


def fixture(path,kind,fmt,hys,snow):
    prior.fixture(path,kind,fmt)
    p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    for key,value in dict(SWHYST=hys,SWSNOW=snow,SWHEA=1,SWCALT=2).items():text=assignment(text,key,value)
    p.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,
        checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,
        checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==magic(project)
        for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
    files=compare(full/'original',out/'original',dict(nprintday=1,flprintdt=False),start,end,project.start_date)
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,origin_unchanged=True,seconds=seconds)


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    parser.add_argument('--kind',choices=('within','below','crossing'),default='crossing')
    parser.add_argument('--hysteresis',choices=(0,1,2),type=int,required=True)
    parser.add_argument('--snow',choices=(0,1),type=int,required=True)
    parser.add_argument('--format',choices=(0,1,2,3),type=int,default=3)
    parser.add_argument('--compatibility-output',action='store_true')
    parser.add_argument('--phase',choices=('short','full'),default='short')
    parser.add_argument('--reuse-build',type=Path);parser.add_argument('--existing-input',type=Path)
    args=parser.parse_args();out=args.output.resolve();out.mkdir();inputs=args.existing_input or out/'input'
    assert args.hysteresis or args.snow
    if not args.existing_input:fixture(inputs,args.kind,args.format,args.hysteresis,args.snow)
    project=m.e.load(inputs,original_output=not args.compatibility_output);build=args.reuse_build or out/'build'
    record=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        kind=args.kind,hysteresis=args.hysteresis,snow=args.snow,format=args.format,optimization=args.optimization,
        original_output=project.original_output,input_root=str(inputs),build_root=str(build),native=metadata(project,m.sha,m.h.APP),
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    save()
    try:
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,
            '--reference-work',args.reference_work,'--build-only','--donor-opt',args.optimization,'--kernel-opt',args.optimization,'--output',build]
        if project.original_output:command+=['--original-output']
        if not args.reuse_build:
            start=time.perf_counter();compiled=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180)
            (out/'build.stdout').write_text(compiled.stdout,encoding='utf8');(out/'build.stderr').write_text(compiled.stderr,encoding='utf8')
            record['build']=dict(returncode=compiled.returncode,seconds=time.perf_counter()-start);save();compiled.check_returncode()
        else:m.validate_bundle(build,args.reference_work,project)
        days=1096 if args.phase=='full' else 35;windows=[(2,4),(4,8),(19,23),(30,34)]
        if args.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        cuts={i for w in windows for i in w}|{days};full=out/'trajectory'
        record['trajectory'],data=m.trajectory(build,args.reference_work,project,full,days,cuts,180);save()
        record['cold']=[own(build,args.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in windows]
        header=struct.pack('<13i',*domain(project));record['native_domains']={}
        for day in (2,4,8,days):
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as z:
                raw=z.read('macro.bin');assert raw[:8]==magic(project) and raw.count(header+header)==1
                assert struct.unpack_from('<d',raw,48+8*(project.nodes+1))[0]==data[day-1]['solute_end_mg_cm2']
                record['native_domains'][str(day)]=dict(bytes=104,actual_domain=True,offset=raw.index(header+header))
        record['process_observations']=dict(maximum_snow_cm=max(r['stock_end_cm'][2] for r in data),
            snow_rain_cm=sum(r['external_flux_cm'][1] for r in data),gross_snow_cm=sum(r['external_flux_cm'][2] for r in data),
            sublimation_cm=sum(r['external_flux_cm'][12] for r in data),bottom_min_cm=min(r['bottom_outward_cm'] for r in data),
            bottom_max_cm=max(r['bottom_outward_cm'] for r in data),irrigation_mg_cm2=sum(r['solute_ledger_mg_cm2'][3] for r in data))
        assert record['process_observations']['irrigation_mg_cm2']>0
        if args.snow:assert record['process_observations']['maximum_snow_cm']>0 and record['process_observations']['sublimation_cm']>0
        record['status']='ACTUAL_GROUNDWATER_CDE_HISTORY_'+args.phase.upper()+'_COMPOUND_NATIVE_USER_FILES_PASS'
        print(args.hysteresis,args.snow,args.optimization,record['status'],flush=True)
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
