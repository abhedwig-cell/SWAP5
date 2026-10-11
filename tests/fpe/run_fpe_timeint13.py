#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

cand_order=Path(sys.argv[1])
full_bdf2=Path(sys.argv[2])
cand_dyn=Path(sys.argv[3])
be_dyn=Path(sys.argv[4])
bank=json.loads(Path(sys.argv[5]).read_text())
mats={x["id"]:x for x in bank["materials"]}

smooth=[("B01",2.0),("B01",4.0),("O05",2.0),("O05",4.0)]
dts=[0.01,0.005,0.0025,0.00125]
dyn_regs={"MOIST":(-50.0,8.0),"WET":(-20.0,12.0),"POND":(-5.0,25.0)}

def run_order(mid,rain,dt):
    m=mats[mid]
    cmd=[str(cand_order),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt)]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    out={"ok":cp.returncode==0,"material":mid,"rain":rain,"dt":dt,
         "stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT13_ORDER_RESULT|")),None)
        if not line:
            out["ok"]=False; out["stderr"]="missing result"; return out
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        for k in ("TOP_H","MID_H","BOTTOM_H","STORAGE"): out[k.lower()]=float(d[k])
        for k in ("NL","BACK","JAC","LIN","WORK","STEPS","CLAMPS"): out[k.lower()]=int(d[k])
        out["work_per_step"]=out["work"]/out["steps"]
    return out

def run_full(mid,rain,dt):
    m=mats[mid]
    cmd=[str(full_bdf2),mid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
         str(m["ksat"]),str(m["lambda"]),str(rain),str(dt),"R1","1","8"]
    cp=subprocess.run(cmd,text=True,capture_output=True)
    out={"ok":cp.returncode==0,"material":mid,"rain":rain,"dt":dt}
    if out["ok"]:
        line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT05_RESULT|")),None)
        if not line: out["ok"]=False; return out
        d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
        for k in ("NL","BACK","JAC","LIN","STEPS"): out[k.lower()]=int(d[k])
        out["work"]=out["nl"]+out["back"]+out["jac"]+out["lin"]
        out["work_per_step"]=out["work"]/out["steps"]
    return out

def order3(a,b,c,key):
    if not all(x["ok"] for x in (a,b,c)): return None
    d1=abs(a[key]-b[key]); d2=abs(b[key]-c[key])
    scale=max(1.0,abs(a[key]),abs(b[key]),abs(c[key]))
    if d1<=1e-12*scale or d2<=1e-12*scale: return None
    return math.log(d1/d2,2.0)

p0_rows=[]; base_rows=[]
for mid,rain in smooth:
    for dt in dts:
        p0_rows.append(run_order(mid,rain,dt))
        base_rows.append(run_full(mid,rain,dt))

p0_cases=[]; orders=[]; cand_work=[]; full_work=[]
for mid,rain in smooth:
    rs=sorted([x for x in p0_rows if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
    bs=sorted([x for x in base_rows if x["material"]==mid and x["rain"]==rain],key=lambda x:-x["dt"])
    complete=all(x["ok"] for x in rs)
    p=order3(rs[1],rs[2],rs[3],"top_h") if len(rs)==4 else None
    if p is not None and math.isfinite(p): orders.append(p)
    stor=[x["storage"] for x in rs if x["ok"]]
    spread=max(stor)-min(stor) if stor else None
    clamps=sum(x.get("clamps",0) for x in rs if x["ok"])
    p0_cases.append({"material":mid,"rain":rain,"complete":complete,"p_top_refined":p,
                     "storage_spread":spread,"clamps":clamps})
    if complete:
        cand_work.extend(x["work_per_step"] for x in rs)
    if all(x["ok"] for x in bs):
        full_work.extend(x["work_per_step"] for x in bs)

med_order=statistics.median(orders) if orders else None
cand_med_work=statistics.median(cand_work) if cand_work else None
full_med_work=statistics.median(full_work) if full_work else None
work_ratio=cand_med_work/full_med_work if cand_med_work is not None and full_med_work else None
p0_pass=(all(x["complete"] for x in p0_cases) and med_order is not None and med_order>=1.6 and
         sum(x["p_top_refined"] is not None and x["p_top_refined"]>=1.5 for x in p0_cases)>=3 and
         all(x["storage_spread"] is not None and x["storage_spread"]<=1e-10 for x in p0_cases) and
         sum(x["clamps"] for x in p0_cases)==0 and work_ratio is not None and work_ratio<=1.0)

p0_summary={"pass":p0_pass,"cases":p0_cases,"median_refined_top_order":med_order,
            "cases_order_ge_1p5":sum(x["p_top_refined"] is not None and x["p_top_refined"]>=1.5 for x in p0_cases),
            "candidate_median_work_per_step":cand_med_work,
            "fully_implicit_median_work_per_step":full_med_work,
            "work_ratio_vs_fully_implicit":work_ratio,
            "total_clamps":sum(x["clamps"] for x in p0_cases)}

print("F_PE_TIMEINT13_P0_RESULTS="+json.dumps(p0_rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13_P0_BASELINE="+json.dumps(base_rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT13_P0_SUMMARY="+json.dumps(p0_summary,separators=(",",":"),sort_keys=True))

p1_rows=[]
p1_summary={"executed":False,"advance":False}
if p0_pass:
    def run_dyn_candidate(mid,rid,h0,rain):
        m=mats[mid]
        cmd=[str(cand_dyn),mid,rid,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
             str(m["ksat"]),str(m["lambda"]),str(h0),str(rain)]
        cp=subprocess.run(cmd,text=True,capture_output=True)
        out={"ok":cp.returncode==0,"material":mid,"regime":rid,"stdout":cp.stdout[-1200:],"stderr":cp.stderr[-1200:]}
        if out["ok"]:
            line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT13_DYNTOP_RESULT|")),None)
            if not line: out["ok"]=False; return out
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("STEPS","NL","BACK","JAC","LIN","ALT","WORK","CLAMPS"): out[k.lower()]=int(d[k])
            for k in ("RUNOFF","POND","STORAGE","TOP_H","MID_H","BOTTOM_H","MAX_LEDGER"): out[k.lower()]=float(d[k])
        return out

    def run_klag(mid,rid,h0,rain):
        m=mats[mid]
        cmd=[str(be_dyn),mid,"KLAG",str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
             str(m["ksat"]),str(m["lambda"]),str(h0),str(rain)]
        cp=subprocess.run(cmd,text=True,capture_output=True)
        out={"ok":cp.returncode==0,"material":mid,"regime":rid}
        if out["ok"]:
            line=next((x for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT12A_RESULT|")),None)
            if not line: out["ok"]=False; return out
            d={k:v for k,v in (f.split("=",1) for f in line.split("|")[1:])}
            for k in ("STEPS","NL","BACK","JAC","LIN","ALT","WORK"): out[k.lower()]=int(d[k])
            out["max_ledger"]=float(d["MAX_LEDGER"])
        return out

    ratios=[]; candidate_complete=[]; pond_ok=True; alt_ok=True; ledger_ok=True; clamp_steps=0; total_steps=0
    for mid in ("B01","B12","O05","O14"):
        for rid,(h0,rain) in dyn_regs.items():
            c=run_dyn_candidate(mid,rid,h0,rain)
            q=run_klag(mid,rid,h0,rain)
            row={"material":mid,"regime":rid,"candidate":c,"klag":q}
            if c["ok"] and q["ok"] and q["work"]:
                row["work_ratio"]=c["work"]/q["work"]; ratios.append(row["work_ratio"])
            else:
                row["work_ratio"]=None
            p1_rows.append(row)
            candidate_complete.append(c["ok"])
            if rid=="POND" and not c["ok"]: pond_ok=False
            if c["ok"]:
                alt_ok=alt_ok and c["alt"]==0
                ledger_ok=ledger_ok and c["max_ledger"]<=5e-8
                clamp_steps += c["clamps"]; total_steps += c["steps"]

    med_ratio=statistics.median(ratios) if ratios else None
    max_ratio=max(ratios) if ratios else None
    clamp_fraction=clamp_steps/total_steps if total_steps else None
    advance=(sum(candidate_complete)==12 and pond_ok and alt_ok and ledger_ok and
             med_ratio is not None and med_ratio<=1.15 and max_ratio is not None and max_ratio<=1.30 and
             clamp_fraction is not None and clamp_fraction<=0.05)
    p1_summary={"executed":True,"complete":sum(candidate_complete),"cases":12,"pond_ok":pond_ok,
                "alt_ok":alt_ok,"ledger_ok":ledger_ok,"median_work_ratio_vs_klag":med_ratio,
                "max_work_ratio_vs_klag":max_ratio,"clamp_fraction":clamp_fraction,"advance":advance}
    print("F_PE_TIMEINT13_P1_RESULTS="+json.dumps(p1_rows,separators=(",",":"),sort_keys=True))

print("F_PE_TIMEINT13_P1_SUMMARY="+json.dumps(p1_summary,separators=(",",":"),sort_keys=True))
classification=("EXTRAPOLATED_K_BDF2_MECHANISM_QUALIFIED" if p0_pass and p1_summary.get("advance") else
                "SMOOTH_ORDER_PASS_DYNAMIC_TOP_ROBUSTNESS_FAIL" if p0_pass else
                "CLOSED_EXTRAPOLATED_K_BDF2_NOT_SECOND_ORDER")
print("F_PE_TIMEINT13_CLASSIFICATION="+classification)
print("F_PE_TIMEINT13=PASS")
