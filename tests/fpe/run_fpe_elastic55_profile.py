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
    cp=subprocess.run([exe,reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC55_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None; meta=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse(line)
        elif line.startswith("ELASTIC55_META|"): meta=parse(line)
    if row is None or meta is None:
        raise SystemExit("F_PE_ELASTIC55_FAIL missing row/meta")
    return row,meta

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
    metas=[]
    for tag,exe in (("O0",a.o0),("O2",a.o2)):
        rr=[]
        for h in HEADS:
            for d in DELTAS:
                for reg in REGIMES:
                    for dt in DTS:
                        r,m=execute(exe,reg,h,d,dt)
                        rr.append(r); metas.append(m)
        rows[tag]=rr
    if len(rows["O0"])!=432 or len(rows["O2"])!=432:
        raise SystemExit("F_PE_ELASTIC55_FAIL requested case count")

    def key(r):
        return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC55_FAIL key drift")
    for k in a0:
        if semantic(a0[k])!=semantic(a2[k]):
            raise SystemExit(f"F_PE_ELASTIC55_FAIL O0/O2 drift {k}")

    r2=rows["O2"]
    full=[r for r in r2 if int(r["full_status"])==1]
    for r in full:
        if r["indicator_available"]!="T":
            raise SystemExit("F_PE_ELASTIC55_FAIL converged full without indicator")
        b=float(r["indicator_binf"])
        if not math.isfinite(b) or b<0: raise SystemExit("F_PE_ELASTIC55_FAIL invalid Binf")

    paired=[r for r in r2 if r["all_converged"]=="T" and r["indicator_available"]=="T" and
            float(r["dh_inf"])>0 and float(r["indicator_binf"])>0]
    failures=[]
    ratios=[]
    per_reg={r:[] for r in REGIMES}
    for r in paired:
        h=float(r["dh_inf"]); b=float(r["indicator_binf"]); ratio=h/b
        ratios.append(ratio); per_reg[r["regime"]].append(ratio)
        if h > ALPHA*b*(1+1e-12):
            failures.append((r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]),h,b,ratio))

    monotonic_seq=0; monotonic_bad=0
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=[r for r in r2 if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d
                     and int(r["full_status"])==1 and r["indicator_available"]=="T"]
                seq=sorted(seq,key=lambda r:float(r["dt"]),reverse=True)
                if len(seq)>=3:
                    monotonic_seq+=1
                    vals=[float(r["indicator_binf"]) for r in seq]
                    if any(vals[i+1] > vals[i]*(1+1e-12) for i in range(len(vals)-1)):
                        monotonic_bad+=1

    # Metadata is repeated; all entries must agree on profile and Ss span.
    pids={int(m["profile"]) for m in metas}
    ssmins={float(m["ss_min"]) for m in metas}; ssmaxs={float(m["ss_max"]) for m in metas}
    if pids!={a.profile_id} or len(ssmins)!=1 or len(ssmaxs)!=1:
        raise SystemExit("F_PE_ELASTIC55_FAIL metadata drift")
    maxratio=max(ratios) if ratios else 0.0
    print(f"ELASTIC55_PROFILE_SUMMARY|profile={a.profile_id}|cases=432|full_converged={len(full)}|paired={len(paired)}|failures={len(failures)}|max_ratio={maxratio:.17e}|ss_min={next(iter(ssmins)):.17e}|ss_max={next(iter(ssmaxs)):.17e}|monotonic_sequences={monotonic_seq}|monotonic_violations={monotonic_bad}")
    for reg in REGIMES:
        if per_reg[reg]:
            print(f"ELASTIC55_REGIME_MAX|profile={a.profile_id}|regime={reg}|max_ratio={max(per_reg[reg]):.17e}")
    for x in failures:
        print("ELASTIC55_ENVELOPE_FAIL|profile="+str(a.profile_id)+"|regime="+x[0]+
              f"|h0={x[1]}|delta={x[2]}|dt={x[3]}|hinf={x[4]:.17e}|binf={x[5]:.17e}|ratio={x[6]:.17e}")
    print(f"ELASTIC55_ALPHA_FROZEN={ALPHA:.17e}")
    print("F_PE_ELASTIC55_PROFILE=PASS")

if __name__=="__main__":
    main()
