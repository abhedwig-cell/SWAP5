#!/usr/bin/env python3
"""Strict O0/O2 check of real SWRD2 composition and its transitive source modules."""
from pathlib import Path
import os, re, shlex, subprocess, tempfile
root=Path(__file__).resolve().parents[2]
test=root/"tests/fmig431/test_swap431_root_supply_fail_closed.f90"
modules={}
for p in (root/"src").rglob("*.f90"):
    for name in re.findall(r"^\s*module\s+(?!procedure\b)(\w+)",p.read_text(),re.I|re.M):
        modules[name.lower()]=p
intrinsic={"iso_fortran_env","iso_c_binding","ieee_arithmetic","omp_lib"}
seen=set()
visiting=set()
ordered=[]
def add(p):
    if p in seen:return
    if p in visiting:raise RuntimeError("cyclic module dependency "+str(p))
    visiting.add(p)
    for name in re.findall(r"^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)",p.read_text(),re.I|re.M):
        name=name.lower()
        if name in modules: add(modules[name])
        elif name not in intrinsic:raise RuntimeError("unresolved Fortran module "+name+" in "+str(p))
    visiting.remove(p)
    seen.add(p)
    ordered.append(p)
add(test)
outputs=[]
with tempfile.TemporaryDirectory(prefix="swap431-root-supply-") as td:
    for opt in ("O0","O2"):
        build=Path(td)/opt
        build.mkdir()
        flags=["-"+opt,"-std=f2008","-ffree-line-length-none","-Wall","-Wextra",
               "-Werror","-Wno-error=compare-reals","-fcheck=all",
               "-ffpe-trap=invalid,zero,overflow","-J"+str(build),"-I"+str(build)]
        compiler=shlex.split(os.environ.get("FC","gfortran"))
        objects=[]
        for i,p in enumerate(ordered):
            obj=build/(str(i)+"_"+p.stem+".o")
            subprocess.run(compiler+flags+["-c",str(p),"-o",str(obj)],check=True)
            objects.append(str(obj))
        exe=build/"test"
        subprocess.run(compiler+flags+objects+["-o",str(exe)],check=True)
        output=subprocess.run([str(exe)],check=True,capture_output=True,text=True)
        outputs.append(output.stdout)
        print(opt+": "+output.stdout.strip())
if outputs[0]!=outputs[1] or "SW431_ROOT_SUPPLY_FAIL_CLOSED=PASS" not in outputs[0]:
    raise SystemExit("SWRD2 O0/O2 output mismatch")
print("SW431_ROOT_SUPPLY_FAIL_CLOSED_O0_O2=PASS")
