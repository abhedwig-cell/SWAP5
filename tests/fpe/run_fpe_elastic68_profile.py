#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)
BUDGETS=(0.01,0.02,0.05,0.10,0.20)
HEAD_SCREEN=0.10
THETA_SCREEN=1.0e-4

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def execute(exe,reg,h,d,dt):
    cp=subprocess.run([exe,reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC68_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse(line)
    if row is None:
        raise SystemExit("F_PE_ELASTIC68_FAIL missing ELASTIC55_BANK")
    return row

def semantic(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","dh_node","dtheta_inf",
          "dtheta_node","dpond","dgwl","indicator_available","indicator_binf","indicator_raw","indicator_defect",
          "full_nonlinear","half1_nonlinear","half2_nonlinear")
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
                    for dt in DTS:
                        rr.append(execute(exe,reg,h,d,dt))
        rows[tag]=rr

    if len(rows["O0"])!=432 or len(rows["O2"])!=432:
        raise SystemExit("F_PE_ELASTIC68_FAIL requested case count")

    def key(r):
        return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC68_FAIL O0/O2 key drift")
    for k in a0:
        if semantic(a0[k])!=semantic(a2[k]):
            raise SystemExit(f"F_PE_ELASTIC68_FAIL O0/O2 drift {k}")

    r2=rows["O2"]
    by_origin={}
    for r in r2:
        o=(r["regime"],float(r["h0"]),float(r["delta"]))
        by_origin.setdefault(o,[]).append(r)
    if len(by_origin)!=48:
        raise SystemExit(f"F_PE_ELASTIC68_FAIL origins={len(by_origin)}")
    for o in by_origin:
        by_origin[o]=sorted(by_origin[o],key=lambda r:float(r["dt"]),reverse=True)

    for budget in BUDGETS:
        accepted=[]; exhausted=0; total_rejections=0; total_work=0
        paired=0; head_max=0.0; theta_max=0.0; head_fail=0; theta_fail=0
        regime_accept={x:0 for x in REGIMES}
        for o,seq in sorted(by_origin.items()):
            chosen=None; attempts=0; work=0
            for r in seq:
                attempts += 1
                work += int(r["full_nonlinear"])
                ok=(int(r["full_status"])==1 and r["indicator_available"]=="T")
                if ok:
                    b=float(r["indicator_binf"])
                    ok=math.isfinite(b) and b>=0.0 and ALPHA*b <= budget*(1.0+1e-12)
                if ok:
                    chosen=r
                    break
            total_work += work
            if chosen is None:
                exhausted += 1
                total_rejections += len(seq)
                continue
            total_rejections += attempts-1
            accepted.append(chosen)
            regime_accept[o[0]] += 1
            pair=chosen["all_converged"]=="T"
            if pair:
                paired += 1
                dh=float(chosen["dh_inf"]); dt=float(chosen["dtheta_inf"])
                head_max=max(head_max,dh); theta_max=max(theta_max,dt)
                if dh > HEAD_SCREEN*(1+1e-12): head_fail += 1
                if dt > THETA_SCREEN*(1+1e-12): theta_fail += 1
            print(
                "ELASTIC68_ACCEPT|profile=%d|budget=%.17g|regime=%s|h0=%.17g|delta=%.17g|dt=%.17g|rejections=%d|work=%d|paired=%s|dh=%.17e|dtheta=%.17e|binf=%.17e"
                % (a.profile_id,budget,o[0],o[1],o[2],float(chosen["dt"]),attempts-1,work,
                   "T" if pair else "F",float(chosen["dh_inf"]),float(chosen["dtheta_inf"]),float(chosen["indicator_binf"]))
            )
        mean_rej=(total_rejections/len(by_origin)) if by_origin else 0.0
        print(
            "ELASTIC68_ARM_PROFILE|profile=%d|budget=%.17g|accepted=%d|exhausted=%d|rejections=%d|mean_rejections=%.17e|work=%d|paired=%d|head_max=%.17e|theta_max=%.17e|head_fail=%d|theta_fail=%d|off=%d|fixed=%d|generated=%d"
            % (a.profile_id,budget,len(accepted),exhausted,total_rejections,mean_rej,total_work,paired,
               head_max,theta_max,head_fail,theta_fail,regime_accept["OFF"],regime_accept["FIXED_1E6"],regime_accept["GENERATED"])
        )
    print("F_PE_ELASTIC68_PROFILE=PASS")

if __name__=="__main__":
    main()
