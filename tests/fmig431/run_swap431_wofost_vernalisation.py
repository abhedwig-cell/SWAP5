#!/usr/bin/env python3
import pathlib,re,subprocess,tempfile,os,shlex
R=pathlib.Path(__file__).resolve().parents[2]
TESTS=[
 R/'tests/fmig431/test_swap431_wofost_vernalisation.f90',
 R/'tests/fmig431/test_swap431_wofost_vernalisation_persistence.f90'
]
FC=shlex.split(os.environ.get('FC','gfortran'))
extra=[R/'tests/fsi/fsi04_real_headcalc_stubs.f90']
mods={}
for p in list((R/'src').rglob('*.f90'))+extra:
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
    visit(test)
    return order

outs={}
with tempfile.TemporaryDirectory(prefix='swap431-vern-') as td:
    for opt in ('O0','O2'):
        b=pathlib.Path(td)/opt;b.mkdir()
        combined=[]
        for tix,test in enumerate(TESTS):
            objs=[]
            order=closure(test)
            for i,p in enumerate(order):
                o=b/(f'{tix}_{i}_'+p.stem+'.o')
                subprocess.run(FC+['-'+opt,'-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-Werror',
                    '-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b),
                    '-c',str(p),'-o',str(o)],check=True)
                objs.append(str(o))
            exe=b/f'test_{tix}'
            subprocess.run(FC+['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace',
                '-ffpe-trap=invalid,zero,overflow']+objs+['-o',str(exe)],check=True)
            x=subprocess.run([str(exe)],capture_output=True,text=True)
            print(x.stdout,end='');print(x.stderr,end='')
            if x.returncode:raise SystemExit(x.returncode)
            combined.append(x.stdout)
        outs[opt]=''.join(combined)
if outs['O0']!=outs['O2']:raise SystemExit('O0/O2 output drift')
for marker in ('SW431_CROP_VERNALISATION=PASS','SW431_CROP_VERNALISATION_PERSISTENCE=PASS'):
    if marker not in outs['O0']:raise SystemExit('missing '+marker)
print('SW431_CROP_VERNALISATION_O0_O2=PASS')
