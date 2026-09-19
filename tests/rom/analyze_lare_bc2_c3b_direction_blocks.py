#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

c3=load_module("bc2c3","analyze_lare_bc2_c3_signed_bias_case.py")
c1=c3.c1
c0=c3.c0

PRIMARY=0.00005
CROSS=0.000025
ROUTES=(PRIMARY,CROSS)
HISTORY="WT_CYCLE"
OBS_DT=c3.OBS_DT
GATE=1.0e-10
VALID_WIDTHS=(2.5,5.0)
PRIMARY_KEY=f"{PRIMARY:.8f}"
CROSS_KEY=f"{CROSS:.8f}"

def regime(delta_h: float) -> str:
    if delta_h < 0.0:
        return "WATER_TABLE_RISING"
    if delta_h > 0.0:
        return "WATER_TABLE_FALLING"
    return "STATIONARY"

def family_interval_vectors(errors):
    elementary=c3.contribution_vectors(errors)
    out={}
    for family,members in c3.FAMILY_MEMBERS.items():
        out[family]=np.sum(np.stack([elementary[k] for k in members]),axis=0)
    return out

def route_blocks(width,dt,init_meta,init_nodes,states,nodes,expected_blocks):
    intervals=[]
    max_add=0.0
    max_teacher_ledger=0.0
    max_reference_ledger=0.0
    max_q90_teacher=0.0
    max_q90_reference=0.0
    max_shape_residual=0.0

    for step in range(1,c0.HISTORY_STEPS[HISTORY]+1):
        y0,p0,_=c1.exact_reference_state(HISTORY,step-1,width,init_meta,init_nodes,states,nodes)
        yr,p1,_=c1.exact_reference_state(HISTORY,step,width,init_meta,init_nodes,states,nodes)
        H0=float(p0["H"]); H1=float(p1["H"])
        teacher=c1.advance_interval(y0,H0,H1,dt,width)
        yt=np.asarray(teacher["y"][:c3.PHYS_N],dtype=float)
        y0p=np.asarray(y0[:c3.PHYS_N],dtype=float)
        yrp=np.asarray(yr[:c3.PHYS_N],dtype=float)

        qteach=c3.fixed_fluxes_from_storage(y0p[:c3.NFIXED],yt[:c3.NFIXED])
        qref=c3.fixed_fluxes_from_storage(y0p[:c3.NFIXED],yrp[:c3.NFIXED])
        refs=c1.reference_fluxes(HISTORY,step,p0,p1,states)
        max_q90_teacher=max(max_q90_teacher,abs(float(qteach[-1])-float(teacher["q90"])))
        max_q90_reference=max(max_q90_reference,abs(float(qref[-1])-float(refs["q90"])))

        Gi_teacher=(float(yt[c3.IDX_WB]-y0p[c3.IDX_WB])/OBS_DT)-float(qteach[-1])+float(teacher["qi"])
        Gi_ref=(float(yrp[c3.IDX_WB]-y0p[c3.IDX_WB])/OBS_DT)-float(qref[-1])+float(refs["qi"])

        errors={}
        for j,key in enumerate(c3.FIXED_KEYS):
            errors[key]=float(qteach[j]-qref[j])
        errors["QI"]=float(teacher["qi"])-float(refs["qi"])
        errors["QH"]=float(teacher["qH"])-float(refs["qH"])
        errors["GEOMETRY_GI"]=Gi_teacher-Gi_ref

        contrib=c3.contribution_vectors(errors)
        local=yt-yrp
        summed=np.sum(np.stack(list(contrib.values())),axis=0)
        max_add=max(max_add,float(np.max(np.abs(summed-local))))

        tledger=float(np.sum(yt-y0p))+float(teacher["qH"])*OBS_DT-c3.THETA_S*(H1-H0)
        rledger=float(np.sum(yrp-y0p))+float(refs["qH"])*OBS_DT-c3.THETA_S*(H1-H0)
        max_teacher_ledger=max(max_teacher_ledger,abs(tledger))
        max_reference_ledger=max(max_reference_ledger,abs(rledger))

        famvec=family_interval_vectors(errors)
        for v in famvec.values():
            _,res=c3.shape_rms(v,H1,width)
            max_shape_residual=max(max_shape_residual,abs(res))

        family_bias={
            family:sum(errors[k] for k in members)
            for family,members in c3.FAMILY_MEMBERS.items()
        }
        intervals.append({
            "step":step,
            "H0":H0,
            "H1":H1,
            "regime":regime(H1-H0),
            "family_bias":family_bias,
            "family_vectors":famvec,
        })

    # Detect maximal exact-sign blocks and require byte-for-value agreement with
    # the response-blind A2 input-geometry preregistration.
    detected=[]
    start=1
    current=intervals[0]["regime"]
    for idx,row in enumerate(intervals[1:],2):
        if row["regime"]!=current:
            detected.append({"steps":[start,idx-1],"regime":current})
            start=idx
            current=row["regime"]
    detected.append({"steps":[start,len(intervals)],"regime":current})
    if detected!=expected_blocks:
        raise RuntimeError(f"A2_GEOMETRY_BLOCK_DRIFT detected={detected} expected={expected_blocks}")

    blocks=[]
    for block in detected:
        lo,hi=block["steps"]
        rows=intervals[lo-1:hi]
        Hfinal=float(rows[-1]["H1"])
        fam={}
        for family in c3.FAMILY_MEMBERS:
            biases=np.asarray([r["family_bias"][family] for r in rows],dtype=float)
            vectors=[r["family_vectors"][family] for r in rows]
            cumulative=np.sum(np.stack(vectors),axis=0)
            shape_values=[]
            for r,v in zip(rows,vectors):
                sr,res=c3.shape_rms(v,float(r["H1"]),width)
                max_shape_residual=max(max_shape_residual,abs(res))
                shape_values.append(sr)
            fam[family]=c3.summarize_channel(
                biases,shape_values,cumulative,Hfinal,width
            )
        rank=sorted(
            fam,
            key=lambda k:(-fam[k]["cumulative_injection_shape_rms_theta_at_final_geometry"],k)
        )
        blocks.append({
            **block,
            "interval_count":len(rows),
            "H_start_cm":float(rows[0]["H0"]),
            "H_end_cm":Hfinal,
            "families":fam,
            "family_rank_by_cumulative_shape_injection":rank,
        })

    hard=max(
        max_add,max_teacher_ledger,max_reference_ledger,
        max_q90_teacher,max_q90_reference,max_shape_residual
    )
    return {
        "dt_day":dt,
        "status":"QUALIFIED" if hard<=GATE else "HARD_GATE_FAILED",
        "blocks":blocks,
        "hard_checks":{
            "max_channel_state_additivity_residual_cm":max_add,
            "max_teacher_physical_ledger_residual_cm":max_teacher_ledger,
            "max_reference_physical_ledger_residual_cm":max_reference_ledger,
            "max_teacher_q90_reconstruction_identity_cm_per_day":max_q90_teacher,
            "max_reference_q90_reconstruction_identity_cm_per_day":max_q90_reference,
            "max_mass_neutral_projection_residual_cm":max_shape_residual,
            "maximum":hard,
            "gate":GATE,
        },
    }

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c3",required=True,type=pathlib.Path)
    ap.add_argument("--c3a",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    if args.width not in VALID_WIDTHS:
        raise SystemExit("unauthorized width")

    pre=json.loads(args.prereg.read_text())
    c3res=json.loads(args.c3.read_text())
    c3a=json.loads(args.c3a.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C3A_REGIME_DEPENDENCE_BEFORE_DIRECTION_BLOCK_RESPONSE"
    assert c3res["decision"]==pre["predecessor"]["required_c3_decision"]
    assert c3a["decision"]==pre["predecessor"]["required_c3a_decision"]
    expected_blocks=pre["geometry_regime_definition"]["A2_input_geometry_check"]["WT_CYCLE"]["contiguous_blocks"]

    init_meta,init_nodes,states,nodes=c0.b0.load_reference(args.reference)
    routes={}
    failures={}
    for dt in ROUTES:
        key=f"{dt:.8f}"
        try:
            routes[key]=route_blocks(
                args.width,dt,init_meta,init_nodes,states,nodes,expected_blocks
            )
            if routes[key]["status"]!="QUALIFIED":
                failures[key]=routes[key]["status"]
        except (ValueError,RuntimeError,FloatingPointError) as exc:
            failures[key]=str(exc)

    complete=not failures and PRIMARY_KEY in routes and CROSS_KEY in routes
    comparisons=[]
    if complete:
        for route_key in (PRIMARY_KEY,CROSS_KEY):
            for idx,block in enumerate(routes[route_key]["blocks"]):
                direction=block["regime"]
                monotonic="WT_RISE" if direction=="WATER_TABLE_RISING" else "WT_FALL"
                expected_top=c3res["cases"][str(args.width)][monotonic]["routes"][route_key][
                    "family_rank_by_cumulative_shape_injection"
                ][0]
                comparisons.append({
                    "route":route_key,
                    "block_index":idx,
                    "steps":block["steps"],
                    "regime":direction,
                    "block_top":block["family_rank_by_cumulative_shape_injection"][0],
                    "monotonic_history":monotonic,
                    "monotonic_top":expected_top,
                    "match":block["family_rank_by_cumulative_shape_injection"][0]==expected_top,
                })

    # Compare primary/cross rank-1 for each frozen block.
    rank1_match=[]
    if complete:
        for idx in range(len(routes[PRIMARY_KEY]["blocks"])):
            ptop=routes[PRIMARY_KEY]["blocks"][idx]["family_rank_by_cumulative_shape_injection"][0]
            ctop=routes[CROSS_KEY]["blocks"][idx]["family_rank_by_cumulative_shape_injection"][0]
            rank1_match.append(ptop==ctop)

    direction_explains=(
        complete
        and all(row["match"] for row in comparisons)
        and all(rank1_match)
    )
    decision=(
        "DIRECTION_PARTITION_EXPLAINS_CYCLE_RANK_SHIFT"
        if direction_explains else
        "WITHIN_DIRECTION_REGIME_DEPENDENCE_REMAINS"
        if complete else
        "NUMERICAL_DIAGNOSTIC_BLOCKED"
    )

    result={
        "schema":"swap5.lare.bc2.c3b.case-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C3B",
        "width_cm":args.width,
        "history":HISTORY,
        "decision":decision,
        "complete":complete,
        "routes":routes,
        "block_vs_monotonic_comparisons":comparisons,
        "primary_cross_block_rank1_match":rank1_match,
        "failures":failures,
        "model_changed":False,
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "width_cm":args.width,
        "complete":complete,
        "comparisons":comparisons,
        "primary_blocks":[
            {
                "steps":b["steps"],
                "regime":b["regime"],
                "rank":b["family_rank_by_cumulative_shape_injection"],
                "top_metrics":b["families"][b["family_rank_by_cumulative_shape_injection"][0]],
            }
            for b in routes.get(PRIMARY_KEY,{}).get("blocks",[])
        ],
        "hard_checks":routes.get(PRIMARY_KEY,{}).get("hard_checks"),
    },sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
