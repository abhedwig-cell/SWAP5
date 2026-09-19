#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
ELL=0.98087
NBINS=200
I=100
J0=101
J1=199
DEPTH=160.0
DT=10.0/86400.0
MASS_TOL=1.0e-12
RELAX_TOL=1.0e-14
LAMBDAS={"G25":0.25,"G50":0.50,"G75":0.75,"G125":1.25}

DTHETA=(TS-TR)/NBINS
THETA_I=TR+I*DTHETA

def psi(theta):
    if not(TR<theta<TS): raise ValueError("theta domain")
    se=(theta-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def kval(theta):
    if not(TR<theta<TS): raise ValueError("theta domain")
    se=(theta-TR)/(TS-TR)
    k=KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2
    if not(math.isfinite(k) and k>0): raise ValueError("K domain")
    return k

THETA=[TR+j*DTHETA for j in range(J0,J1+1)]
PSI=[psi(t) for t in THETA]
K=[kval(t) for t in THETA]
KI=kval(THETA_I)

def velocity(theta_j,psi_j,k_j,h):
    if not(math.isfinite(h) and h>0): raise ValueError("front height domain")
    return (k_j-KI)/(theta_j-THETA_I)*(abs(psi_j)/h-1.0)

def storage(h):
    return THETA_I*DEPTH + DTHETA*math.fsum(h)

def one_step(h):
    vel=[velocity(t,p,k,x) for t,p,k,x in zip(THETA,PSI,K,h)]
    raw=[x+DT*v for x,v in zip(h,vel)]
    if not all(math.isfinite(x) and 0.0<x<=DEPTH for x in raw):
        raise ValueError("raw front physical bounds")
    before_relax=DTHETA*math.fsum(raw)
    relaxed=sorted(raw,reverse=True)
    after_relax=DTHETA*math.fsum(relaxed)
    if abs(after_relax-before_relax)>RELAX_TOL:
        raise ValueError("relaxation storage drift")
    return relaxed,vel,before_relax,after_relax

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_FULL_ALGORITHM_PREFLIGHT"
    assert p["candidate"]["moisture_bins"]==NBINS
    assert p["time_integration"]["internal_substep_max_seconds"]==10
    assert "bin i=100" in p["groundwater_front"]["baseline_theta"]
    assert p["scientific_role"]["blind_confirmation"] is False

    eq=PSI[:]
    rows={}
    passed=True
    for hid,lam in LAMBDAS.items():
        h=[lam*x for x in PSI]
        initial_ok=all(math.isfinite(x) and 0.0<x<=DEPTH for x in h)
        mono_initial=all(h[k]>=h[k+1] for k in range(len(h)-1))
        l1_before=math.fsum(abs(x-e) for x,e in zip(h,eq))
        try:
            s0=storage(h)
            hn,vel,brel,arel=one_step(h)
            s1=storage(hn)
            l1_after=math.fsum(abs(x-e) for x,e in zip(hn,eq))
            bex=-(s1-s0)
            mass=(s1-s0)+bex
            qout=bex/DT
            mono_after=all(hn[k]>=hn[k+1] for k in range(len(hn)-1))
            relax_mass=abs(arel-brel)
            direction_ok=(qout<0.0 if lam<1.0 else qout>0.0)
            rowpass=(initial_ok and mono_initial and mono_after and l1_after<l1_before
                     and relax_mass<=RELAX_TOL and abs(mass)<=MASS_TOL and direction_ok)
            rows[hid]={
              "lambda":lam,"pass":rowpass,"initial_physical":initial_ok,
              "initial_monotone":mono_initial,"post_relax_monotone":mono_after,
              "L1_distance_to_equilibrium_before_cm":l1_before,
              "L1_distance_to_equilibrium_after_cm":l1_after,
              "storage_before_cm":s0,"storage_after_cm":s1,
              "bottom_outward_exchange_cm":bex,
              "bottom_outward_flux_cm_per_day":qout,
              "mass_residual_cm":mass,
              "capillary_relaxation_storage_difference_cm":relax_mass,
              "max_abs_velocity_cm_per_day":max(abs(v) for v in vel),
              "min_front_cm":min(hn),"max_front_cm":max(hn)
            }
            passed=passed and rowpass
        except Exception as exc:
            rows[hid]={"lambda":lam,"pass":False,"error":str(exc)}
            passed=False

    result={
      "schema":"swap5.f-romv2-d13.full-algorithm-preflight.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D13",
      "decision":"D13_FMC_GROUNDWATER_FRONT_PREFLIGHT_PASS" if passed else "D13_FMC_GROUNDWATER_FRONT_PREFLIGHT_NO_GO",
      "SWAP_trajectory_evidence_consumed":False,
      "theta_i":THETA_I,"effective_saturation_i":0.5,
      "active_bin_count":len(THETA),"dtheta":DTHETA,
      "substep_seconds":10.0,
      "cases":rows,
      "preflight_pass":passed,
      "post_preflight_lambda_or_equation_retuning_authorized":False,
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__":
    raise SystemExit(main())
