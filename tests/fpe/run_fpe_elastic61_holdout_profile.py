#!/usr/bin/env python3
from __future__ import annotations
import argparse,math,subprocess,collections

H_LIMIT=0.01
THETA_LIMIT=1e-5
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
        raise SystemExit(f"F_PE_ELASTIC61_FAIL holdout rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC59_BANK|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC61_FAIL holdout missing row")
    return row

def sem(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","dtheta_inf",
          "indicator_available","defect_head_inf")
    return tuple(r.get(k) for k in keys)

def select(rows,alpha):
    chosen=[]; exhausted=0
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=sorted([r for r in rows if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d],
                           key=lambda r:float(r["dt"]),reverse=True)
                pick=None
                for r in seq:
                    if int(r["full_status"])!=1 or r["indicator_available"]!="T": continue
                    if alpha*float(r["defect_head_inf"])<=H_LIMIT:
                        pick=r; break
                if pick is None: exhausted+=1
                else: chosen.append(pick)
    return chosen,exhausted

def summary(name,chosen,exhausted):
    paired=[r for r in chosen if r["all_converged"]=="T"]
    hf=[r for r in paired if float(r["dh_inf"])>H_LIMIT+1e-12]
    tf=[r for r in paired if float(r["dtheta_inf"])>THETA_LIMIT+1e-12]
    sat=[r for r in chosen if float(r["h0"])>=0]; unsat=[r for r in chosen if float(r["h0"])<0]
    maxh=max((float(r["dh_inf"]) for r in paired),default=0.0)
    maxt=max((float(r["dtheta_inf"]) for r in paired),default=0.0)
    dtc=collections.Counter(float(r["dt"]) for r in chosen)
    print(f"ELASTIC61_CANDIDATE|candidate={name}|selected={len(chosen)}|exhausted={exhausted}|paired_selected={len(paired)}|sat_selected={len(sat)}|unsat_selected={len(unsat)}|head_failures={len(hf)}|theta_failures={len(tf)}|max_hinf={maxh:.17e}|max_dtheta={maxt:.17e}")
    for dt,n in sorted(dtc.items(),reverse=True):
        print(f"ELASTIC61_DT|candidate={name}|dt={dt:.17e}|count={n}")
    for r in hf[:20]:
        print(f"ELASTIC61_HEAD_FAIL|candidate={name}|regime={r['regime']}|h0={r['h0']}|delta={r['delta']}|dt={r['dt']}|defect={r['defect_head_inf']}|hinf={r['dh_inf']}")
    return dict(selected=len(chosen),exhausted=exhausted,paired=len(paired),sat=len(sat),unsat=len(unsat),
                head_fail=len(hf),theta_fail=len(tf),maxh=maxh,maxt=maxt)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--alpha",type=float,required=True)
    ap.add_argument("--o0",required=True);ap.add_argument("--o2",required=True)
    a=ap.parse_args()
    if not math.isfinite(a.alpha) or a.alpha<=0: raise SystemExit("F_PE_ELASTIC61_FAIL invalid alpha")

    rows={}
    for tag,exe in (("O0",a.o0),("O2",a.o2)):
        rr=[]
        for h in HEADS:
            for d in DELTAS:
                for reg in REGIMES:
                    for dt in DTS: rr.append(execute(exe,reg,h,d,dt))
        rows[tag]=rr
    if len(rows["O0"])!=432 or len(rows["O2"])!=432: raise SystemExit("F_PE_ELASTIC61_FAIL row count")
    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]};a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC61_FAIL key drift")
    for k in a0:
        if sem(a0[k])!=sem(a2[k]): raise SystemExit(f"F_PE_ELASTIC61_FAIL O0/O2 {k}")
    print("F_PE_ELASTIC61_A5_O0_O2=PASS")

    for r in rows["O2"]:
        if int(r["full_status"])==1 and r["indicator_available"]=="T":
            d=float(r["defect_head_inf"])
            if not math.isfinite(d) or d<0: raise SystemExit("F_PE_ELASTIC61_FAIL invalid defect")

    scaled,e_scaled=select(rows["O2"],a.alpha)
    unscaled,e_unscaled=select(rows["O2"],1.0)
    s=summary("SCALED_D1",scaled,e_scaled)
    u=summary("UNSCALED_D1",unscaled,e_unscaled)
    print(f"ELASTIC61_PROFILE|profile={a.profile_id}|alpha={a.alpha:.17e}|scaled_selected={s['selected']}|scaled_sat={s['sat']}|scaled_head_fail={s['head_fail']}|scaled_theta_fail={s['theta_fail']}|unscaled_selected={u['selected']}|unscaled_sat={u['sat']}|unscaled_head_fail={u['head_fail']}|unscaled_theta_fail={u['theta_fail']}")
    print("F_PE_ELASTIC61_HOLDOUT_PROFILE=PASS")
if __name__=="__main__": main()
