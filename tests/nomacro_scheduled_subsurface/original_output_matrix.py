"""Explicit original output controls on real production hosts and native restarts."""
import argparse
from datetime import date,timedelta
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import zipfile
import original_output_baseline as baseline

m=baseline.schedule.m
ROOT=baseline.ROOT


def fixture(path,name):
    base=name
    if name.startswith('cde-'):base='water-'+name[4:]
    if name.startswith(('age-csv','cde-solbal-csv')):base='water-csv'+name[-1]
    if name in ('water-csv0-omitted','water-default-precision'):base='water-csv0' if 'omitted' in name else 'water-custom-csv5'
    if name=='water-nprint3':base='water-nprint2'
    baseline.fixture(path,base)
    control=path/'swap.swp';text=control.read_text(encoding='cp1252')
    if name.startswith('cde-'):text=baseline.assignment(text,'SWSOLU',1)
    if name.startswith('age-csv'):text=baseline.assignment(text,'SWSOLU',2)
    if name.startswith('cde-solbal-csv'):
        text=baseline.assignment(text,'INLIST_CSV',"'WATBAL,GWL,SOLBAL,S_CONC,Q'")
        text=baseline.assignment(text,'SWIRFIX',1)
        text,count=re.subn(r'(?mi)^([ \t]*CMLTB[ \t]*=[ \t]*\n).*?^\* End of table',lambda match:match[1]+' -10.0 0.1\n -95.0 0.1\n* End of table',text,count=1,flags=re.S);assert count==1
    if name=='water-nprint3':text=baseline.assignment(text,'NPRINTDAY',3)
    if name=='water-csv0-omitted':
        for key in ('SWCSV','INLIST_CSV','NUM_DECIMALS'):text=re.sub(r'(?mi)^[ \t]*'+key+r'[ \t]*=[^\r\n]*\r?\n','',text)
    if name=='water-default-precision':text=re.sub(r'(?mi)^[ \t]*NUM_DECIMALS[ \t]*=[^\r\n]*\r?\n','',text)
    control.write_text(text,encoding='cp1252')


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source)
    origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        from original_output import magic
        assert a.read('macro.bin')[:8]==magic(project)
        for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
    assert m.sha(source)==digest
    from original_output import selection
    from original_output_files import compare
    files=compare(full/'original',out/'original',selection(project),start,end,project.start_date)
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,origin_unchanged=True,seconds=seconds)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--case',required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--phase',choices=('short','full'),default='short');p.add_argument('--reuse-build',type=Path);p.add_argument('--existing-input',type=Path)
    a=p.parse_args();a.output.mkdir();inputs=a.existing_input or a.output/'input'
    if not a.existing_input:fixture(inputs,a.case)
    project=m.e.load(inputs,original_output=True);build=a.reuse_build or a.output/'build'
    from original_output import metadata
    selected=metadata(project)
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),case=a.case,optimization=a.optimization,original_output=selected,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        if not a.reuse_build:
            cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--original-output','--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
            start=time.monotonic();r=subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(returncode=r.returncode,seconds=time.monotonic()-start);save();assert r.returncode==0,r.stderr
        last=1096 if a.phase=='full' else 35 if selected['swmonth'] or selected['swodat'] else 10
        windows=[(2,4),(last-3,last-1)]
        if selected['swmonth'] or selected['swodat']:windows.append((30,34))
        if last==1096:windows += [(199,201),(364,367),(530,532),(1094,1096)]
        cuts={x for pair in windows for x in pair}
        full=a.output/'trajectory';result,data=m.trajectory(build,a.reference_work,project,full,last,cuts,120);q['trajectory']=result;save()
        actual=baseline.controls((full/'original/swap.swp').read_text(encoding='cp1252'));requested=baseline.controls((inputs/'swap.swp').read_text(encoding='cp1252'))
        assert actual==requested,(actual,requested)
        q['requested_controls_preserved']=True;q['csv']=baseline.outputs(full/'original')
        if selected['swcsv']==0:assert not list((full/'original').glob('result_output.*'))
        q['own']=[]
        for s,e in windows:q['own'].append(own(build,a.reference_work,project,full,data,s,e,a.output/('own-'+str(s))));save()
        q['status']='ORIGINAL_OUTPUT_'+a.phase.upper()+'_NATIVE_SOURCE_PASS';print(q['status'],a.case,a.optimization,flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
