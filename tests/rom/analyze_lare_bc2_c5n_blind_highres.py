#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
HISTS={"N01":0.70,"N02":0.80,"N03":0.90,"N04":0.75}
OBS_STEPS=1024
OBS_DT=0.0008
LARE_DT=0.0001
EQ_TOL=1.0e-12
LEDGER_GATE=1.0e-10

PARTITIONS={
 "R3":[0.0,140.0,150.0,160.0],
 "R4":[0.0,130.0,140.0,150.0,160.0],
 "R5":[0.0,120.0,130.0,140.0,150.0,160.0],
 "R6":[0.0,110.0,120.0,130.0,140.0,150.0,160.0],
 "R8":[0.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
 "R12":[0.0,50.0,60.0,70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
 "R16":[float(x) for x in range(0,161,10)],
 "P4_TOP_LOWER":[0.0,10.0,140.0,150.0,160.0],
 "U4":[0.0,40.0,80.0,120.0,160.0],
 "U8":[0.0,20.0,40.0,60.0,80.0,100.0,120.0,140.0,160.0],
}
LADDER=("R3","R4","R5","R6","R8","R12","R16")
CONTROLS=("P4_TOP_LOWER","U4","U8")
GW_KEYS=(
 "total_storage_rmse_cm",
 "cumulative_bottom_rmse_cm",
 "interval_bottom_flux_rmse_cm_per_day",
 "bottom_flux_sign_mismatch_count",
 "mean_abs_history_signed_bottom_flux_error_cm_per_day",
 "max_abs_final_cumulative_bottom_error_cm",
 "reversal_sequence_mismatch_history_count",
 "reversal_penalty_steps",
)
PROFILE_KEYS=GW_KEYS+("mapped_theta_rmse",)

def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

bc=load_module("bc1_c5n_base",HERE/"run_lare_bc1_stage_b.py")
bc.HISTORY_SE=dict(HISTS)
bc.OBS_DT=OBS_DT
bc.STEPS=OBS_STEPS
for name,bounds in PARTITIONS.items():
    bc.PARTITIONS[name]=np.diff(np.asarray(bounds,dtype=float))

def symbol(history,step):
    if history=="N01":
        if step<=224:return "BOTTOM_HEAD_FALL"
        if step<=576:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="N02":
        if step<=288:return "BOTTOM_HEAD_RISE"
        if step<=576:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    if history=="N03":
        if step<=352:return "BOTTOM_HEAD_FALL"
        if step<=576:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="N04":
        if step<=224:return "BOTTOM_HEAD_RISE"
        if step<=576:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    raise ValueError(history)

def boundary_psi(history,sym,psi0):
    if sym=="BOTTOM_HEAD_RISE": return 0.875*psi0
    if sym=="BOTTOM_HEAD_FALL": return 1.125*psi0
    if sym=="HOLD": return None
    raise ValueError((history,sym))

bc.symbol=symbol
bc.boundary_psi=boundary_psi
bc.THETA_R=0.01
bc.THETA_S=0.416774
bc.ALPHA=0.00541
bc.N_VG=1.301528
bc.M_VG=1.0-1.0/bc.N_VG
bc.KS=0.895023
bc.LAMBDA=-0.334926

def qstats(values):
    a=np.asarray(values,dtype=float)
    return {
      "rmse":float(np.sqrt(np.mean(a*a))),
      "mean":float(np.mean(a)),
      "mean_abs":float(np.mean(np.abs(a))),
      "max_abs":float(np.max(np.abs(a))),
    }

def map_piecewise_theta(layer_storage,bounds):
    dz=np.diff(np.asarray(bounds,dtype=float))
    theta=np.asarray(layer_storage,dtype=float)/dz
    out=[]
    for node in range(16):
        lo=node*10.0;hi=(node+1)*10.0
        total=0.0
        for t,a,b in zip(theta,bounds,bounds[1:]):
            w=max(0.0,min(hi,b)-max(lo,a))
            if w>0.0: total+=float(t)*w
        out.append(total/10.0)
    return out

def fields(payload):
    return bc.fields(payload)

def load_reference(path:pathlib.Path,factor:int):
    states={};profiles={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1])
            h=r.get("HISTORY")
            if h in HISTS:
                states[(h,int(r["STEP"]))]=r
        elif line.startswith("LAREGW1_PROFILE|"):
            r=fields(line.split("|",1)[1])
            h=r.get("HISTORY")
            if h in HISTS:
                profiles[(h,int(r["OBS_STEP"]),int(r["BIN"]))]=float(r["THETA"])
    out={}
    expected=OBS_STEPS*factor
    for h in HISTS:
        total=[];cum=[];q=[];theta=[];running=0.0
        for obs in range(1,OBS_STEPS+1):
            lo=(obs-1)*factor+1;hi=obs*factor
            exch=0.0
            for step in range(lo,hi+1):
                key=(h,step)
                if key not in states:
                    raise RuntimeError(f"incomplete Reference state {path} {key}")
                exch+=float(states[key]["BOTTOM_OUTWARD_EXCHANGE"])
            running+=exch
            end=states[(h,hi)]
            total.append(float(end["TOTAL_STORAGE"]))
            cum.append(running)
            q.append(exch/OBS_DT)
            bins=[]
            for b in range(1,17):
                key=(h,obs,b)
                if key not in profiles:
                    raise RuntimeError(f"incomplete Reference profile {path} {key}")
                bins.append(profiles[key])
            theta.append(bins)
        if sum(1 for (hh,_) in states if hh==h)!=expected:
            raise RuntimeError(f"unexpected Reference state count {path} {h}")
        out[h]={"total":total,"cum":cum,"q":q,"theta":theta}
    return out

def candidate_arrays(result,bounds):
    storage=np.asarray(result["layer_storage_cm"],dtype=float)
    return {
      "total":np.sum(storage,axis=1).tolist(),
      "cum":[float(x) for x in result["cumulative_bottom_downward_cm"]],
      "q":[float(x) for x in result["interval_average_bottom_downward_flux_cm_per_day"]],
      "theta":[map_piecewise_theta(row,bounds) for row in storage],
    }

def reversal_steps(values):
    return bc.reversals([float(x) for x in values])

def compare_routes(candidate,reference):
    S=[];C=[];Q=[];T=[];finals=[];signerr=0;rev_mismatch=0;rev_penalty=0
    hist_signed=[];by={}
    for h in HISTS:
        ca=candidate[h];rr=reference[h]
        ds=np.asarray(ca["total"])-np.asarray(rr["total"])
        dc=np.asarray(ca["cum"])-np.asarray(rr["cum"])
        dq=np.asarray(ca["q"])-np.asarray(rr["q"])
        dt=np.asarray(ca["theta"])-np.asarray(rr["theta"])
        S.extend(ds.tolist());C.extend(dc.tolist());Q.extend(dq.tolist());T.extend(dt.ravel().tolist())
        finals.append(float(dc[-1]))
        mean_signed=float(np.mean(dq));hist_signed.append(abs(mean_signed))
        se=int(np.count_nonzero(np.sign(np.asarray(ca["q"]))!=np.sign(np.asarray(rr["q"]))))
        signerr+=se
        cr=reversal_steps(ca["q"]);rv=reversal_steps(rr["q"])
        mismatch=len(cr)!=len(rv)
        if mismatch:
            penalty=OBS_STEPS;rev_mismatch+=1
        else:
            penalty=max([abs(x-y) for x,y in zip(cr,rv)] or [0])
        rev_penalty=max(rev_penalty,penalty)
        by[h]={
          "total_storage_rmse_cm":qstats(ds)["rmse"],
          "cumulative_bottom_rmse_cm":qstats(dc)["rmse"],
          "interval_bottom_flux_rmse_cm_per_day":qstats(dq)["rmse"],
          "bottom_flux_sign_mismatch_count":se,
          "abs_mean_signed_bottom_flux_error_cm_per_day":abs(mean_signed),
          "max_abs_final_cumulative_bottom_error_cm":abs(float(dc[-1])),
          "mapped_theta_rmse":qstats(dt.ravel())["rmse"],
          "candidate_reversal_steps":cr,
          "reference_reversal_steps":rv,
          "reversal_sequence_mismatch":mismatch,
          "reversal_penalty_steps":penalty,
        }
    pooled_signed=float(np.mean(np.asarray(Q,dtype=float)))
    mean_abs_hist=float(np.mean(hist_signed))
    return {
      "total_storage_rmse_cm":qstats(S)["rmse"],
      "cumulative_bottom_rmse_cm":qstats(C)["rmse"],
      "interval_bottom_flux_rmse_cm_per_day":qstats(Q)["rmse"],
      "bottom_flux_sign_mismatch_count":int(signerr),
      "mean_abs_history_signed_bottom_flux_error_cm_per_day":mean_abs_hist,
      "max_abs_final_cumulative_bottom_error_cm":max(abs(x) for x in finals),
      "reversal_sequence_mismatch_history_count":int(rev_mismatch),
      "reversal_penalty_steps":int(rev_penalty),
      "mapped_theta_rmse":qstats(T)["rmse"],
      "pooled_signed_bottom_flux_bias_cm_per_day":pooled_signed,
      "cancellation_ratio":0.0 if mean_abs_hist==0.0 else abs(pooled_signed)/mean_abs_hist,
      "by_history":by,
    }

def no_worse(a,b,keys):
    for k in keys:
        if k in ("bottom_flux_sign_mismatch_count","reversal_sequence_mismatch_history_count","reversal_penalty_steps"):
            if int(a[k])>int(b[k]):return False
        elif float(a[k])>float(b[k])+EQ_TOL:
            return False
    return True

def run_member(member,bounds,refs):
    histories={};status="QUALIFIED";failures={};maxledger=0.0;maxiter=0
    for h in HISTS:
        case=bc.Case(member,h,"CURRENT_LAYER_FACE")
        try:
            sol=bc.solve(case,LARE_DT)
            if float(sol["max_abs_water_ledger_cm"])>LEDGER_GATE:
                raise RuntimeError("water ledger gate")
            histories[h]=candidate_arrays(sol,bounds)
            maxledger=max(maxledger,float(sol["max_abs_water_ledger_cm"]))
            maxiter=max(maxiter,int(sol["max_corrector_iterations"]))
        except ValueError as exc:
            status="OUTSIDE_QUALIFIED_DOMAIN";failures[h]=str(exc)
        except (RuntimeError,FloatingPointError) as exc:
            status="NUMERICAL_BLOCKED";failures[h]=str(exc)
    metrics={}
    if status=="QUALIFIED" and len(histories)==len(HISTS):
        for name,ref in refs.items():
            metrics[name]=compare_routes(histories,ref)
    return {
      "id":member,"dimension":len(bounds)-1,"boundaries_cm":bounds,
      "status":status,"failures":failures,
      "max_abs_water_ledger_cm":maxledger,
      "max_corrector_iterations":maxiter,
      "metrics":metrics,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r512-t16",required=True,type=pathlib.Path)
    ap.add_argument("--r1024-t16",required=True,type=pathlib.Path)
    ap.add_argument("--r2048-t16",required=True,type=pathlib.Path)
    ap.add_argument("--r2048-t8",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c5m",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    c5m=json.loads(a.c5m.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5N_FRESH_REFERENCE_OR_LARE_RESPONSE"
    assert p["blind_design"]["response_blind"] is True
    assert p["representations"]["no_response_based_repartitioning"] is True
    assert c5m["decision"]=="PRESERVE_PLACEMENT_PURPOSE_AND_INTERACTION_FINDINGS_REJECT_UNIVERSAL_LAYER_COUNT_PREREGISTER_FRESH_HIGH_RES_B14_DYNAMIC_TEST"

    r512=load_reference(a.r512_t16,16)
    r1024=load_reference(a.r1024_t16,16)
    r2048=load_reference(a.r2048_t16,16)
    r2048t8=load_reference(a.r2048_t8,8)
    refs={"R512_T16":r512,"R1024_T16":r1024,"R2048_T16":r2048,"R2048_T8":r2048t8}

    refcomp={
      "R512_T16_vs_R2048_T16":compare_routes(r512,r2048),
      "R1024_T16_vs_R2048_T16":compare_routes(r1024,r2048),
      "R2048_T8_vs_R2048_T16":compare_routes(r2048t8,r2048),
    }
    temporal_quality_gw=no_worse(refcomp["R2048_T8_vs_R2048_T16"],refcomp["R1024_T16_vs_R2048_T16"],GW_KEYS)
    temporal_quality_profile=no_worse(refcomp["R2048_T8_vs_R2048_T16"],refcomp["R1024_T16_vs_R2048_T16"],PROFILE_KEYS)

    members=[run_member(m,PARTITIONS[m],refs) for m in list(LADDER)+list(CONTROLS)]
    all_attempted=len(members)==len(LADDER)+len(CONTROLS)
    integrity=all_attempted and all(
      x["status"]!="QUALIFIED" or x["max_abs_water_ledger_cm"]<=LEDGER_GATE for x in members
    )

    crossing={}
    for x in members:
        if x["status"]!="QUALIFIED":continue
        m=x["metrics"]["R2048_T16"]
        crossing[x["id"]]={
          "R512_GW":no_worse(m,refcomp["R512_T16_vs_R2048_T16"],GW_KEYS),
          "R512_PROFILE":no_worse(m,refcomp["R512_T16_vs_R2048_T16"],PROFILE_KEYS),
          "R1024_GW":no_worse(m,refcomp["R1024_T16_vs_R2048_T16"],GW_KEYS),
          "R1024_PROFILE":no_worse(m,refcomp["R1024_T16_vs_R2048_T16"],PROFILE_KEYS),
          "R2048_T8_GW":no_worse(m,refcomp["R2048_T8_vs_R2048_T16"],GW_KEYS),
          "R2048_T8_PROFILE":no_worse(m,refcomp["R2048_T8_vs_R2048_T16"],PROFILE_KEYS),
        }

    def member(mid):
        return next(x for x in members if x["id"]==mid)
    def place(low,uniform,refname):
        a1=member(low);b1=member(uniform)
        if a1["status"]!="QUALIFIED" or b1["status"]!="QUALIFIED":return None
        return no_worse(a1["metrics"][refname],b1["metrics"][refname],GW_KEYS)

    placement={
      "R4_no_worse_U4_vs_R2048":place("R4","U4","R2048_T16"),
      "R4_no_worse_U4_vs_R1024":place("R4","U4","R1024_T16"),
      "R8_no_worse_U8_vs_R2048":place("R8","U8","R2048_T16"),
      "R8_no_worse_U8_vs_R1024":place("R8","U8","R1024_T16"),
      "R4_no_worse_P4_vs_R2048":place("R4","P4_TOP_LOWER","R2048_T16"),
      "P4_no_worse_R4_vs_R2048":place("P4_TOP_LOWER","R4","R2048_T16"),
    }
    placement["R4_reference_stable"]=placement["R4_no_worse_U4_vs_R2048"] is True and placement["R4_no_worse_U4_vs_R1024"] is True
    placement["R8_reference_stable"]=placement["R8_no_worse_U8_vs_R2048"] is True and placement["R8_no_worse_U8_vs_R1024"] is True

    ladder=[x for x in members if x["id"] in LADDER and x["dimension"]<16 and x["status"]=="QUALIFIED"]
    def min_dim(key):
        vals=[x["dimension"] for x in ladder if crossing.get(x["id"],{}).get(key) is True]
        return min(vals) if vals else None
    frontiers={
      "R512_GW":[x["id"] for x in ladder if crossing.get(x["id"],{}).get("R512_GW")],
      "R512_PROFILE":[x["id"] for x in ladder if crossing.get(x["id"],{}).get("R512_PROFILE")],
      "R1024_GW":[x["id"] for x in ladder if crossing.get(x["id"],{}).get("R1024_GW")],
      "R1024_PROFILE":[x["id"] for x in ladder if crossing.get(x["id"],{}).get("R1024_PROFILE")],
      "R2048_T8_GW":[x["id"] for x in ladder if crossing.get(x["id"],{}).get("R2048_T8_GW")],
      "R2048_T8_PROFILE":[x["id"] for x in ladder if crossing.get(x["id"],{}).get("R2048_T8_PROFILE")],
      "minimum_dimension_R512_GW":min_dim("R512_GW"),
      "minimum_dimension_R512_PROFILE":min_dim("R512_PROFILE"),
      "minimum_dimension_R1024_GW":min_dim("R1024_GW"),
      "minimum_dimension_R1024_PROFILE":min_dim("R1024_PROFILE"),
      "minimum_dimension_R2048_T8_GW":min_dim("R2048_T8_GW"),
      "minimum_dimension_R2048_T8_PROFILE":min_dim("R2048_T8_PROFILE"),
    }

    if not integrity:
        decision="C5N_REFERENCE_OR_EXECUTION_BLOCKED"
    elif not temporal_quality_gw:
        decision="C5N_REFERENCE_TEMPORAL_QUALITY_BLOCKS_HIGH_RES_FRONTIER"
    elif frontiers["R1024_PROFILE"]:
        decision="C5N_R1024_RELATIVE_GW_PROFILE_FRONTIER_PRESENT"
    elif frontiers["R1024_GW"]:
        decision="C5N_R1024_RELATIVE_GW_FRONTIER_ONLY"
    elif frontiers["R512_GW"]:
        decision="C5N_R512_BOUNDED_GW_FRONTIER_ONLY"
    else:
        decision="C5N_NO_REDUCED_HIGH_RES_FRONTIER"

    out={
      "schema":"swap5.lare.bc2.c5n.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5N",
      "decision":decision,
      "response_blind":True,
      "fresh_histories":["N01","N02","N03","N04"],
      "reference_quality":{
        "comparators":refcomp,
        "R2048_T8_T16_componentwise_no_worse_than_R1024_R2048_GW":temporal_quality_gw,
        "R2048_T8_T16_componentwise_no_worse_than_R1024_R2048_PROFILE":temporal_quality_profile,
      },
      "integrity":{
        "all_frozen_candidates_attempted":all_attempted,
        "lare_integrity":integrity,
        "maximum_qualified_lare_water_ledger_cm":max([x["max_abs_water_ledger_cm"] for x in members if x["status"]=="QUALIFIED"] or [0.0]),
      },
      "members":members,
      "crossing":crossing,
      "frontiers":frontiers,
      "placement_tests":placement,
      "hypotheses":{
        "H_PLACEMENT_R4":placement["R4_reference_stable"],
        "H_PLACEMENT_R8":placement["R8_reference_stable"],
        "H_REDUCED_MEMBER_CROSSES_R512_GW":bool(frontiers["R512_GW"]),
        "H_REDUCED_MEMBER_CROSSES_R1024_GW":bool(frontiers["R1024_GW"]),
        "H_PROFILE_REQUIRES_MORE_STATE":(
          frontiers["minimum_dimension_R1024_GW"] is not None and
          frontiers["minimum_dimension_R1024_PROFILE"] is not None and
          frontiers["minimum_dimension_R1024_PROFILE"]>frontiers["minimum_dimension_R1024_GW"]
        )
      },
      "interpretation_boundaries":[
        "R2048_T16 is the finest available numerical control, not continuum truth.",
        "R512/R1024 crossing is comparator-relative representation evidence, not application acceptance.",
        "R2048_T8 crossing is a numerical temporal-floor comparison, not a hydrological tolerance.",
        "Per-history signed bias is used in the formal groundwater vector; pooled signed bias is diagnostic only.",
        "Minimum dimensions are workload/comparator-specific and must not be generalized universally.",
        "No partition, closure, history or threshold was tuned after N01-N04 response exposure."
      ],
      "scientific_firewall":{
        "C5A_formal_decision_changed":False,
        "production_reference_changed":False,
        "boundary_counterfactual":False,
        "new_closure_fit":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,
      "reference_temporal_quality_GW":temporal_quality_gw,
      "reference_temporal_quality_PROFILE":temporal_quality_profile,
      "frontiers":frontiers,
      "placement_tests":placement,
      "max_lare_ledger":out["integrity"]["maximum_qualified_lare_water_ledger_cm"]
    },sort_keys=True))

if __name__=="__main__":
    main()
