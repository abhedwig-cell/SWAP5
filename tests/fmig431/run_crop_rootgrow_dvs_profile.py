#!/usr/bin/env python3
import pathlib,re,subprocess,tempfile,os,shlex
R=pathlib.Path(__file__).resolve().parents[2]
T=R/'tests/fmig431/test_crop_rootgrow_dvs_profile.f90'
FC=shlex.split(os.environ.get('FC','gfortran'))
mods={}
for p in (R/'src').rglob('*.f90'):
    for n in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):
        mods[n.lower()]=p
order=[];seen=set();vis=set();intr={'iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'}
def visit(p):
    if p in seen:return
    if p in vis:raise RuntimeError('cycle '+str(p))
    vis.add(p)
    for n in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)',p.read_text(),re.M|re.I):
        q=mods.get(n.lower())
        if q and q!=p:visit(q)
        elif not q and n.lower() not in intr:raise RuntimeError('missing '+n+' from '+str(p))
    vis.remove(p);seen.add(p);order.append(p)
visit(T)
with tempfile.TemporaryDirectory(prefix='crop-rootgrow-dvs-') as td:
    for opt in ('O0','O2'):
        b=pathlib.Path(td)/opt;b.mkdir();objs=[]
        flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace',
               '-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
        for p in order:
            o=b/(p.stem+'.o');subprocess.run(FC+flags+['-c',str(p),'-o',str(o)],check=True);objs.append(str(o))
        exe=b/'test';subprocess.run(FC+flags+objs+['-o',str(exe)],check=True)
        x=subprocess.run([str(exe)],capture_output=True,text=True)
        print(x.stdout,end='');print(x.stderr,end='')
        if x.returncode or 'SW431_CROP_ROOTGROW_DVS_PROFILE=PASS' not in x.stdout:raise SystemExit(1)
