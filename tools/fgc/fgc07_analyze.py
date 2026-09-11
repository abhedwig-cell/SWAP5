#!/usr/bin/env python3
from __future__ import annotations
import csv, json, math, subprocess, sys
from pathlib import Path

EXE = Path(sys.argv[1])
OUT = Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
SY_CLASSES = [0.20, 0.05]
DT_LEVELS = [0.5, 0.25, 0.125, 0.0625, 0.03125]
INTERNAL_TARGET = 1.0/64.0
REF_DT = 1.0/128.0


def run_case(sy: float, dt: float, nint: int, scheme: str) -> dict:
    p = subprocess.run([str(EXE), f"{sy:.17g}", f"{dt:.17g}", str(nint), scheme],
                       text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180, check=False)
    if p.returncode != 0:
        print(p.stdout, file=sys.stderr)
        raise SystemExit(f"F-GC07 executable failed Sy={sy} dt={dt} nint={nint} scheme={scheme}")
    line = next((x for x in p.stdout.splitlines() if x.startswith("FGC07_RESULT:")), None)
    if line is None or "FGC07_TEMPORAL_COUPLING_CASE PASS" not in p.stdout:
        print(p.stdout, file=sys.stderr)
        raise SystemExit("F-GC07 result marker missing")
    fields = {}
    for token in line[len("FGC07_RESULT:"):].split(":"):
        k, v = token.split("=", 1)
        fields[k] = v.strip()
    ints = {"NINT", "TRIALS", "NONLINEAR", "LINEAR", "JAC", "RETRIES"}
    row = {k: (int(v) if k in ints else (v if k == "SCHEME" else float(v))) for k, v in fields.items()}
    row["stdout"] = p.stdout
    nwin = round(1.0/dt)
    expected_trials = nwin * {"PRED": 1, "PC1": 2, "PC4": 5}[scheme]
    if row["TRIALS"] != expected_trials:
        raise SystemExit(f"unexpected trial count {row['TRIALS']} expected {expected_trials}")
    if abs(row["INTERFACE_MASS_CM"]) > 1e-13:
        raise SystemExit(f"interface mass identity violated {row['INTERFACE_MASS_CM']}")
    if row["MAX_SWAP_MASS_CM"] > 1e-10:
        raise SystemExit(f"SWAP mass gate violated {row['MAX_SWAP_MASS_CM']}")
    return row


def observed_orders(rows: list[dict], key: str) -> list[float | None]:
    out = []
    for a, b in zip(rows[:-1], rows[1:]):
        ea, eb = a[key], b[key]
        if ea > 0.0 and eb > 0.0 and math.isfinite(ea) and math.isfinite(eb):
            out.append(math.log(ea/eb, 2.0))
        else:
            out.append(None)
    return out


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k:r.get(k) for k in fields})


def write_svg(path: Path, series: list[tuple[str,list[tuple[float,float]]]], title: str, ylabel: str) -> None:
    pts = [(x,y) for _,s in series for x,y in s if x>0 and y>0 and math.isfinite(x) and math.isfinite(y)]
    if not pts:
        path.write_text("<svg xmlns='http://www.w3.org/2000/svg' width='800' height='500'><text x='20' y='40'>No positive finite data</text></svg>\n")
        return
    lx=[math.log10(x) for x,y in pts]; ly=[math.log10(y) for x,y in pts]
    xmin,xmax=min(lx),max(lx); ymin,ymax=min(ly),max(ly)
    if xmin==xmax: xmax=xmin+1
    if ymin==ymax: ymax=ymin+1
    W,H=800,500; L,R,T,B=90,30,55,70
    def xy(x,y):
        xx=L+(math.log10(x)-xmin)/(xmax-xmin)*(W-L-R)
        yy=T+(ymax-math.log10(y))/(ymax-ymin)*(H-T-B)
        return xx,yy
    chunks=[f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}' height='{H}'>",
            f"<text x='{W/2}' y='28' text-anchor='middle' font-size='18'>{title}</text>",
            f"<line x1='{L}' y1='{H-B}' x2='{W-R}' y2='{H-B}' stroke='black'/>",
            f"<line x1='{L}' y1='{T}' x2='{L}' y2='{H-B}' stroke='black'/>",
            f"<text x='{W/2}' y='{H-18}' text-anchor='middle'>coupling window DeltaT [day]</text>",
            f"<text x='18' y='{H/2}' transform='rotate(-90 18 {H/2})' text-anchor='middle'>{ylabel}</text>"]
    dash=["","6,4","2,3","10,3,2,3"]
    for idx,(name,s) in enumerate(series):
        pp=[xy(x,y) for x,y in s if x>0 and y>0 and math.isfinite(x) and math.isfinite(y)]
        if len(pp)>=2:
            d=" ".join(("M" if j==0 else "L")+f"{a:.1f},{b:.1f}" for j,(a,b) in enumerate(pp))
            chunks.append(f"<path d='{d}' fill='none' stroke='black' stroke-width='{1+idx%3}' stroke-dasharray='{dash[idx%len(dash)]}'/>")
        for a,b in pp: chunks.append(f"<circle cx='{a:.1f}' cy='{b:.1f}' r='{3+idx%2}' fill='white' stroke='black'/>")
        chunks.append(f"<text x='{W-R-190}' y='{T+18*idx}' font-size='12'>{name}</text>")
    chunks.append("</svg>\n")
    path.write_text("\n".join(chunks))

raw=[]
refs={}
for sy in SY_CLASSES:
    refs[sy]=run_case(sy, REF_DT, 1, "PC4")
    raw.append(refs[sy])
    for scheme in ("PRED","PC1"):
        for dt in DT_LEVELS:
            nint=max(1,round(dt/INTERNAL_TARGET))
            raw.append(run_case(sy,dt,nint,scheme))
    raw.append(run_case(sy,0.25,16,"PC4"))
    for nint in (1,2,4,8,16,32,64):
        raw.append(run_case(sy,0.25,nint,"PC1"))

# Deduplicate exact repeated runs while keeping deterministic order.
uniq=[]; seen=set()
for r in raw:
    key=(r["SY"],r["DTC"],r["NINT"],r["SCHEME"])
    if key not in seen:
        seen.add(key); uniq.append(r)
raw=uniq

metrics={"reference":{},"coupling_convergence":{},"internal_refinement":{},"corrector_contraction":{}}
plot_series=[]
for sy in SY_CLASSES:
    ref=refs[sy]
    metrics["reference"][str(sy)]={k:ref[k] for k in ("DTC","NINT","SCHEME","FINAL_H_CM","CUM_QSWAP_CM","MAX_HEAD_RES_CM","TRIALS")}
    for scheme in ("PRED","PC1"):
        rows=sorted([r for r in raw if r["SY"]==sy and r["SCHEME"]==scheme and r["DTC"] in DT_LEVELS and r["NINT"]==max(1,round(r["DTC"]/INTERNAL_TARGET))], key=lambda r:r["DTC"], reverse=True)
        for r in rows:
            r["HEAD_ERROR_REF_CM"]=abs(r["FINAL_H_CM"]-ref["FINAL_H_CM"])
            r["FLUX_ERROR_REF_CM"]=abs(r["CUM_QSWAP_CM"]-ref["CUM_QSWAP_CM"])
            r["STEP_EST_HEAD_CM"]=None
        for i in range(len(rows)-1):
            rows[i]["STEP_EST_HEAD_CM"]=abs(rows[i]["FINAL_H_CM"]-rows[i+1]["FINAL_H_CM"])
        orders_h=observed_orders(rows,"HEAD_ERROR_REF_CM")
        orders_q=observed_orders(rows,"FLUX_ERROR_REF_CM")
        ratios=[]
        for r in rows[:-1]:
            eta=r["STEP_EST_HEAD_CM"]; err=r["HEAD_ERROR_REF_CM"]
            if eta and eta>0: ratios.append(err/eta)
        key=f"Sy={sy}:{scheme}"
        metrics["coupling_convergence"][key]={
            "rows":[{k:r.get(k) for k in ("DTC","NINT","FINAL_H_CM","CUM_QSWAP_CM","HEAD_ERROR_REF_CM","FLUX_ERROR_REF_CM","STEP_EST_HEAD_CM","MAX_HEAD_RES_CM","TRIALS","NONLINEAR","LINEAR")} for r in rows],
            "observed_order_head_pairs":orders_h,
            "observed_order_flux_pairs":orders_q,
            "step_estimator_error_over_eta_range":[min(ratios),max(ratios)] if ratios else None
        }
        plot_series.append((key,[(r["DTC"],r["HEAD_ERROR_REF_CM"]) for r in rows]))

    ir=sorted([r for r in raw if r["SY"]==sy and r["DTC"]==0.25 and r["SCHEME"]=="PC1" and r["NINT"] in (1,2,4,8,16,32,64)], key=lambda r:r["NINT"])
    iref=ir[-1]
    irows=[]
    for r in ir[:-1]:
        irows.append({"NINT":r["NINT"],"INTERNAL_DT_DAY":0.25/r["NINT"],
                      "HEAD_ERROR_FIXED_DTC_CM":abs(r["FINAL_H_CM"]-iref["FINAL_H_CM"]),
                      "FLUX_ERROR_FIXED_DTC_CM":abs(r["CUM_QSWAP_CM"]-iref["CUM_QSWAP_CM"]),
                      "TRIALS":r["TRIALS"],"NONLINEAR":r["NONLINEAR"],"LINEAR":r["LINEAR"]})
    metrics["internal_refinement"][str(sy)]={"reference_nint":64,"rows":irows}

    pc4=next(r for r in raw if r["SY"]==sy and r["DTC"]==0.25 and r["NINT"]==16 and r["SCHEME"]=="PC4")
    rvals=[pc4[f"R{i}_CM"] for i in range(5)]
    contractions=[rvals[i]/rvals[i-1] if rvals[i-1]>0 else None for i in range(1,5)]
    metrics["corrector_contraction"][str(sy)]={"max_residual_by_stage_cm":rvals,"stage_contraction_ratio":contractions,"trials":pc4["TRIALS"]}

write_csv(OUT/"fgc07_raw_results.csv",raw,["SY","DTC","NINT","SCHEME","FINAL_H_CM","CUM_QSWAP_CM","MAX_HEAD_RES_CM","MAX_SWAP_MASS_CM","INTERFACE_MASS_CM","TRIALS","NONLINEAR","LINEAR","JAC","RETRIES","R0_CM","R1_CM","R2_CM","R3_CM","R4_CM"])
write_svg(OUT/"fgc07_head_convergence.svg",plot_series,"F-GC07 controlled coupling-window convergence","final groundwater-head error vs refined PC4 numerical reference [cm]")

payload={
  "schema_version":1,
  "work_unit":"F-GC07",
  "canonical_source_head":"0aeb0a2ed4096e1f9493d3dabc70962ea5270182",
  "reference_is_physical_truth":False,
  "reference_definition":{"scheme":"PC4","DeltaT_day":REF_DT,"SWAP_internal_substeps_per_window":1,"horizon_day":1.0,"origin_day":4100.125},
  "test_classes":{"Sy=0.2":"moderate simple-aquifer storage response","Sy=0.05":"more responsive simple-aquifer storage response"},
  "interface_mass_contract":"q_SWAP + q_GW = 0 algebraically for every accepted transfer; rejected predictor/corrector trials are not booked",
  "metrics":metrics,
  "raw_run_count":len(raw)
}
(OUT/"fgc07_results.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")
print(f"FGC07_ANALYSIS_RAW_RUNS={len(raw)}")
print("FGC07_ANALYSIS_MASS_CONTRACT=PASS")
print("FGC07_ANALYSIS_REFERENCE_NONTRUTH_DECLARATION=PASS")
print("FGC07_ANALYSIS PASS")
