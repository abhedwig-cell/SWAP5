from __future__ import annotations
import argparse, json, math
from pathlib import Path

W_TOL=1e-4
M1_MIN=1e-2
RESP_THR=1e-18

def fields(line:str)->dict[str,str]:
    out={}
    for tok in line.strip().split("|")[1:]:
        if "=" in tok:
            k,v=tok.split("=",1)
            out[k]=v
    return out

def as_bool(v:str)->bool:
    return v.strip().upper() in {"T","TRUE",".TRUE."}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    args=ap.parse_args()
    lines=Path(args.input).read_text(encoding="utf-8").splitlines()
    recon=[x for x in lines if x.startswith("RZM06E02_RECON|")]
    forcing=[x for x in lines if x.startswith("RZM06E02_FORCING|")]
    probe=[x for x in lines if x.startswith("RZM06E02_PROBE|")]
    assert len(recon)==1 and len(forcing)==1 and len(probe)==1
    r=fields(recon[0]); f=fields(forcing[0]); p=fields(probe[0])
    dw=float(r["ABS_DW"]); dm=float(r["ABS_DM1"])
    assert math.isfinite(dw) and math.isfinite(dm)
    assert dw<=W_TOL and dm>=M1_MIN
    assert abs(float(f["HC_M"])-(-1.8979370901690651))<=1e-15
    assert abs(float(f["BOTTOM_HEAD_CM"])-(-29.793709016906497))<=1e-12
    admitted_a=as_bool(p["ADMITTED_A"]); admitted_b=as_bool(p["ADMITTED_B"])
    result={
      "schema":"swap5.gc_rootzone_memory.rzm06e02.fixed_hc_h2_probe.v1",
      "preregistration_commit":"c0291cc0669b0e9022695d495bcf62b4bad40a57",
      "production_changes":False,
      "reconstruction":{
        "profile_water_a_cm":float(r["WA"]),
        "profile_water_b_cm":float(r["WB"]),
        "abs_delta_profile_water_cm":dw,
        "distribution_moment_a_cm":float(r["M1A"]),
        "distribution_moment_b_cm":float(r["M1B"]),
        "abs_delta_distribution_moment_cm":dm,
        "upper30_a_cm":float(r["UPPERA"]),
        "upper30_b_cm":float(r["UPPERB"]),
        "state_gate_pass":True,
      },
      "forcing":{
        "fixed_interface_head_m":float(f["HC_M"]),
        "bottom_boundary_elevation_m":float(f["BOTTOM_Z_M"]),
        "mapped_bottom_pressure_head_cm":float(f["BOTTOM_HEAD_CM"]),
        "top_flux_cm_per_day":float(f["TOP_FLUX"]),
        "dt_day":float(f["DT_DAY"]),
      },
      "order_independence":any(x=="GC_RZM06E02_ORDER_INDEPENDENCE=PASS" for x in lines),
      "probe":{"admitted_a":admitted_a,"admitted_b":admitted_b},
    }
    assert result["order_independence"]
    if admitted_a and admitted_b:
        abs_delta=float(p["ABS_DELTA_EXCHANGE"])
        support=as_bool(p["SUPPORT"])
        assert math.isfinite(abs_delta)
        assert abs(float(p["THRESHOLD"])-RESP_THR)<=1e-30
        assert support==(abs_delta>RESP_THR)
        result["probe"].update({
          "status_a":int(p["A_STATUS"]),
          "status_b":int(p["B_STATUS"]),
          "bottom_outward_exchange_a_cm":float(p["A_EXCHANGE"]),
          "bottom_outward_exchange_b_cm":float(p["B_EXCHANGE"]),
          "delta_exchange_cm":float(p["DELTA_EXCHANGE"]),
          "abs_delta_exchange_cm":abs_delta,
          "support_threshold_cm":float(p["THRESHOLD"]),
          "terminal_bottom_flux_a_cm_per_day":float(p["A_TERMINAL_FLUX"]),
          "terminal_bottom_flux_b_cm_per_day":float(p["B_TERMINAL_FLUX"]),
          "mass_residual_a_cm":float(p["A_MASS"]),
          "mass_residual_b_cm":float(p["B_MASS"]),
        })
        if support:
            decision="SUPPORTED_H2_VERTICAL_DISTRIBUTION_MEMORY_FOR_SELECTED_REAL_SWAP_PAIR"
        else:
            decision="NO_SUPPORT_H2_AT_SELECTED_PAIR"
    else:
        result["probe"].update({
          "status_a":int(p["A_STATUS"]),
          "status_b":int(p["B_STATUS"]),
          "solver_rejections_a":int(p["A_SOLVER_REJECTIONS"]),
          "solver_rejections_b":int(p["B_SOLVER_REJECTIONS"]),
          "mass_complete_a":as_bool(p["A_MASS_COMPLETE"]),
          "mass_complete_b":as_bool(p["B_MASS_COMPLETE"]),
        })
        decision="PROBE_NOT_ADMITTED"
    result["decision"]=decision
    result["interpretation_boundary"]=[
      "The immutable E01 pair was selected without response access.",
      "A support decision applies to the selected pair and frozen fixed-Hc probe.",
      "A no-support decision would apply only to this selected pair and probe, not globally.",
      "No production coupling admission or second MODFLOW hydraulic state follows."
    ]
    print("RZM06E02_EXPERIMENT_JSON",json.dumps(result,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E02_ANALYSIS=PASS")

if __name__=="__main__":
    main()
