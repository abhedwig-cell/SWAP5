#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def execute(exe,reg,h,d,dt):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC56_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC56_FAIL missing row")
    return row

def sem(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","indicator_available","indicator_binf","indicator_raw","indicator_defect")
    return tuple(r.get(k) for k in keys)

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
                    for idx,dt in enumerate(DTS):
                        r=execute(exe,reg,h,d,dt)
                        r["_retry"]=idx
                        rr.append(r)
        rows[tag]=rr
    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC56_FAIL key drift")
    for k in a0:
        if sem(a0[k])!=sem(a2[k]): raise SystemExit(f"F_PE_ELASTIC56_FAIL O0/O2 {k}")
    print("F_PE_ELASTIC56_A3_O0_O2=PASS")

    rr=rows["O2"]
    violations=[]
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=[r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d]
                seq=sorted(seq,key=lambda r:r["_retry"])
                retained=[r for r in seq if int(r["full_status"])==1 and r["indicator_available"]=="T"]
                if len(retained) < 3:
                    continue
                increasing=[]
                for prev,nxt in zip(retained,retained[1:]):
                    b0=float(prev["indicator_binf"]); b1=float(nxt["indicator_binf"])
                    if b1 <= b0*(1+1e-12):
                        continue
                    i0=prev["_retry"]; i1=nxt["_retry"]
                    cls="CONTIGUOUS" if i1==i0+1 else "GAP"
                    rel=b1/b0-1.0 if b0>0 else math.inf
                    mag="SMALL" if rel<=0.05 else ("MODERATE" if rel<=0.25 else "LARGE")
                    p0=prev["all_converged"]=="T"; p1=nxt["all_converged"]=="T"
                    h0=float(prev["dh_inf"]) if p0 else math.nan
                    h1=float(nxt["dh_inf"]) if p1 else math.nan
                    margin0=(ALPHA*b0-h0) if p0 else math.nan
                    margin1=(ALPHA*b1-h1) if p1 else math.nan
                    gaps=[]
                    for j in range(i0+1,i1):
                        x=seq[j]
                        gaps.append(f"{j}:{x['full_status']}:{x['indicator_available']}")
                    increasing.append(dict(profile=a.profile_id,regime=reg,h0=h,delta=d,
                             retry0=i0,retry1=i1,dt0=float(prev["dt"]),dt1=float(nxt["dt"]),
                             b0=b0,b1=b1,growth=b1/b0 if b0>0 else math.inf,rel=rel,
                             cls=cls,mag=mag,p0=p0,p1=p1,hinf0=h0,hinf1=h1,
                             margin0=margin0,margin1=margin1,gaps=",".join(gaps) if gaps else "NONE"))
                if increasing:
                    worst=max(increasing,key=lambda x:x["growth"])
                    worst["transition_count"]=len(increasing)
                    violations.append(worst)

    print(f"ELASTIC56_PROFILE_COUNT|profile={a.profile_id}|violations={len(violations)}")
    for v in violations:
        print("ELASTIC56_VIOLATION|"+("|".join([
            f"profile={v['profile']}",f"regime={v['regime']}",f"h0={v['h0']}",f"delta={v['delta']}",
            f"retry0={v['retry0']}",f"retry1={v['retry1']}",f"dt0={v['dt0']}",f"dt1={v['dt1']}",
            f"binf0={v['b0']:.17e}",f"binf1={v['b1']:.17e}",f"growth={v['growth']:.17e}",
            f"rel_increase={v['rel']:.17e}",f"class={v['cls']}",f"magnitude={v['mag']}",
            f"paired0={'T' if v['p0'] else 'F'}",f"paired1={'T' if v['p1'] else 'F'}",
            f"hinf0={v['hinf0']}",f"hinf1={v['hinf1']}",f"margin0={v['margin0']}",f"margin1={v['margin1']}",
            f"gaps={v['gaps']}",f"transition_count={v['transition_count']}"
        ])))
    print("F_PE_ELASTIC56_PROFILE=PASS")

if __name__=="__main__":
    main()
