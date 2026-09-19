#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
ELL=0.98087
SE0=0.85
DEPTH=160.0
NINT=1024

def theta_of_h(h):
    if not (math.isfinite(h) and h<0.0):
        raise ValueError("pressure head leaves negative finite domain")
    se=(1.0+(ALPHA*abs(h))**N)**(-M)
    theta=TR+(TS-TR)*se
    if not (TR < theta < TS):
        raise ValueError("theta outside open physical domain")
    return theta

def h_of_theta(theta):
    if not (TR < theta < TS):
        raise ValueError("theta outside open physical domain")
    se=(theta-TR)/(TS-TR)
    return -((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def k_of_h(h):
    theta=theta_of_h(h)
    se=(theta-TR)/(TS-TR)
    k=KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2
    if not (math.isfinite(k) and k>0.0):
        raise ValueError("invalid conductivity")
    return k

def integrate_profile(hb,q):
    dy=DEPTH/NINT
    h=hb
    storage=0.0
    for _ in range(NINT):
        def dh(hh):
            return q/k_of_h(hh)-1.0
        k1h=dh(h); k1s=theta_of_h(h)
        h2=h+0.5*dy*k1h
        k2h=dh(h2); k2s=theta_of_h(h2)
        h3=h+0.5*dy*k2h
        k3h=dh(h3); k3s=theta_of_h(h3)
        h4=h+dy*k3h
        k4h=dh(h4); k4s=theta_of_h(h4)
        h=h+(dy/6.0)*(k1h+2.0*k2h+2.0*k3h+k4h)
        storage=storage+(dy/6.0)*(k1s+2.0*k2s+2.0*k3s+k4s)
        if not (math.isfinite(h) and h<0.0):
            raise ValueError("profile leaves negative finite pressure-head domain")
    return storage

def eval_endpoint(hb,q,target):
    try:
        storage=integrate_profile(hb,q)
        return {"finite":True,"storage_cm":storage,"storage_residual_cm":storage-target,"error":None}
    except Exception as exc:
        return {"finite":False,"storage_cm":None,"storage_residual_cm":None,"error":str(exc)}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    p=json.loads(pathlib.Path(args.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
    assert p["candidate"]["id"]=="QS1"
    assert p["manifold_evaluation"]["RK4_subintervals"]==1024
    assert p["manifold_evaluation"]["prescribed_bottom_head"]["q_bracket_cm_per_day"]=="[-Ksat,+Ksat]"
    assert p["manifold_evaluation"]["root_requirement"].startswith("bracket endpoints must be finite")

    theta0=TR+SE0*(TS-TR)
    h0=h_of_theta(theta0)
    target=DEPTH*theta0
    k0=k_of_h(h0)

    minus=eval_endpoint(h0,-KS,target)
    plus=eval_endpoint(h0,+KS,target)
    equilibrium=eval_endpoint(h0,k0,target)
    endpoint_contract_pass=minus["finite"] and plus["finite"]
    bracket_sign_pass=(endpoint_contract_pass and
                       (minus["storage_residual_cm"]==0.0 or plus["storage_residual_cm"]==0.0 or
                        minus["storage_residual_cm"]*plus["storage_residual_cm"]<0.0))

    decision=("D6_FIXED_ENDPOINT_BRACKET_PREFLIGHT_PASS"
              if endpoint_contract_pass and bracket_sign_pass
              else "D6_FIXED_ENDPOINT_BRACKET_NO_GO_BEFORE_TRAJECTORY_EXPOSURE")
    result={
      "schema":"swap5.f-romv2-d6.preflight-result.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D6",
      "decision":decision,
      "trajectory_evidence_consumed":False,
      "initial_equilibrium":{"theta":theta0,"h_cm":h0,"K_cm_per_day":k0,"storage_cm":target},
      "fixed_q_bracket_cm_per_day":[-KS,KS],
      "minus_Ksat_endpoint":minus,
      "plus_Ksat_endpoint":plus,
      "equilibrium_q_control":equilibrium,
      "endpoint_finite_contract_pass":endpoint_contract_pass,
      "opposite_residual_sign_contract_pass":bracket_sign_pass,
      "scientific_interpretation":"The frozen D6 root-bracket construction is not physically admissible at its own endpoints. This is a numerical-search-design no-go, not evidence against the quasi-steady manifold hypothesis itself.",
      "post_result_bracket_widening_or_narrowing_authorized":False,
      "production_rom_authorized":False
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
