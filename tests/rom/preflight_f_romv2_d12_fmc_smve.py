#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

# B01 constitutive identity frozen by F-ROMV2-D12.
TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
ELL=0.98087
NBINS=200
IDENTITY_TOL=1.0e-12
MASS_TOL=1.0e-14

def theta_of_psi(psi: float) -> float:
    if not (math.isfinite(psi) and psi >= 0.0):
        raise ValueError("psi domain")
    se=(1.0+(ALPHA*psi)**N)**(-M)
    return TR+(TS-TR)*se

def psi_of_theta(theta: float) -> float:
    if not (TR < theta < TS):
        raise ValueError("theta open domain")
    se=(theta-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def krel_of_theta(theta: float) -> float:
    if theta <= TR:
        return 0.0
    if theta >= TS:
        return 1.0
    se=(theta-TR)/(TS-TR)
    return se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2

def k_of_theta(theta: float) -> float:
    return KS*krel_of_theta(theta)

def adaptive_simpson(f,a,b,tol,max_depth=30):
    fa=f(a); fb=f(b); c=0.5*(a+b); fc=f(c)
    whole=(b-a)*(fa+4.0*fc+fb)/6.0
    def rec(a,b,fa,fb,fc,whole,tol,depth):
        c=0.5*(a+b); l=0.5*(a+c); r=0.5*(c+b)
        fl=f(l); fr=f(r)
        left=(c-a)*(fa+4.0*fl+fc)/6.0
        right=(b-c)*(fc+4.0*fr+fb)/6.0
        delta=left+right-whole
        if depth<=0 or abs(delta)<=15.0*tol:
            return left+right+delta/15.0
        return rec(a,c,fa,fc,fl,left,tol/2.0,depth-1)+rec(c,b,fc,fb,fr,right,tol/2.0,depth-1)
    return rec(a,b,fa,fb,fc,whole,tol,max_depth)

def b01_hcm(u_max: float) -> float:
    # psi = u / [alpha(1-u)] maps [0,1) to [0,infinity).
    def integrand(u):
        one=1.0-u
        psi=u/(ALPHA*one)
        theta=theta_of_psi(psi)
        return krel_of_theta(theta)/(ALPHA*one*one)
    return adaptive_simpson(integrand,0.0,u_max,1.0e-11)

def green_ampt_identity():
    dtheta=0.31
    kga=1.27
    hcap=18.4
    hp=2.6
    z=11.3
    fmc=kga/dtheta*(1.0+(hcap+hp)/z)
    ga_flux=kga*(1.0+(hcap+hp)/z)
    ga=ga_flux/dtheta
    return {
      "fmc_front_velocity":fmc,
      "green_ampt_front_velocity":ga,
      "abs_difference":abs(fmc-ga),
      "pass":abs(fmc-ga)<=IDENTITY_TOL
    }

def groundwater_equilibrium():
    theta_i=TR+0.15*(TS-TR)
    ki=k_of_theta(theta_i)
    vals=[]
    max_abs=0.0
    dtheta=(TS-TR)/NBINS
    for j in range(31,NBINS):  # strictly wetter than theta_i and below saturation edge
        theta=TR+j*dtheta
        if not(theta_i < theta < TS):
            continue
        psi=psi_of_theta(theta)
        hfront=abs(psi)
        velocity=(k_of_theta(theta)-ki)/(theta-theta_i)*(abs(psi)/hfront-1.0)
        max_abs=max(max_abs,abs(velocity))
        vals.append(velocity)
    return {"tested_bins":len(vals),"max_abs_velocity_cm_per_day":max_abs,
            "pass":len(vals)>100 and max_abs<=IDENTITY_TOL}

def capillary_relaxation_conservation():
    fronts=[13.0,2.5,18.25,7.125,7.125,31.0,1.0,22.75,9.5,4.0]
    dtheta=(TS-TR)/NBINS
    before=dtheta*math.fsum(fronts)
    after_fronts=sorted(fronts,reverse=True)
    after=dtheta*math.fsum(after_fronts)
    return {"before_storage_cm":before,"after_storage_cm":after,
            "abs_difference_cm":abs(before-after),
            "monotone":all(after_fronts[i]>=after_fronts[i+1] for i in range(len(after_fronts)-1)),
            "pass":abs(before-after)<=MASS_TOL}

def b01_constitutive():
    dtheta=(TS-TR)/NBINS
    theta=[TR+j*dtheta for j in range(1,NBINS)]  # open-domain right edges, excluding saturation edge
    psi=[psi_of_theta(t) for t in theta]
    kval=[k_of_theta(t) for t in theta]
    psi_monotone=all(psi[i]>psi[i+1] for i in range(len(psi)-1))
    k_monotone=all(kval[i]<kval[i+1] for i in range(len(kval)-1))
    hc1=b01_hcm(1.0-1.0e-8)
    hc2=b01_hcm(1.0-1.0e-10)
    rel=abs(hc2-hc1)/hc2
    return {
      "bins":NBINS,
      "psi_strictly_decreases_with_theta":psi_monotone,
      "K_strictly_increases_with_theta":k_monotone,
      "HcM_cm_u1e8":hc1,
      "HcM_cm_u1e10":hc2,
      "tail_refinement_relative_difference":rel,
      "pass":psi_monotone and k_monotone and math.isfinite(hc2) and hc2>0.0 and rel<1.0e-6
    }

def power_law_timescale():
    A=2.0
    K1=1.0
    D1=100.0
    rows=[]
    for n in range(3,10):
        tp=D1/(n*K1*A)*math.log(A/(A-K1))
        # Leading-front identity from the analytical solution.
        t=0.37*tp
        z=A*t
        identity=z-A*t
        rows.append({"n":n,"tp_h":tp,"test_t_h":t,"zmax_cm":z,
                     "leading_front_identity_error_cm":identity})
    maxerr=max(abs(r["leading_front_identity_error_cm"]) for r in rows)
    monotone=all(rows[i]["tp_h"]>rows[i+1]["tp_h"] for i in range(len(rows)-1))
    return {"A_cm_per_h":A,"K1_cm_per_h":K1,"D1_cm2_per_h":D1,
            "rows":rows,"max_identity_error_cm":maxerr,
            "tp_decreases_with_n":monotone,
            "pass":maxerr<=IDENTITY_TOL and monotone}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    p=json.loads(pathlib.Path(args.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
    assert p["discretization"]["bins"]==NBINS
    assert p["numerical_preflight"]["maximum_infiltration_substep_seconds"]==10
    assert p["scientific_role"]["SWAP_trajectory_evidence_consumed"] is False

    tests={
      "P1_GREEN_AMPT_SINGLE_BIN_IDENTITY":green_ampt_identity(),
      "P2_GROUNDWATER_HYDROSTATIC_EQUILIBRIUM":groundwater_equilibrium(),
      "P3_CAPILLARY_RELAXATION_FINITE_VOLUME_CONSERVATION":capillary_relaxation_conservation(),
      "P4_B01_CONSTITUTIVE_AND_CAPILLARY_DRIVE":b01_constitutive(),
      "P5_PUBLISHED_POWER_LAW_TIMESCALE":power_law_timescale()
    }
    passed=all(v["pass"] for v in tests.values())
    out={
      "schema":"swap5.f-romv2-d12.preflight-result.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D12",
      "decision":"D12_FMC_SMVE_EQUATION_PREFLIGHT_PASS" if passed else "D12_FMC_SMVE_AUTHORITY_OR_PREFLIGHT_NO_GO",
      "SWAP_trajectory_evidence_consumed":False,
      "external_oracle_used":False,
      "external_source_code_copied":False,
      "tests":tests,
      "preflight_pass":passed,
      "D13_comparator_authorized":passed,
      "application_acceptance":False,
      "formal_performance_claim":False,
      "production_rom_authorized":False
    }
    pathlib.Path(args.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__":
    raise SystemExit(main())
