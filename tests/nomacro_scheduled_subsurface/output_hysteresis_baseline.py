"""Actual existing hysteresis carry and explicit original-output refusal."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import time
import zipfile
import original_output_matrix as original
import age_runtime

m=original.m
ROOT=original.ROOT


def fixture(path,kind,mode):
    original.fixture(path,'cde-solbal-csv1');control=path/'swap.swp';text=control.read_text(encoding='cp1252')
    for key,value in [('SWSOLU',{'water':0,'cde':1,'age':2}[kind]),('SWHYST',mode),('INLIST_CSV',"'WATBAL,GWL,SOLBAL'")]:text=original.baseline.assignment(text,key,value)
    control.write_text(text,encoding='cp1252')


def history(raw):
    """Read the actual original SWENDTYPE2 sequential records, no physics."""
    records=[];pos=0
    while pos<len(raw):
        length=struct.unpack_from('<i',raw,pos)[0];assert 0<=length<=len(raw)-pos-8
        assert struct.unpack_from('<i',raw,pos+4+length)[0]==length
        records.append(raw[pos+4:pos+4+length]);pos+=length+8
    values=iter(records)
    integer=lambda:struct.unpack('<i',next(values))[0]
    assert integer()==1 and integer()==0 # complete single end state, no filter
    nodes=integer();assert nodes==34
    h=struct.unpack('<'+str(nodes)+'d',next(values));pond=struct.unpack('<d',next(values))[0]
    assert integer()==0 # no snow
    evaporation=integer()
    if evaporation==1:next(values)
    elif evaporation==2:next(values);next(values)
    else:assert evaporation==0
    mode=integer();assert mode in (1,2)
    index=struct.unpack('<'+str(nodes)+'i',next(values))
    arrays=[struct.unpack('<'+str(nodes)+'d',next(values)) for _ in range(3)]
    return dict(nodes=nodes,mode=mode,index=list(index),delp=list(arrays[0]),fhyst=list(arrays[1]),hm1=list(arrays[2]),h=list(h),pond=pond)


def own(build,reference,project,full,data,start,end,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source);origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
    result,seconds=m.bounded(45,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        for name in ('result.end','macro.bin'):assert a.read(name)==b.read(name),name
    for path in (out/'original').glob('*.csv'):
        cold=m.csvlines(path);warm=m.csvlines(full/'original'/path.name)
        # Main compatibility CSV has an initialization row. Age exports have
        # daily records; reuse the exact admitted observer convention.
        if path.name=='result_output.csv':assert cold[-(end-start):]==warm[start+2:end+2]
        else:assert cold[-(end-start):]==warm[start+1:end+1],path.name
    assert m.sha(source)==digest
    return dict(start=start,end=end,exact_physical=True,exact_all_csv=True,exact_complete_native=True,origin_unchanged=True,seconds=seconds)


def main():
    p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),optimization=a.optimization,profiles={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def call(cmd,out,label):
        start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=ROOT,capture_output=True,text=True,timeout=180);(out/(label+'.stdout')).write_text(r.stdout);(out/(label+'.stderr')).write_text(r.stderr)
        return r,dict(returncode=r.returncode,seconds=time.monotonic()-start,stdout=r.stdout,stderr=r.stderr)
    try:
        for mode in (1,2):
            for kind in ('water','cde','age'):
                name=kind+'-hys'+str(mode);out=a.output/name;out.mkdir();inputs=out/'input';fixture(inputs,kind,mode);project=m.e.load(inputs)
                command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization]
                r,refusal=call([*command,'--original-output','--output',out/'original-output-refused'],out,'original-output-refusal');assert r.returncode!=0 and 'excludes SWHYST' in r.stdout+r.stderr,(r.stdout,r.stderr)
                build=out/'build';r,compiled=call([*command,'--output',build],out,'compatibility-build');assert r.returncode==0,r.stderr
                meta,_=m.validate_bundle(build,a.reference_work,project);assert 'original_output' not in meta['identity']
                result,data=m.trajectory(build,a.reference_work,project,out/'trajectory',10,{2,4,8,10},60)
                states={}
                for day in (2,4,8,10):
                    with zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as z:states[str(day)]=history(z.read('result.end'))
                assert all(s['mode']==mode for s in states.values())
                active=any(any(v!=(1 if mode==1 else -1) for v in s['index']) or any(v!=1. for v in s['fhyst']) for s in states.values());assert active,'No actual hysteretic reversal/scanning history observed'
                windows=[own(build,a.reference_work,project,out/'trajectory',data,s,e,out/('own-'+str(s))) for s,e in ((2,4),(4,8))]
                if kind=='cde':assert abs(data[4]['solute_ledger_mg_cm2'][3]-48)<=1e-10
                q['profiles'][name]=dict(original_output_refusal=refusal,build=compiled,coverage=result,own=windows,actual_hysteresis_history=states,active_scanning_observed=active,build_sha256=m.sha(build/'BUILD.json'));save();print(name,a.optimization,'EXISTING_HYSTERESIS_NATIVE_PASS_ORIGINAL_OUTPUT_REFUSED',flush=True)
        q['status']='SIX_HYSTERESIS_COMPATIBILITY_SHORT_NATIVE_AND_ORIGINAL_OUTPUT_REFUSALS_OBSERVED'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
