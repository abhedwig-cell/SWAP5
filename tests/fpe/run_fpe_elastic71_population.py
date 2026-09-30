#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,re,shutil,subprocess,tempfile,time
from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path

BUDGETS=(0.01,0.20)
WORKERS=(1,2,4)
SHARDS_PER_PROFILE=4

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v
    return d

def task(exe,pdir,budget,count,offset,root,tag):
    td=root/tag; td.mkdir(parents=True,exist_ok=True)
    for name in ("request.cfg","profile.rows","retention.txt"):
        shutil.copy2(pdir/name,td/name)
    (td/"population_control.txt").write_text(f"{budget:.17g} {count} {offset}\n")
    cp=subprocess.run([str(exe)],cwd=td,text=True,capture_output=True)
    if cp.returncode!=0:
        raise RuntimeError(f"task {tag} rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC71_PROFILE|"): row=parse(line)
    if row is None: raise RuntimeError(f"task {tag} missing row")
    return row

def make_tasks(manifest,build):
    tasks=[]
    for m in manifest:
        pid=int(m["profile_id"]); n=int(m["columns"])
        q,r=divmod(n,SHARDS_PER_PROFILE); offset=0
        for shard in range(SHARDS_PER_PROFILE):
            count=q+(1 if shard<r else 0)
            tasks.append((pid,shard,count,offset,build/f"p{pid}"/"rom0_test",Path(m["profile_dir"])))
            offset+=count
    if sum(x[2] for x in tasks)!=1024: raise SystemExit("F_PE_ELASTIC71_FAIL task population")
    return tasks

def run_arm(tasks,budget,workers,tmp):
    t0=time.perf_counter(); rows=[]
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futs=[]
        for pid,shard,count,offset,exe,pdir in tasks:
            tag=f"b{str(budget).replace('.','p')}_w{workers}_p{pid}_s{shard}"
            futs.append(pool.submit(task,exe,pdir,budget,count,offset,tmp,tag))
        for f in as_completed(futs): rows.append(f.result())
    sec=time.perf_counter()-t0
    agg={k:0 for k in ("count","completed","retries","temporal","mass","solver")}
    bins=[0]*10
    for r in rows:
        for k in agg: agg[k]+=int(r[k])
        vals=[int(x) for x in r["dtbins"].split()]
        if len(vals)!=10: raise SystemExit("F_PE_ELASTIC71_FAIL dtbins")
        bins=[a+b for a,b in zip(bins,vals)]
    if agg["count"]!=1024: raise SystemExit("F_PE_ELASTIC71_FAIL aggregate count")
    return agg,bins,sec

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--manifest",required=True); ap.add_argument("--build",required=True); ap.add_argument("--population-root",required=True)
    a=ap.parse_args()
    manifest=json.loads(Path(a.manifest).read_text())
    pop=Path(a.population_root)
    for m in manifest: m["profile_dir"]=str(pop/f"p{int(m['profile_id'])}")
    tasks=make_tasks(manifest,Path(a.build))
    deterministic={}
    with tempfile.TemporaryDirectory(prefix="elastic71-tasks-") as td:
        tmp=Path(td)
        for budget in BUDGETS:
            for workers in WORKERS:
                agg,bins,sec=run_arm(tasks,budget,workers,tmp)
                key=budget
                det=(tuple(agg[k] for k in ("count","completed","retries","temporal","mass","solver")),tuple(bins))
                if key in deterministic and deterministic[key]!=det:
                    raise SystemExit(f"F_PE_ELASTIC71_FAIL worker deterministic drift budget={budget}")
                deterministic[key]=det
                throughput=agg["count"]/sec
                print("ELASTIC71_ARM|budget=%.17g|workers=%d|seconds=%.9f|throughput=%.3f|count=%d|completed=%d|retries=%d|temporal=%d|mass=%d|solver=%d|dtbins=%s" %
                      (budget,workers,sec,throughput,agg["count"],agg["completed"],agg["retries"],agg["temporal"],agg["mass"],agg["solver"]," ".join(map(str,bins))))
    strict=deterministic[0.01][0]; policy=deterministic[0.20][0]
    _,sc,sr,st,sm,ss=strict
    _,pc,pr,pt,pm,ps=policy
    if pc<sc: raise SystemExit("F_PE_ELASTIC71_FAIL completion regression")
    if pr>sr: raise SystemExit("F_PE_ELASTIC71_FAIL retry regression")
    if pm!=sm or pm!=0: raise SystemExit("F_PE_ELASTIC71_FAIL mass behavior")
    if ps>ss: raise SystemExit("F_PE_ELASTIC71_FAIL solver regression")
    if not (pc>sc or pr<sr): raise SystemExit("F_PE_ELASTIC71_FAIL no deterministic work benefit")
    print(f"ELASTIC71_DETERMINISTIC|strict_completed={sc}|policy_completed={pc}|strict_retries={sr}|policy_retries={pr}|strict_temporal={st}|policy_temporal={pt}|mass={pm}|strict_solver={ss}|policy_solver={ps}")
    print("F_PE_ELASTIC71=PASS")
if __name__=="__main__": main()
