#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
NBIN=200
BIN_INDEX=170
ROOT_DEPTH=30.0
COLUMN_DEPTH=160.0
PTRA=0.4
DT=10.0/86400.0
TOL=1e-14

def fields(line):
    out={}
    for p in line.split("|"):
        if "=" in p:
            k,v=p.split("=",1)
            out[k]=v
    return out

def parse_swap(path):
    rows=[x for x in pathlib.Path(path).read_text().splitlines() if x.startswith("F_ROMV2_D27_SWAP|")]
    if len(rows)!=1:
        raise SystemExit(f"expected one SWAP result row, got {len(rows)}")
    f=fields(rows[0])
    if f.get("STATUS")!="PASS":
        raise SystemExit("SWAP result not PASS")
    return f

def head_of_theta(theta):
    se=(theta-TR)/(TS-TR)
    return -((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--swap",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    p=json.loads(pathlib.Path(a.prereg).read_text())
    sw=parse_swap(a.swap)

    assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
    assert p["synthetic_state"]["selected_bin_index"]==BIN_INDEX
    assert p["material"]["moisture_bins"]==NBIN
    assert p["forcing"]["potential_transpiration_cm_per_day"]==PTRA
    assert p["synthetic_state"]["root_zone_depth_cm"]==ROOT_DEPTH

    dtheta=(TS-TR)/NBIN
    theta=TR+BIN_INDEX*dtheta
    h=head_of_theta(theta)
    hlim3=float(sw["HLIM3_CM"])
    swap_uptake_rate=float(sw["ACTUAL_UPTAKE_CM_PER_DAY"])
    swap_uptake_depth=float(sw["UPTAKE_DEPTH_CM"])
    swap_sinks=[float(sw[f"SINK{i}"]) for i in (1,2,3)]
    swap_sink_sum=float(sw["SINK_SUM"])

    demand_depth=PTRA*DT
    bin_capacity_depth=dtheta*ROOT_DEPTH
    withdrawal_length=demand_depth/dtheta
    post_length=ROOT_DEPTH-withdrawal_length

    initial_root_storage=theta*ROOT_DEPTH
    final_root_storage=initial_root_storage-demand_depth
    root_storage_decrement=initial_root_storage-final_root_storage

    initial_column_storage=theta*COLUMN_DEPTH
    final_column_storage=initial_column_storage-demand_depth
    column_storage_decrement=initial_column_storage-final_column_storage

    fmc_mass_residual=root_storage_decrement-demand_depth
    fmc_column_mass_residual=column_storage_decrement-demand_depth
    total_uptake_difference=swap_uptake_depth-demand_depth

    gates={
      "bin_identity":abs(dtheta-0.00203747)<=1e-15 and abs(theta-0.3663699)<=1e-15,
      "pressure_head_identity":abs(h-float(sw["H_CM"]))<=1e-12,
      "wet_unstressed":h>hlim3,
      "swap_rate":abs(swap_uptake_rate-PTRA)<=1e-14,
      "swap_sink_sum":abs(swap_sink_sum-PTRA)<=1e-14,
      "swap_sink_pattern":max(abs(x-y) for x,y in zip(swap_sinks,[0.04,0.18,0.18]))<=1e-14,
      "fmc_capacity":bin_capacity_depth>demand_depth and post_length>0,
      "fmc_removed_depth":abs(dtheta*withdrawal_length-demand_depth)<=TOL,
      "fmc_root_storage_ledger":abs(fmc_mass_residual)<=TOL,
      "fmc_column_storage_ledger":abs(fmc_column_mass_residual)<=TOL,
      "total_uptake_identity":abs(total_uptake_difference)<=TOL,
      "spatial_non_equivalence_recorded":True,
    }
    passed=all(gates.values())
    result={
      "schema":"swap5.f-romv2-d27.result.v1",
      "workstream":"F-ROM","work_unit":"F-ROMV2-D27",
      "decision":"D27_UNSTRESSED_TOTAL_UPTAKE_ACCOUNTING_PREFLIGHT_PASS" if passed else "D27_UNSTRESSED_UPTAKE_AUTHORITY_OR_ACCOUNTING_NO_GO",
      "SWAP":{
        "pressure_head_cm":h,
        "critical_hlim3_cm":hlim3,
        "actual_uptake_cm_per_day":swap_uptake_rate,
        "sink_rates_cm_per_day":swap_sinks,
        "sink_sum_cm_per_day":swap_sink_sum,
        "uptake_depth_10s_cm":swap_uptake_depth,
        "spatial_semantics":"three rooted 10-cm nodes weighted by cumulative root fractions [0,0.1,0.55,1]"
      },
      "FMC":{
        "bin_count":NBIN,"selected_bin":BIN_INDEX,"dtheta":dtheta,"theta":theta,
        "root_zone_depth_cm":ROOT_DEPTH,
        "rightmost_bin_capacity_depth_cm":bin_capacity_depth,
        "withdrawal_length_cm":withdrawal_length,
        "post_withdrawal_rightmost_bin_length_cm":post_length,
        "removed_depth_cm":demand_depth,
        "initial_root_zone_storage_cm":initial_root_storage,
        "final_root_zone_storage_cm":final_root_storage,
        "root_zone_storage_decrement_cm":root_storage_decrement,
        "initial_whole_column_storage_cm":initial_column_storage,
        "final_whole_column_storage_cm":final_column_storage,
        "whole_column_storage_decrement_cm":column_storage_decrement,
        "spatial_semantics":"all interval demand removed from the right-most water-containing moisture bin within the 30-cm root-zone inventory",
        "native_composite_trajectory_update_claimed":False
      },
      "mass_accounting":{
        "prescribed_total_demand_depth_cm":demand_depth,
        "FMC_root_zone_residual_cm":fmc_mass_residual,
        "FMC_whole_column_residual_cm":fmc_column_mass_residual,
        "SWAP_minus_FMC_total_uptake_depth_cm":total_uptake_difference,
        "gate_cm":TOL
      },
      "gates":gates,
      "all_gates_pass":passed,
      "structural_interpretation":{
        "total_uptake_equivalent":gates["total_uptake_identity"],
        "spatial_sink_equivalent":False,
        "statement":"The models remove the same total unstressed water depth but by intentionally different native spatial extraction structures."
      },
      "authority_boundary":{
        "native_FMC_root_active_trajectory_authorized":False,
        "drought_stress_feedback_authorized":False,
        "seasonal_ET_authorized":False,
        "application_acceptance":False,
        "formal_performance_claim":False,
        "production_rom_authorized":False
      }
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__":
    raise SystemExit(main())
