#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; HCM=14.085215420920257
NBINS=200; I=100; J0=101; J1=199; DEPTH=160.0
DT=10.0/86400.0; DTH=(TS-TR)/NBINS; TOL=1e-12
PULSE_FACTOR=0.75; PULSE_STEPS=16; MAX_TRANSITION_STEPS=512

def theta(j): return TR+j*DTH
def psi(t):
    se=(t-TR)/(TS-TR)
    return ((se**(-1/M)-1)**(1/N))/ALPHA
def kval(t):
    se=(t-TR)/(TS-TR)
    k=KS*se**ELL*(1-(1-se**(1/M))**M)**2
    if not(math.isfinite(k) and k>0): raise ValueError("K domain")
    return k

TI=theta(I); KI=kval(TI); TD=theta(J1); KD=kval(TD)
GEFF=max(abs(psi(TD)),HCM); ADV=(KD-KI)/(TD-TI)

def initial_surface():
    return {j:120.0+(10.0-120.0)*(j-J0)/(J1-J0) for j in range(J0,J1+1)}
def initial_gw():
    return {j:0.25*abs(psi(theta(j))) for j in range(J0,J1+1)}

def relax(d):
    keys=sorted(d)
    before=math.fsum(d[j] for j in keys)
    vals=sorted((d[j] for j in keys),reverse=True)
    out={j:v for j,v in zip(keys,vals)}
    after=math.fsum(out[j] for j in keys)
    if abs(DTH*(after-before))>1e-14: raise ValueError("relaxation mass drift")
    return out

def surface_step(fronts):
    supply=PULSE_FACTOR*KS*DT
    gray=KI*DT
    rem=supply-gray
    if rem<0: raise ValueError("gray exceeds pulse supply")
    out=dict(fronts)
    for j in range(J0,J1+1):
        z=fronts[j]
        raw=z+DT*ADV*(1+GEFF/z)
        if not math.isfinite(raw): raise ValueError("surface nonfinite")
        demand=max(0.0,DTH*(raw-z))
        take=min(rem,demand)
        if take>0:
            out[j]=z+take/DTH; rem-=take
        if take<demand-1e-18 or rem<=1e-18: break
    if rem>1e-14: raise ValueError("unabsorbed D17 pulse supply")
    return relax(out),supply,gray

def gw_velocity(j,h):
    tj=theta(j)
    v=(kval(tj)-KI)/(tj-TI)*(abs(psi(tj))/h-1.0)
    if not math.isfinite(v): raise ValueError("GW velocity nonfinite")
    return v

def advance_gw(gw):
    raw={j:h+DT*gw_velocity(j,h) for j,h in gw.items()}
    if not all(math.isfinite(h) and 0<h<=DEPTH for h in raw.values()):
        raise ValueError("GW front bounds")
    return relax(raw)

def slug_velocity(j):
    return (kval(theta(j))-kval(theta(j-1)))/(theta(j)-theta(j-1))

def storage(fronts=None,slugs=None,gw=None):
    s=TI*DEPTH
    if fronts is not None: s += DTH*math.fsum(fronts.values())
    if slugs is not None: s += DTH*math.fsum(length for _,length in slugs.values())
    if gw is not None: s += DTH*math.fsum(gw.values())
    return s

def min_gap_fronts(fronts,gw):
    return min(DEPTH-fronts[j]-gw[j] for j in range(J0,J1+1))

def min_gap_slugs(slugs,gw):
    vals=[]
    for j,(top,length) in slugs.items():
        vals.append(DEPTH-gw[j]-(top+length))
    return min(vals) if vals else None

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--prereg",required=True); ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_EVENT_PREFLIGHT"
    assert p["frozen_identity"]["moisture_bins"]==200
    assert p["frozen_identity"]["process_step_seconds"]==10
    assert p["stage1_event_preflight"]["event_search_max_steps"]==512

    fronts=initial_surface(); gw=initial_gw()
    maxmass=0.0
    # Reproduce admitted D17 C75_G25 pulse exactly.
    for st in range(1,PULSE_STEPS+1):
        sb=storage(fronts=fronts,gw=gw)
        fronts2,supply,gray=surface_step(fronts)
        g0=DTH*math.fsum(gw.values())
        gw2=advance_gw(gw)
        g1=DTH*math.fsum(gw2.values())
        bottom=gray-(g1-g0)
        sa=storage(fronts=fronts2,gw=gw2)
        mass=(sa-sb)-supply+bottom
        maxmass=max(maxmass,abs(mass))
        if abs(mass)>TOL: raise SystemExit(f"D17 reconstruction mass failure step {st}")
        if min_gap_fronts(fronts2,gw2)<=0: raise SystemExit(f"D17 reconstruction contact step {st}")
        fronts,gw=fronts2,gw2

    reconstructed_gap=min_gap_fronts(fronts,gw)
    reconstructed_storage=storage(fronts=fronts,gw=gw)

    # Transition: qtop=KI exactly pays gray demand, so no water remains to maintain connected fronts.
    slugs={j:[0.0,z] for j,z in fronts.items()}
    detach_storage=storage(slugs=slugs,gw=gw)
    if abs(detach_storage-reconstructed_storage)>TOL: raise SystemExit("detachment storage drift")

    first_merge_step=None
    first_merge_bins=[]
    first_merge_pre=None
    first_merge_post=None
    total_merges=0
    min_gap_before_merge=None
    step_rows=[]

    for st in range(1,MAX_TRANSITION_STEPS+1):
        sb=storage(slugs=slugs,gw=gw)
        top_supply=KI*DT
        gray_bottom=KI*DT

        # Eq.19 translation, invariant lengths.
        moved={}
        max_len_drift=0.0
        for j,(top,length) in slugs.items():
            d=slug_velocity(j)*DT
            nt=top+d; nb=nt+length
            if not(math.isfinite(nt) and 0<=nt<nb<=DEPTH):
                raise SystemExit(f"slug bounds step={st} bin={j} top={nt} bottom={nb}")
            moved[j]=[nt,length]
            max_len_drift=max(max_len_drift,abs((nb-nt)-length))
        if max_len_drift>1e-12: raise SystemExit("slug length drift")

        pre_gap=min_gap_slugs(moved,gw)
        if pre_gap is not None:
            min_gap_before_merge=pre_gap if min_gap_before_merge is None else min(min_gap_before_merge,pre_gap)

        # Primary-source merge: whole slug length raises same-bin groundwater front.
        merge_bins=[]
        gmerged=dict(gw)
        surviving={}
        merge_water=0.0
        for j,(top,length) in moved.items():
            bottom=top+length
            gw_top=DEPTH-gw[j]
            if bottom>=gw_top:
                nh=gw[j]+length
                if not(math.isfinite(nh) and 0<nh<=DEPTH):
                    raise SystemExit(f"merged GW bounds step={st} bin={j} H={nh}")
                gmerged[j]=nh
                merge_bins.append(j)
                merge_water += DTH*length
            else:
                surviving[j]=[top,length]

        s_after_merge=storage(slugs=surviving,gw=gmerged)
        merge_residual=s_after_merge-(storage(slugs=moved,gw=gw))
        if abs(merge_residual)>TOL:
            raise SystemExit(f"merge mass residual step={st} residual={merge_residual}")

        # Existing D13 groundwater dynamics and relaxation after internal merge.
        g_before_dynamic=DTH*math.fsum(gmerged.values())
        gw2=advance_gw(gmerged)
        g_after_dynamic=DTH*math.fsum(gw2.values())
        gw_bottom=-(g_after_dynamic-g_before_dynamic)
        bottom=gray_bottom+gw_bottom
        sa=storage(slugs=surviving,gw=gw2)
        mass=(sa-sb)-top_supply+bottom
        maxmass=max(maxmass,abs(mass))
        if abs(mass)>TOL: raise SystemExit(f"transition mass failure step={st} residual={mass}")

        post_gap=min_gap_slugs(surviving,gw2)
        if post_gap is not None and post_gap<0:
            raise SystemExit(f"post-GW overlap step={st} gap={post_gap}")

        step_rows.append({
          "step":st,"merge_count":len(merge_bins),"merge_bins":merge_bins,
          "merge_water_cm":merge_water,"merge_residual_cm":merge_residual,
          "top_supply_cm":top_supply,"gray_bottom_exchange_cm":gray_bottom,
          "groundwater_bottom_exchange_cm":gw_bottom,"total_bottom_exchange_cm":bottom,
          "mass_residual_cm":mass,"remaining_slug_count":len(surviving),
          "pre_merge_min_gap_cm":pre_gap,"post_step_min_gap_cm":post_gap
        })

        if merge_bins and first_merge_step is None:
            first_merge_step=st
            first_merge_bins=list(merge_bins)
            first_merge_pre={"storage_cm":sb,"pre_merge_min_gap_cm":pre_gap,"slug_count":len(slugs)}
            first_merge_post={"storage_cm":sa,"post_step_min_gap_cm":post_gap,"slug_count":len(surviving)}
        total_merges += len(merge_bins)
        slugs,gw=surviving,gw2

        if first_merge_step is not None:
            # Stage-1 needs only the first transition plus one accepted post-merge state.
            break

    passed=(first_merge_step is not None and total_merges>0 and maxmass<=TOL)
    result={
      "schema":"swap5.f-romv2-d18.event-preflight-result.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D18",
      "decision":"D18_FMC_SLUG_GW_MERGE_EVENT_PREFLIGHT_PASS" if passed else "D18_FMC_SLUG_GW_MERGE_EVENT_PREFLIGHT_NO_GO",
      "SWAP_trajectory_evidence_consumed":False,
      "D17_reconstruction":{
        "history":"C75_G25","pulse_steps":PULSE_STEPS,
        "storage_cm":reconstructed_storage,"minimum_separation_cm":reconstructed_gap
      },
      "transition":{
        "top_flux_cm_per_day":KI,
        "top_supply_equals_gray_demand":True,
        "first_merge_step":first_merge_step,
        "first_merge_time_seconds":None if first_merge_step is None else first_merge_step*10,
        "first_merge_bins":first_merge_bins,
        "total_merges_through_stop":total_merges,
        "minimum_pre_merge_gap_cm":min_gap_before_merge,
        "max_abs_mass_residual_cm":maxmass,
        "first_merge_pre":first_merge_pre,
        "first_merge_post":first_merge_post
      },
      "steps":step_rows,
      "preflight_pass":passed,
      "post_preflight_retuning_authorized":False,
      "production_rom_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({k:result[k] for k in ("decision","D17_reconstruction","transition","preflight_pass")},sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__": raise SystemExit(main())
