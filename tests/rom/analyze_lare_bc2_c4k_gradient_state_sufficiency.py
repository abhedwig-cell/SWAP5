#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

b4=load_module("bc2b4_c4k","analyze_lare_bc2_b4_boundary_localization.py")
b8=load_module("bc2b8_c4k","analyze_lare_bc2_b8_terminal_control_volume.py")
b3=b8.b3

WIDTHS=(2.5,5.0)
HISTORIES=("WT_RISE","WT_FALL")
MIN_CROSS=32
MIN_CONTROL=1000

def endpoint_rows(history,d,states,nodes):
    out=[]
    for step in range(1,b3.HISTORY_STEPS[history]+1):
        profile=nodes[(history,step)]
        p=b8.projected(profile,states[(history,step)]["total"],d)
        H=float(p["H"])
        B=H-b3.ANCHOR-d
        if B<=0.0:
            raise ValueError("nonpositive bulk thickness")
        theta_b=float(p["Wb64"]/B)
        theta_t=float(p["Wt64"]/d)
        state=np.asarray([
            H/b3.PROFILE_DEPTH,
            (theta_b-b3.THETA_R)/(b3.THETA_S-b3.THETA_R),
            (theta_t-b3.THETA_R)/(b3.THETA_S-b3.THETA_R),
        ],dtype=float)
        hd=b4.sample_h(profile,H-d)
        h2d=b4.sample_h(profile,H-2.0*d)
        psi_d=-float(hd)
        psi_2d=-float(h2d)
        s_terminal=psi_d/d
        s_bulk=(psi_2d-psi_d)/d
        curvature=s_bulk-s_terminal
        vals=[H,theta_b,theta_t,*state.tolist(),psi_d,psi_2d,s_terminal,s_bulk,curvature]
        if not all(math.isfinite(x) for x in vals):
            raise ValueError("nonfinite endpoint state or geometry")
        out.append({
            "history":history,"step":step,"H_cm":H,
            "Wb_cm":float(p["Wb64"]),"Wt_cm":float(p["Wt64"]),
            "theta_b":theta_b,"theta_t":theta_t,
            "state":state.tolist(),
            "psi_d_cm":psi_d,"psi_2d_cm":psi_2d,
            "s_terminal":s_terminal,
            "s_bulk_adjacent":s_bulk,
            "curvature_proxy":curvature,
        })
    return out

def state_matrix(rows):
    return np.asarray([r["state"] for r in rows],dtype=float)

def cross_pairs(rise,fall):
    A=state_matrix(rise); B=state_matrix(fall)
    D=np.sqrt(np.sum((A[:,None,:]-B[None,:,:])**2,axis=2))
    pairs=set()
    for i in range(D.shape[0]):
        j=int(np.argmin(D[i,:]))
        pairs.add((i,j))
    for j in range(D.shape[1]):
        i=int(np.argmin(D[:,j]))
        pairs.add((i,j))
    return sorted(pairs),D

def control_pool(rows,label):
    S=state_matrix(rows)
    n=len(rows)
    ii,jj=np.triu_indices(n,k=1)
    dist=np.sqrt(np.sum((S[ii]-S[jj])**2,axis=1))
    q={}
    for key in ("s_terminal","s_bulk_adjacent","curvature_proxy"):
        vals=np.asarray([r[key] for r in rows],dtype=float)
        q[key]=np.abs(vals[ii]-vals[jj])
    return {
        "history":label,
        "i":ii.astype(int),
        "j":jj.astype(int),
        "distance":dist,
        "response_abs":q,
    }

def combine_controls(a,b):
    distance=np.concatenate([a["distance"],b["distance"]])
    history=np.asarray([a["history"]]*len(a["distance"])+[b["history"]]*len(b["distance"]),dtype=object)
    ii=np.concatenate([a["i"],b["i"]])
    jj=np.concatenate([a["j"],b["j"]])
    response_abs={
        key:np.concatenate([a["response_abs"][key],b["response_abs"][key]])
        for key in a["response_abs"]
    }
    order=np.argsort(distance,kind="stable")
    return {
        "distance":distance[order],
        "history":history[order],
        "i":ii[order],
        "j":jj[order],
        "response_abs":{k:v[order] for k,v in response_abs.items()}
    }

def nearest_control_index(sorted_dist,target):
    pos=int(np.searchsorted(sorted_dist,target,side="left"))
    candidates=[]
    if pos<len(sorted_dist): candidates.append(pos)
    if pos>0: candidates.append(pos-1)
    if not candidates:
        raise RuntimeError("empty control pool")
    return min(candidates,key=lambda k:(abs(float(sorted_dist[k])-target),k))

def stats(x):
    a=np.asarray(x,dtype=float)
    return {
        "count":int(len(a)),
        "min":float(np.min(a)),
        "median":float(np.median(a)),
        "mean":float(np.mean(a)),
        "p90":float(np.percentile(a,90)),
        "max":float(np.max(a)),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4j-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--b4-result",required=True,type=pathlib.Path)
    ap.add_argument("--b8-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c4j=json.loads(args.c4j_closeout.read_text())
    r4=json.loads(args.b4_result.read_text())
    r8=json.loads(args.b8_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4J_BEFORE_REFERENCE_GRADIENT_STATE_SUFFICIENCY"
    assert c4j["status"]==pre["predecessors"]["C4J"]["required_status"]
    assert r4["decision"]==pre["predecessors"]["B4"]["required_decision"]
    assert r8["decision"]==pre["predecessors"]["B8"]["required_decision"]

    init_meta,init_nodes,states,nodes=b3.load_reference(args.reference)
    by_width={}
    all_complete=True
    support_all=True

    for d in WIDTHS:
        try:
            rise=endpoint_rows("WT_RISE",d,states,nodes)
            fall=endpoint_rows("WT_FALL",d,states,nodes)
            pairs,D=cross_pairs(rise,fall)
            ctrl=combine_controls(control_pool(rise,"WT_RISE"),control_pool(fall,"WT_FALL"))
            if len(pairs)<MIN_CROSS or len(ctrl["distance"])<MIN_CONTROL:
                raise RuntimeError("insufficient pairing population")

            cross_dist=[]
            matched_dist=[]
            metrics={k:{"cross":[],"control":[],"cross_gt_control":[]} for k in ("s_terminal","s_bulk_adjacent","curvature_proxy")}
            closest=[]
            for i,j in pairs:
                dist=float(D[i,j])
                k=nearest_control_index(ctrl["distance"],dist)
                cross_dist.append(dist)
                matched_dist.append(float(ctrl["distance"][k]))
                rec={
                    "rise_step":int(rise[i]["step"]),
                    "fall_step":int(fall[j]["step"]),
                    "state_distance":dist,
                    "matched_control_distance":float(ctrl["distance"][k]),
                    "matched_control_history":str(ctrl["history"][k]),
                    "matched_control_steps":[int(ctrl["i"][k]+1),int(ctrl["j"][k]+1)],
                }
                for key in metrics:
                    cv=abs(float(rise[i][key])-float(fall[j][key]))
                    tv=float(ctrl["response_abs"][key][k])
                    metrics[key]["cross"].append(cv)
                    metrics[key]["control"].append(tv)
                    metrics[key]["cross_gt_control"].append(cv>tv)
                    rec[key+"_cross_abs_difference"]=cv
                    rec[key+"_control_abs_difference"]=tv
                closest.append(rec)

            closest=sorted(closest,key=lambda x:(x["state_distance"],x["rise_step"],x["fall_step"]))[:32]
            metric_summary={}
            for key,row in metrics.items():
                c=np.asarray(row["cross"],dtype=float)
                t=np.asarray(row["control"],dtype=float)
                metric_summary[key]={
                    "cross":stats(c),
                    "matched_control":stats(t),
                    "fraction_cross_gt_matched_control":float(np.mean(row["cross_gt_control"])),
                    "median_cross_minus_control":float(np.median(c)-np.median(t)),
                    "p90_cross_minus_control":float(np.percentile(c,90)-np.percentile(t,90)),
                }

            curv_r=np.asarray([x["curvature_proxy"] for x in rise],dtype=float)
            curv_f=np.asarray([x["curvature_proxy"] for x in fall],dtype=float)
            support=(
                metric_summary["s_terminal"]["cross"]["median"]>metric_summary["s_terminal"]["matched_control"]["median"]
                and metric_summary["curvature_proxy"]["cross"]["median"]>metric_summary["curvature_proxy"]["matched_control"]["median"]
                and metric_summary["s_terminal"]["fraction_cross_gt_matched_control"]>0.5
                and metric_summary["curvature_proxy"]["fraction_cross_gt_matched_control"]>0.5
            )
            support_all &= support
            by_width[str(d)]={
                "status":"COMPLETE",
                "cross_direction_pair_count":len(pairs),
                "control_pair_count":int(len(ctrl["distance"])),
                "state_distance":{
                    "cross":stats(cross_dist),
                    "matched_control":stats(matched_dist),
                    "median_absolute_matching_error":float(np.median(np.abs(np.asarray(cross_dist)-np.asarray(matched_dist))))
                },
                "hidden_geometry":metric_summary,
                "curvature_by_direction":{
                    "WT_RISE":stats(curv_r),
                    "WT_FALL":stats(curv_f),
                    "WT_RISE_fraction_positive":float(np.mean(curv_r>0.0)),
                    "WT_FALL_fraction_positive":float(np.mean(curv_f>0.0)),
                },
                "closest_32_cross_pairs":closest,
                "direction_history_information_supported":support
            }
        except Exception as exc:
            all_complete=False
            support_all=False
            by_width[str(d)]={"status":"BLOCKED","error":str(exc)}

    if not all_complete:
        decision="C4K_DIAGNOSTIC_BLOCKED"
    elif support_all:
        decision="DIRECTION_HISTORY_INFORMATION_SUPPORTED"
    else:
        decision="CURRENT_STATE_NOT_SHOWN_INSUFFICIENT"

    result={
        "schema":"swap5.lare.bc2.c4k.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC2-C4K",
        "decision":decision,
        "complete":all_complete,
        "widths":by_width,
        "interpretation":[
            "Pair selection and distance matching use only the physically normalized reduced state (H, theta_b, theta_t); hidden Reference profile geometry is exposed only after pairs are frozen.",
            "The local geometry uses B4-supported full-order point-head diagnostics at d and 2d above the water table.",
            "A positive result means opposite water-table motion direction carries additional information about local lower-profile geometry beyond closeness in the current reduced state in this A2 laboratory.",
            "This diagnostic does not decide whether the additional information should be represented by Hdot, a curvature state, another storage partition or a different closure family."
        ],
        "next_authority":"SCIENTIFIC_CHOICE_REQUIRED_FOR_DIRECTION_INFORMATION_REPRESENTATION" if decision=="DIRECTION_HISTORY_INFORMATION_SUPPORTED" else "MEMORYLESS_STATE_SUFFICIENCY_NOT_REJECTED_IN_THIS_TEST",
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "complete":all_complete,
        "summary":{d:{
            "status":v["status"],
            "supported":v.get("direction_history_information_supported"),
            "cross_pairs":v.get("cross_direction_pair_count"),
            "state_distance":v.get("state_distance"),
            "s_terminal":v.get("hidden_geometry",{}).get("s_terminal"),
            "curvature":v.get("hidden_geometry",{}).get("curvature_proxy"),
            "curvature_by_direction":v.get("curvature_by_direction")
        } for d,v in by_width.items()}
    },sort_keys=True))
    return 0 if all_complete else 2

if __name__=="__main__":
    raise SystemExit(main())
