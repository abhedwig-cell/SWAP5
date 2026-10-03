#!/usr/bin/env python3
import pathlib,re,subprocess,tempfile
R=pathlib.Path(__file__).resolve().parents[2];test=R/"tests/performance/falsify_bartholomeus_micro_monotonicity.f90"
src=R/"src/physics/oxygen/mod_bartholomeus_micro.f90"
with tempfile.TemporaryDirectory() as td:
 exe=pathlib.Path(td)/"m";subprocess.run(["gfortran","-O3","-ffree-line-length-none",str(src),str(test),"-o",str(exe)],check=True)
 out=subprocess.check_output([str(exe)],text=True);print(out)
 v=int(re.search(r"MICRO_MONO_DECREASE_VIOLATIONS=(\d+)",out).group(1))
 if v: raise SystemExit("MICRO monotonicity falsified")
