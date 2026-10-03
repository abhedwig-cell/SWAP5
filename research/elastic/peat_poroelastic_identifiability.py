#!/usr/bin/env python3
"""F-PE-ELASTIC72B offline synthetic poroelastic identifiability preflight."""
from __future__ import annotations
import argparse, json, math, random, statistics

def head_series(n_hours: int, amplitude_m: float) -> list[float]:
    return [
        amplitude_m * math.sin(2.0*math.pi*(i/24.0)/30.0)
        + 0.3*amplitude_m*math.sin(2.0*math.pi*(i/24.0)/7.0)
        for i in range(n_hours)
    ]

def slope(x, y):
    xm=statistics.fmean(x); ym=statistics.fmean(y)
    return sum((a-xm)*(b-ym) for a,b in zip(x,y))/sum((a-xm)**2 for a in x)

def estimate_ss(head_m, displacement_m, thickness_m):
    strain=[d/thickness_m for d in displacement_m]
    return -slope(head_m,strain)

def quantile(xs,p):
    xs=sorted(xs); k=(len(xs)-1)*p
    lo=math.floor(k); hi=math.ceil(k)
    if lo==hi: return xs[lo]
    return xs[lo]*(hi-k)+xs[hi]*(k-lo)

def run_mc(ss_m_inv, thickness_m, amplitude_m, noise_mm, days, reps, seed):
    h=head_series(days*24,amplitude_m)
    rng=random.Random(seed); est=[]; sigma=noise_mm/1000.0
    for _ in range(reps):
        d=[(-ss_m_inv*hh)*thickness_m+rng.gauss(0.0,sigma) for hh in h]
        est.append(estimate_ss(h,d,thickness_m))
    return {
      "ss_true_m_inv":ss_m_inv,
      "ss_true_cm_inv":ss_m_inv/100.0,
      "noise_mm":noise_mm,
      "median_m_inv":statistics.median(est),
      "p025_m_inv":quantile(est,0.025),
      "p975_m_inv":quantile(est,0.975),
      "positive_fraction":sum(v>0 for v in est)/len(est)
    }

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--output"); a=ap.parse_args()
    rows=[]
    for ss in (1e-5,3e-5,1e-4,3e-4,1e-3):
        for noise in (0.1,0.5,1.0):
            rows.append(run_mc(ss,2.0,0.2,noise,90,500,
              42072+int(ss*1e9)+int(noise*10)))
    payload={
      "relation":"Ss_skeleton ~= -d(epsilon_z)/dH",
      "scenario":{"days":90,"sampling_hours":1,"layer_thickness_m":2.0,
                  "head_amplitude_m":0.2,"replicates":500},
      "rows":rows}
    out=json.dumps(payload,indent=2)+"\n"
    if a.output: open(a.output,"w",encoding="utf-8").write(out)
    else: print(out,end="")
    return 0
if __name__=="__main__": raise SystemExit(main())
