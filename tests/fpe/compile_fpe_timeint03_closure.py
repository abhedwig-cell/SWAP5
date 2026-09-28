#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, re, subprocess

MODULE_RE=re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)",re.I)
USE_RE=re.compile(r"^\s*use(?:\s*,\s*(?:non_)?intrinsic\s*::)?\s*(?:::)?\s*([a-zA-Z_]\w*)",re.I)

def source_modules(path):
    out=set()
    for line in path.read_text(encoding="utf-8",errors="ignore").splitlines():
        m=MODULE_RE.match(line)
        if m: out.add(m.group(1).lower())
    return out

def used_modules(path):
    out=set()
    for line in path.read_text(encoding="utf-8",errors="ignore").splitlines():
        m=USE_RE.match(line)
        if m:
            name=m.group(1).lower()
            if not name.startswith(("iso_","ieee_")): out.add(name)
    return out

def run(cmd): subprocess.run(cmd,check=True)

ap=argparse.ArgumentParser()
ap.add_argument("--root",default=".")
ap.add_argument("--stub",required=True)
ap.add_argument("--target",required=True)
ap.add_argument("--external-source",action="append",default=[])
ap.add_argument("--external-module-source",action="append",default=[])
ap.add_argument("--build",required=True)
ap.add_argument("--opt",default="2")
args=ap.parse_args()

root=pathlib.Path(args.root).resolve()
stub=(root/args.stub).resolve()
target=(root/args.target).resolve()
external=[pathlib.Path(p).resolve() if pathlib.Path(p).is_absolute() else (root/p).resolve() for p in args.external_source]
external_modules=[pathlib.Path(p).resolve() if pathlib.Path(p).is_absolute() else (root/p).resolve() for p in args.external_module_source]
build=pathlib.Path(args.build).resolve(); build.mkdir(parents=True,exist_ok=True)

candidates=sorted(list((root/"src").rglob("*.f90"))+list((root/"src").rglob("*.F90")))+external_modules
providers={}
for path in candidates:
    for mod in source_modules(path):
        if mod in providers and providers[mod]!=path:
            raise SystemExit(f"duplicate module provider {mod}: {providers[mod]} vs {path}")
        providers[mod]=path

stub_mods=source_modules(stub)
order=[]; visiting=set(); visited=set(); unresolved=set()

def add_file(path):
    if path in visited:return
    if path in visiting:raise SystemExit(f"dependency cycle {path}")
    visiting.add(path)
    for mod in used_modules(path):
        if mod in stub_mods:continue
        provider=providers.get(mod)
        if provider is None: unresolved.add(mod)
        else:add_file(provider)
    visiting.remove(path);visited.add(path);order.append(path)

for path in external:
    if not path.is_file():raise SystemExit(f"missing external source {path}")
    add_file(path)
for mod in used_modules(target):
    if mod in stub_mods:continue
    provider=providers.get(mod)
    if provider is None:unresolved.add(mod)
    else:add_file(provider)
if unresolved:raise SystemExit("unresolved modules: "+", ".join(sorted(unresolved)))

common=["gfortran","-std=f2008","-ffree-line-length-none","-Wall","-Wextra","-fcheck=all","-fbacktrace",
        "-fopenmp","-ffpe-trap=invalid,zero,overflow",f"-O{args.opt}","-J",str(build),"-I",str(build)]
objects=[]
stub_obj=build/"stubs.o";run(common+["-c",str(stub),"-o",str(stub_obj)]);objects.append(stub_obj)
for i,path in enumerate(order):
    obj=build/f"m_{i:04d}_{path.stem}.o";run(common+["-c",str(path),"-o",str(obj)]);objects.append(obj)
target_obj=build/"test.o";run(common+["-c",str(target),"-o",str(target_obj)]);objects.append(target_obj)
exe=build/"timeint03_test"
run(["gfortran","-fopenmp",f"-O{args.opt}",*[str(x) for x in objects],"-o",str(exe)])
print(f"F_PE_TIMEINT03_BUILD_SOURCE_COUNT={len(order)}")
print(f"F_PE_TIMEINT03_BUILD_EXECUTABLE={exe}")
