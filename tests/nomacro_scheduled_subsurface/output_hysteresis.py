"""Original output and complete actual hysteresis carry on the real host."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import time
import zipfile
import output_hysteresis_baseline as baseline
from original_output_files import compare
from original_output_hysteresis import metadata,magic

m=baseline.m
ROOT=baseline.ROOT


def fixture(path,kind,mode,fmt,calendar):
    baseline.fixture(path,kind,mode);p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    groups="'WATBAL,GWL,SOLBAL,S_CONC,Q'" if kind=='cde' else "'WATBAL,GWL'"
    for key,value in [('SWCSV',fmt),('INLIST_CSV',groups),('NPRINTDAY',3 if calendar=='np3' else 1),('SWMONTH',int('monthly' in calendar))]:text=baseline.original.baseline.assignment(text,key,value)
    if calendar=='perstep-monthly':text+='\nFLPRINTDT = .TRUE.\n'
    p.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source);origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project));assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==magic(project)
        for name in ('result.end','macro.bin'):assert a.read(name)==b.read(name),name
    files=compare(full/'original',out/'original',metadata(project),start,end,project.start_date);assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,origin_unchanged=True,seconds=seconds)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--kind',choices=('water','cde','age'),required=True);p.add_argument('--hysteresis-mode',choices=(1,2),type=int,required=True);p.add_argument('--output-format',choices=(0,1,2,3),type=int,required=True);p.add_argument('--calendar',choices=('daily','np3','monthly','perstep-monthly'),default='daily');p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--phase',choices=('short','full'),default='short');p.add_argument('--existing-input',type=Path);p.add_argument('--reuse-build',type=Path);p.add_argument('--baseline-root',type=Path)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();inputs=a.existing_input or a.output/'input'
    if not a.existing_input:fixture(inputs,a.kind,a.hysteresis_mode,a.output_format,a.calendar)
    project=m.e.load(inputs,original_output=True);selected=metadata(project);build=a.reuse_build or a.output/'build'
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),kind=a.kind,hysteresis_mode=a.hysteresis_mode,output_format=a.output_format,calendar=a.calendar,optimization=a.optimization,original_output=selected,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        if not a.reuse_build:
            start=time.monotonic();command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--original-output','--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
            r=subprocess.run(list(map(str,command)),capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(returncode=r.returncode,seconds=time.monotonic()-start);save();assert r.returncode==0,r.stderr
        meta,_=m.validate_bundle(build,a.reference_work,project);assert meta['identity']['original_output']==selected
        days=1096 if a.phase=='full' else 35 if 'monthly' in a.calendar else 10
        windows=[(2,4),(4,8)]
        if 'monthly' in a.calendar:windows.append((30,34))
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        cuts={2,4,8,days}|{n for pair in windows for n in pair};full=a.output/'trajectory';result,data=m.trajectory(build,a.reference_work,project,full,days,cuts,150);q['trajectory']=result;save()
        header=struct.pack('<5i',1,project.nodes,0,a.hysteresis_mode,{'water':0,'cde':1,'age':2}[a.kind]);states={};domains={}
        for day in (2,4,8,days):
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as z:
                raw=z.read('macro.bin');assert raw[:8]==magic(project);assert raw.count(header+header)==1
                pos=raw.index(header+header);assert pos>=48;states[str(day)]=baseline.history(z.read('result.end'));domains[str(day)]=dict(offset=pos,exact_actual_flags=True,bytes=40)
        assert all(s['mode']==a.hysteresis_mode for s in states.values());assert any(any(v!=(1 if a.hysteresis_mode==1 else -1) for v in s['index']) or any(v!=1 for v in s['fhyst']) for s in states.values())
        q['actual_hysteresis_history']=states;q['native_domains']=domains
        if a.kind=='cde':
            assert abs(data[4]['solute_ledger_mg_cm2'][3]-48)<=1e-10
            with zipfile.ZipFile(full/'accepted-column-1-day-4.zip') as z:
                conserved=struct.unpack_from('<'+str(project.nodes+2)+'d',z.read('macro.bin'),48);assert all(v>=0 for v in conserved)
            q['active_chemical_source_mg_cm2']=data[4]['solute_ledger_mg_cm2'][3];q['conserved_cde_prefix_at48']=True
        if a.baseline_root and a.calendar=='daily' and a.phase=='short':
            old=a.baseline_root/(a.kind+'-hys'+str(a.hysteresis_mode))/'trajectory';previous=m.rows(old);assert m.physical(data)==m.physical(previous)
            q['existing_compatibility_physical_exact']=True
        q['own']=[own(build,a.reference_work,project,full,data,s,e,a.output/('own-'+str(s))) for s,e in windows]
        q['status']='ORIGINAL_OUTPUT_HYSTERESIS_'+a.phase.upper()+'_SOURCE_NATIVE_PASS';save();print(q['status'],a.kind,a.hysteresis_mode,a.output_format,a.calendar,a.optimization,flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
