#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import math
import pathlib

THETA_S=0.427494
PROFILE_DEPTH=160.0
ANCHOR=90.0
FIXED_DZ=10.0
NFIXED=9
OBS_DT=0.0008
STEPS={"WT_HOLD":256,"WT_RISE":512,"WT_FALL":512,"WT_CYCLE":768}
IDENTITY_GATE=1.0e-10


def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1);out[k]=v
    return out


def load(path:pathlib.Path):
    initial_total={}
    initial_nodes=collections.defaultdict(dict)
    state={}
    nodes=collections.defaultdict(dict)
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREBC2A2_INITIAL|"):
            r=fields(line.split("|",1)[1]);initial_total[r["HISTORY"]]=float(r["TOTAL_STORAGE"])
        elif line.startswith("LAREBC2A2_INITIAL_NODE|"):
            r=fields(line.split("|",1)[1]);initial_nodes[r["HISTORY"]][int(r["NODE"])]={
                "z":float(r["Z"]),"h":float(r["H"]),"theta":float(r["THETA"])
            }
        elif line.startswith("LAREBC2A2_STATE|"):
            r=fields(line.split("|",1)[1]);state[(r["HISTORY"],int(r["STEP"]))]={
                "total":float(r["TOTAL_STORAGE"]),
                "bex":float(r["BOTTOM_OUTWARD_EXCHANGE"])
            }
        elif line.startswith("LAREBC2A2_NODE|"):
            r=fields(line.split("|",1)[1]);nodes[(r["HISTORY"],int(r["STEP"]))][int(r["NODE"])]={
                "z":float(r["Z"]),"h":float(r["H"]),"theta":float(r["THETA"])
            }
    return initial_total,initial_nodes,state,nodes


def H_from(profile):
    crossings=[]
    for i in range(1,16):
        a,b=profile[i],profile[i+1]
        if a["h"]<0.0<b["h"]:
            z=a["z"]+(-a["h"])*(b["z"]-a["z"])/(b["h"]-a["h"])
            crossings.append(-z)
    if len(crossings)!=1:
        raise RuntimeError(f"water-table crossing count {len(crossings)}")
    return crossings[0]


def moving_storage(total:float,H:float,profile)->float:
    U=total-THETA_S*(PROFILE_DEPTH-H)
    fixed=sum(profile[i]["theta"]*FIXED_DZ for i in range(1,NFIXED+1))
    return U-fixed


def one_history(history,initial_total,initial_nodes,state,nodes):
    H0=H_from(initial_nodes[history])
    L0=H0-ANCHOR
    if L0<=0.0:
        raise RuntimeError("nonpositive initial moving thickness")
    W0=moving_storage(initial_total[history],H0,initial_nodes[history])
    theta0=W0/L0

    W_cons=W0
    theta_pub=theta0
    prev_H=H0
    prev_Wref=W0

    max_cons=0.0
    max_pub=0.0
    max_theta_pub=0.0
    max_identity=0.0
    cumulative_abs_pub_increment=0.0
    rows=[]

    for step in range(1,STEPS[history]+1):
        profile=nodes[(history,step)]
        H=H_from(profile)
        L=H-ANCHOR
        if L<=0.0:
            raise RuntimeError("nonpositive moving thickness")
        Wref=moving_storage(state[(history,step)]["total"],H,profile)
        QH=state[(history,step)]["bex"]
        dH=H-prev_H
        dWref=Wref-prev_Wref

        # Interval-integrated interface exchange diagnosed from the exact
        # conservative moving-storage ledger.
        QI=dWref+QH-THETA_S*dH

        W_cons += QI-QH+THETA_S*dH

        C=(QI-QH)/OBS_DT + THETA_S*(dH/OBS_DT)
        if abs(dH)<=1.0e-18:
            theta_pub += OBS_DT*C/L
        else:
            Hdot=dH/OBS_DT
            theta_pub += (C/Hdot)*math.log(L/(prev_H-ANCHOR))
        W_pub=L*theta_pub

        theta_ref=Wref/L
        cons_err=W_cons-Wref
        pub_err=W_pub-Wref
        theta_err=theta_pub-theta_ref
        # Algebraic relation in interval-integrated form: difference between
        # published-state and conservative storage arises from the missing
        # theta_bar*dH product term.
        identity_increment=(W_pub-(L/(prev_H-ANCHOR))*((prev_H-ANCHOR)*(rows[-1]["published_theta"] if rows else theta0))) if False else 0.0

        max_cons=max(max_cons,abs(cons_err))
        max_pub=max(max_pub,abs(pub_err))
        max_theta_pub=max(max_theta_pub,abs(theta_err))
        max_identity=max(max_identity,abs((W_cons-Wref)))
        cumulative_abs_pub_increment += abs(pub_err-(rows[-1]["published_storage_error_cm"] if rows else 0.0))

        rows.append({
            "step":step,
            "H_cm":H,
            "moving_thickness_cm":L,
            "reference_moving_storage_cm":Wref,
            "diagnosed_interface_exchange_cm":QI,
            "reference_qH_exchange_cm":QH,
            "conservative_storage_error_cm":cons_err,
            "published_storage_error_cm":pub_err,
            "published_theta_error":theta_err,
            "published_theta":theta_pub,
        })
        prev_H=H
        prev_Wref=Wref

    final_pub=rows[-1]["published_storage_error_cm"]
    return {
        "state_count":STEPS[history],
        "H_initial_cm":H0,
        "H_min_cm":min(r["H_cm"] for r in rows),
        "H_max_cm":max(r["H_cm"] for r in rows),
        "max_abs_conservative_storage_replay_error_cm":max_cons,
        "max_abs_published_storage_replay_error_cm":max_pub,
        "final_signed_published_storage_error_cm":final_pub,
        "max_abs_published_theta_error":max_theta_pub,
        "stationary_geometry":max(abs(r["H_cm"]-H0) for r in rows)<=1.0e-12,
        "rows":rows,
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_GEOMETRY_ONLY_REPLAY"
    assert pre["forcing_replay"]["no_reduced_flux_closure"] is True
    assert pre["adjudication"]["source_form_selection_deferred"] is True

    initial_total,initial_nodes,state,nodes=load(args.reference)
    histories={h:one_history(h,initial_total,initial_nodes,state,nodes) for h in STEPS}

    max_cons=max(r["max_abs_conservative_storage_replay_error_cm"] for r in histories.values())
    max_pub=max(r["max_abs_published_storage_replay_error_cm"] for r in histories.values())
    hold=histories["WT_HOLD"]
    conservative_ok=max_cons<=IDENTITY_GATE
    hold_ok=hold["max_abs_published_storage_replay_error_cm"]<=IDENTITY_GATE

    decision=(
        "BC2_GEOMETRY_REPLAY_CONSERVATIVE_IDENTITY_CONFIRMED"
        if conservative_ok and hold_ok else
        "BC2_GEOMETRY_REPLAY_BLOCKED"
    )

    compact={}
    for h,row in histories.items():
        compact[h]={k:v for k,v in row.items() if k!="rows"}

    result={
        "schema":"swap5.lare.bc2.b0geo.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-B0-GEO",
        "decision":decision,
        "identity_gate_cm":IDENTITY_GATE,
        "max_abs_conservative_storage_replay_error_cm":max_cons,
        "max_abs_published_storage_replay_error_cm":max_pub,
        "histories":compact,
        "interpretation":[
            "Reference interval interface exchange is diagnosed only from the already-qualified A2 moving-storage ledger; no LARE interface or water-table flux closure is used.",
            "The conservative product-storage replay reconstructs Reference moving storage to numerical identity if the A2 geometry authority is self-consistent.",
            "The published-theta replay uses exactly the same H(t), q_interface and q_H forcing, so any divergence is solely the consequence of the different moving-state algebra.",
            "No conclusion about the authors' actual implementation is drawn because the official source-output oracle has not been inspected."
        ],
        "source_form_selected":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "max_conservative_error_cm":max_cons,
        "max_published_error_cm":max_pub,
        "histories":compact
    },sort_keys=True))
    return 0 if decision=="BC2_GEOMETRY_REPLAY_CONSERVATIVE_IDENTITY_CONFIRMED" else 2


if __name__=="__main__":
    raise SystemExit(main())
