"""Replay the sealed Andelst contact macro import without a Richards step."""

import argparse
import hashlib
import io
import os
import pathlib
import re
import subprocess
import tarfile
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--ref", default="a4da56a0c60105862fc3dc91b6101ff1c963cf84")
parser.add_argument("--fc", default="gfortran")
parser.add_argument("--trace-guards", action="store_true")
args = parser.parse_args()

def git(*args):
    return subprocess.check_output(["git",*args])
ref=args.ref
paths=git("ls-tree","-r","--name-only",ref,"src","app/solute_column").decode().splitlines()
modules={pathlib.PurePosixPath(p).stem:p for p in paths if p.endswith(".f90")}
start="app/solute_column/read_swp_macro_initial.f90"
ordered={}
def add(path):
    if path in ordered:return
    data=git("show",f"{ref}:{path}")
    for name in re.findall(rb"(?im)^\s*use\s*(?:::|,\s*intrinsic\s*::)?\s+(\w+)",data):
        name=name.decode().lower()
        if name not in ("iso_fortran_env","ieee_arithmetic"):
            aliases={"mod_column_swp_macro_geometry":"app/solute_column/read_swp_macro_geometry.f90"}
            add(aliases.get(name) or modules[name])
    ordered[path]=data
add(start)
archive="integration/dataqual15/ANDELST_CONTACT_DIAGNOSTIC.tar.xz"
with tarfile.open(fileobj=io.BytesIO(git("show",f"{ref}:{archive}")),mode="r:xz") as t:
    fixture=t.extractfile("run/macro.nml").read()
marker=b" call require(ok.and.abs(initial%rapid_kd-rapid_kd)<=1d-12,'source rapid reference')"
assert ordered[start].count(marker)==1
ordered[start]=ordered[start].replace(marker,b" write(*,'(a,1x,l1,3(1x,es25.17))') 'rapid_kd',ok,initial%rapid_kd,rapid_kd,initial%rapid_kd-rapid_kd\n"+marker)
shrinkage = "src/process/macropore/mod_macropore_dynamic_shrinkage.f90"
source = ordered[shrinkage].decode()
begin = source.index("    kd=0.0_real64;ok=.false.;n=size(z)")
end = source.index("    kd=total;ok=.true.", begin)
body = source[begin:end]
guard = re.compile(r"(?m)^( +)(if\(.*?(?:&\n[^\n]*)*\))return$")
guards = []
def report_guard(match):
    indent, predicate = match.groups()
    guards.append(" ".join(predicate.replace("&", "").split()))
    return (
        f"{indent}{predicate}then\n"
        f"{indent}  write(*,*) 'rapid guard {len(guards)}'\n"
        f"{indent}  return\n"
        f"{indent}end if"
    )
if args.trace_guards:
    body = guard.sub(report_guard, body)
    assert len(guards) == 13, guards
    for number, predicate in enumerate(guards, start=1):
        print("rapid guard", number, predicate, flush=True)
    ordered[shrinkage] = (source[:begin] + body + source[end:]).encode()
program="""program probe
use mod_column_swp_macro_initial
implicit none
type(native_macro_initial_t) :: initial
call import_column_macro_initial('macro.nml',initial)
end program
"""
statuses = []
with tempfile.TemporaryDirectory(prefix="s5-contact-import-") as d:
    root=pathlib.Path(d)
    sources=[]
    for path,data in ordered.items():
        f=root/pathlib.PurePosixPath(path).name
        f.write_bytes(data)
        sources.append(f.name)
    (root/"probe.f90").write_text(program)
    (root/"macro.nml").write_bytes(fixture)
    print("Sources",len(sources),sources,"fixture sha256",hashlib.sha256(fixture).hexdigest(),flush=True)
    for opt in ("O0","O2"):
        name="probe.exe" if os.name=="nt" else "./probe"
        subprocess.run([args.fc,"-"+opt,"-ffree-line-length-none","-fcheck=all",*sources,"probe.f90","-o",name],cwd=root,check=True,timeout=45)
        print(opt,flush=True)
        r=subprocess.run([str(root/name)],cwd=root,timeout=5)
        print("status",r.returncode,flush=True)
        statuses.append(r.returncode)
raise SystemExit(1 if any(statuses) else 0)
