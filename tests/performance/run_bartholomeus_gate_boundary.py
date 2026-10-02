#!/usr/bin/env python3
import os,pathlib,re,shlex,subprocess,tempfile,json
R=pathlib.Path(__file__).resolve().parents[2];FC=shlex.split(os.environ.get("FC","gfortran"));test=R/"tests/performance/falsify_bartholomeus_gate_boundary.f90"
mods={}
for p in (R/"src").rglob("*.f90"):
 t=p.read_text()
 for n in re.findall(r"^\s*module\s+(\w+)\s*$",t,re.M|re.I):mods[n.lower()]=p
seen=set();order=[]
def visit(p):
 if p in seen:return
 seen.add(p)
 for n in re.findall(r"^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)",p.read_text(),re.M|re.I):
  if n.lower() in mods:visit(mods[n.lower()])
 order.append(p)
visit(test)
with tempfile.TemporaryDirectory() as td:
 b=pathlib.Path(td);flags=["-O3","-ffree-line-length-none","-J"+str(b),"-I"+str(b)];objs=[]
 for p in order[:-1]:
  o=b/(p.stem+".o");subprocess.run(FC+flags+["-c",str(p),"-o",str(o)],check=True);objs.append(str(o))
 exe=b/"boundary";subprocess.run(FC+flags+objs+[str(test),"-o",str(exe)],check=True)
 out=subprocess.check_output([str(exe)],text=True);print(out)
 vals={m.group(1):int(m.group(2)) for m in re.finditer(r"^(BOUNDARY_[A-Z0-9_]+)=(\d+)$",out,re.M)}
 result={"head":os.environ.get("GITHUB_SHA","not-specified"),**vals}
 pathlib.Path("c3a_perf02_boundary_result.json").write_text(json.dumps(result,indent=2)+"\n")
 if vals.get("BOUNDARY_FALSE_SKIPS",-1)!=0: raise SystemExit("false skip")
 if vals.get("BOUNDARY_N_GT_2_SKIPS",-1)!=0: raise SystemExit("n>2 skip")
