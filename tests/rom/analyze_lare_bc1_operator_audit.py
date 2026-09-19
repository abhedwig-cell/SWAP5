#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import statistics

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
KS=31.225016
LAMBDA=0.98087
M=1.0-1.0/N
DZ_LAST=10.0
EXPECTED_MODE5=2112

SE0_BY_HISTORY={
    "G00":0.85,
    "G01":0.65,
    "G02":0.85,
    "G03":0.95,
    "G04":0.85,
    "G05":0.65,
}
RISE={"BOTTOM_HEAD_RISE","COMBINED_RISE_PLUS"}
FALL={"BOTTOM_HEAD_FALL","COMBINED_FALL_MINUS"}

def fields(payload:str)->dict[str,str]:
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def h_from_se(se:float)->float:
    return -((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def h_from_theta(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    if not (0.0 < se < 1.0):
        raise ValueError(f"theta outside unsaturated MvG inverse domain: {theta}")
    return h_from_se(se)

def theta_from_h(h:float)->float:
    if h>=0.0: return TS
    se=(1.0+abs(ALPHA*h)**N)**(-M)
    return TR+(TS-TR)*se

def k_from_theta(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    if se >= 1.0-1.0e-6:
        return KS
    if not (0.0 < se < 1.0):
        raise ValueError(f"invalid effective saturation: {se}")
    term=(1.0-se**(1.0/M))**M
    return min(KS, KS*(se**LAMBDA)*(1.0-term)**2)

def k_from_h(h:float)->float:
    return k_from_theta(theta_from_h(h))

def bottom_head(history:str,symbol:str)->float:
    h0=h_from_se(SE0_BY_HISTORY[history])
    if symbol in RISE:
        return 0.75*h0
    if symbol in FALL:
        return 1.25*h0
    raise ValueError(f"mode-5 symbol not recognized: {history} {symbol}")

def sign(x:float)->int:
    return 1 if x>0 else (-1 if x<0 else 0)

def quantile(values:list[float],q:float)->float:
    if not values:return 0.0
    xs=sorted(values)
    pos=q*(len(xs)-1)
    lo=int(math.floor(pos)); hi=int(math.ceil(pos))
    if lo==hi:return xs[lo]
    return xs[lo]*(hi-pos)+xs[hi]*(pos-lo)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    assert prereg["phase"]=="PREREGISTERED_BEFORE_PRESCRIBED_HEAD_OPERATOR_RESPONSE_AUDIT"
    gates=prereg["stage_A_operator_audit"]["technical_identity_gates"]

    states={}
    nodes={}
    for line in args.input.open(errors="replace"):
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1])
            key=(r["HISTORY"],int(r["STEP"]))
            states[key]=r
        elif line.startswith("LAREGW1_NODE|"):
            r=fields(line.split("|",1)[1])
            key=(r["HISTORY"],int(r["STEP"]))
            nodes.setdefault(key,{})[int(r["NODE"])]=(float(r["H"]),float(r["THETA"]))

    selected=[]
    replay_errors=[]
    swap_errors=[]
    source_errors=[]
    swap_sign_mismatch=0
    source_sign_mismatch=0
    h_inverse_errors=[]
    by_symbol={}
    by_history={}

    for key,r in sorted(states.items()):
        if int(r["BOTTOM_MODE"])!=5:
            continue
        history,step=key
        if key not in nodes or 16 not in nodes[key]:
            raise SystemExit(f"missing last node {key}")
        h16,theta16=nodes[key][16]
        symbol=r["SYMBOL"]
        hb=bottom_head(history,symbol)
        ref=float(r["BOTTOM_FLUX"])

        hbar=h_from_theta(theta16)
        k_node=k_from_h(h16)
        k_bar=k_from_theta(theta16)
        k_boundary=k_from_h(hb)
        gradient_ref=1.0+2.0*(h16-hb)/DZ_LAST

        replay=k_node*gradient_ref
        # psi=-h, so 1 + 2*(psi_b-psi_bar)/L = 1 + 2*(hbar-hb)/L
        swapface=k_bar*(1.0+2.0*(hbar-hb)/DZ_LAST)
        sourceface=k_boundary*(1.0+2.0*(hbar-hb)/DZ_LAST)

        replay_err=replay-ref
        swap_err=swapface-ref
        source_err=sourceface-ref
        replay_errors.append(abs(replay_err))
        swap_errors.append(abs(swap_err))
        source_errors.append(abs(source_err))
        h_inverse_errors.append(abs(hbar-h16))
        if sign(swapface)!=sign(ref): swap_sign_mismatch+=1
        if sign(sourceface)!=sign(ref): source_sign_mismatch+=1

        rec={
            "history":history,"step":step,"symbol":symbol,
            "h_last_cm":h16,"theta_last":theta16,"h_inverse_cm":hbar,
            "bottom_head_cm":hb,
            "reference_bottom_outward_flux_cm_per_day":ref,
            "reference_operator_replay_cm_per_day":replay,
            "bc1_swapface_cm_per_day":swapface,
            "bc1_sourceface_cm_per_day":sourceface,
            "reference_operator_abs_error_cm_per_day":abs(replay_err),
            "swapface_abs_error_cm_per_day":abs(swap_err),
            "sourceface_abs_error_cm_per_day":abs(source_err),
        }
        selected.append(rec)
        by_symbol.setdefault(symbol,[]).append(rec)
        by_history.setdefault(history,[]).append(rec)

    if len(selected)!=EXPECTED_MODE5:
        raise SystemExit(f"mode5 state count {len(selected)} != {EXPECTED_MODE5}")

    max_replay=max(replay_errors)
    max_swap=max(swap_errors)
    max_h_inv=max(h_inverse_errors)

    identity_pass=(
        max_replay <= float(gates["reference_operator_max_abs_error_cm_per_day"])
        and max_swap <= float(gates["swapface_max_abs_error_cm_per_day"])
        and swap_sign_mismatch == int(gates["swapface_terminal_flux_sign_mismatch_count"])
    )

    def summary(rows):
        src=[abs(x["sourceface_cm_per_day"]-x["reference_bottom_outward_flux_cm_per_day"]) for x in rows]
        sw=[abs(x["bc1_swapface_cm_per_day"]-x["reference_bottom_outward_flux_cm_per_day"]) for x in rows]
        return {
            "count":len(rows),
            "reference_flux_range_cm_per_day":[
                min(x["reference_bottom_outward_flux_cm_per_day"] for x in rows),
                max(x["reference_bottom_outward_flux_cm_per_day"] for x in rows),
            ],
            "swapface_max_abs_error_cm_per_day":max(sw),
            "sourceface_median_abs_error_cm_per_day":statistics.median(src),
            "sourceface_p95_abs_error_cm_per_day":quantile(src,0.95),
            "sourceface_max_abs_error_cm_per_day":max(src),
            "sourceface_sign_mismatch_count":sum(
                sign(x["sourceface_cm_per_day"])!=sign(x["reference_bottom_outward_flux_cm_per_day"])
                for x in rows
            ),
        }

    worst_source=sorted(
        selected,
        key=lambda x:x["sourceface_abs_error_cm_per_day"],
        reverse=True
    )[:20]

    result={
        "schema":"swap5.lare.bc1.operator-audit-result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC1-A",
        "decision":(
            "BC1_SWAPFACE_OPERATOR_IDENTITY_QUALIFIED"
            if identity_pass else
            "BC1_SWAPFACE_OPERATOR_IDENTITY_FAILED"
        ),
        "authority":{
            "preregistration":str(args.prereg),
            "stage_a_payload_sha256":hashlib.sha256(args.input.read_bytes()).hexdigest(),
        },
        "mode5_state_count":len(selected),
        "geometry":{
            "last_layer_cm":[150,160],
            "last_layer_thickness_cm":DZ_LAST,
            "identity_reason":"D3 and D4 last reduced layer equals fine Reference node-16 control volume"
        },
        "constitutive":{
            "theta_r":TR,"theta_s":TS,"alpha_per_cm":ALPHA,"n":N,"m":M,
            "Ksat_cm_per_day":KS,"lambda":LAMBDA,
            "max_abs_analytic_inverse_head_error_cm":max_h_inv,
        },
        "technical_identity_gates":{
            **gates,
            "observed_reference_operator_max_abs_error_cm_per_day":max_replay,
            "observed_swapface_max_abs_error_cm_per_day":max_swap,
            "observed_swapface_terminal_flux_sign_mismatch_count":swap_sign_mismatch,
            "pass":identity_pass,
        },
        "sourceface_sensitivity":{
            "overall":{
                "median_abs_error_cm_per_day":statistics.median(source_errors),
                "p95_abs_error_cm_per_day":quantile(source_errors,0.95),
                "max_abs_error_cm_per_day":max(source_errors),
                "sign_mismatch_count":source_sign_mismatch,
            },
            "by_symbol":{k:summary(v) for k,v in sorted(by_symbol.items())},
            "by_history":{k:summary(v) for k,v in sorted(by_history.items())},
            "worst_20":worst_source,
            "selection_status":"CONTROL_ONLY_NOT_FITTED_NOT_PUBLISHED_GENERAL_UNSATURATED_FORMULA",
        },
        "stage_B_authorized":identity_pass,
        "scientific_interpretation":[
            "BC1-SWAPFACE is an operator-binding test, not a dynamics or application-fidelity result.",
            "Because the reduced D3/D4 last layer is exactly the fine 150-160 cm Reference control volume, successful identity isolates subsequent prescribed-head errors to internal reduced dynamics rather than lower-face operator mismatch.",
            "BC1-SOURCEFACE is reported only as a non-fitted Dirichlet sensitivity and cannot be relabelled as published general-unsaturated LARE authority.",
        ],
        "moving_water_table_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],
        "mode5_state_count":len(selected),
        "max_replay_error":max_replay,
        "max_swapface_error":max_swap,
        "swap_sign_mismatch":swap_sign_mismatch,
        "sourceface":result["sourceface_sensitivity"]["overall"],
    },sort_keys=True))
    return 0 if identity_pass else 2

if __name__=="__main__":
    raise SystemExit(main())
