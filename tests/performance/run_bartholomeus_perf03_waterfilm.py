#!/usr/bin/env python3
import pathlib,re,shlex,subprocess,tempfile,os
R=pathlib.Path(__file__).resolve().parents[2];FC=shlex.split(os.environ.get("FC","gfortran"));test=R/"tests/performance/characterize_bartholomeus_perf03_waterfilm.f90"
mods={}
for p in (R/"src").rglob("*.f90"):
 for n in re.findall(r"^\\s*module\\s+(\\w+)\\s*$",p.read_text(),re.M|re.I):mods[n.lower()]=p
seen=set();order=[]
def visit(p):
 if p in seen:return
 seen.add(p)
 for n in re.findall(r"^\\s*use\\s+(?:,\\s*non_intrinsic\\s*::\\s*)?(\\w+)",p.read_text(),re.M|re.I):
  if n.lower() in mods:visit(mods[n.lower()])
 order.append(p)
visit(test)
with tempfile.TemporaryDirectory() as td:
 b=pathlib.Path(td);flags=["-O3","-ffree-line-length-none","-J"+str(b),"-I"+str(b)];objs=[]
 for p in order[:-1]:
  o=b/(p.stem+".o");subprocess.run(FC+flags+["-c",str(p),"-o",str(o)],check=True);objs.append(str(o))
 exe=b/"wf";subprocess.run(FC+flags+objs+[str(test),"-o",str(exe)],check=True);subprocess.run([str(exe)],check=True)
