#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, statistics, subprocess

ALPHA=0.17320259355765216
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.035,0.035)
DTS=(0.015625,0.0078125,0.00390625,0.001953125)
BANDS=(
    ("LE_0P01",0.0,0.01),
    ("0P01_0P05",0.01,0.05),
    ("0P05_0P10",0.05,0.10),
    ("0P10_0P25",0.10,0.25),
    ("0P25_0P50",0.25,0.50),
    ("GT_0P50",0.50,float("inf")),
)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def run(exe,reg,h,d,dt):
    cp=subprocess.run([exe,reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC58_BANK|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC58_FAIL missing row")
    return row

def semantic(r):
    keys=("full_status","indicator_available","indicator_binf","ref8_ok","ref16_ok","ref_stable",
          "href16","href8_16","thetaref16","storage_ref_signed","storage_ref_l1")
    return tuple(r.get(k) for k in keys)

def band_name(x):
    for name,lo,hi in BANDS:
        if name=="LE_0P01":
            if x<=hi: return name
        elif name=="GT_0P50":
            if x>lo: return name
        elif lo < x <= hi:
            return name
    raise RuntimeError(x)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    a=ap.parse_args()
    rows={}
    for tag,exe in (("O0",a.o0),("O2",a.o2)):
        rr=[]
        for h in HEADS:
            for d in DELTAS:
                for reg in REGIMES:
                    for dt in DTS:
                        rr.append(run(exe,reg,h,d,dt))
        rows[tag]=rr
    if len(rows["O0"])!=96 or len(rows["O2"])!=96:
        raise SystemExit("F_PE_ELASTIC58_FAIL profile case count")
    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]};a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC58_FAIL O0/O2 keys")
    for k in a0:
        if semantic(a0[k])!=semantic(a2[k]):
            raise SystemExit(f"F_PE_ELASTIC58_FAIL O0/O2 drift {k}")
    rr=rows["O2"]
    full=[r for r in rr if int(r["full_status"])==1]
    for r in full:
        if r["indicator_available"]!="T":
            raise SystemExit("F_PE_ELASTIC58_FAIL full without indicator")
        b=float(r["indicator_binf"])
        if not math.isfinite(b) or b<0: raise SystemExit("F_PE_ELASTIC58_FAIL bad Binf")
    qualified=[]
    for r in rr:
        if int(r["full_status"])!=1 or r["indicator_available"]!="T" or r["ref_stable"]!="T":
            continue
        b=float(r["indicator_binf"]); eb=ALPHA*b; h=float(r["href16"])
        vals=[h,float(r["href8_16"]),float(r["thetaref16"]),float(r["storage_ref_signed"]),float(r["storage_ref_l1"])]
        if not all(math.isfinite(x) and x>=0 for x in vals):
            raise SystemExit("F_PE_ELASTIC58_FAIL nonfinite reference metric")
        ratio=h/eb if eb>0 else (0.0 if h==0 else math.inf)
        qualified.append((r,eb,h,ratio))
    failures=[x for x in qualified if x[2] > x[1]*(1+1e-12)]
    print(f"ELASTIC58_PROFILE_SUMMARY|profile={a.profile_id}|cases=96|full_converged={len(full)}|reference_qualified={len(qualified)}|envelope_failures={len(failures)}")
    for r,eb,h,ratio in failures:
        print(f"ELASTIC58_ENVELOPE_FAIL|profile={a.profile_id}|regime={r['regime']}|h0={r['h0']}|delta={r['delta']}|dt={r['dt']}|ebound={eb:.17e}|href={h:.17e}|ratio={ratio:.17e}")
    by={name:[] for name,_,_ in BANDS}
    for item in qualified: by[band_name(item[1])].append(item)
    for name,_,_ in BANDS:
        vals=by[name]
        if not vals:
            print(f"ELASTIC58_BAND|profile={a.profile_id}|band={name}|count=0")
            continue
        hs=[x[2] for x in vals]; ratios=[x[3] for x in vals if math.isfinite(x[3])]
        print(f"ELASTIC58_BAND|profile={a.profile_id}|band={name}|count={len(vals)}|median_href={statistics.median(hs):.17e}|max_href={max(hs):.17e}|max_ratio={max(ratios) if ratios else float('nan'):.17e}")
    print(f"ELASTIC58_ALPHA_FROZEN={ALPHA:.17e}")
    print("F_PE_ELASTIC58_PROFILE=PASS")

if __name__=="__main__":
    main()
