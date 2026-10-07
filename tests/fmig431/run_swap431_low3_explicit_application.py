#!/usr/bin/env python3
import pathlib,re,subprocess,tempfile,os,shlex
R=pathlib.Path(__file__).resolve().parents[2]
T=R/'tests/fmig431/test_swap431_low3_explicit_application.f90'
FC=shlex.split(os.environ.get('FC','gfortran'))
LINK=shlex.split(os.environ.get('FMR_FC_LINK_FLAGS',''))
mods={}
for p in list((R/'src').rglob('*.f90'))+[R/'tests/fsi/fsi04_real_headcalc_stubs.f90']:
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
visit(R/'src/legacy/b1_10_port/headcalc.f90');visit(T)
sources=[p for p in order if p!=T]
with tempfile.TemporaryDirectory(prefix='low3-app-') as td:
    markers={}
    for opt in ('O0','O2'):
        b=pathlib.Path(td)/opt;b.mkdir()
        flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
               '-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
        objs=[]
        for p in sources:
            o=b/(p.stem+'.o');subprocess.run(FC+flags+['-c',str(p),'-o',str(o)],check=True);objs.append(str(o))
        o=b/(T.stem+'.o');subprocess.run(FC+flags+['-c',str(T),'-o',str(o)],check=True)
        exe=b/'test';subprocess.run(FC+LINK+flags+objs+[str(o),'-o',str(exe)],check=True)
        x=subprocess.run([str(exe)],capture_output=True,text=True)
        print(x.stdout,end='');print(x.stderr,end='')
        if x.returncode:raise SystemExit(x.returncode)
        m=[line for line in x.stdout.splitlines() if 'PASS' in line]
        if 'LOW03EXP_APPLICATION_GATE=PASS' not in x.stdout:raise SystemExit('missing application gate')
        markers[opt]=m
    if markers['O0']!=markers['O2']:raise SystemExit('O0/O2 PASS marker drift')
print('SW431_LOW3_EXPLICIT_APPLICATION_O0_O2=PASS')
