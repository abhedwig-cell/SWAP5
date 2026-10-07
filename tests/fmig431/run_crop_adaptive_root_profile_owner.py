#!/usr/bin/env python3
import pathlib,re,subprocess,tempfile,os,shlex
R=pathlib.Path(__file__).resolve().parents[2]
FC=shlex.split(os.environ.get('FC','gfortran'))
tests=[
 ('owner',R/'tests/fmig431/test_crop_adaptive_root_profile_owner.f90','SW431_ROOT_DENSITY_ADAPTIVE=PASS'),
 ('runtime',R/'tests/fmig431/test_crop_adaptive_root_profile_runtime.f90','SW431_ROOT_DENSITY_ADAPTIVE_RUNTIME=PASS'),
]
mods={}
for p in list((R/'src').rglob('*.f90'))+[R/'tests/fsi/fsi04_real_headcalc_stubs.f90']:
    for n in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.M|re.I):
        mods[n.lower()]=p
intr={'iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'}
def closure(target):
    order=[];seen=set();vis=set()
    def visit(p):
        if p in seen:return
        if p in vis:raise RuntimeError('cycle '+str(p))
        vis.add(p)
        for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',p.read_text(),re.M|re.I):
            q=mods.get(n.lower())
            if q is not None and q!=p:visit(q)
            elif q is None and n.lower() not in intr:raise RuntimeError('missing '+n+' from '+str(p))
        vis.remove(p);seen.add(p);order.append(p)
    if target.name.endswith('_runtime.f90'): visit(R/'src/legacy/b1_10_port/headcalc.f90')
    visit(target);return order
with tempfile.TemporaryDirectory(prefix='adaptive-root-profile-') as td:
    td=pathlib.Path(td)
    for name,target,marker in tests:
        outputs=[]
        for opt in ('O0','O2'):
            b=td/(name+'-'+opt);b.mkdir();objs=[]
            flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
                   '-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
            for i,p in enumerate(closure(target)):
                o=b/(str(i)+'_'+p.stem+'.o');subprocess.run(FC+flags+['-c',str(p),'-o',str(o)],check=True);objs.append(str(o))
            exe=b/'test';subprocess.run(FC+flags+objs+['-o',str(exe)],check=True)
            x=subprocess.run([str(exe)],capture_output=True,text=True);print(x.stdout,end='');print(x.stderr,end='')
            if x.returncode or marker not in x.stdout:raise SystemExit(1)
            outputs.append(x.stdout)
        if outputs[0]!=outputs[1]:raise SystemExit(name+' O0/O2 output drift')
print('SW431_ROOT_DENSITY_ADAPTIVE_O0_O2=PASS')
