#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
HISTS={"N01":0.70,"N02":0.80,"N03":0.90,"N04":0.75}
NSTEPS=1024
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

bc=load_module("bc1_c5n",HERE/"run_lare_bc1_stage_b.py")
bc.HISTORY_SE=dict(HISTS)
bc.OBS_DT=OBS_DT
bc.STEPS=NSTEPS
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
    if sym=="BOTTOM_HEAD_RISE":return 0.875*psi0
    if sym=="BOTTOM_HEAD_FALL":return 1.125*psi0
    if sym=="HOLD":return None
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

def fields(payload:str):
    return bc.fields(payload)

def qstats(x):
    a=np.asarray(x,dtype=float)
    return {
      "rmse":float(np.sqrt(np.mean(a*a))),
      "mean":float(np.mean(a)),
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
            if w>0.0:total+=float(t)*w
        out.append(total/10.0)
    return out

def parse_reference(path:pathlib.Path,factor:int):
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
                profiles.setdefault((h,int(r["OBS_STEP"])),{})[int(r["BIN"])]=float(r["THETA"])
    out={}
    expected=NSTEPS*factor
    for h in HISTS:
        total=[];cum=[];q=[];theta=[];cx=0.0
        if sum(1 for hh,ss in states if hh==h)!=expected:
            raise RuntimeError(f"{path}: state count mismatch {h}")
        for obs in range(1,NSTEPS+1):
            lo=(obs-1)*factor+1;hi=obs*factor
            rows=[states[(h,s)] for s in range(lo,hi+1)]
            ex=sum(float(x["BOTTOM_OUTWARD_EXCHANGE"]) for x in rows)
            cx+=ex
            total.append(float(rows[-1]["TOTAL_STORAGE"]))
            cum.append(cx)
            q.append(ex/OBS_DT)
            bins=profiles.get((h,obs),{})
            if sorted(bins)!=list(range(1,17)):
                raise RuntimeError(f"{path}: incomplete profile {h} obs={obs}")
            theta.append([bins[i] for i in range(1,17)])
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
    S=[];C=[];Q=[];T=[];finals=[];signerr=0;rev_mismatch=0;rev_penalty=0;by={}
    hist_signed=[]
    for h in HISTS:
        ca=candidate[h];rr=reference[h]
        ds=np.asarray(ca["total"])-np.asarray(rr["total"])
        dc=np.asarray(ca["cum"])-np.asarray(rr["cum"])
        dq=np.asarray(ca["q"])-np.asarray(rr["q"])
        dt=np.asarray(ca["theta"])-np.asarray(rr["theta"])
        S.extend(ds.tolist());C.extend(dc.tolist());Q.extend(dq.tolist());T.extend(dt.ravel().tolist())
        finals.append(float(dc[-1]))
        hm=float(np.mean(dq));hist_signed.append(hm)
        se=int(np.count_nonzero(np.sign(np.asarray(ca["q"]))!=np.sign(np.asarray(rr["q"]))))
        signerr+=se
        cr=reversal_steps(ca["q"]);rrev=reversal_steps(rr["q"])
        mismatch=len(cr)!=len(rrev)
        if mismatch:
            penalty=NSTEPS;rev_mismatch+=1
        else:
            penalty=max([abs(x-y) for x,y in zip(cr,rrev)] or [0])
        rev_penalty=max(rev_penalty,penalty)
        by[h]={
          "total_storage_rmse_cm":qstats(ds)["rmse"],
          "cumulative_bottom_rmse_cm":qstats(dc)["rmse"],
          "interval_bottom_flux_rmse_cm_per_day":qstats(dq)["rmse"],
          "bottom_flux_sign_mismatch_count":se,
          "signed_bottom_flux_bias_cm_per_day":hm,
          "abs_signed_bottom_flux_bias_cm_per_day":abs(hm),
          "abs_final_cumulative_bottom_error_cm":abs(float(dc[-1])),
          "mapped_theta_rmse":qstats(dt.ravel())["rmse"],
          "candidate_reversal_steps":cr,
          "reference_reversal_steps":rrev,
          "reversal_sequence_mismatch":mismatch,
          "reversal_penalty_steps":penalty,
        }
    pooled_mean=float(np.mean(np.asarray(Q,dtype=float)))
    mean_abs_hist=float(np.mean(np.abs(np.asarray(hist_signed,dtype=float))))
    return {
      "total_storage_rmse_cm":qstats(S)["rmse"],
      "cumulative_bottom_rmse_cm":qstats(C)["rmse"],
      "interval_bottom_flux_rmse_cm_per_day":qstats(Q)["rmse"],
      "bottom_flux_sign_mismatch_count":int(signerr),
      "mean_abs_history_signed_bottom_flux_error_cm_per_day":mean_abs_hist,
      "pooled_signed_bottom_flux_bias_cm_per_day":pooled_mean,
      "pooled_abs_signed_bottom_flux_bias_cm_per_day":abs(pooled_mean),
      "cancellation_ratio":abs(pooled_mean)/mean_abs_hist if mean_abs_hist else None,
      "max_abs_final_cumulative_bottom_error_cm":max(abs(x) for x in finals),
      "reversal_sequence_mismatch_history_count":int(rev_mismatch),
      "reversal_penalty_steps":int(rev_penalty),
      "mapped_theta_rmse":qstats(T)["rmse"],
      "by_history":by,
    }

def no_worse(a,b,keys):
    for k in keys:
        av=a[k];bv=b[k]
        if isinstance(av,int) and isinstance(bv,int):
            if av>bv:return False
        elif float(av)>float(bv)+EQ_TOL:
            return False
    return True

def run_member(member,bounds,target):
    histories={};failures={};status="QUALIFIED";maxledger=0.0;maxiter=0
    for h in HISTS:
        try:
            sol=bc.solve(bc.Case(member,h,"CURRENT_LAYER_FACE"),LARE_DT)
            if float(sol["max_abs_water_ledger_cm"])>LEDGER_GATE:
                raise RuntimeError("water ledger gate")
            histories[h]=candidate_arrays(sol,bounds)
            maxledger=max(maxledger,float(sol["max_abs_water_ledger_cm"]))
            maxiter=max(maxiter,int(sol["max_corrector_iterations"]))
        except ValueError as exc:
            status="OUTSIDE_QUALIFIED_DOMAIN";failures[h]=str(exc)
        except (RuntimeError,FloatingPointError) as exc:
            status="NUMERICAL_BLOCKED";failures[h]=str(exc)
    metrics=compare_routes(histories,target) if status=="QUALIFIED" and len(histories)==len(HISTS) else None
    return {
      "id":member,"dimension":len(bounds)-1,"boundaries_cm":bounds,
      "status":status,"failures":failures,
      "max_abs_water_ledger_cm":maxledger,"max_corrector_iterations":maxiter,
      "metrics":metrics
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
    p=json.loads(a.prereg.read_text());m=json.loads(a.c5m.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5N_FRESH_REFERENCE_OR_LARE_RESPONSE"
    assert p["implementation_binding"]["state"]=="BOUND_BEFORE_EXECUTION"
    assert m["decision"]=="PRESERVE_PLACEMENT_PURPOSE_AND_INTERACTION_FINDINGS_REJECT_UNIVERSAL_LAYER_COUNT_PREREGISTER_FRESH_HIGH_RES_B14_DYNAMIC_TEST"

    r512=parse_reference(a.r512_t16,16)
    r1024=parse_reference(a.r1024_t16,16)
    r2048=parse_reference(a.r2048_t16,16)
    r2048t8=parse_reference(a.r2048_t8,8)

    comp512=compare_routes(r512,r2048)
    comp1024=compare_routes(r1024,r2048)
    temporal=compare_routes(r2048t8,r2048)

    ref_quality={
      "temporal_no_worse_than_R512_GW":no_worse(temporal,comp512,GW_KEYS),
      "temporal_no_worse_than_R512_PROFILE":no_worse(temporal,comp512,PROFILE_KEYS),
      "temporal_no_worse_than_R1024_GW":no_worse(temporal,comp1024,GW_KEYS),
      "temporal_no_worse_than_R1024_PROFILE":no_worse(temporal,comp1024,PROFILE_KEYS),
    }
    ref_quality["R1024_frontier_interpretable"]=ref_quality["temporal_no_worse_than_R1024_GW"] and ref_quality["temporal_no_worse_than_R1024_PROFILE"]
    ref_quality["R512_frontier_interpretable"]=ref_quality["temporal_no_worse_than_R512_GW"] and ref_quality["temporal_no_worse_than_R512_PROFILE"]

    members=[]
    if ref_quality["R512_frontier_interpretable"] or ref_quality["R1024_frontier_interpretable"]:
        for member in list(LADDER)+list(CONTROLS):
            members.append(run_member(member,PARTITIONS[member],r2048))
    else:
        # Fail closed before candidate response generation if the high-resolution control is not temporally qualified.
        out={
          "schema":"swap5.lare.bc2.c5n.result.v1","workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5N",
          "blind_validation":True,"status":"C5N_REFERENCE_TEMPORAL_QUALITY_BLOCKED_BEFORE_LARE_RESPONSE",
          "reference_comparators":{"R512_vs_R2048":comp512,"R1024_vs_R2048":comp1024,"R2048_T8_vs_T16":temporal},
          "reference_quality":ref_quality,"members":[],
          "scientific_firewall":{
            "candidate_response_generated":False,"C5A_formal_decision_changed":False,
            "application_acceptance_adjudicated":False,"performance_comparison_authorized":False,
            "speed_claim_authorized":False,"production_rom_authorized":False
          }
        }
        a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
        print(json.dumps({"status":out["status"],"reference_quality":ref_quality},sort_keys=True))
        return

    qualified=[x for x in members if x["status"]=="QUALIFIED"]
    maxledger=max([x["max_abs_water_ledger_cm"] for x in qualified] or [0.0])
    reduced=[x for x in qualified if x["dimension"]<16 and x["id"] in LADDER]

    crossings={}
    for x in qualified:
        mm=x["metrics"]
        crossings[x["id"]]={
          "R512_GW":no_worse(mm,comp512,GW_KEYS),
          "R512_PROFILE":no_worse(mm,comp512,PROFILE_KEYS),
          "R1024_GW":no_worse(mm,comp1024,GW_KEYS),
          "R1024_PROFILE":no_worse(mm,comp1024,PROFILE_KEYS),
          "TEMPORAL_FLOOR_GW":no_worse(mm,temporal,GW_KEYS),
          "TEMPORAL_FLOOR_PROFILE":no_worse(mm,temporal,PROFILE_KEYS),
        }

    def ladder_frontier(key):
        ids=[x["id"] for x in reduced if crossings[x["id"]][key]]
        dims=[x["dimension"] for x in reduced if crossings[x["id"]][key]]
        return ids,min(dims) if dims else None

    fronts={};mins={}
    for key in ("R512_GW","R512_PROFILE","R1024_GW","R1024_PROFILE","TEMPORAL_FLOOR_GW","TEMPORAL_FLOOR_PROFILE"):
        fronts[key],mins[key]=ladder_frontier(key)

    def placement(low,uniform):
        arow=next(x for x in qualified if x["id"]==low)
        brow=next(x for x in qualified if x["id"]==uniform)
        return no_worse(arow["metrics"],brow["metrics"],GW_KEYS)

    if ref_quality["R1024_frontier_interpretable"] and fronts["R1024_PROFILE"]:
        status="C5N_HIGH_RES_GW_PROFILE_FRONTIER_PRESENT"
    elif ref_quality["R1024_frontier_interpretable"] and fronts["R1024_GW"]:
        status="C5N_HIGH_RES_GW_FRONTIER_ONLY"
    elif ref_quality["R512_frontier_interpretable"] and (fronts["R512_GW"] or fronts["R512_PROFILE"]):
        status="C5N_MODERATE_RESOLUTION_FRONTIER_ONLY"
    else:
        status="C5N_NO_REDUCED_HIGH_RES_COMPARATOR_FRONTIER"

    out={
      "schema":"swap5.lare.bc2.c5n.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5N",
      "blind_validation":True,
      "material":"B14","status":status,
      "formal_C5A_decision_retained":"C5A_DYNAMIC_HEAD_REDUCED_FRONTIER_NOT_PRESERVED",
      "reference_comparators":{
        "R512_vs_R2048":comp512,
        "R1024_vs_R2048":comp1024,
        "R2048_T8_vs_T16":temporal
      },
      "reference_quality":ref_quality,
      "members":members,
      "crossings":crossings,
      "frontiers":fronts,
      "minimum_dimensions":mins,
      "placement_tests":{
        "R4_no_worse_than_U4_GW":placement("R4","U4"),
        "R8_no_worse_than_U8_GW":placement("R8","U8")
      },
      "hypotheses":{
        "H_PLACEMENT_R4":placement("R4","U4"),
        "H_PLACEMENT_R8":placement("R8","U8"),
        "H_REDUCED_MEMBER_CROSSES_R512_GW":bool(fronts["R512_GW"]),
        "H_REDUCED_MEMBER_CROSSES_R1024_GW":bool(fronts["R1024_GW"]) if ref_quality["R1024_frontier_interpretable"] else None,
        "H_PROFILE_REQUIRES_MORE_STATE":(
          mins["R1024_PROFILE"]>mins["R1024_GW"]
          if ref_quality["R1024_frontier_interpretable"] and mins["R1024_PROFILE"] is not None and mins["R1024_GW"] is not None
          else None
        )
      },
      "integrity":{
        "all_candidates_attempted":len(members)==len(LADDER)+len(CONTROLS),
        "maximum_qualified_lare_water_ledger_cm":maxledger,
        "pass":len(members)==len(LADDER)+len(CONTROLS) and maxledger<=LEDGER_GATE
      },
      "interpretation_boundaries":[
        "R2048_T16 is the finest available numerical control, not continuum truth.",
        "R512/R1024 frontiers are comparator-resolution statements, not application acceptance.",
        "The temporal-floor crossing is a numerical indistinguishability diagnostic only.",
        "Per-history signed flux bias, not pooled signed bias, participates in frontier gates; pooled cancellation is reported diagnostically.",
        "No universal minimum layer count is inferred.",
        "No performance, speed or production claim is authorized."
      ],
      "scientific_firewall":{
        "candidate_response_generated":True,
        "C5A_formal_decision_changed":False,
        "production_reference_changed":False,
        "new_closure_fit":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,"reference_quality":ref_quality,
      "minimum_dimensions":mins,"frontiers":fronts,
      "placement_tests":out["placement_tests"],"integrity":out["integrity"]
    },sort_keys=True))

if __name__=="__main__":
    main()
