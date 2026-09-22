from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))
sys.path.insert(0, str(ROOT / "tests" / "fgc" / "support"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import (
    initialize_case,
    trial_discard,
    groundwater_response,
    reference_root,
)
from test_gc_fixed_interface_fgc44_stencil_class_tangent_g09d import (
    estimate_e3,
    resolve_sy,
    run_policy,
)

PREREG = ROOT / "integration" / "research" / "GC_FIXED_INTERFACE_G10_PREREGISTRATION.json"
E4 = ROOT / "docs" / "publication" / "evidence" / "PUB_GC_E4_FULL_RESULT.json"

DURATION_DAY = 1.0e-2
QBOT_CM_PER_DAY = 1.0e-6
OFFSETS_M = (
    -1.0e-5,-8.0e-6,-5.0e-6,-3.0e-6,-1.0e-6,-3.0e-7,0.0,
    3.0e-7,1.0e-6,3.0e-6,5.0e-6,8.0e-6,1.0e-5,
)
NONLINEARITY_THRESHOLD = 0.05


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_prereg() -> list[dict[str, object]]:
    p=json.loads(PREREG.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G10","wrong G10 preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_EXECUTION","G10 preregistration not frozen")
    require(float(p["configured_swap"]["duration_day"])==DURATION_DAY,"G10 duration drifted")
    require(float(p["configured_swap"]["predictor_qbot_cm_per_day"])==QBOT_CM_PER_DAY,"G10 qbot drifted")
    require(tuple(float(x) for x in p["fixed_head_scan_offsets_m"])==OFFSETS_M,"G10 head scan drifted")
    require(float(p["material_nonlinearity_gate"]["threshold_fraction"])==NONLINEARITY_THRESHOLD,
            "G10 nonlinearity threshold drifted")
    return [dict(x) for x in p["groundwater_regimes"]]


def check_frozen_e4_authority() -> None:
    e4=json.loads(E4.read_text())
    b4=next(x for x in e4["baselines"] if x["baseline_id"]=="B4")
    require(float(b4["window_day"])==DURATION_DAY,"E4 B4 duration drifted")
    require(float(b4["qbot_cm_per_day"])==QBOT_CM_PER_DAY,"E4 B4 qbot drifted")
    require(str(b4["head_response_status"])=="READY","E4 B4 no longer READY authority")
    require(float(b4["largest_centered_head_delta_m"])>=1.0e-5,"E4 B4 centered envelope authority drifted")
    require(float(b4["J_R_estimate"])<0.0,"E4 B4 local J_R authority invalid")
    d10=next(x for x in b4["head_derivatives"] if float(x["scale"])==1.0e-5)
    require(bool(d10["centered_available"]),"E4 B4 1e-5 pair authority unavailable")
    rel=abs(float(d10["J_R"])-float(b4["J_R_estimate"]))/abs(float(b4["J_R_estimate"]))
    require(rel>=NONLINEARITY_THRESHOLD,"E4 B4 no longer supports carrier-selection rationale")


def fixed_scan(
    swap:Fgc44RealSwap,
    origin:tuple[int,float,int,float],
    href:float,
)->list[dict[str,object]]:
    rows=[]
    for dh in OFFSETS_M:
        status,q=trial_discard(swap,origin,href+dh)
        row={
            "dh_m":dh,
            "head_m":href+dh,
            "status":int(status),
            "q_swap_m_per_s":float(q) if status==0 else None,
            "e3":None,
        }
        if status==0:
            e3=estimate_e3(swap,origin,href+dh)
            row["e3"]=e3
        rows.append(row)
        print("FGC44_G10_SCAN_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
    return rows


def select_starts(rows:list[dict[str,object]])->list[tuple[str,float]]:
    valid=[
        r for r in rows
        if int(r["status"])==0
        and isinstance(r["e3"],dict)
        and r["e3"]["classification"]=="AVAILABLE"
        and float(r["dh_m"])!=0.0
    ]
    neg=[float(r["dh_m"]) for r in valid if float(r["dh_m"])<0.0]
    pos=[float(r["dh_m"]) for r in valid if float(r["dh_m"])>0.0]
    require(neg and pos,"G10 did not retain E3-qualified starts on both signs")
    return [("NEG",min(neg)),("POS",max(pos))]


def main()->None:
    regimes=load_prereg()
    check_frozen_e4_authority()
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    swaplib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(libmf6.is_file(),"missing live MODFLOW library")
    require(swaplib.is_file(),"missing real SWAP bridge library")

    swap=Fgc44RealSwap(swaplib)
    _,_,href,origin,diag=initialize_case(swap,DURATION_DAY,QBOT_CM_PER_DAY)
    require(origin==(0,0.0,0,0.0),"G10 B4 did not initialize at immutable origin")
    u=float(diag["u"])
    href_e3=estimate_e3(swap,origin,href)
    require(href_e3["classification"]=="AVAILABLE","G10 B4 href E3 unavailable")
    p0=float(href_e3["slope_per_s"])

    rows=fixed_scan(swap,origin,href)
    local_rows=[
        r for r in rows
        if int(r["status"])==0
        and isinstance(r["e3"],dict)
        and r["e3"]["classification"]=="AVAILABLE"
    ]
    require(any(float(r["dh_m"])==0.0 for r in local_rows),"G10 scan lost href")
    for r in local_rows:
        p=float(r["e3"]["slope_per_s"])
        r["relative_slope_change_from_href"]=abs(p-p0)/abs(p0)

    max_row=max(local_rows,key=lambda r:float(r["relative_slope_change_from_href"]))
    max_rel=float(max_row["relative_slope_change_from_href"])
    material=max_rel>=NONLINEARITY_THRESHOLD
    require(material,
            f"G10 B4 did not reproduce preregistered >=5% class-consistent nonlinearity: {max_rel}")

    starts=select_starts(rows)
    print("FGC44_G10_CARRIER_JSON="+json.dumps({
        "duration_day":DURATION_DAY,
        "qbot_cm_per_day":QBOT_CM_PER_DAY,
        "reference_head_m":href,
        "predictor_u":u,
        "href_e3":href_e3,
        "max_relative_slope_change":max_rel,
        "max_change_dh_m":max_row["dh_m"],
        "max_change_e3":max_row["e3"],
        "material_nonlinearity":material,
        "starts":[{"side":s,"dh_m":d} for s,d in starts],
    },sort_keys=True,separators=(",",":")))

    policy_rows=[]
    root_rows=[]
    for regime in regimes:
        sy=resolve_sy(regime,u)
        a,intercept,fit_error=groundwater_response(
            libmf6,swaplib,DURATION_DAY,href,regime,sy
        )
        root=reference_root(swap,origin,rows,a,intercept)
        root_row={
            "regime_id":regime["id"],
            "sy":sy,
            "a_per_s":a,
            "gw_intercept":intercept,
            "gw_fit_error_m_per_s":fit_error,
            "initial_head_bias_m":float(regime["initial_head_bias_m"]),
            "realized_r_at_href":a/abs(p0),
            "reference_root_m":root,
        }
        root_rows.append(root_row)
        print("FGC44_G10_REGIME_JSON="+json.dumps(root_row,sort_keys=True,separators=(",",":")))
        if root is None:
            continue

        for side,start_dh in starts:
            for policy in ("P1_E3","P4_E3"):
                res=run_policy(
                    policy,libmf6,swaplib,swap,DURATION_DAY,QBOT_CM_PER_DAY,
                    regime,sy,a,intercept,float(root),start_dh
                )
                row={
                    **root_row,
                    "start_side":side,
                    "start_dh_m":start_dh,
                    "policy":policy,
                    **res,
                }
                policy_rows.append(row)
                print("FGC44_G10_POLICY_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))
                if policy=="P4_E3":
                    require(res["classification"]=="CONVERGED",
                            f"G10 P4 failed {regime['id']} {side}: {res}")

    require(swap.state()==origin,"G10 diagnostics mutated accepted SWAP/ledger authority")
    rooted=[r for r in root_rows if r["reference_root_m"] is not None]
    require(rooted,"G10 produced no admissible coupled root in any frozen groundwater regime")

    p1=[x for x in policy_rows if x["policy"]=="P1_E3"]
    p4=[x for x in policy_rows if x["policy"]=="P4_E3"]
    expected_p4=2*len(rooted)
    require(len(p4)==expected_p4,"G10 incomplete P4 rooted replay matrix")
    summary={
        "carrier_material_nonlinearity":"PASS",
        "max_relative_slope_change":max_rel,
        "max_change_dh_m":max_row["dh_m"],
        "rooted_regime_count":len(rooted),
        "unrooted_regime_count":len(root_rows)-len(rooted),
        "policy_case_count":len(policy_rows),
        "p1_case_count":len(p1),
        "p1_converged_count":sum(x["classification"]=="CONVERGED" for x in p1),
        "p1_nonconverged_count":sum(x["classification"]!="CONVERGED" for x in p1),
        "p1_raw_inadmissible_total":sum(int(x.get("raw_inadmissible",0)) for x in p1),
        "p1_merit_increase_total":sum(int(x.get("merit_increases",0)) for x in p1),
        "p4_case_count":len(p4),
        "p4_converged_count":sum(x["classification"]=="CONVERGED" for x in p4),
        "p4_total_contractions":sum(int(x.get("contractions",0)) for x in p4),
        "p4_raw_inadmissible_total":sum(int(x.get("raw_inadmissible",0)) for x in p4),
        "safeguard_activation":"EXERCISED" if any(int(x.get("contractions",0))>0 for x in p4) else "NOT_EXERCISED",
        "p1_fail_p4_success_count":sum(
            1 for p4row in p4
            for p1row in p1
            if p1row["regime_id"]==p4row["regime_id"]
            and p1row["start_side"]==p4row["start_side"]
            and p1row["classification"]!="CONVERGED"
            and p4row["classification"]=="CONVERGED"
        ),
    }
    print("FGC44_G10_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("FGC44_G10_TRANSACTION_AUTHORITY=PASS")
    print("FGC44_G10_NONLINEAR_CARRIER=PASS")
    print("GC_FIXED_INTERFACE_G10_EXECUTION=PASS")


if __name__=="__main__":
    main()
