#!/usr/bin/env python3
import os,pathlib,re,shlex,subprocess,tempfile,json,statistics
R=pathlib.Path(__file__).resolve().parents[2];FC=shlex.split(os.environ.get("FC","gfortran"));test=R/"tests/performance/benchmark_bartholomeus_perf02.f90"
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
 b=pathlib.Path(td);flags=["-O3","-march=native","-ffree-line-length-none","-J"+str(b),"-I"+str(b)];objs=[]
 for p in order[:-1]:
  o=b/(p.stem+".o");subprocess.run(FC+flags+["-c",str(p),"-o",str(o)],check=True);objs.append(str(o))
 exe=b/"perf02";subprocess.run(FC+flags+objs+[str(test),"-o",str(exe)],check=True)
 outs=[]; parsed=[]
 for _ in range(7):
  out=subprocess.check_output([str(exe)],text=True);outs.append(out);print(out)
  d={}
  for m in re.finditer(r"PERF02_(GATED|PERF01|GATE)_REGIME=(\d+) NS=\s*([0-9.Ee+\-]+)",out):d[f"{m.group(1)}_{m.group(2)}"]=float(m.group(3))
  for m in re.finditer(r"PERF02_(GATED|PERF01)_MIXED_NS=\s*([0-9.Ee+\-]+)",out):d[f"{m.group(1)}_MIXED"]=float(m.group(2))
  parsed.append(d)
 keys=sorted(set().union(*(x.keys() for x in parsed)))
 result={"head":os.environ.get("GITHUB_SHA","not-specified"),"compiler":subprocess.check_output(FC+["--version"],text=True).splitlines()[0],"runs":parsed,"median_ns":{k:statistics.median(x[k] for x in parsed) for k in keys},"outputs":outs}
 pathlib.Path("c3a_perf02_result.json").write_text(json.dumps(result,indent=2)+"\n")
 print(json.dumps(result["median_ns"],indent=2))
