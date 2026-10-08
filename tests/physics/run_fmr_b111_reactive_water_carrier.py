#!/usr/bin/env python3
import os,pathlib,re,shlex,subprocess,tempfile

ROOT=pathlib.Path(__file__).resolve().parents[2]
FC=shlex.split(os.environ.get("FC","gfortran"))
TEST=ROOT/"tests/physics/test_fmr_b111_reactive_water_carrier.f90"
EXTRA=[ROOT/"tests/fsi/fsi04_real_headcalc_stubs.f90"]
LEGACY_HEAD=ROOT/"src/legacy/b1_10_port/headcalc.f90"

modules={}
for p in list((ROOT/"src").rglob("*.f90"))+EXTRA:
    if not p.exists():
        continue
    text=p.read_text()
    for name in re.findall(r"^\s*module\s+(\w+)\s*$",text,re.M|re.I):
        modules[name.lower()]=p

ordered=[];seen=set();visiting=set()
intrinsic={"iso_fortran_env","iso_c_binding","ieee_arithmetic","omp_lib"}

def visit(p):
    if p in seen:return
    if p in visiting:raise RuntimeError("module cycle: "+str(p))
    visiting.add(p)
    text=p.read_text()
    for name in re.findall(r"^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)",text,re.M|re.I):
        key=name.lower()
        q=modules.get(key)
        if q is not None and q!=p:visit(q)
        elif q is None and key not in intrinsic:
            raise RuntimeError("unresolved module: "+name+" required by "+str(p))
    visiting.remove(p);seen.add(p);ordered.append(p)

visit(TEST)
sources=[p for p in ordered if p!=TEST]
if any(p.name=="mod_reference_richards_legacy_binding.f90" for p in sources):
    sources.append(LEGACY_HEAD)
with tempfile.TemporaryDirectory(prefix="swap431-reactive-water-carrier-") as folder:
    for opt in ("O0","O2"):
        build=pathlib.Path(folder)/opt;build.mkdir()
        flags=["-"+opt,"-std=f2008","-ffree-line-length-none","-fopenmp","-fcheck=all","-fbacktrace",
               "-ffpe-trap=invalid,zero,overflow","-J"+str(build),"-I"+str(build)]
        objects=[]
        for p in sources:
            obj=build/(p.stem+".o")
            subprocess.run(FC+flags+["-c",str(p),"-o",str(obj)],check=True,stdout=subprocess.DEVNULL)
            objects.append(str(obj))
        test_obj=build/(TEST.stem+".o")
        exe=build/TEST.stem
        subprocess.run(FC+flags+["-c",str(TEST),"-o",str(test_obj)],check=True,stdout=subprocess.DEVNULL)
        subprocess.run(FC+flags+objects+[str(test_obj),"-o",str(exe)],check=True,stdout=subprocess.DEVNULL)
        run=subprocess.run([str(exe)],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        print(run.stdout,end="")
        run.check_returncode()
        if "FMR_B111_REACTIVE_WATER_CARRIER_PASS" not in run.stdout:
            raise RuntimeError("missing accepted-water carrier marker for "+opt)
print("FMR_B111_REACTIVE_WATER_CARRIER_O0_O2_PASS")
