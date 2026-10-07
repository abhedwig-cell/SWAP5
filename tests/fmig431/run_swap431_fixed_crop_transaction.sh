#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap431-fixed-tx-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
git show 85c0f7838d56c63d49f16af8242bdf4cbe4219d9:tests/fwof/test_fwof34_accepted_window_runtime_lineage.f90 > "$BUILD/fwof34_full.f90"
python3 - "$BUILD/fwof34_full.f90" "$BUILD/fwof34_module.f90" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
marker='\nprogram test_fwof34_accepted_window_runtime_lineage\n'
if marker not in s: raise SystemExit('F-WOF34 split marker missing')
Path(sys.argv[2]).write_text(s.split(marker,1)[0].rstrip()+'\n')
PY
python3 - "$ROOT" "$BUILD" <<'PY'
import pathlib,re,subprocess,os,shlex,sys
R=pathlib.Path(sys.argv[1]); B=pathlib.Path(sys.argv[2])
T=R/'tests/fmig431/test_swap431_fixed_crop_transaction.f90'
EXTRA=B/'fwof34_module.f90'
FC=shlex.split(os.environ.get('FC','gfortran'))
mods={}
for p in list((R/'src').rglob('*.f90'))+[EXTRA]:
    txt=p.read_text()
    for n in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)',txt,re.M|re.I):
        mods[n.lower()]=p
intr={'iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'}
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
visit(T)
outs=[]
for opt in ('O0','O2'):
    d=B/opt;d.mkdir();objs=[]
    flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-Werror',
           '-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(d),'-I'+str(d)]
    for i,p in enumerate(order):
        o=d/(str(i)+'_'+p.stem+'.o')
        subprocess.run(FC+flags+['-c',str(p),'-o',str(o)],check=True)
        objs.append(str(o))
    exe=d/'test'
    subprocess.run(FC+flags+objs+['-o',str(exe)],check=True)
    x=subprocess.run([str(exe)],capture_output=True,text=True)
    print(x.stdout,end='');print(x.stderr,end='')
    if x.returncode:raise SystemExit(x.returncode)
    for m in ('SW431_CROP_FIXED_ATOMIC_TRANSACTION=PASS','SW431_CROP_FIXED_END_EVENT=PASS','SW431_CROP_FIXED_RESTART=PASS'):
        if m not in x.stdout:raise SystemExit('missing '+m)
    outs.append(x.stdout)
if outs[0]!=outs[1]:raise SystemExit('O0/O2 output drift')
print('SW431_CROP_FIXED_TRANSACTION_O0_O2=PASS')
PY
