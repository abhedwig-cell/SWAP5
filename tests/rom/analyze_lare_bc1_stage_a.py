#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import math
import pathlib

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
KS=31.225016
LAMBDA=0.98087
M=1.0-1.0/N
L_LAST=10.0

SE0_BY_HISTORY={
    "G00":0.85,
    "G01":0.65,
    "G02":0.85,
    "G03":0.95,
    "G04":0.85,
    "G05":0.65,
}

def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out

def h_from_se(se:float)->float:
    if not 0.0 < se < 1.0:
        raise ValueError(("se",se))
    return -((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def h_from_theta(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    return h_from_se(se)

def k_from_h(h:float)->float:
    if h >= 0.0:
        return KS
    se=(1.0+(ALPHA*abs(h))**N)**(-M)
    return KS*se**LAMBDA*(1.0-(1.0-se**(1.0/M))**M)**2

def k_from_theta(theta:float)->float:
    se=(theta-TR)/(TS-TR)
    if not 0.0 < se < 1.0:
        raise ValueError(("theta/se",theta,se))
    return KS*se**LAMBDA*(1.0-(1.0-se**(1.0/M))**M)**2

def boundary_head(history:str,symbol:str)->float:
    h0=h_from_se(SE0_BY_HISTORY[history])
    if symbol in ("BOTTOM_HEAD_RISE","COMBINED_RISE_PLUS"):
        return 0.75*h0
    if symbol in ("BOTTOM_HEAD_FALL","COMBINED_FALL_MINUS"):
        return 1.25*h0
    raise ValueError((history,symbol))

def sign(x:float)->int:
    return 1 if x>0.0 else -1 if x<0.0 else 0

def stats(errors:list[float], predicted:list[float], observed:list[float])->dict[str,object]:
    if not errors:
        raise ValueError("empty candidate")
    ae=[abs(x) for x in errors]
    return {
        "record_count":len(errors),
        "mean_signed_error_cm_per_day":sum(errors)/len(errors),
        "mean_abs_error_cm_per_day":sum(ae)/len(ae),
        "rms_error_cm_per_day":math.sqrt(sum(x*x for x in errors)/len(errors)),
        "max_abs_error_cm_per_day":max(ae),
        "terminal_flux_sign_mismatch_count":sum(sign(a)!=sign(b) for a,b in zip(predicted,observed)),
        "predicted_flux_range_cm_per_day":[min(predicted),max(predicted)],
        "reference_flux_range_cm_per_day":[min(observed),max(observed)],
    }

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    assert prereg["phase"]=="PREREGISTERED_BEFORE_PRESCRIBED_HEAD_OPERATOR_RESPONSE_AUDIT"
    expected=int(prereg["stage_A_operator_audit"]["expected_mode5_state_count"])
    gates=prereg["stage_A_operator_audit"]["technical_identity_gates"]

    states={}
    nodes={}
    for line in args.input.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            row=fields(line.split("|",1)[1])
            if int(row["BOTTOM_MODE"])==5:
                states[(row["HISTORY"],int(row["STEP"]))]=row
        elif line.startswith("LAREGW1_NODE|"):
            row=fields(line.split("|",1)[1])
            if int(row["NODE"])==16:
                nodes[(row["HISTORY"],int(row["STEP"]))]=row

    if len(states)!=expected:
        raise SystemExit(f"mode-5 state count {len(states)} != preregistered {expected}")
    if not set(states).issubset(nodes):
        raise SystemExit("missing node-16 rows")

    err_ref=[];pred_ref=[];obs=[]
    err_swap=[];pred_swap=[]
    err_source=[];pred_source=[]
    roundtrip_h=[]
    rows=[]
    by_symbol=collections.defaultdict(lambda:{"ref":[],"swap":[],"source":[],"obs":[],"pr":[],"ps":[],"psrc":[]})

    for key in sorted(states):
        state=states[key]
        node=nodes[key]
        history=state["HISTORY"]
        symbol=state["SYMBOL"]
        hb=boundary_head(history,symbol)
        hN=float(node["H"])
        thetaN=float(node["THETA"])
        qobs=float(state["BOTTOM_FLUX"])

        hbar=h_from_theta(thetaN)
        k_node=k_from_h(hN)
        k_bar=k_from_theta(thetaN)
        k_boundary=k_from_h(hb)

        grad_ref=1.0+2.0*(hN-hb)/L_LAST
        grad_lare=1.0+2.0*(hbar-hb)/L_LAST

        qref=k_node*grad_ref
        qswap=k_bar*grad_lare
        qsource=k_boundary*grad_lare

        er=qref-qobs
        es=qswap-qobs
        eso=qsource-qobs

        pred_ref.append(qref);pred_swap.append(qswap);pred_source.append(qsource);obs.append(qobs)
        err_ref.append(er);err_swap.append(es);err_source.append(eso)
        roundtrip_h.append(hbar-hN)
        b=by_symbol[symbol]
        for name,val in (("ref",er),("swap",es),("source",eso)): b[name].append(val)
        b["obs"].append(qobs);b["pr"].append(qref);b["ps"].append(qswap);b["psrc"].append(qsource)

        rows.append({
            "history":history,"step":key[1],"symbol":symbol,
            "h_N_cm":hN,"theta_N":thetaN,"h_boundary_cm":hb,
            "h_from_theta_cm":hbar,
            "reference_bottom_outward_flux_cm_per_day":qobs,
            "REFERENCE_OPERATOR_REPLAY_cm_per_day":qref,
            "BC1_SWAPFACE_cm_per_day":qswap,
            "BC1_SOURCEFACE_cm_per_day":qsource,
            "REFERENCE_OPERATOR_REPLAY_error_cm_per_day":er,
            "BC1_SWAPFACE_error_cm_per_day":es,
            "BC1_SOURCEFACE_error_cm_per_day":eso,
        })

    refstats=stats(err_ref,pred_ref,obs)
    swapstats=stats(err_swap,pred_swap,obs)
    sourcestats=stats(err_source,pred_source,obs)
    symbol_stats={}
    for symbol,b in sorted(by_symbol.items()):
        symbol_stats[symbol]={
            "REFERENCE_OPERATOR_REPLAY":stats(b["ref"],b["pr"],b["obs"]),
            "BC1_SWAPFACE":stats(b["swap"],b["ps"],b["obs"]),
            "BC1_SOURCEFACE":stats(b["source"],b["psrc"],b["obs"]),
        }

    roundtrip={
        "max_abs_h_from_theta_minus_emitted_h_cm":max(abs(x) for x in roundtrip_h),
        "rms_h_from_theta_minus_emitted_h_cm":math.sqrt(sum(x*x for x in roundtrip_h)/len(roundtrip_h)),
    }

    gate={
        "reference_operator_identity":refstats["max_abs_error_cm_per_day"]<=float(gates["reference_operator_max_abs_error_cm_per_day"]),
        "swapface_identity":swapstats["max_abs_error_cm_per_day"]<=float(gates["swapface_max_abs_error_cm_per_day"]),
        "swapface_sign_identity":swapstats["terminal_flux_sign_mismatch_count"]==int(gates["swapface_terminal_flux_sign_mismatch_count"]),
    }
    passed=all(gate.values())
    result={
        "schema":"swap5.lare.bc1.stage-a.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC1-A",
        "decision":"BC1_SWAPFACE_OPERATOR_QUALIFIED_FOR_REDUCED_DYNAMICS" if passed else "BC1_OPERATOR_AUDIT_BLOCKED",
        "mode5_state_count":len(states),
        "B01_parameters":{
            "theta_r":TR,"theta_s":TS,"alpha_per_cm":ALPHA,"n":N,
            "Ksat_cm_per_day":KS,"lambda":LAMBDA
        },
        "geometry":{
            "last_layer_cm":[150,160],
            "last_layer_thickness_cm":L_LAST,
            "D3_D4_share_exact_last_fine_cell":True
        },
        "constitutive_roundtrip":roundtrip,
        "candidates":{
            "REFERENCE_OPERATOR_REPLAY":refstats,
            "BC1_SWAPFACE":swapstats,
            "BC1_SOURCEFACE":sourcestats
        },
        "by_symbol":symbol_stats,
        "technical_identity_gates":gate,
        "sourceface_selected_from_response":False,
        "interpretation":[
            "REFERENCE_OPERATOR_REPLAY is a sign/extraction self-check against the current fine Reference mode-5 face operator.",
            "BC1_SWAPFACE uses only projected last-layer storage and prescribed boundary head; D3 and D4 share the exact 10-cm fine Reference bottom cell.",
            "BC1_SOURCEFACE is reported as a no-fit Dirichlet sensitivity and is not treated as an explicitly published arbitrary-unsaturated-head formula.",
            "Stage-A operator qualification does not establish D3/D4 reduced-dynamics fidelity; internal LARE interface closure remains approximate."
        ],
        "stage_B_reduced_dynamics_authorized":passed,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
        "diagnostic_rows":rows
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":result["decision"],
        "mode5_state_count":len(states),
        "constitutive_roundtrip":roundtrip,
        "candidates":result["candidates"],
        "technical_identity_gates":gate
    },sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__":
    raise SystemExit(main())
