from __future__ import annotations
import argparse
import json
import math
from pathlib import Path

W_TOL=1e-4
ROOT_TOL=1e-4
H16_MIN=1e-2
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

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    lines=Path(args.input).read_text(encoding="utf-8").splitlines()
    recon=[x for x in lines if x.startswith("RZM06E04_RECON|")]
    forcing=[x for x in lines if x.startswith("RZM06E04_FORCING|")]
    probe=[x for x in lines if x.startswith("RZM06E04_PROBE|")]
    assert len(recon)==1 and len(forcing)==1 and len(probe)==1

    r=fields(recon[0]); f=fields(forcing[0]); p=fields(probe[0])
    dw=float(r["ABS_DW"])
    dr=float(r["ABS_DROOT"])
    dh16=float(r["ABS_DH16"])
    assert math.isfinite(dw) and math.isfinite(dr) and math.isfinite(dh16)
    assert dw<=W_TOL and dr<=ROOT_TOL and dh16>=H16_MIN
    assert abs(float(f["HC_M"])-(-1.8979370901690651))<=1e-15
    assert abs(float(f["BOTTOM_HEAD_CM"])-(-29.793709016906497))<=1e-12

    admitted_a=as_bool(p["ADMITTED_A"])
    admitted_b=as_bool(p["ADMITTED_B"])
    result={
      "schema":"swap5.gc_rootzone_memory.rzm06e04.rootmatched_interface_memory_probe.v1",
      "preregistration_commit":"dc08a9699e2257299aad4dc1b91fbd3d78aa9f8e",
      "production_changes":False,
      "reconstruction":{
        "profile_water_a_cm":float(r["WA"]),
        "profile_water_b_cm":float(r["WB"]),
        "abs_delta_profile_water_cm":dw,
        "root30_water_a_cm":float(r["UPPERA"]),
        "root30_water_b_cm":float(r["UPPERB"]),
        "abs_delta_root30_water_cm":dr,
        "H16_a_cm":float(r["H16A"]),
        "H16_b_cm":float(r["H16B"]),
        "abs_delta_H16_cm":dh16,
        "state_gate_pass":True
      },
      "forcing":{
        "fixed_interface_head_m":float(f["HC_M"]),
        "bottom_boundary_elevation_m":float(f["BOTTOM_Z_M"]),
        "mapped_bottom_pressure_head_cm":float(f["BOTTOM_HEAD_CM"]),
        "top_flux_cm_per_day":float(f["TOP_FLUX"]),
        "dt_day":float(f["DT_DAY"])
      },
      "order_independence":any(x=="GC_RZM06E04_ORDER_INDEPENDENCE=PASS" for x in lines),
      "probe":{"admitted_a":admitted_a,"admitted_b":admitted_b}
    }
    assert result["order_independence"]

    if admitted_a and admitted_b:
        abs_delta=float(p["ABS_DELTA_EXCHANGE"])
        threshold=float(p["THRESHOLD"])
        support=as_bool(p["SUPPORT"])
        assert math.isfinite(abs_delta) and abs_delta>=0
        assert threshold==RESP_THR
        assert support==(abs_delta>RESP_THR)
        result["probe"].update({
          "exchange_a_cm":float(p["A_EXCHANGE"]),
          "exchange_b_cm":float(p["B_EXCHANGE"]),
          "delta_exchange_cm":float(p["DELTA_EXCHANGE"]),
          "abs_delta_exchange_cm":abs_delta,
          "response_threshold_cm":threshold,
          "terminal_flux_a_cm_per_day":float(p["A_TERMINAL_FLUX"]),
          "terminal_flux_b_cm_per_day":float(p["B_TERMINAL_FLUX"]),
          "mass_residual_a_cm":float(p["A_MASS"]),
          "mass_residual_b_cm":float(p["B_MASS"]),
          "support":support
        })
        result["decision"]=(
          "SUPPORTED_ROOTMATCHED_INTERFACE_ADJACENT_MEMORY_FOR_SELECTED_REAL_SWAP_PAIR"
          if support else "NO_SUPPORT_AT_SELECTED_ROOTMATCHED_PAIR"
        )
    else:
        result["probe"].update({
          "status_a":int(p["A_STATUS"]),
          "status_b":int(p["B_STATUS"]),
          "solver_rejections_a":int(p.get("A_SOLVER_REJECTIONS","0")),
          "solver_rejections_b":int(p.get("B_SOLVER_REJECTIONS","0")),
          "mass_complete_a":as_bool(p.get("A_MASS_COMPLETE","F")),
          "mass_complete_b":as_bool(p.get("B_MASS_COMPLETE","F"))
        })
        result["decision"]="PROBE_NOT_ADMITTED"

    result["interpretation_boundary"]=[
      "Support falsifies H_c plus total-profile-water plus upper-30-cm-water sufficiency for this selected C01 pair/window.",
      "Support does not establish H16 as the unique or minimal missing state coordinate.",
      "No production coupling admission follows."
    ]
    Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("RZM06E04_RESULT_JSON",json.dumps(result,sort_keys=True,separators=(",",":")))
    print("GC_RZM06E04_ANALYSIS=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
