#!/usr/bin/env python3
from __future__ import annotations

import argparse, hashlib, json, math, pathlib, statistics

TR=0.02; TS=0.427494; ALPHA=0.021659; N=1.734737
KS=31.225016; LAMBDA=0.98087; M=1.0-1.0/N
DZ_LAST=10.0; EXPECTED_MODE5=2112
SE0_BY_HISTORY={"G00":0.85,"G01":0.65,"G02":0.85,"G03":0.95,"G04":0.85,"G05":0.65}
RISE={"BOTTOM_HEAD_RISE","COMBINED_RISE_PLUS"}
FALL={"BOTTOM_HEAD_FALL","COMBINED_FALL_MINUS"}

def fields(payload):
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1); out[k]=v
    return out

def h_from_se(se):
    return -((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def h_from_theta(theta):
    se=(theta-TR)/(TS-TR)
    if not (0.0 < se < 1.0): raise ValueError(theta)
    return h_from_se(se)

def theta_from_h(h):
    if h>=0.0: return TS
    return TR+(TS-TR)*(1.0+abs(ALPHA*h)**N)**(-M)

def k_from_theta(theta):
    se=(theta-TR)/(TS-TR)
    if se >= 1.0-1.0e-6: return KS
    if not (0.0 < se < 1.0): raise ValueError(se)
    term=(1.0-se**(1.0/M))**M
    return min(KS,KS*(se**LAMBDA)*(1.0-term)**2)

def k_from_h(h): return k_from_theta(theta_from_h(h))

def bottom_head(history,symbol):
    h0=h_from_se(SE0_BY_HISTORY[history])
    if symbol in RISE: return 0.75*h0
    if symbol in FALL: return 1.25*h0
    raise ValueError((history,symbol))

def sgn(x): return 1 if x>0 else (-1 if x<0 else 0)

def quantile(values,q):
    xs=sorted(values); pos=q*(len(xs)-1); lo=int(math.floor(pos)); hi=int(math.ceil(pos))
    if lo==hi:return xs[lo]
    return xs[lo]*(hi-pos)+xs[hi]*(pos-lo)

def dist_summary(values):
    return {
        "median":statistics.median(values),
        "p95":quantile(values,0.95),
        "max":max(values),
        "rms":math.sqrt(sum(v*v for v in values)/len(values)),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    assert prereg["phase"]=="PREREGISTERED_BEFORE_PRESCRIBED_HEAD_OPERATOR_RESPONSE_AUDIT"
    gates=prereg["stage_A1_operator_audit"]["hard_gates"]

    states={}; nodes={}
    for line in args.input.open(errors="replace"):
        if line.startswith("LAREGW1_STATE|"):
            r=fields(line.split("|",1)[1]); states[(r["HISTORY"],int(r["STEP"]))]=r
        elif line.startswith("LAREGW1_NODE|"):
            r=fields(line.split("|",1)[1]); key=(r["HISTORY"],int(r["STEP"]))
            nodes.setdefault(key,{})[int(r["NODE"])]=(float(r["H"]),float(r["THETA"]))

    rows=[]; h_roundtrip=[]; state_identity=[]; terminal_diff=[]; lagged_terminal_diff=[]
    sourceface_state_diff=[]; state_sign_mismatch=0; sourceface_state_sign_mismatch=0
    lagged_terminal_sign_mismatch=0

    for key,r in sorted(states.items()):
        if int(r["BOTTOM_MODE"])!=5: continue
        history,step=key
        h16,theta16=nodes[key][16]; symbol=r["SYMBOL"]; hb=bottom_head(history,symbol)
        terminal=float(r["BOTTOM_FLUX"])
        hbar=h_from_theta(theta16)
        k_state=k_from_h(h16); k_bar=k_from_theta(theta16); k_boundary=k_from_h(hb)
        gradient=1.0+2.0*(h16-hb)/DZ_LAST
        state_operator=k_state*gradient
        swapface=k_bar*(1.0+2.0*(hbar-hb)/DZ_LAST)
        sourceface=k_boundary*(1.0+2.0*(hbar-hb)/DZ_LAST)

        if step>1:
            base_h=nodes[(history,step-1)][16][0]
            base_authority="PREVIOUS_ACCEPTED_STATE"
        else:
            base_h=h_from_se(SE0_BY_HISTORY[history])
            base_authority="ANALYTIC_SEED_ANCHOR"
        lagged_face=k_from_h(base_h)*gradient

        h_roundtrip.append(abs(hbar-h16))
        state_identity.append(abs(swapface-state_operator))
        terminal_diff.append(abs(state_operator-terminal))
        lagged_terminal_diff.append(abs(lagged_face-terminal))
        sourceface_state_diff.append(abs(sourceface-state_operator))
        state_sign_mismatch += sgn(swapface)!=sgn(state_operator)
        sourceface_state_sign_mismatch += sgn(sourceface)!=sgn(state_operator)
        lagged_terminal_sign_mismatch += sgn(lagged_face)!=sgn(terminal)

        rows.append({
            "history":history,"step":step,"symbol":symbol,
            "h_last_cm":h16,"theta_last":theta16,"h_inverse_cm":hbar,
            "base_h_last_cm":base_h,"base_h_authority":base_authority,
            "bottom_head_cm":hb,
            "state_face_operator_cm_per_day":state_operator,
            "bc1_swapface_state_operator_cm_per_day":swapface,
            "bc1_sourceface_state_operator_cm_per_day":sourceface,
            "reference_swkimpl0_lagged_face_cm_per_day":lagged_face,
            "reported_balance_materialized_terminal_qbot_cm_per_day":terminal,
            "swapface_vs_state_operator_abs_error_cm_per_day":abs(swapface-state_operator),
            "state_operator_vs_terminal_qbot_abs_difference_cm_per_day":abs(state_operator-terminal),
            "lagged_face_vs_terminal_qbot_abs_difference_cm_per_day":abs(lagged_face-terminal),
            "sourceface_vs_state_operator_abs_difference_cm_per_day":abs(sourceface-state_operator),
        })

    if len(rows)!=EXPECTED_MODE5: raise SystemExit(f"mode5 count {len(rows)}")

    identity_pass=(
        max(h_roundtrip)<=float(gates["analytic_h_theta_roundtrip_max_abs_error_cm"])
        and max(state_identity)<=float(gates["swapface_vs_state_operator_max_abs_error_cm_per_day"])
        and state_sign_mismatch==int(gates["swapface_vs_state_operator_sign_mismatch_count"])
    )

    def subset_summary(rs):
        return {
            "count":len(rs),
            "swapface_state_identity_max_abs_error_cm_per_day":max(x["swapface_vs_state_operator_abs_error_cm_per_day"] for x in rs),
            "state_operator_vs_terminal_qbot":dist_summary([x["state_operator_vs_terminal_qbot_abs_difference_cm_per_day"] for x in rs]),
            "lagged_face_vs_terminal_qbot":dist_summary([x["lagged_face_vs_terminal_qbot_abs_difference_cm_per_day"] for x in rs]),
            "sourceface_vs_state_operator":dist_summary([x["sourceface_vs_state_operator_abs_difference_cm_per_day"] for x in rs]),
            "sourceface_state_sign_mismatch_count":sum(sgn(x["bc1_sourceface_state_operator_cm_per_day"])!=sgn(x["state_face_operator_cm_per_day"]) for x in rs),
        }

    by_symbol={}; by_history={}
    for row in rows:
        by_symbol.setdefault(row["symbol"],[]).append(row)
        by_history.setdefault(row["history"],[]).append(row)

    result={
        "schema":"swap5.lare.bc1.stage-a1-result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC1-A1",
        "decision":"BC1_SWAPFACE_STATE_OPERATOR_IDENTITY_QUALIFIED" if identity_pass else "BC1_SWAPFACE_STATE_OPERATOR_IDENTITY_FAILED",
        "authority":{
            "preregistration":str(args.prereg),
            "stage_a_payload_sha256":hashlib.sha256(args.input.read_bytes()).hexdigest(),
            "supersedes_identity_target":"integration/f-rom/LARE_BC1_STAGE_A0_BLOCKED.json",
        },
        "mode5_state_count":len(rows),
        "geometry":{"last_layer_cm":[150,160],"thickness_cm":DZ_LAST},
        "constitutive":{"theta_r":TR,"theta_s":TS,"alpha_per_cm":ALPHA,"n":N,"m":M,"Ksat_cm_per_day":KS,"lambda":LAMBDA},
        "hard_gates":{
            **gates,
            "observed_analytic_h_theta_roundtrip_max_abs_error_cm":max(h_roundtrip),
            "observed_swapface_vs_state_operator_max_abs_error_cm_per_day":max(state_identity),
            "observed_swapface_vs_state_operator_sign_mismatch_count":state_sign_mismatch,
            "pass":identity_pass,
        },
        "reference_time_level_diagnostic":{
            "state_operator_vs_balance_materialized_terminal_qbot":dist_summary(terminal_diff),
            "swkimpl0_lagged_face_vs_balance_materialized_terminal_qbot":dist_summary(lagged_terminal_diff),
            "lagged_face_vs_terminal_qbot_sign_mismatch_count":lagged_terminal_sign_mismatch,
            "interpretation":"Neither comparison is an A1 identity gate. They expose Reference SWKIMPL=0 conductivity time level and post-solve balance materialization."
        },
        "sourceface_sensitivity":{
            "vs_same_state_operator":dist_summary(sourceface_state_diff),
            "state_operator_sign_mismatch_count":sourceface_state_sign_mismatch,
            "by_symbol":{k:subset_summary(v) for k,v in sorted(by_symbol.items())},
            "by_history":{k:subset_summary(v) for k,v in sorted(by_history.items())},
            "selection_status":"CONTROL_ONLY_NOT_A_PUBLISHED_GENERAL_UNSATURATED_FORMULA",
        },
        "scientific_interpretation":[
            "BC1-SWAPFACE exactly binds same-state fixed-head face geometry and constitutive mapping because D3/D4 end in the same 150-160 cm control volume as REF16.",
            "The reported terminal qbot is not a raw same-state Darcy face operator: Reference SWKIMPL=0 lags K over the timestep and post-solve mode-5 qbot is materialized from the water balance.",
            "Head-driven reduced dynamics must compare hydrological exchange to the balance-materialized Reference output without fitting the LARE physical closure to Reference numerical time-level semantics."
        ],
        "stage_B_authorized":identity_pass,
        "moving_water_table_authorized":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":result["decision"],"mode5_state_count":len(rows),
        "max_h_roundtrip":max(h_roundtrip),"max_state_identity":max(state_identity),
        "state_sign_mismatch":state_sign_mismatch,
        "state_vs_terminal_max":max(terminal_diff),
        "lagged_vs_terminal_max":max(lagged_terminal_diff),
        "sourceface_vs_state_max":max(sourceface_state_diff),
    },sort_keys=True))
    return 0 if identity_pass else 2

if __name__=="__main__":
    raise SystemExit(main())
