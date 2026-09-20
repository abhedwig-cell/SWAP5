#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

import numpy as np

HISTS=("U01","U02","U03","U04")
METRIC_KEYS=(
    "surface_0_20_storage_rmse_cm",
    "root_zone_0_40_storage_rmse_cm",
    "upper_0_80_storage_rmse_cm",
    "mapped_10cm_theta_rmse",
)
VIEWS={
    "SURFACE_20":("surface_0_20_storage_rmse_cm",),
    "ROOT_ZONE_40":("surface_0_20_storage_rmse_cm","root_zone_0_40_storage_rmse_cm"),
    "UPPER_ZONE_80":("surface_0_20_storage_rmse_cm","root_zone_0_40_storage_rmse_cm","upper_0_80_storage_rmse_cm"),
    "PROFILE_STATE":METRIC_KEYS,
}
LADDER=("R3","R4","R5","R6","R8","R12","R16")
CONTROLS=("P4_TOP_LOWER","U4","U8")


def fields(line:str)->dict[str,str]:
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out


def parse_reference(path:pathlib.Path)->dict[str,dict[str,np.ndarray]]:
    states={h:{} for h in HISTS}
    profiles={h:{} for h in HISTS}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            r=fields(line)
            h=r.get("CASE")
            if h in states:
                states[h][int(r["STEP"])]=float(r["TOTAL_STORAGE"])
        elif line.startswith("LAREDYN0R_PROFILE|"):
            r=fields(line)
            h=r.get("CASE")
            if h in profiles:
                obs=int(r["OBS_STEP"])
                profiles[h].setdefault(obs,{})[int(r["BIN"])]=float(r["THETA"])
    out={}
    factor=32
    for h in HISTS:
        if sorted(states[h])!=list(range(1,1024*factor+1)):
            raise RuntimeError(f"Reference state coverage mismatch {h}")
        if sorted(profiles[h])!=list(range(1,1025)):
            raise RuntimeError(f"Reference profile coverage mismatch {h}")
        total=[];s20=[];r40=[];u80=[];theta=[]
        for obs in range(1,1025):
            bins=profiles[h][obs]
            if sorted(bins)!=list(range(1,17)):
                raise RuntimeError(f"Reference profile bins mismatch {h} {obs}")
            p=np.asarray([bins[i] for i in range(1,17)],dtype=float)
            total.append(states[h][obs*factor])
            s20.append(float(np.sum(p[:2])*10.0))
            r40.append(float(np.sum(p[:4])*10.0))
            u80.append(float(np.sum(p[:8])*10.0))
            theta.append(p)
        out[h]={
            "total_storage_cm":np.asarray(total),
            "surface_0_20_storage_cm":np.asarray(s20),
            "root_zone_0_40_storage_cm":np.asarray(r40),
            "upper_0_80_storage_cm":np.asarray(u80),
            "theta_10cm":np.asarray(theta),
        }
    return out


def rmse(x)->float:
    a=np.asarray(x,dtype=float)
    return float(np.sqrt(np.mean(a*a)))


def qstats(x)->dict[str,float]:
    a=np.asarray(x,dtype=float)
    aa=np.abs(a)
    return {
        "rmse":rmse(a),
        "mean":float(np.mean(a)),
        "mean_abs":float(np.mean(aa)),
        "max_abs":float(np.max(aa)),
    }


def compare(candidate,reference)->dict[str,object]:
    pooled={k:[] for k in (
        "total_storage_rmse_cm",
        "surface_0_20_storage_rmse_cm",
        "root_zone_0_40_storage_rmse_cm",
        "upper_0_80_storage_rmse_cm",
        "mapped_10cm_theta_rmse",
    )}
    by={}
    max_s20=0.0
    max_s20_where=None
    for h in HISTS:
        c=candidate["histories"][h]
        r=reference[h]
        dtot=np.asarray(c["total_storage_cm"],dtype=float)-r["total_storage_cm"]
        ds20=np.asarray(c["surface_0_20_storage_cm"],dtype=float)-r["surface_0_20_storage_cm"]
        dr40=np.asarray(c["root_zone_0_40_storage_cm"],dtype=float)-r["root_zone_0_40_storage_cm"]
        du80=np.asarray(c["upper_0_80_storage_cm"],dtype=float)-r["upper_0_80_storage_cm"]
        dtheta=np.asarray(c["theta_10cm"],dtype=float)-r["theta_10cm"]
        vals={
            "total_storage_rmse_cm":rmse(dtot),
            "surface_0_20_storage_rmse_cm":rmse(ds20),
            "root_zone_0_40_storage_rmse_cm":rmse(dr40),
            "upper_0_80_storage_rmse_cm":rmse(du80),
            "mapped_10cm_theta_rmse":rmse(dtheta),
            "surface_0_20_storage_max_abs_error_cm":float(np.max(np.abs(ds20))),
            "root_zone_0_40_storage_max_abs_error_cm":float(np.max(np.abs(dr40))),
            "upper_0_80_storage_max_abs_error_cm":float(np.max(np.abs(du80))),
        }
        idx=int(np.argmax(np.abs(ds20)))
        if abs(float(ds20[idx]))>max_s20:
            max_s20=abs(float(ds20[idx]))
            max_s20_where={"history":h,"observation_step":idx+1,"time_day":(idx+1)*0.0008}
        by[h]=vals
        pooled["total_storage_rmse_cm"].append(dtot)
        pooled["surface_0_20_storage_rmse_cm"].append(ds20)
        pooled["root_zone_0_40_storage_rmse_cm"].append(dr40)
        pooled["upper_0_80_storage_rmse_cm"].append(du80)
        pooled["mapped_10cm_theta_rmse"].append(dtheta.ravel())
    return {
        "pooled":{k:rmse(np.concatenate([np.asarray(vv).ravel() for vv in v])) for k,v in pooled.items()},
        "by_history":by,
        "maximum_absolute_surface_0_20_error":{"value_cm":max_s20,**(max_s20_where or {})},
    }


def classify(metrics:dict[str,float],uncertainty:dict[str,float])->dict[str,object]:
    per_metric={}
    for k in METRIC_KEYS:
        value=float(metrics[k])
        u=float(uncertainty[k])
        unresolved=value<=u
        ratio=(value/u if u>0.0 else (0.0 if value==0.0 else math.inf))
        per_metric[k]={
            "candidate_rmse":value,
            "reference_U_combined":u,
            "exceedance_ratio":ratio,
            "classification":"NUMERICALLY_UNRESOLVED_FROM_REFERENCE" if unresolved else "NUMERICALLY_RESOLVED_DIFFERENCE",
        }
    views={}
    for view,keys in VIEWS.items():
        ok=all(per_metric[k]["classification"]=="NUMERICALLY_UNRESOLVED_FROM_REFERENCE" for k in keys)
        views[view]="NUMERICALLY_UNRESOLVED_VIEW" if ok else "RESOLVED_DIFFERENCE_VIEW"
    return {"per_metric":per_metric,"views":views}


def componentwise_no_worse(a:dict[str,float],b:dict[str,float],keys)->bool:
    return all(float(a[k])<=float(b[k])+1e-12 for k in keys)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c6n1-result",required=True,type=pathlib.Path)
    ap.add_argument("--b01-reference",required=True,type=pathlib.Path)
    ap.add_argument("--b14-reference",required=True,type=pathlib.Path)
    ap.add_argument("--candidate-dir",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    n1=json.loads(a.c6n1_result.read_text())
    assert pre["phase"]=="SCIENTIFIC_DESIGN_FROZEN_BEFORE_C6N1_RESULT_EXECUTION_BLOCKED"
    assert n1["status"]=="C6N1_R2048_T32_REFERENCE_UNCERTAINTY_QUALIFIED"
    assert n1["decision"]=="AUTHORIZE_C6N2_EXISTING_REPRESENTATION_PROSPECTIVE_SURFACE_COMPARISON"
    assert n1["scientific_firewall"]["candidate_response_generated"] is False

    refs={
        "B01":parse_reference(a.b01_reference),
        "B14":parse_reference(a.b14_reference),
    }
    rows={}
    for material in ("B01","B14"):
        uncertainty={
            k:float(n1["materials"][material]["metrics"][k]["combined_reference_uncertainty"])
            for k in METRIC_KEYS
        }
        mrows={}
        for member in LADDER+CONTROLS:
            path=a.candidate_dir/f"{material}_{member}.json"
            c=json.loads(path.read_text())["candidate"]
            row={
                "id":member,
                "dimension":int(c["dimension"]),
                "status":c["status"],
                "max_abs_water_ledger_cm":float(c["max_abs_water_ledger_cm"]),
                "max_corrector_iterations":int(c["max_corrector_iterations"]),
                "failures":c["failures"],
            }
            if c["status"]=="QUALIFIED" and c["histories"] is not None:
                cmp=compare(c,refs[material])
                row["comparison"]=cmp
                row["classification"]=classify(cmp["pooled"],uncertainty)
            else:
                row["comparison"]=None
                row["classification"]=None
            mrows[member]=row
        rows[material]=mrows

    minima={}
    placement={}
    any_reduced_unresolved=False
    for material in ("B01","B14"):
        minima[material]={}
        for view in VIEWS:
            good=[
                rows[material][m]["dimension"]
                for m in LADDER if m!="R16"
                and rows[material][m]["classification"] is not None
                and rows[material][m]["classification"]["views"][view]=="NUMERICALLY_UNRESOLVED_VIEW"
            ]
            minima[material][view]=min(good) if good else None
            any_reduced_unresolved |= bool(good)

        def pm(member):
            r=rows[material][member]
            return None if r["comparison"] is None else r["comparison"]["pooled"]

        placement[material]={
            "P4_TOP_LOWER_no_worse_than_R4_SURFACE20_ROOT40":(
                pm("P4_TOP_LOWER") is not None and pm("R4") is not None and
                componentwise_no_worse(pm("P4_TOP_LOWER"),pm("R4"),
                    ("surface_0_20_storage_rmse_cm","root_zone_0_40_storage_rmse_cm"))
            ),
            "R4_P4_U4_componentwise":{
                m:pm(m) for m in ("R4","P4_TOP_LOWER","U4")
            },
            "R8_U8_componentwise":{
                m:pm(m) for m in ("R8","U8")
            },
        }

    all_candidates_attempted=all(
        rows[material][m]["status"] in ("QUALIFIED","OUTSIDE_QUALIFIED_DOMAIN","NUMERICAL_BLOCKED")
        for material in ("B01","B14") for m in LADDER+CONTROLS
    )
    maxledger=max(
        [rows[material][m]["max_abs_water_ledger_cm"]
         for material in ("B01","B14") for m in LADDER+CONTROLS
         if rows[material][m]["status"]=="QUALIFIED"] or [0.0]
    )
    status="C6N2_NUMERICALLY_UNRESOLVED_REDUCED_FRONTIER" if any_reduced_unresolved else "C6N2_RESOLVED_REDUCED_DIFFERENCES_ONLY"

    out={
        "schema":"swap5.lare.bc2.c6n2.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C6N2",
        "status":status,
        "purpose":"SURFACE_DRIVEN_UPPER_ZONE_PROFILE_STATE_WITH_PRESCRIBED_BOTTOM_FLUX",
        "reference":"R2048_T32_WITH_C6N1_METRIC_SPECIFIC_NUMERICAL_UNCERTAINTY",
        "materials":rows,
        "minimum_numerically_unresolved_lower_zone_dimension":minima,
        "placement_tests":placement,
        "hypotheses":{
            "H_TOP_PLACEMENT_R4":{m:placement[m]["P4_TOP_LOWER_no_worse_than_R4_SURFACE20_ROOT40"] for m in ("B01","B14")},
            "H_PURPOSE_DIMENSION_SEPARATION":minima,
            "H_MATERIAL_TRANSFER":"REPORT_SEPARATELY_NO_MATERIAL_INVARIANT_MINIMUM_PRESUMED",
        },
        "integrity":{
            "all_candidates_attempted":all_candidates_attempted,
            "maximum_qualified_water_ledger_cm":maxledger,
            "pass":all_candidates_attempted and maxledger<=1e-10,
        },
        "interpretation_boundary":[
            "NUMERICALLY_UNRESOLVED means candidate-to-Reference RMSE is at or below C6N1 numerical uncertainty for the declared metric/view.",
            "RESOLVED_DIFFERENCE is not hydrological application failure.",
            "Bottom flux is prescribed and bottom-exchange fidelity is out of scope.",
            "No ET/root uptake, groundwater, drought, performance or production claim follows."
        ],
        "scientific_firewall":{
            "candidate_response_generated":True,
            "new_representation_selected":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "speed_claim_authorized":False,
            "production_rom_authorized":False,
        },
        "model_changed":False,
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "status":status,
        "minimum_dimensions":minima,
        "placement":placement,
        "integrity":out["integrity"],
    },sort_keys=True))


if __name__=="__main__":
    main()
