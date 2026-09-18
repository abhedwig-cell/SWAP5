from __future__ import annotations
import argparse,json,math,os,platform,re,resource,statistics,subprocess,time
from pathlib import Path
PAIRS=12; WARMUPS=2; K=2.0; TARGET=0.05; ROUTES=("REFERENCE","ROSSFAST")
M={
 "route":re.compile(r"^F_ROSS19_ROUTE=(REFERENCE|ROSSFAST)$",re.M),
 "cases":re.compile(r"^F_ROSS19_CASE_COUNT=(\d+)$",re.M),
 "reps":re.compile(r"^F_ROSS19_INNER_REPETITIONS=(\d+)$",re.M),
 "solves":re.compile(r"^F_ROSS19_TIMED_SOLVE_COUNT=(\d+)$",re.M),
 "cpu":re.compile(r"^F_ROSS19_SOLVER_CPU_SECONDS=\s*([0-9.Ee+\-]+)$",re.M),
 "checksum":re.compile(r"^F_ROSS19_CHECKSUM=\s*([0-9.Ee+\-]+)$",re.M),
 "paired":re.compile(r"^F_ROSS19_PAIRED_ADMISSIBLE_COUNT=(\d+)$",re.M),
 "disc":re.compile(r"^F_ROSS19_DISCREPANCY_FAIL_COUNT=(\d+)$",re.M),
 "gate":re.compile(r"^F_ROSS19_GATE=PASS$",re.M),
}
def child_cpu():
 u=resource.getrusage(resource.RUSAGE_CHILDREN); return float(u.ru_utime+u.ru_stime)
def parse(text,route):
 v={}
 for n,p in M.items():
  m=p.search(text)
  if not m: raise RuntimeError(f"missing {n}\n{text}")
  v[n]=True if n=="gate" else m.group(1)
 if v["route"]!=route: raise RuntimeError("route mismatch")
 if int(v["cases"])!=36 or int(v["reps"])!=200 or int(v["solves"])!=7200: raise RuntimeError("dimension drift")
 cpu=float(v["cpu"])
 if not math.isfinite(cpu) or cpu<=0: raise RuntimeError("invalid CPU")
 return {"route":route,"solver_cpu_seconds":cpu,"checksum_text":str(v["checksum"]),
         "paired_valid_count":int(v["paired"]),"discrepancy_fail_count":int(v["disc"])}
def run(exe,route,cpu,cycle,measured):
 env=os.environ.copy(); env["SWAP5_ROSS19_ROUTE"]=route; env["OMP_NUM_THREADS"]="1"
 def pin(): os.sched_setaffinity(0,{cpu})
 cb=child_cpu(); wb=time.perf_counter_ns()
 p=subprocess.run([str(exe.resolve())],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,check=False,preexec_fn=pin)
 wa=time.perf_counter_ns(); ca=child_cpu()
 if p.returncode: raise RuntimeError(f"{route} failed {p.returncode}\n{p.stdout}")
 r=parse(p.stdout,route); r.update({"cycle":cycle,"measured":measured,"child_cpu_seconds":ca-cb,
                                   "wall_elapsed_seconds":(wa-wb)/1e9,"target_cpu":cpu})
 print("F_ROSS19_SAMPLE="+json.dumps(r,sort_keys=True,separators=(",",":")),flush=True); return r
def dist(v):
 return {"n":len(v),"mean":statistics.fmean(v),"median":statistics.median(v),
         "stdev":statistics.stdev(v) if len(v)>1 else 0.0,"min":min(v),"max":max(v)}
def model():
 try:
  for l in Path("/proc/cpuinfo").read_text(errors="replace").splitlines():
   if l.lower().startswith("model name") and ":" in l: return l.split(":",1)[1].strip()
 except OSError: pass
 return None
def main():
 ap=argparse.ArgumentParser(); ap.add_argument("--executable",type=Path,required=True); ap.add_argument("--output",type=Path,required=True); a=ap.parse_args()
 cpus=sorted(os.sched_getaffinity(0)); cpu=cpus[0]; checks={}; samples=[]
 for _ in range(WARMUPS):
  for route in ROUTES:
   r=run(a.executable,route,cpu,-1,False); checks.setdefault(route,r["checksum_text"])
   if checks[route]!=r["checksum_text"]: raise RuntimeError("warmup checksum drift")
 for cycle in range(PAIRS):
  order=ROUTES if cycle%2==0 else tuple(reversed(ROUTES))
  for route in order:
   r=run(a.executable,route,cpu,cycle,True); checks.setdefault(route,r["checksum_text"])
   if checks[route]!=r["checksum_text"]: raise RuntimeError("measured checksum drift")
   samples.append(r)
 pairs={}
 for r in samples: pairs.setdefault(r["cycle"],{})[r["route"]]=r
 deltas=[]; speed=[]; child=[]; wall=[]
 for c in sorted(pairs):
  ref=pairs[c]["REFERENCE"]; ross=pairs[c]["ROSSFAST"]
  deltas.append(ross["solver_cpu_seconds"]/ref["solver_cpu_seconds"]-1)
  speed.append(ref["solver_cpu_seconds"]/ross["solver_cpu_seconds"])
  child.append(ross["child_cpu_seconds"]/ref["child_cpu_seconds"]-1)
  wall.append(ross["wall_elapsed_seconds"]/ref["wall_elapsed_seconds"]-1)
 d=dist(deltas); mde=K*d["stdev"]/math.sqrt(PAIRS); mean=d["mean"]
 outcome="SCREENING_ROSSFAST_FASTER" if mean < -mde else ("SCREENING_REFERENCE_FASTER" if mean > mde else "SCREENING_NOT_RESOLVED")
 result={"schema":"swap5.f-ross19.adaptive-performance-screen.v1","host":{"platform":platform.platform(),"cpu_model":model(),"classification":"GITHUB_HOSTED_SCREENING_ONLY"},
         "measurement":{"warmups":WARMUPS,"pairs":PAIRS,"case_count":36,"inner_repetitions_per_case":200,"timed_solves_per_sample":7200,"target_cpu":cpu,"outlier_deletion":False},
         "route_checksums":checks,"paired_valid_count":samples[0]["paired_valid_count"],"discrepancy_fail_count":samples[0]["discrepancy_fail_count"],
         "rossfast_over_reference_relative_delta":{**d,"mde":mde,"target_resolution_relative":TARGET,"target_resolution_qualified":mde<=TARGET},
         "reference_over_rossfast_speedup":dist(speed),"whole_child_cpu_relative_delta":dist(child),"wall_elapsed_relative_delta":dist(wall),
         "screening_outcome":outcome,"formal_performance_claim":False,"samples":samples}
 a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
 print(json.dumps(result,indent=2,sort_keys=True)); print(f"F_ROSS19_SCREENING_OUTCOME={outcome}"); print(f"F_ROSS19_MEAN_RELATIVE_DELTA={mean:.12g}")
 print(f"F_ROSS19_MDE={mde:.12g}"); print(f"F_ROSS19_MEAN_REFERENCE_OVER_ROSSFAST={statistics.fmean(speed):.12g}"); print("F_ROSS19_PERFORMANCE_GATE=PASS")
 return 0
if __name__=="__main__": raise SystemExit(main())
