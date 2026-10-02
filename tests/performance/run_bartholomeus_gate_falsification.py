#!/usr/bin/env python3
import os,pathlib,re,shlex,subprocess,tempfile,json
R=pathlib.Path(__file__).resolve().parents[2];FC=shlex.split(os.environ.get("FC","gfortran"));test=R/"tests/performance/falsify_bartholomeus_gate.f90"
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
 exe=b/"gate";subprocess.run(FC+flags+objs+[str(test),"-o",str(exe)],check=True)
 out=subprocess.check_output([str(exe)],text=True);print(out)
 rows=[]
 for line in out.splitlines():
  m=re.match(r"GATE_ROW\s+([\d.Ee+\-]+)\s+([\d.Ee+\-]+)\s+([\d.Ee+\-]+)\s+([\d.Ee+\-]+)\s+CTOP\s+([\d.Ee+\-]+)\s+MINFAC\s+([\d.Ee+\-]+)",line)
  if m:rows.append(tuple(map(float,m.groups())))
 candidates=[]
 for th in sorted(set(r[3] for r in rows)):
  sel=[r for r in rows if r[3]>=th];fp=sum(r[5]<1-1e-14 for r in sel)
  candidates.append({"gfp_min_threshold":th,"skips":len(sel),"false_skips":fp})
 safe=[x for x in candidates if x["false_skips"]==0]
 result={"head":os.environ.get("GITHUB_SHA","not-specified"),"rows":len(rows),"no_stress":sum(r[5]>=1-1e-14 for r in rows),"safe_gfp_rules":safe}
 # Search conservative conjunctive rules GFP>=g, CTOP>=c, root<=r, temp<=t.
 combos=[]
 for g in sorted(set(x[3] for x in rows)):
  for ct in sorted(set(x[4] for x in rows)):
   for root in sorted(set(x[2] for x in rows)):
    for temp in sorted(set(x[1] for x in rows)):
     sel=[x for x in rows if x[3]>=g and x[4]>=ct and x[2]<=root and x[1]<=temp]
     if not sel: continue
     fp=sum(x[5]<1-1e-14 for x in sel)
     if fp==0: combos.append({"gfp":g,"ctop":ct,"root_max":root,"temp_max":temp,"skips":len(sel)})
 combos.sort(key=lambda x:x["skips"],reverse=True)
 result["safe_conjunctive_rules"]=combos[:50]
 pathlib.Path("c3a_gate_result.json").write_text(json.dumps(result,indent=2)+"\n");print(json.dumps(result,indent=2))
