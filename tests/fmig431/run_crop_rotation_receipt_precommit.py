#!/usr/bin/env python3
import pathlib,re,subprocess,tempfile,os,shlex
R=pathlib.Path(__file__).resolve().parents[2]
T=R/'tests/fmig431/test_crop_rotation_receipt_precommit.f90'
FC=shlex.split(os.environ.get('FC','gfortran'))
mods={}
for p in (R/'src').rglob('*.f90'):
    for n in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.M|re.I):
        mods[n.lower()]=p
intr={'iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'}
order=[];seen=set();vis=set()
def visit(p):
    if p in seen:return
    if p in vis:raise RuntimeError('cycle '+str(p))
    vis.add(p)
    text=p.read_text()
    for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',text,re.M|re.I):
        q=mods.get(n.lower())
        if q is not None and q!=p: visit(q)
        elif q is None and n.lower() not in intr: raise RuntimeError('missing '+n+' from '+str(p))
    vis.remove(p);seen.add(p);order.append(p)
visit(T)
outputs=[]
with tempfile.TemporaryDirectory(prefix='swap431-crop-rotation-receipt-') as td:
    for opt in ('O0','O2'):
        b=pathlib.Path(td)/opt;b.mkdir();objs=[]
        flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace',
               '-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
        for i,p in enumerate(order[:-1]):
            o=b/(str(i)+'_'+p.stem+'.o')
            subprocess.run(FC+flags+['-c',str(p),'-o',str(o)],check=True)
            objs.append(str(o))
        t=b/'test.o'; subprocess.run(FC+flags+['-c',str(T),'-o',str(t)],check=True); objs.append(str(t))
        exe=b/'test';subprocess.run(FC+flags+objs+['-o',str(exe)],check=True)
        x=subprocess.run([str(exe)],capture_output=True,text=True)
        print(x.stdout,end='');print(x.stderr,end='')
        if x.returncode or 'SW431_CROP_ROTATION_PRECOMMIT_NO_MUTATION=PASS' not in x.stdout: raise SystemExit(1)
        outputs.append(x.stdout)
if outputs[0]!=outputs[1]: raise SystemExit('O0/O2 output drift')
print('SW431_CROP_ROTATION_RECEIPT_PRECOMMIT_O0_O2=PASS')
