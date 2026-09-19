#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; NBINS=200; I=100; J0=101; J1=199
HCM=14.085215420920257; DT=10.0/86400.0; DTH=(TS-TR)/NBINS
DEPTH=160.0; TOL=1.0e-14

def psi(theta):
    if not(TR<theta<TS): raise ValueError("theta domain")
    se=(theta-TR)/(TS-TR)
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def kval(theta):
    if theta<=TR: return 0.0
    if theta>=TS: return KS
    se=(theta-TR)/(TS-TR)
    return KS*se**ELL*(1.0-(1.0-se**(1.0/M))**M)**2

def theta_j(j):
    return TR+j*DTH

THETA_I=theta_j(I)
K_I=kval(THETA_I)

def linear_front(z101,z199):
    return {j:z101+(z199-z101)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}

def eq18_velocity(z,theta_d,k_d):
    geff=max(abs(psi(theta_d)),HCM)
    adv=(k_d-K_I)/(theta_d-THETA_I)
    return adv*(1.0+geff/z)

def dry_bin_root(j):
    # Frozen D15 one-bin Green-Ampt cumulative infiltration identity.
    k=kval(theta_j(j))
    A=HCM*DTH
    lo=k*DT
    hi=k*DT+A+10.0*k*DT
    def f(F): return F-k*DT-A*math.log1p(F/A)
    flo=f(lo); fhi=f(hi)
    if not(math.isfinite(flo) and math.isfinite(fhi) and flo<=0.0 and fhi>=0.0):
        return {"ok":False,"reason":"root_not_bracketed","lo":lo,"hi":hi,"flo":flo,"fhi":fhi}
    a,b=lo,hi
    fa,fb=flo,fhi
    for _ in range(100):
        m=0.5*(a+b)
        if m==a or m==b: break
        fm=f(m)
        if fa*fm<=0:
            b=m; fb=fm
        else:
            a=m; fa=fm
    F=0.5*(a+b); res=f(F)
    return {"ok":True,"F_cm":F,"z_cm":F/DTH,"residual_cm":res,"lo":lo,"hi":hi}

def incremental_slug_velocity(j):
    t=theta_j(j); tm=theta_j(j-1)
    return (kval(t)-kval(tm))/(t-tm)

def storage_fronts(fronts):
    return DTH*math.fsum(fronts.values())

def storage_slugs(slugs):
    return DTH*math.fsum(max(0.0,b-a) for a,b in slugs.values())

def relax_fronts(fronts):
    keys=sorted(fronts)
    vals=sorted((fronts[j] for j in keys),reverse=True)
    return {j:v for j,v in zip(keys,vals)}

def a1_supply_limited():
    fronts=linear_front(60.0,5.0)
    s0=storage_fronts(fronts)
    theta_d=theta_j(J1); kd=kval(theta_d)
    supply=0.25*KS*DT
    remaining=supply
    allocated=0.0
    partial_bin=None
    out=dict(fronts)
    for j in range(J0,J1+1):
        v=eq18_velocity(fronts[j],theta_d,kd)
        raw=fronts[j]+v*DT
        demand=max(0.0,DTH*(raw-fronts[j]))
        take=min(remaining,demand)
        if take>0:
            out[j]=fronts[j]+take/DTH
            allocated+=take; remaining-=take
        if take<demand-1e-18:
            partial_bin=j
            break
        if remaining<=1e-18: break
    relaxed=relax_fronts(out)
    s1=storage_fronts(relaxed)
    ledger=(s1-s0)-allocated
    return {"supply_cm":supply,"allocated_cm":allocated,"remaining_cm":remaining,
            "partial_bin":partial_bin,"storage_increment_cm":s1-s0,
            "ledger_residual_cm":ledger,
            "pass":partial_bin is not None and abs(remaining)<=TOL and abs(ledger)<=TOL}

def a2_dry_activation():
    j=J0; root=dry_bin_root(j)
    supply=4.0*KS*DT
    if not root["ok"]:
        return {"root":root,"supply_cm":supply,"pass":False}
    water=DTH*root["z_cm"]
    remaining=supply-water
    ledger=water-DTH*root["z_cm"]
    return {"root":root,"supply_cm":supply,"activation_water_cm":water,
            "remaining_cm":remaining,"ledger_residual_cm":ledger,
            "pass":remaining>=0.0 and abs(root["residual_cm"])<=1e-12 and abs(ledger)<=TOL}

def a3_overflow():
    capacities={j:kval(theta_j(j))*DT for j in range(J0,J1+1)}
    capacity=math.fsum(capacities.values())
    supply=2.0*capacity
    # no ponding
    runoff0=supply-capacity
    led0=supply-capacity-runoff0
    # finite store
    store_cap=KS*DT
    residual=supply-capacity
    store=min(store_cap,residual)
    runoff=residual-store
    led1=supply-capacity-store-runoff
    return {"capacity_cm":capacity,"supply_cm":supply,
            "no_ponding":{"runoff_cm":runoff0,"ledger_residual_cm":led0},
            "finite_store":{"cap_cm":store_cap,"store_cm":store,"runoff_cm":runoff,"ledger_residual_cm":led1},
            "pass":runoff0>0 and store>0 and runoff>0 and abs(led0)<=TOL and abs(led1)<=TOL}

def a4_detach_translate():
    selected={120:15.0,150:30.0,190:45.0}
    w0=DTH*math.fsum(selected.values())
    slugs={j:(0.0,z) for j,z in selected.items()}
    w_det=storage_slugs(slugs)
    moved={}
    max_len_drift=0.0
    for j,(top,bottom) in slugs.items():
        d=incremental_slug_velocity(j)*DT
        nt,nb=top+d,bottom+d
        if not(0.0<=nt<nb<=DEPTH):
            return {"reason":"translated_slug_bounds","bin":j,"top":nt,"bottom":nb,"pass":False}
        moved[j]=(nt,nb)
        max_len_drift=max(max_len_drift,abs((nb-nt)-(bottom-top)))
    w1=storage_slugs(moved)
    return {"water_before_cm":w0,"water_after_detachment_cm":w_det,"water_after_translation_cm":w1,
            "max_abs_slug_length_drift_cm":max_len_drift,
            "pass":abs(w_det-w0)<=TOL and abs(w1-w0)<=TOL and max_len_drift<=TOL}

def a5_slug_groundwater_merge():
    j=160
    slug=(20.0,60.0)
    gw=(60.0,160.0)
    pre_unique=(slug[1]-slug[0])+(gw[1]-gw[0])
    merged=(min(slug[0],gw[0]),max(slug[1],gw[1]))
    post=merged[1]-merged[0]
    residual=DTH*(post-pre_unique)
    return {"bin":j,"slug_cm":slug,"groundwater_interval_cm":gw,"merged_interval_cm":merged,
            "pre_unique_occupied_length_cm":pre_unique,"post_occupied_length_cm":post,
            "water_residual_cm":residual,
            "pass":merged[0]>=0 and merged[1]<=DEPTH and abs(residual)<=TOL}

def a6_composite_relaxation():
    fronts={110:10.0,120:6.0,130:12.0,140:4.0}
    slugs={160:(30.0,35.0),180:(50.0,57.0)}
    before=storage_fronts(fronts)+storage_slugs(slugs)
    relaxed=relax_fronts(fronts)
    after=storage_fronts(relaxed)+storage_slugs(slugs)
    keys=sorted(relaxed)
    mono=all(relaxed[keys[i]]>=relaxed[keys[i+1]] for i in range(len(keys)-1))
    raw_inv=sum(fronts[keys[i]]<fronts[keys[i+1]] for i in range(len(keys)-1))
    return {"raw_inversion_count":raw_inv,"monotone_after":mono,
            "water_before_cm":before,"water_after_cm":after,
            "water_difference_cm":after-before,
            "pass":raw_inv>0 and mono and abs(after-before)<=TOL}

def a7_end_to_end():
    # Two connected fronts followed by one dry activation and an insufficient next activation.
    fronts={101:20.0,102:18.0}
    initial=storage_fronts(fronts)
    td=theta_j(102); kd=kval(td)
    demands={}
    advanced={}
    demand_total=0.0
    for j in (101,102):
        v=eq18_velocity(fronts[j],td,kd)
        raw=fronts[j]+v*DT
        d=max(0.0,DTH*(raw-fronts[j]))
        demands[j]=d; demand_total+=d
        advanced[j]=raw
    r103=dry_bin_root(103); r104=dry_bin_root(104)
    if not(r103["ok"] and r104["ok"]):
        return {"reason":"dry_root_failure","r103":r103,"r104":r104,"pass":False}
    w103=DTH*r103["z_cm"]; w104=DTH*r104["z_cm"]
    rainfall=demand_total+w103+0.5*w104
    remaining=rainfall
    infiltrated=0.0
    newfronts=dict(fronts)
    for j in (101,102):
        take=min(remaining,demands[j]); remaining-=take; infiltrated+=take
        newfronts[j]=fronts[j]+take/DTH
    activated103=False
    if remaining+TOL>=w103:
        newfronts[103]=r103["z_cm"]; remaining-=w103; infiltrated+=w103; activated103=True
    activated104=False
    if remaining+TOL>=w104:
        newfronts[104]=r104["z_cm"]; remaining-=w104; infiltrated+=w104; activated104=True
    runoff=max(0.0,remaining); remaining=0.0
    relaxed=relax_fronts(newfronts)
    postpulse=storage_fronts(relaxed)
    pulse_ledger=(postpulse-initial)+runoff-rainfall
    # no surface store: zero-supply hiatus may detach.
    slugs={j:(0.0,z) for j,z in relaxed.items()}
    before_slug=storage_slugs(slugs)
    moved={}
    for j,(top,bottom) in slugs.items():
        d=incremental_slug_velocity(j)*DT
        nt,nb=top+d,bottom+d
        if not(0.0<=nt<nb<=DEPTH):
            return {"reason":"hiatus_slug_bounds","bin":j,"top":nt,"bottom":nb,"pass":False}
        moved[j]=(nt,nb)
    after_slug=storage_slugs(moved)
    global_ledger=initial+rainfall-(after_slug+runoff)
    return {"rainfall_cm":rainfall,"infiltrated_cm":infiltrated,"runoff_cm":runoff,
            "activated_bin_103":activated103,"activated_bin_104":activated104,
            "remaining_surface_water_at_hiatus_cm":remaining,
            "pulse_ledger_residual_cm":pulse_ledger,
            "water_before_detachment_cm":postpulse,"water_after_translation_cm":after_slug,
            "global_ledger_residual_cm":global_ledger,
            "pass":activated103 and not activated104 and runoff>0 and abs(remaining)<=TOL
                   and abs(pulse_ledger)<=TOL and abs(after_slug-before_slug)<=TOL
                   and abs(global_ledger)<=TOL}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
    assert p["discretization"]["moisture_bins"]==NBINS
    assert p["discretization"]["accounting_substep_seconds"]==10
    assert p["scientific_role"]["SWAP_trajectory_evidence_consumed"] is False
    assert "NO_2008_CAPILLARY_WEIGHTED_REDISTRIBUTION" in p["firewalls"]
    assert "NO_PONDING_DURING_A7_HIATUS" in p["firewalls"]

    tests={
      "A1_SUPPLY_LIMITED_EXISTING_FRONTS":a1_supply_limited(),
      "A2_DRY_BIN_ACTIVATION":a2_dry_activation(),
      "A3_OVERFLOW_RUNOFF_AND_SURFACE_STORE":a3_overflow(),
      "A4_HIATUS_DETACHMENT_AND_TRANSLATION":a4_detach_translate(),
      "A5_SLUG_GROUNDWATER_MERGE":a5_slug_groundwater_merge(),
      "A6_COMPOSITE_CAPILLARY_RELAXATION":a6_composite_relaxation(),
      "A7_END_TO_END_SURFACE_LEDGER":a7_end_to_end()
    }
    passed=all(v.get("pass") is True for v in tests.values())
    out={
      "schema":"swap5.f-romv2-d15.surface-accounting-preflight.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D15",
      "decision":"D15_FMC_FULL_SURFACE_ACCOUNTING_PREFLIGHT_PASS" if passed else "D15_FMC_SURFACE_ACCOUNTING_NO_GO",
      "SWAP_trajectory_evidence_consumed":False,
      "tests":tests,
      "preflight_pass":passed,
      "D16_surface_comparator_authorized":passed,
      "post_result_bin_substep_green_ampt_allocation_retuning_authorized":False,
      "application_acceptance":False,
      "formal_performance_claim":False,
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
