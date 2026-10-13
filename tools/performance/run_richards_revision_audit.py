#!/usr/bin/env python3
"""Same-fixture continuous Richards trajectories on full pinned revision trees.

Diagnostic only. The fixed-step/halving diagnostic driver does not replace F-KT.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import resource
import re
import shutil
import statistics
import subprocess
import sys
import time

sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
DRIVER=ROOT/'tests/performance/full_richards_trajectory_audit.f90'
COMMON=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-O2']

def run(cmd,cwd,out,label):
    before=resource.getrusage(resource.RUSAGE_CHILDREN);start=time.monotonic()
    cp=subprocess.run(cmd,cwd=cwd,capture_output=True)
    wall=time.monotonic()-start;after=resource.getrusage(resource.RUSAGE_CHILDREN)
    (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
    return {'command':list(map(str,cmd)),'wall_seconds':wall,'user_cpu_seconds':after.ru_utime-before.ru_utime,
            'system_cpu_seconds':after.ru_stime-before.ru_stime,'exit':cp.returncode,
            'stdout_sha256':hashlib.sha256(cp.stdout).hexdigest()}

def build(tree,out,profile=False):
    out.mkdir()
    stub=out/'stubs.f90'
    text=(ROOT/'tests/f-app07/mc_irr01_realistic_headcalc_stubs.f90').read_text()
    text=text.replace('integer, parameter :: numnod = 4','integer, parameter :: numnod = 50\n  integer :: grid_i')
    text=text.replace('[-12.5d0, -37.5d0, -62.5d0, -87.5d0]','[(-1.0d0-2.0d0*(grid_i-1),grid_i=1,numnod)]')
    text=text.replace('[25.0d0, 25.0d0, 25.0d0, 25.0d0]','2.0d0')
    text=text.replace('[12.5d0,25.0d0,25.0d0,25.0d0,12.5d0]','[1.0d0,(2.0d0,grid_i=2,numnod),1.0d0]')
    stub.write_text(text)
    spec=importlib.util.spec_from_file_location('identity',ROOT/'tools/performance/irrigation_build_identity.py')
    identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
    files=sorted((tree/'src').rglob('*.f90'))+[stub]
    headcalc=tree/'src/legacy/b1_10_port/headcalc.f90'
    sources=identity.discover(files,[DRIVER,headcalc])+[headcalc,DRIVER]
    manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files+[DRIVER]}
    (out/'INPUTS.json').write_text(json.dumps({'source_identity':manifest,'ordered_sources':list(map(str,sources)),
                                           'flags':COMMON+(['-pg'] if profile else [])},indent=2,sort_keys=True))
    objects=[];events=[]
    flags=COMMON+(['-pg'] if profile else [])
    for i,p in enumerate(sources):
        obj=out/f'{i}.o'
        event=run(['gfortran',*flags,'-J',str(out),'-I',str(out),'-c',str(p),'-o',str(obj)],tree,out,f'compile-{i}')
        events.append(event)
        if event['exit']:raise ValueError('compile failed: '+str(p))
        objects.append(str(obj))
    event=run(['gfortran',*flags,*objects,'-o',str(out/'trajectory')],tree,out,'link');events.append(event)
    if event['exit']:raise ValueError('link failed')
    return {'compile_events':events,'executable_sha256':hashlib.sha256((out/'trajectory').read_bytes()).hexdigest()}

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output-dir',required=True)
    ap.add_argument('--baseline',default='50346642bd565f79134ea17d5462e544b354998c')
    ap.add_argument('--repeat',type=int,default=5);args=ap.parse_args()
    out=Path(args.output_dir).resolve();out.mkdir(parents=True,exist_ok=False)
    current=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    trees={'current':ROOT,'earlier':out/'earlier-tree','recent':out/'recent-tree'}
    subprocess.run(['git','worktree','add','--detach',str(trees['earlier']),args.baseline],cwd=ROOT,check=True)
    subprocess.run(['git','worktree','add','--detach',str(trees['recent']),'a3859c89eaf97256a6330bb9f6370013c4a9e2f2'],cwd=ROOT,check=True)
    report={'head':current,'baseline':args.baseline,'fixture_sha256':hashlib.sha256(DRIVER.read_bytes()).hexdigest(),
            'builds':{},'runs':[],'physical_differences':[],'equivalent':False,'legacy_swap431':'UNKNOWN','scope':'50-node 100-cm soil, 0.1/30-day pulsed infiltration, fixed-step diagnostic Full Richards only; no crop/coupling/F-KT timing'}
    try:
        for name,tree in trees.items():report['builds'][name]=build(tree,out/name)
        for horizon in ['0.1','30']:
            for repeat in range(args.repeat):
                order=['earlier','recent','current'] if repeat%2==0 else ['current','recent','earlier']
                pair={}
                for name in order:
                    rec=run([str(out/name/'trajectory'),horizon],out,out,f'{name}-{horizon}-{repeat}')
                    rec.update(revision=name,horizon=horizon,repeat=repeat)
                    timer=re.search(rb'RICHARDS_SOLVE_CPU_SECONDS=\s*([0-9.E+\-]+)',(out/(f'{name}-{horizon}-{repeat}'+'.stderr')).read_bytes())
                    rec['solver_cpu_seconds']=float(timer.group(1)) if timer else 'UNKNOWN'
                    raw=(out/(f'{name}-{horizon}-{repeat}'+'.stdout')).read_bytes()
                    physical=[]
                    for line in raw.splitlines(keepends=True):
                        if line.startswith(b'RICHARDS_AUDIT_RESULT'):
                            rec['diagnostics']=line.decode().strip()
                        elif line.startswith(b'STEP='):
                            physical.append(line.split(b' NL=')[0]+b' MASS='+line.split(b' MASS=')[1])
                        else:physical.append(line)
                    rec['physical_sha256']=hashlib.sha256(b''.join(physical)).hexdigest()
                    report['runs'].append(rec);pair[name]=rec
                    if rec['exit']:raise ValueError('trajectory science failed '+name)
                for name in ['earlier','recent']:
                    if pair[name]['physical_sha256']!=pair['current']['physical_sha256']:
                        report['physical_differences'].append({'revision':name,'horizon':horizon,'repeat':repeat})
        report['equivalent']=not report['physical_differences']
        for name,tree in trees.items():
            if name=='recent':continue
            report['builds'][name+'-gprof']=build(tree,out/(name+'-gprof'),True)
            rec=run([str(out/(name+'-gprof')/'trajectory'),'30'],out/(name+'-gprof'),out,name+'-profile-run')
            report[name+'-gprof-run']=rec
            if rec['exit']:raise ValueError('profile trajectory failed')
            expected=next(r['stdout_sha256'] for r in report['runs'] if r['revision']==name and r['horizon']=='30')
            if rec['stdout_sha256']!=expected:raise ValueError('gprof physical/work output drift')
            gprof=run(['gprof',str(out/(name+'-gprof')/'trajectory'),str(out/(name+'-gprof')/'gmon.out')],out,out,name+'-gprof')
            report[name+'-gprof']=gprof
            if gprof['exit']:raise ValueError('gprof extraction failed')
    except (ValueError,OSError,subprocess.SubprocessError) as e:report['failure']=str(e)
    finally:
        (out/'CONTROL.json').write_text(json.dumps(report,sort_keys=True,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k in ['equivalent','failure','scope']},indent=2),flush=True)
    return 0 if report['equivalent'] and 'failure' not in report else 1
if __name__=='__main__':sys.exit(main())
