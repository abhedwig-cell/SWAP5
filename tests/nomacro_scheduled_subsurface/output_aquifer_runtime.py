"""Actual mixed aquifer/output source, compound budgets and complete cold state."""
import argparse
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import time
import zipfile
import original_output_matrix as original
from original_output_files import compare
from original_output_aquifer import metadata,selection,magic

m=original.m;ROOT=original.ROOT
PHYSICS={'soil-transfer':(1.,0.,0.,0.,100.),'box-release':(0.,1.,0.,0.,100.),'sorption-decay':(1.,.25,.2,.001,100.),'stiff-loss':(0.,1.,0.,10.,.1)}


def fixture(path,kind,fmt,hys):
    spec=importlib.util.spec_from_file_location('original_mixed_aquifer_reference',ROOT/'reference/swap-4.3.1/patches/NOMACRO-AQUIFER-SOLUTE-01/run.py')
    ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref);ref.fixture(path,*PHYSICS[kind])
    p=path/'swap.swp';text=p.read_text(encoding='cp1252')
    for key,value in [('SWCSV',fmt),('SWHYST',hys)]:text=ref.assignment(text,key,value)
    p.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
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
    ap.add_argument('--kind',choices=PHYSICS,required=True);ap.add_argument('--format',choices=(0,1,2,3),type=int,default=3);ap.add_argument('--hysteresis',choices=(0,1,2),type=int,default=0)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True);ap.add_argument('--phase',choices=('short','full'),default='short')
    a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir();inputs=a.output/'input';fixture(inputs,a.kind,a.format,a.hysteresis)
    project=m.e.load(inputs,original_output=True);build=a.output/'build';q=dict(status='RUNNING',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),kind=a.kind,output_format=a.format,hysteresis=a.hysteresis,optimization=a.optimization,output=metadata(project),whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--original-output','--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
        t=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(returncode=r.returncode,seconds=time.monotonic()-t);save();assert r.returncode==0,r.stderr
        days=1096 if a.phase=='full' else 10;windows=[(2,4),(4,8),(6,10)]
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        full=a.output/'trajectory';q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,days,{2,4,8,days}|{i for w in windows for i in w},150)
        fields=('aquifer_residual_mg_cm2','aquifer_exchange_residual_mg_cm2','soil_aquifer_residual_mg_cm2');q['maximum_residuals']={k:max(abs(row[k]) for row in data) for k in fields};assert all(v<=1e-10 for v in q['maximum_residuals'].values())
        q['final_aquifer_state']=data[-1]['aquifer_state'];save();q['own']=[own(build,a.reference_work,project,full,data,s,e,a.output/('own-'+str(s))) for s,e in windows]
        header=struct.pack('<7i',1,34,0,1,1,a.hysteresis,1);q['native_domains']={}
        for day in (2,4,8,days):
            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as z:
                raw=z.read('macro.bin');assert raw[:8]==magic(project) and raw.endswith(header+header)
                q['native_domains'][str(day)]=dict(bytes=56,actual_private_swbr=1,exact_actual_domain=True,offset=len(raw)-56,conserved_cde_prefix_offset_bytes=48)
        q['status']='ORIGINAL_OUTPUT_AQUIFER_'+a.phase.upper()+'_COMPOUND_SOURCE_NATIVE_USER_FILES_PASS'
        print(a.kind,a.optimization,a.format,a.hysteresis,q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
