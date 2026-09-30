#!/usr/bin/env python3
from pathlib import Path
import argparse, subprocess, sys

def run(cmd, out=None):
    cp=subprocess.run(cmd,text=True,capture_output=out is not None)
    if cp.returncode:
        raise SystemExit((cp.stdout or "")+"\n"+(cp.stderr or ""))
    if out is not None: Path(out).write_text(cp.stdout,encoding="utf-8")
    return cp

ap=argparse.ArgumentParser()
ap.add_argument("--artifact-dir",required=True)
ap.add_argument("--root",default=".")
a=ap.parse_args()
root=Path(a.root).resolve()
build=Path("/tmp")/"swap5-elastic67"
build.mkdir(parents=True,exist_ok=True)
work=build/"work"; work.mkdir(exist_ok=True)

run(["python3",str(root/"tests/fpe/prepare_fpe_elastic67.py"),"--repo-root",str(root),"--artifact-dir",a.artifact_dir,"--work-dir",str(work),"--fixture",str(build/"test.f90"),"--geometry-json",str(build/"geometry.json")])
run(["python3",str(root/"tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py"),"--source",str(root/"tests/fsi/fsi04_real_headcalc_stubs.f90"),"--geometry-json",str(build/"geometry.json"),"--output",str(build/"stub.f90")])
run(["python3",str(root/"tests/fpe/materialize_fpe_elastic53_mode7_indicator.py"),"--root",str(root),"--indicator-out",str(build/"indicator.f90"),"--oracle-out",str(build/"unused.f90")])

outputs=[]
for opt in (0,2):
    out=build/f"o{opt}"
    run(["python3",str(root/"tests/rom/compile_f_rom0_fortran_closure.py"),"--root",str(root),"--stub",str(build/"stub.f90"),"--target",str(build/"test.f90"),"--external-source",str(build/"indicator.f90"),"--external-source",str(root/"src/legacy/b1_10_port/headcalc.f90"),"--build",str(out),"--opt",str(opt)])
    lines=[]
    for delta in ("-0.05","-0.035"):
        for regime in ("OFF","FIXED_1E6","GENERATED"):
            for dt in ("0.0009765625","0.00048828125"):
                cp=subprocess.run([str(out/"rom0_test"),regime,"-20",delta,dt],text=True,capture_output=True)
                if cp.returncode: raise SystemExit(cp.stdout+"\n"+cp.stderr)
                lines.append(cp.stdout)
    outputs.append("".join(lines))
if outputs[0]!=outputs[1]: raise SystemExit("F_PE_ELASTIC67_FAIL O0/O2 drift")
path=build/"result.txt"; path.write_text(outputs[1],encoding="utf-8")
print(outputs[1],end="")
run(["python3",str(root/"tests/fpe/summarize_fpe_elastic67.py"),str(path)])
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True,cwd=root).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True,cwd=root).splitlines()
if any(x.startswith("src/") for x in names): raise SystemExit("F_PE_ELASTIC67_FAIL source scope")
print("F_PE_ELASTIC67_A5_SOURCE_SCOPE=PASS")
print("F_PE_ELASTIC67_RUN=PASS")
