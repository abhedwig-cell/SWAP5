"""Actual implicit HeadCalc compositions, strict daily guards and native cold state."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import age_groundwater_runtime as previous
from original_output_baseline import assignment

m=previous.m
ROOT=previous.ROOT


def fixture(path, solute, hysteresis, bottom, step, kmean=1, mode='explicit', fmt=3, reset=1, npd=None):
    npd = npd if npd is not None else (3 if step else 1)
    actual_mode='periodic' if mode=='daily' else mode
    if bottom==1:
        previous.fixture(path,hysteresis,step,actual_mode,fmt,reset,npd,1)
    else:
        previous.age.fixture(path,actual_mode,hysteresis,fmt,reset,npd,'point')
    control=path/'swap.swp'
    text=control.read_text(encoding='cp1252')
    for key,value in dict(SWKIMPL=1,SWKMEAN=kmean,SWSOLU=solute,SWBOTB=bottom,
                          FLPRINTDT='.TRUE.' if step else '.FALSE.').items():
        text=assignment(text,key,value)
    if mode=='daily':text=assignment(text,'PERIOD',1)
    def supported(match):
        names=match[1].split();rows=[]
        for line in match[2].splitlines():
            fields=line.split();assert len(fields)==len(names)
            fields[names.index('KSATEXM')]=fields[names.index('KSATFIT')]
            rows.append(' '.join(fields))
        return match[1]+'\n'.join(rows)+'\n* End of table'
    text,count=re.subn(r'(?mi)^([ \t]*ORES[ \t]+OSAT[^\r\n]*\n)(.*?)^\* End of table',supported,text,count=1,flags=re.S)
    assert count==1
    control.write_text(text,encoding='cp1252')


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--solute',choices=(0,1,2),type=int,required=True)
    p.add_argument('--hysteresis',choices=(0,1,2),type=int,required=True)
    p.add_argument('--bottom',choices=(1,5,8),type=int,required=True)
    p.add_argument('--kmean',choices=range(1,7),type=int,default=1)
    p.add_argument('--perstep',action='store_true')
    p.add_argument('--mode',choices=('explicit','periodic','monthly','terminal','daily'),default='explicit')
    p.add_argument('--format',choices=(0,1,2,3),type=int,default=3)
    p.add_argument('--reset',choices=(0,1),type=int,default=1)
    p.add_argument('--nprintday',type=int)
    p.add_argument('--phase',choices=('short','full','limit'),default='short')
    p.add_argument('--reuse-build',type=Path);p.add_argument('--existing-input',type=Path)
    a=p.parse_args();out=a.output.resolve();out.mkdir();inputs=a.existing_input or out/'input'
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),parameters={k:str(v) if isinstance(v,Path) else v for k,v in vars(a).items()},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        if not a.existing_input:fixture(inputs,a.solute,a.hysteresis,a.bottom,a.perstep,a.kmean,a.mode,a.format,a.reset,a.nprintday)
        if a.phase=='limit' and not a.existing_input:
            path=inputs/'fixed-irrigation.irg';text=path.read_text(encoding='cp1252');assert text.count('2002-01-05')==1
            path.write_text(text.replace('2002-01-05','2002-01-01'),encoding='cp1252')
        project=m.e.load(inputs,original_output=True);q['numerical_policy']=m.e.inspect(inputs)['implicit_conductivity']
        build=a.reuse_build or out/'build';q.update(input_root=str(inputs),build_root=str(build))
        cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        if not a.reuse_build:
            t=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
            q['build']=dict(returncode=r.returncode,seconds=time.perf_counter()-t)
            (out/'build.stdout').write_text(r.stdout,encoding='utf8');(out/'build.stderr').write_text(r.stderr,encoding='utf8');save();r.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project)
        assert meta['identity']['implicit_conductivity']['policy']==q['numerical_policy']['policy']
        days={'full':1096,'short':35,'limit':2}[a.phase]
        windows=[(1,2)] if a.phase=='limit' else [(2,4),(7,9),(30,34)]
        if a.phase=='full':windows += [(199,201),(364,367),(530,532),(1094,1096)]
        full=out/'trajectory';q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,days,{days,*(v for pair in windows for v in pair)},180);save()
        q['cold']=[]
        for start,end in windows:
            q['cold'].append(previous.own(build,a.reference_work,project,full,data,start,end,out/f'own-{start}'));save()
        q['native_codec']=m.e.auxiliary_magic(project).decode()
        q['status']='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_'+a.phase.upper()+'_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'
        print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
