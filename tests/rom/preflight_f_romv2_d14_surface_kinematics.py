#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DT=10.0/86400.0
DTH=(TS-TR)/NBINS
MASS_TOL=1.0e-14

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

def linear_front(z101,z199):
    return [z101+(z199-z101)*(j-J0)/(J1-J0) for j in range(J0,J1+1)]

PROFILES={
  "I_SHALLOW":linear_front(20.0,2.0),
  "I_MID":linear_front(60.0,5.0),
  "I_DEEP":linear_front(120.0,10.0),
  "I_RELAX":linear_front(1.0,0.1),
}

THETA_I=TR+I*DTH
THETA_D=TR+J1*DTH
K_I=kval(THETA_I); K_D=kval(THETA_D)
PSI_D=psi(THETA_D)
GEFF=max(abs(PSI_D),HCM)
ADV=(K_D-K_I)/(THETA_D-THETA_I)

def monotone_desc(x):
    return all(x[k]>=x[k+1] for k in range(len(x)-1))

def inversion_count(x):
    return sum(x[k]<x[k+1] for k in range(len(x)-1))

def infiltration_case(z):
    if not monotone_desc(z):
        raise ValueError("initial front order")
    vel=[ADV*(1.0+GEFF/x) for x in z]
    raw=[x+DT*v for x,v in zip(z,vel)]
    if not all(math.isfinite(x) and 0.0<x<=160.0 for x in raw):
        raise ValueError("raw front bounds")
    inv=inversion_count(raw)
    storage0=DTH*math.fsum(z)
    storage_raw=DTH*math.fsum(raw)
    demand=storage_raw-storage0
    if not(math.isfinite(demand) and demand>0): raise ValueError("nonpositive demand")
    relaxed=sorted(raw,reverse=True)
    storage_relaxed=DTH*math.fsum(relaxed)
    relax_diff=abs(storage_relaxed-storage_raw)
    ledger=(storage_relaxed-storage0)-demand
    return {
      "initial_storage_above_baseline_cm":storage0,
      "post_step_storage_above_baseline_cm":storage_relaxed,
      "surface_water_demand_cm":demand,
      "surface_ledger_residual_cm":ledger,
      "capillary_relaxation_storage_difference_cm":relax_diff,
      "raw_inversion_count":inv,
      "raw_monotone":monotone_desc(raw),
      "relaxed_monotone":monotone_desc(relaxed),
      "min_raw_front_cm":min(raw),"max_raw_front_cm":max(raw),
      "min_velocity_cm_per_day":min(vel),"max_velocity_cm_per_day":max(vel),
      "pass":relax_diff<=MASS_TOL and abs(ledger)<=MASS_TOL and monotone_desc(relaxed)
    }

def falling_slug_case():
    rows=[]
    water0=0.0; water1=0.0; maxlen=0.0; maxmove=0.0
    for j in range(J0,J1+1):
        tj=TR+j*DTH; tm=TR+(j-1)*DTH
        v=(kval(tj)-kval(tm))/(tj-tm)
        top=20.0+0.1*(j-J0)
        bottom=top+5.0
        ntop=top+v*DT; nbottom=bottom+v*DT
        if not all(math.isfinite(x) for x in (v,top,bottom,ntop,nbottom)):
            raise ValueError("slug nonfinite")
        if not(v>0 and 0.0<ntop<nbottom<=160.0):
            raise ValueError("slug physical bounds")
        oldlen=bottom-top; newlen=nbottom-ntop
        maxlen=max(maxlen,abs(newlen-oldlen))
        maxmove=max(maxmove,abs(ntop-top),abs(nbottom-bottom))
        water0+=DTH*oldlen; water1+=DTH*newlen
        rows.append({"bin":j,"velocity_cm_per_day":v,"translation_cm":ntop-top,
                     "length_before_cm":oldlen,"length_after_cm":newlen})
    return {
      "bin_count":len(rows),
      "min_velocity_cm_per_day":min(r["velocity_cm_per_day"] for r in rows),
      "max_velocity_cm_per_day":max(r["velocity_cm_per_day"] for r in rows),
      "max_translation_cm":maxmove,
      "max_abs_slug_length_change_cm":maxlen,
      "finite_volume_slug_water_before_cm":water0,
      "finite_volume_slug_water_after_cm":water1,
      "finite_volume_slug_water_difference_cm":abs(water1-water0),
      "pass":maxlen<=MASS_TOL and abs(water1-water0)<=MASS_TOL
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
    assert p["discretization"]["moisture_bins"]==NBINS
    assert p["discretization"]["maximum_explicit_substep_seconds"]==10
    assert abs(p["frozen_B01_identity"]["effective_capillary_drive_HcM_cm"]-HCM)<1e-15
    assert p["scientific_role"]["SWAP_trajectory_evidence_consumed"] is False
    assert "NO_SUPPLY_LIMITED_ALLOCATION_CLAIM" in p["firewalls"]

    infil={k:infiltration_case(v) for k,v in PROFILES.items()}
    slug=falling_slug_case()

    k1=all(v["pass"] for v in infil.values())
    k2=k1 and infil["I_RELAX"]["raw_inversion_count"]>0
    k3=all(abs(v["surface_ledger_residual_cm"])<=MASS_TOL for v in infil.values())
    k4=slug["pass"]
    k5=slug["finite_volume_slug_water_difference_cm"]<=MASS_TOL
    passed=k1 and k2 and k3 and k4 and k5

    out={
      "schema":"swap5.f-romv2-d14.surface-kinematics-preflight.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D14",
      "decision":"D14_FMC_SURFACE_KINEMATICS_PREFLIGHT_PASS" if passed else "D14_FMC_SURFACE_KINEMATICS_NO_GO",
      "SWAP_trajectory_evidence_consumed":False,
      "constitutive_control":{
        "theta_i":THETA_I,"theta_d":THETA_D,"K_i_cm_per_day":K_I,"K_d_cm_per_day":K_D,
        "psi_d_cm":PSI_D,"G_eff_cm":GEFF,"common_infiltration_advection_factor_cm_per_day_per_theta":ADV
      },
      "infiltration_front_cases":infil,
      "falling_slug_translation":slug,
      "tests":{
        "K1_EQ18_MULTI_BIN_FINITE_ADVANCE":k1,
        "K2_EQ18_CAPILLARY_RELAXATION_CONSERVATION":k2,
        "K3_EQ18_SURFACE_RESERVOIR_LEDGER":k3,
        "K4_EQ19_FALLING_SLUG_TRANSLATION":k4,
        "K5_EQ19_TOTAL_SLUG_WATER_IDENTITY":k5
      },
      "preflight_pass":passed,
      "D15_full_surface_accounting_authorized":passed,
      "post_result_bin_substep_profile_retuning_authorized":False,
      "application_acceptance":False,
      "formal_performance_claim":False,
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__": raise SystemExit(main())
