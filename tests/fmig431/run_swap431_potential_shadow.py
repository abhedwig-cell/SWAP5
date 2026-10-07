#!/usr/bin/env python3
import pathlib,re,subprocess,tempfile,os,shlex
R=pathlib.Path(__file__).resolve().parents[2]
TESTS=[
 R/'tests/fmig431/test_swap431_potential_shadow.f90',
 R/'tests/fmig431/test_swap431_potential_shadow_daily.f90'
]
FC=shlex.split(os.environ.get('FC','gfortran'))
mods={}
for p in (R/'src').rglob('*.f90'):
    for n in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.M|re.I):
        mods[n.lower()]=p
intr={'iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'}
def closure(test):
    order=[];seen=set();vis=set()
    def visit(p):
        p=pathlib.Path(p)
        if p in seen:return
        if p in vis:raise RuntimeError('cycle '+str(p))
        vis.add(p);txt=p.read_text()
        for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',txt,re.M|re.I):
            q=mods.get(n.lower())
            if q is not None and q!=p:visit(q)
            elif q is None and n.lower() not in intr:raise RuntimeError('missing '+n+' from '+str(p))
        vis.remove(p);seen.add(p);order.append(p)
    visit(test);return order
outs={}
with tempfile.TemporaryDirectory(prefix='swap431-potential-shadow-') as td:
    for opt in ('O0','O2'):
        b=pathlib.Path(td)/opt;b.mkdir()
        combined=[]
        for ti,test in enumerate(TESTS):
            objs=[]
            flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-Werror',
                   '-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
            for i,p in enumerate(closure(test)):
                o=b/(f'{ti}_{i}_'+p.stem+'.o')
                subprocess.run(FC+flags+['-c',str(p),'-o',str(o)],check=True);objs.append(str(o))
            exe=b/f'test_{ti}';subprocess.run(FC+flags+objs+['-o',str(exe)],check=True)
            x=subprocess.run([str(exe)],capture_output=True,text=True)
            print(x.stdout,end='');print(x.stderr,end='')
            if x.returncode:raise SystemExit(x.returncode)
            combined.append(x.stdout)
        outs[opt]=''.join(combined)
if outs['O0']!=outs['O2']:raise SystemExit('O0/O2 output drift')
for marker in ('SW431_CROP_POTENTIAL_SHADOW=PASS','SW431_CROP_POTENTIAL_SHADOW_DAILY=PASS'):
    if marker not in outs['O0']:raise SystemExit('missing '+marker)
print('SW431_CROP_POTENTIAL_SHADOW_O0_O2=PASS')
