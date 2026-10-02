#!/usr/bin/env python3
import os,pathlib,re,shlex,subprocess,tempfile,json,statistics
R=pathlib.Path(__file__).resolve().parents[2];FC=shlex.split(os.environ.get("FC","gfortran"));test=R/"tests/performance/benchmark_bartholomeus_c3a_stages.f90"
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
 exe=b/"stages";subprocess.run(FC+flags+objs+[str(test),"-o",str(exe)],check=True)
 rows=[]
 for _ in range(7):
  out=subprocess.check_output([str(exe)],text=True);rows.append({k:float(v) for k,v in re.findall(r"(STAGE_[A-Z]+_NS)=\s*([0-9.Ee+\-]+)",out)})
 keys=["STAGE_WATERFILM_NS","STAGE_ASSEMBLY_NS","STAGE_PROFILE_NS"]
 result={"head":os.environ.get("GITHUB_SHA","not-specified"),"runs":rows,"median_ns":{k:statistics.median(x[k] for x in rows) for k in keys}}
 print(json.dumps(result,indent=2));pathlib.Path("c3a_stage_result.json").write_text(json.dumps(result,indent=2)+"\n")
