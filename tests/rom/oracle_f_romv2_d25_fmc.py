#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737; M=1.0-1.0/N
KS=31.225016; ELL=0.98087; HCM=14.085215420920257
NBINS=200; I=100; J0=101; J1=199; DEPTH=160.0
DT=10.0/86400.0; DTH=(TS-TR)/NBINS; TOL=1e-12; RELAX_TOL=1e-14
PONDMAX=KS*DT; RSRO=0.001
FACTORS={"RG05":0.5,"RG20":2.0,"RG40":4.0}; STEPS=16

def theta(j): return TR+j*DTH
def psi(t):
    if not(TR<t<TS): raise ValueError("theta domain")
    se=(t-TR)/(TS-TR)
    return ((se**(-1/M)-1)**(1/N))/ALPHA
def kval(t):
    if not(TR<t<TS): raise ValueError("theta domain")
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

def relax_map(d):
    keys=sorted(d)
    before=DTH*math.fsum(d[j] for j in keys)
    vals=sorted((d[j] for j in keys),reverse=True)
    out={j:v for j,v in zip(keys,vals)}
    after=DTH*math.fsum(out.values())
    drift=after-before
    if abs(drift)>RELAX_TOL: raise ValueError("relaxation mass drift")
    return out,drift

def surface_route(residual):
    if residual<=PONDMAX:
        return residual,0.0
    ratio=DT/RSRO
    store=(residual+ratio*PONDMAX)/(1.0+ratio)
    runoff=residual-store
    if not(0.0<=store<=residual and runoff>=0.0):
        raise ValueError("surface reservoir")
    return store,runoff

def connected_surface_step(fronts,available):
    gray=KI*DT
    if available+1e-18<gray:
        raise ValueError("available surface water below gray-bin demand")
    rem=available-gray; alloc=0.0; out=dict(fronts)
    for j in range(J0,J1+1):
        z=fronts[j]
        raw=z+DT*ADV*(1+GEFF/z)
        if not(math.isfinite(raw) and 0.0<raw<DEPTH):
            raise ValueError("surface front bounds")
        demand=max(0.0,DTH*(raw-z))
        take=min(rem,demand)
        if take>0:
            out[j]=z+take/DTH; rem-=take; alloc+=take
        if take<demand-1e-18 or rem<=1e-18:
            break
    out,drift=relax_map(out)
    store,runoff=surface_route(max(0.0,rem))
    return out,gray,alloc,store,runoff,drift

def gw_velocity(j,h):
    tj=theta(j)
    return (kval(tj)-KI)/(tj-TI)*(abs(psi(tj))/h-1.0)

def groundwater_step(gw):
    raw={}
    for j,h in gw.items():
        nh=h+DT*gw_velocity(j,h)
        if not(math.isfinite(nh) and 0.0<nh<=DEPTH):
            raise ValueError("groundwater front bounds")
        raw[j]=nh
    return relax_map(raw)

def groundwater_storage(gw):
    return TI*DEPTH+DTH*math.fsum(gw.values())
def total_soil_storage(fronts,gw):
    return TI*DEPTH+DTH*math.fsum(fronts.values())+DTH*math.fsum(gw.values())
def minimum_gap(fronts,gw):
    vals={j:DEPTH-fronts[j]-gw[j] for j in range(J0,J1+1)}
    j=min(vals,key=vals.get)
    return vals[j],j
def terminal_bottom_flux(gw):
    return KI-DTH*math.fsum(gw_velocity(j,gw[j]) for j in range(J0,J1+1))

def mapped_theta16(fronts,gw):
    vals=[]
    for c in range(16):
        top=10.0*c;bot=top+10.0;t=TI
        for j in range(J0,J1+1):
            surf=max(0.0,min(fronts[j],bot)-top)
            gtop=DEPTH-gw[j]
            ground=max(0.0,bot-max(gtop,top))
            if surf>0 and ground>0 and min(fronts[j],bot)>max(gtop,top):
                raise ValueError("surface-groundwater overlap")
            t+=DTH*(surf+ground)/10.0
        if not(TR<t<TS): raise ValueError("mapped theta bounds")
        vals.append(t)
    return vals

def run(factor):
    fronts=initial_surface();gw=initial_gw();surfstore=0.0;cumrun=0.0;cuminfil=0.0;cumbottom=0.0
    s0=total_soil_storage(fronts,gw)
    gap0,j0=minimum_gap(fronts,gw)
    if gap0<=0: raise ValueError("initial contact")
    max_surface=max_soil=max_global=max_srel=max_grel=0.0
    mingap=gap0;mingap_bin=j0
    rows=[]
    for step in range(1,STEPS+1):
        rain=factor*KS*DT
        sb=total_soil_storage(fronts,gw); g0=groundwater_storage(gw); prevstore=surfstore
        fronts2,gray,alloc,surfstore,runoff,srel=connected_surface_step(fronts,prevstore+rain)
        gw2,grel=groundwater_step(gw); g1=groundwater_storage(gw2)
        dgw=g1-g0
        infil=gray+alloc
        bottom=gray-dgw
        sa=total_soil_storage(fronts2,gw2)
        surface_ledger=prevstore+rain-infil-surfstore-runoff
        soil_ledger=(sa-sb)-infil+bottom
        global_ledger=(sa-sb)+surfstore-prevstore+runoff+bottom-rain
        gap,jgap=minimum_gap(fronts2,gw2)
        if gap<=0: raise ValueError(f"surface-groundwater contact step={step} bin={jgap}")
        theta16=mapped_theta16(fronts2,gw2)
        if max(abs(surface_ledger),abs(soil_ledger),abs(global_ledger))>TOL:
            raise ValueError(f"ledger step={step}")
        max_surface=max(max_surface,abs(surface_ledger));max_soil=max(max_soil,abs(soil_ledger))
        max_global=max(max_global,abs(global_ledger));max_srel=max(max_srel,abs(srel));max_grel=max(max_grel,abs(grel))
        if gap<mingap: mingap=gap;mingap_bin=jgap
        cumrun+=runoff;cuminfil+=infil;cumbottom+=bottom
        rows.append({"step":step,"rain_cm":rain,"infiltration_cm":infil,"cumulative_infiltration_cm":cuminfil,
                     "surface_store_cm":surfstore,"runoff_cm":runoff,"cumulative_runoff_cm":cumrun,
                     "bottom_exchange_cm":bottom,"cumulative_bottom_exchange_cm":cumbottom,
                     "bottom_flux_cm_per_day":terminal_bottom_flux(gw2),"soil_storage_cm":sa,
                     "theta16":theta16,
                     "minimum_separation_cm":gap,"surface_ledger_cm":surface_ledger,
                     "soil_ledger_cm":soil_ledger,"global_ledger_cm":global_ledger})
        fronts,gw=fronts2,gw2
    sf=total_soil_storage(fronts,gw)
    rain_total=STEPS*factor*KS*DT
    final_global=s0+rain_total-(sf+surfstore+cumrun+cumbottom)
    return {"pass":abs(final_global)<=TOL,"factor":factor,"initial_storage_cm":s0,"final_storage_cm":sf,
            "rainfall_cm":rain_total,"cumulative_infiltration_cm":cuminfil,"final_surface_store_cm":surfstore,
            "cumulative_runoff_cm":cumrun,"cumulative_bottom_exchange_cm":cumbottom,
            "initial_minimum_separation_cm":gap0,"minimum_separation_cm":mingap,
            "minimum_separation_bin":mingap_bin,"final_global_ledger_cm":final_global,
            "max_abs_surface_ledger_cm":max_surface,"max_abs_soil_ledger_cm":max_soil,
            "max_abs_global_ledger_cm":max_global,"max_surface_relaxation_drift_cm":max_srel,
            "max_groundwater_relaxation_drift_cm":max_grel,"rows":rows}

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--prereg",required=True);ap.add_argument("--output",required=True)
    a=ap.parse_args();p=json.loads(pathlib.Path(a.prereg).read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_FMC_INTERNAL_PREFLIGHT_AND_RICHARDS_TRAJECTORY_EXECUTION"
    assert p["initial_composite_state"]["groundwater_component"]["lambda"]==0.25
    assert p["discretization"]["moisture_bins"]==200 and p["discretization"]["process_step_seconds"]==10
    assert [h["rainfall_factor_Ksat"] for h in p["histories"]]==[0.5,2.0,4.0]
    assert "NO_CONTACT_OR_MERGE_IN_D24" in p["firewalls"]
    rows={};failure=None
    try:
        for h,f in FACTORS.items(): rows[h]=run(f)
        passed=all(v["pass"] for v in rows.values())
    except Exception as exc:
        passed=False;failure=str(exc)
    out={"schema":"swap5.f-romv2-d25.fmc-oracle.v1","workstream":"F-ROM","work_unit":"F-ROMV2-D25",
         "decision":"D25_FROZEN_D24_PYTHON_ORACLE_PASS" if passed else "D25_FROZEN_D24_PYTHON_ORACLE_NO_GO",
         "R16_R2_trajectory_evidence_consumed":False,"theta_i":TI,"K_i_cm_per_day":KI,
         "gray_throughflow_fraction_Ksat":KI/KS,"histories":rows,"failure":failure,
         "preflight_pass":passed,"R16_R2_trajectory_generation_authorized":passed,
         "post_preflight_retuning_authorized":False,"production_rom_authorized":False}
    pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({k:v for k,v in out.items() if k!="histories"}|{"history_summary":{h:{x:v[x] for x in ("pass","cumulative_runoff_cm","cumulative_bottom_exchange_cm","minimum_separation_cm","final_global_ledger_cm")} for h,v in rows.items()}},sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__": raise SystemExit(main())
