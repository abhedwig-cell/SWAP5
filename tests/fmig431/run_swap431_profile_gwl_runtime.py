#!/usr/bin/env python3
import os,pathlib,re,shlex,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
TEST=ROOT/'tests/fmig431/test_swap431_profile_gwl_runtime.f90'
FC=shlex.split(os.environ.get('FC','gfortran'))
modules={}
for p in list((ROOT/'src').rglob('*.f90'))+[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']:
    for n in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):
        modules[n.lower()]=p
ordered=[];seen=set();visiting=set()
intrinsic={'iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'}
def visit(p):
    if p in seen:return
    if p in visiting:raise RuntimeError('module cycle: '+str(p))
    visiting.add(p)
    for n in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)',p.read_text(),re.M|re.I):
        q=modules.get(n.lower())
        if q and q!=p:visit(q)
        elif not q and n.lower() not in intrinsic:raise RuntimeError('missing module: '+n)
    visiting.remove(p);seen.add(p);ordered.append(p)
visit(TEST)
with tempfile.TemporaryDirectory(prefix='swap431-gwl-runtime-') as folder:
    for opt in ('O0','O2'):
        build=pathlib.Path(folder)/opt;build.mkdir()
        flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
        objs=[]
        for p in ordered:
            obj=build/(p.stem+'.o');objs.append(str(obj))
            subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True)
        exe=build/'test'
        subprocess.run(FC+flags+objs+['-o',str(exe)],check=True)
        out=subprocess.check_output([str(exe)],text=True)
        if 'SW431_GW_PROJECTION_RUNTIME_COMMIT=PASS' not in out:
            raise RuntimeError('transaction marker missing')
        print(opt+' SW431_GW_PROJECTION_RUNTIME=PASS',flush=True)
