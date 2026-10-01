#!/usr/bin/env python3
"""F-MACRO-ALT14: RFM falsification matrix harness.

Research-only.
Combines:
- source-state dependent RFM-1B activation;
- fixed legacy 4% direct comparator;
- common reduced MB+IC routing;
- simple wetting/tracer-arrival diagnostics.

The routing operator is deliberately synthetic. It is used only to rank
falsification cases and observables, not as a SWAP-equivalence oracle.
"""

from __future__ import annotations
import json, math

SIGMA_B = 0.65
LEGACY_A_MP = 0.04
MB = 0.25
Z_AH = 25.0
Z_IC = 85.0
R_AH = 0.2
A = 0.31
B = 0.55

# ALT12 representative default-MvG screen values.
TOP_STATES = {
    "-10":   {"K": 19.55,   "S": 2.23},
    "-50":   {"K": 2.30,    "S": 9.47},
    "-100":  {"K": 0.396,   "S": 13.34},
    "-300":  {"K": 0.0122,  "S": 17.52},
    "-1000": {"K": 0.00019, "S": 19.77},
}

CASES = [
    {"name":"weak_structural", "h":"-100",  "R":4.0,  "duration_h":0.5},
    {"name":"short_heavy",     "h":"-100",  "R":60.0, "duration_h":0.1},
    {"name":"long_heavy",      "h":"-100",  "R":30.0, "duration_h":2.0},
    {"name":"wet_moderate",    "h":"-10",   "R":15.0, "duration_h":0.5},
    {"name":"dry_moderate",    "h":"-1000", "R":15.0, "duration_h":0.5},
]

def cdf(x):
    return 0.5*(1.0+math.erf(x/math.sqrt(2.0)))

def partition(R,b50):
    mu=math.log(b50); lr=math.log(R)
    zt=(lr-mu-SIGMA_B*SIGMA_B)/SIGMA_B
    ztail=(lr-mu)/SIGMA_B
    truncated=math.exp(mu+0.5*SIGMA_B*SIGMA_B)*cdf(zt)
    matrix=truncated+R*(1.0-cdf(ztail))
    matrix=max(0.0,min(R,matrix))
    return matrix,R-matrix

def integrated_activation(h,R,duration_h,dt=0.001):
    pars=TOP_STATES[h]
    n=max(1,round(duration_h/dt)); dt=duration_h/n
    pref=0.0; onset=None
    for i in range(n):
        tau=(i+0.5)*dt
        b50=pars["K"]+pars["S"]/(2.0*math.sqrt(tau))
        _,p=partition(R,b50)
        pref+=p*dt
        if onset is None and p/R>=1e-4:
            onset=tau
    total=R*duration_h
    return {
        "source":total,
        "legacy_pref":LEGACY_A_MP*total,
        "legacy_fraction":LEGACY_A_MP,
        "rfm_pref":pref,
        "rfm_fraction":pref/total,
        "rfm_onset_h":onset,
    }

def survival(z):
    if z<=Z_AH: ic=1.0
    elif z>=Z_IC: ic=0.0
    else:
        x=(z-Z_AH)/(Z_IC-Z_AH)
        ic=(1.0-R_AH)*((1.0-x**A)**B)
    return MB+(1.0-MB)*ic

def route_rfm(h,R,duration_h,total_h=4.0,dt=0.001,release_rate=3.0):
    depths=[i*5.0 for i in range(21)]
    surv=[survival(z) for z in depths]
    storage=[0.0]*len(depths)
    deposition=0.0
    bottom=0.0
    first_50=None
    first_bottom=None
    release_fraction=1.0-math.exp(-release_rate*dt)
    pars=TOP_STATES[h]

    for n in range(round(total_h/dt)):
        t=n*dt
        if t<duration_h:
            tau=t+0.5*dt
            b50=pars["K"]+pars["S"]/(2.0*math.sqrt(tau))
            _,p=partition(R,b50)
            storage[0]+=p*dt

        released=[w*release_fraction for w in storage]
        for i,q in enumerate(released):
            storage[i]-=q

        carry=[0.0]*len(storage)
        for i in range(len(storage)-1):
            frac=surv[i+1]/surv[i] if surv[i]>1e-14 else 0.0
            transmitted=released[i]*frac
            carry[i+1]+=transmitted
            deposition+=released[i]-transmitted
            if depths[i+1]==50.0 and first_50 is None and transmitted/dt>1e-6:
                first_50=t

        if first_bottom is None and released[-1]/dt>1e-6:
            first_bottom=t
        bottom+=released[-1]

        for i,q in enumerate(carry):
            storage[i]+=q

    return {
        "first_arrival_50cm_h":first_50,
        "first_bottom_arrival_h":first_bottom,
        "bottom":bottom,
        "deposition":deposition,
        "residual_storage":sum(storage),
    }

def main():
    results=[]
    for case in CASES:
        a=integrated_activation(case["h"],case["R"],case["duration_h"])
        r=route_rfm(case["h"],case["R"],case["duration_h"])
        results.append({**case,"activation":a,"routing":r})

    output={
        "schema":"swap5.f_macro_alt14.falsification_matrix.v1",
        "status":"RESEARCH_ONLY",
        "cases":results,
        "falsification_rules":{
            "weak_event":"Reject RFM activation if independent data show immediate appreciable deep preferential response during weak unponded input despite high matrix intake capacity.",
            "intense_event":"Reject RFM if strong events do not show increasing preferential fraction or faster/deeper response.",
            "duration":"Reject dynamic b50 if longer sustained input does not increase preferential activation relative to short pulses at comparable intensity/state.",
            "antecedent_state":"Reject if one sigma_B cannot explain dry/wet response ordering through state-derived K and S.",
            "geometry":"Reject continuous connectivity if one parameter set cannot transfer across forcing states while preserving arrival/deposition/bottom-flux observables.",
            "mass":"Reject any implementation with non-conservative accepted water accounting."
        },
        "qualification_boundary":"Synthetic routing is diagnostic only; empirical/reference event data are required for model discrimination."
    }
    print(json.dumps(output,indent=2,sort_keys=True))

if __name__=="__main__":
    main()
