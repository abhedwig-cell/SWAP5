#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DTH=(TS-TR)/NBINS; DEPTH=160.0
DT=10.0/86400.0; NSUB=9; NOBS=64; TOL=1e-14

HISTORIES={
  "S10_P16_H48":{"z101":20.0,"z199":2.0,"rain_factor":0.10,"pulse_obs":16},
  "M25_P16_H48":{"z101":60.0,"z199":5.0,"rain_factor":0.25,"pulse_obs":16},
  "D50_P16_H48":{"z101":120.0,"z199":10.0,"rain_factor":0.50,"pulse_obs":16},
  "M50_P32_H32":{"z101":60.0,"z199":5.0,"rain_factor":0.50,"pulse_obs":32},
}

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA
def kval(t):
    if t<=TR:return 0.0
    if t>=TS:return KS
    se=(t-TR)/(TS-TR)
    return KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2

THETA_I=theta(I); K_I=kval(THETA_I)

def profile(spec):
    return {j:spec["z101"]+(spec["z199"]-spec["z101"])*(j-J0)/(J1-J0) for j in range(J0,J1+1)}

def eq18_velocity(z):
    td=theta(J1); kd=kval(td)
    geff=max(abs(psi(td)),HCM)
    return (kd-K_I)/(td-THETA_I)*(1.0+geff/z)

def eq19_velocity(j):
    return (kval(theta(j))-kval(theta(j-1)))/DTH

def front_storage(fronts):
    return THETA_I*DEPTH + DTH*math.fsum(fronts.values())

def slug_excess_storage(slugs):
    return DTH*math.fsum(b-a for a,b in slugs.values())

def cell_averages_fronts(fronts,n):
    dz=DEPTH/n; out=[]
    for c in range(n):
        a=c*dz; b=(c+1)*dz
        v=THETA_I
        for z in fronts.values():
            v += DTH*max(0.0,min(z,b)-a)/dz if z>a else 0.0
        out.append(v)
    return out

def cell_averages_slugs(slugs,n):
    dz=DEPTH/n; out=[]
    for c in range(n):
        a=c*dz; b=(c+1)*dz
        v=THETA_I
        for top,bot in slugs.values():
            v += DTH*max(0.0,min(bot,b)-max(top,a))/dz
        out.append(v)
    return out

def relax(fronts):
    keys=sorted(fronts)
    vals=sorted((fronts[j] for j in keys),reverse=True)
    return {j:v for j,v in zip(keys,vals)}

def pulse_step(fronts,rain):
    s0=front_storage(fronts)
    supply=rain*DT; rem=supply; out=dict(fronts); partial=None
    for j in range(J0,J1+1):
        raw=fronts[j]+DT*eq18_velocity(fronts[j])
        if not(math.isfinite(raw) and 0.0<raw<=DEPTH):
            return None,{"reason":"raw_front_bounds","bin":j,"raw_cm":raw}
        demand=max(0.0,DTH*(raw-fronts[j]))
        take=min(rem,demand)
        if take>0.0:
            out[j]=fronts[j]+take/DTH
            rem-=take
        if take < demand-1e-18:
            partial=j
            break
        if rem<=1e-18:
            break
    out=relax(out)
    s1=front_storage(out)
    ledger=(s1-s0)-(supply-rem)
    if abs(ledger)>TOL:
        return None,{"reason":"pulse_ledger","residual_cm":ledger}
    if rem>TOL:
        return None,{"reason":"unallocated_supply_would_require_dry_activation_or_surface_storage","remaining_cm":rem}
    return out,{"supply_cm":supply,"allocated_cm":supply-rem,"ledger_residual_cm":ledger,"partial_bin":partial}

def translate(slugs):
    w0=slug_excess_storage(slugs)
    out={}
    for j,(a,b) in slugs.items():
        d=eq19_velocity(j)*DT
        na,nb=a+d,b+d
        if not(math.isfinite(na) and math.isfinite(nb) and 0.0<=na<nb<=DEPTH):
            return None,{"reason":"slug_bounds","bin":j,"top_cm":na,"bottom_cm":nb}
        out[j]=(na,nb)
    w1=slug_excess_storage(out)
    res=w1-w0
    if abs(res)>TOL:
        return None,{"reason":"slug_water_drift","residual_cm":res}
    return out,{"ledger_residual_cm":res}

def storage_from_cells(vals):
    return math.fsum(vals)*(DEPTH/len(vals))

def zones_from_cells(vals):
    half=len(vals)//2; dz=DEPTH/len(vals)
    return math.fsum(vals[:half])*dz, math.fsum(vals[half:])*dz

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_SWAP_TRAJECTORY_EXECUTION"
    assert p["fmc_discretization"]["moisture_bins"]==NBINS
    assert p["fmc_discretization"]["process_substep_seconds"]==10
    assert p["fmc_discretization"]["process_substeps_per_observation"]==NSUB
    assert "NO_DRY_BIN_ACTIVATION_IN_D16" in p["firewalls"]

    rows={}; overall=True; maxledger=0.0
    for hid,spec in HISTORIES.items():
        fronts=profile(spec)
        mono=all(fronts[j]>=fronts[j+1] for j in range(J0,J1))
        bounds=all(0.0<z<=DEPTH for z in fronts.values())
        c16=cell_averages_fronts(fronts,16); c2=cell_averages_fronts(fronts,2)
        exact=front_storage(fronts)
        u16,l16=zones_from_cells(c16); u2,l2=zones_from_cells(c2)
        map_ok=(abs(storage_from_cells(c16)-exact)<=1e-12 and abs(storage_from_cells(c2)-exact)<=1e-12
                and abs(u16-u2)<=1e-12 and abs(l16-l2)<=1e-12)
        failure=None; pulse_supply=0.0; partial_bins=[]; slugs=None
        for obs in range(1,NOBS+1):
            for _ in range(NSUB):
                if obs<=spec["pulse_obs"]:
                    fronts,info=pulse_step(fronts,spec["rain_factor"]*KS)
                    if fronts is None:
                        failure={"observation":obs,**info}; break
                    pulse_supply+=info["supply_cm"]; maxledger=max(maxledger,abs(info["ledger_residual_cm"]))
                    if info["partial_bin"] is not None: partial_bins.append(info["partial_bin"])
                else:
                    if slugs is None:
                        slugs={j:(0.0,z) for j,z in fronts.items()}
                    slugs,info=translate(slugs)
                    if slugs is None:
                        failure={"observation":obs,**info}; break
                    maxledger=max(maxledger,abs(info["ledger_residual_cm"]))
            if failure: break
        if slugs is None:
            final_cells=cell_averages_fronts(fronts,16)
            final_storage=front_storage(fronts)
        else:
            final_cells=cell_averages_slugs(slugs,16)
            final_storage=THETA_I*DEPTH+slug_excess_storage(slugs)
        expected=exact+pulse_supply
        final_ledger=final_storage-expected
        passed=(mono and bounds and map_ok and failure is None and abs(final_ledger)<=1e-12)
        overall &= passed
        rows[hid]={
          "initial_monotone":mono,"initial_bounds":bounds,"initial_total_storage_cm":exact,
          "initial_mapping_identity_pass":map_ok,"pulse_supply_cm":pulse_supply,
          "partial_existing_front_bin_min":min(partial_bins) if partial_bins else None,
          "partial_existing_front_bin_max":max(partial_bins) if partial_bins else None,
          "dry_bin_activation_count":0,"runoff_cm":0.0,"surface_storage_cm":0.0,
          "failure":failure,"final_storage_cm":final_storage,
          "final_global_ledger_residual_cm":final_ledger,
          "final_theta_min":min(final_cells),"final_theta_max":max(final_cells),
          "pass":passed
        }

    out={"schema":"swap5.f-romv2-d16.surface-preflight.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D16",
         "decision":"D16_FMC_MATCHED_SURFACE_PREFLIGHT_PASS" if overall else "D16_FMC_MATCHED_SURFACE_PREFLIGHT_NO_GO",
         "SWAP_trajectory_evidence_consumed":False,"histories":rows,
         "max_abs_process_ledger_residual_cm":maxledger,
         "preflight_pass":overall,"post_preflight_workload_retuning_authorized":False,
         "production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0 if overall else 2
if __name__=="__main__": raise SystemExit(main())
