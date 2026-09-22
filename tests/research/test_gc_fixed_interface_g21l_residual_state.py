from __future__ import annotations

import ctypes
import json
import math
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"research"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import initialize_case

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21L_PREREGISTRATION.json"
G21K=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21K_RESULT.json"
DURATION=3.90625e-5
BASE=1.0e-12

def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)

def blob_sha(path:Path)->str:
    return subprocess.check_output(["git","hash-object",str(path.relative_to(ROOT))],cwd=ROOT,text=True).strip()

def bind_snapshot(swap:Fgc44RealSwap):
    fn=swap.lib.fgc44_g21l_residual_snapshot_c
    fn.restype=ctypes.c_int
    fn.argtypes=[
        ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),
        ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
    ]
    return fn

def snapshot(fn)->dict[str,int|float|bool]:
    ints=[ctypes.c_int() for _ in range(4)]
    vals=[ctypes.c_double() for _ in range(4)]
    status=fn(*[ctypes.byref(x) for x in ints],*[ctypes.byref(x) for x in vals])
    require(status==0,f"G21L residual observer failed status={status}")
    require(ints[0].value==1,"G21L residual observer unavailable")
    out={
        "available":True,
        "max_index":int(ints[1].value),
        "nonconverged_balance_count":int(ints[2].value),
        "nonconverged_head_count":int(ints[3].value),
        "residual_sum":float(vals[0].value),
        "residual_max_abs":float(vals[1].value),
        "residual_l2_half":float(vals[2].value),
        "max_signed_residual":float(vals[3].value),
    }
    require(all(math.isfinite(float(out[k])) for k in ["residual_sum","residual_max_abs","residual_l2_half","max_signed_residual"]),
            "G21L nonfinite residual snapshot")
    require(int(out["max_index"])>0,"G21L invalid max residual index")
    return out

def main()->None:
    p=json.loads(PREREG.read_text())
    k=json.loads(G21K.read_text())
    require(p["work_unit"]=="GC-FIXED-INTERFACE-G21L","wrong G21L preregistration")
    require(p["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION","G21L preregistration not frozen")
    require(k["decision"]=="QUALIFIED_B2_TOTAL_THRESHOLD_AND_B1_BACKTRACKING_OCCLUSION","G21L parent G21K drift")

    paths={
        "headcalc":ROOT/"src/legacy/b1_10_port/headcalc.f90",
        "serialized_reference_backend":ROOT/"src/runtime/mod_fmr_serialized_reference_backend.f90",
        "standard_fgc44_test_bridge":ROOT/"tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90",
    }
    for key,path in paths.items():
        require(blob_sha(path)==p["frozen_source_blobs"][key],f"G21L production source blob drift {key}")
    require("research_residual_snapshot" not in paths["serialized_reference_backend"].read_text(),
            "G21L production backend contaminated by research observer")
    require("fgc44_g21l_residual_snapshot_c" not in paths["standard_fgc44_test_bridge"].read_text(),
            "G21L standard bridge contaminated by research observer")
    print("FGC44_G21L_SOURCE_AUDIT_JSON="+json.dumps({
        "production_blobs_match":True,
        "production_backend_observer_absent":True,
        "standard_bridge_observer_absent":True,
        "research_build_only":True,
    },sort_keys=True,separators=(",",":")))

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"G21L missing research FGC44 library")
    swap=Fgc44RealSwap(lib)
    fn=bind_snapshot(swap)
    _,_,_,origin,_=initialize_case(swap,0.01,1.0e-6)
    require(origin==(0,0.0,0,0.0),"G21L dirty origin")

    rows={}
    for case in p["frozen_cases"]:
        cid=str(case["id"])
        raw=swap.g21i_solver_prefix(float(case["head_m"]),DURATION,int(case["max_iterations"]))
        backend=swap.g21g_backend_observation()
        require(int(backend["solver_status"])==int(case["expected_solver_status"]),
                f"G21L solver-status drift {cid}: {backend}")
        require(int(backend["backtracking_attempts"])==int(case["expected_backtracking"]),
                f"G21L backtracking drift {cid}: {backend}")
        snap=snapshot(fn)
        require(swap.state()==origin and not swap.g15_has_live_candidate(),
                f"G21L authority drift after {cid}")
        require(not swap.swap_preflight() and not swap.ledger_preflight(),
                f"G21L publication authority after {cid}")
        row={
            "id":cid,
            "head_m":float(case["head_m"]),
            "max_iterations":int(case["max_iterations"]),
            "solver_status":int(backend["solver_status"]),
            "nonlinear_iterations":int(backend["nonlinear_iterations"]),
            "backtracking_attempts":int(backend["backtracking_attempts"]),
            "raw_result_status":int(raw["result_status"]),
            **snap,
        }
        rows[cid]=row
        print("FGC44_G21L_CASE_JSON="+json.dumps(row,sort_keys=True,separators=(",",":")))

    b2fail=abs(float(rows["B2_STATUS6"]["residual_sum"]))
    low=float(p["frozen_thresholds"]["b2_total_largest_fail"])
    high=float(p["frozen_thresholds"]["b2_total_smallest_pass"])
    require(low < b2fail <= high,
            f"G21L B2 direct total residual {b2fail} outside G21K adjacent bracket [{low},{high}]")
    require(abs(float(rows["B2_STATUS0"]["residual_sum"]))<=BASE,
            "G21L B2 status0 total residual exceeds production tolerance")

    require(float(rows["B1_STATUS6"]["residual_max_abs"])>BASE,
            "G21L B1 status6 max compartment residual does not exceed production tolerance")
    require(int(rows["B1_STATUS6"]["nonconverged_balance_count"])>=1,
            "G21L B1 status6 has no nonconverged balance compartment")
    require(float(rows["B1_STATUS0"]["residual_max_abs"])<=BASE,
            "G21L B1 status0 max compartment residual exceeds production tolerance")
    require(int(rows["B1_STATUS0"]["nonconverged_balance_count"])==0,
            "G21L B1 status0 retains nonconverged balance compartments")

    swap.g16_begin_session()
    post=[]
    for case in p["frozen_cases"]:
        obs=swap.g16_observe_head(float(case["head_m"]))
        observed=int(obs["participant_status"])
        require(observed==int(case["expected_participant_status"]),
                f"G21L normal participant status drift {case['id']}")
        require(swap.state()==origin and not swap.g15_has_live_candidate(),
                f"G21L G16 authority drift {case['id']}")
        post.append(observed)
    counts=swap.g16_counts()
    require(counts==(4,4,0,4),f"G21L G16 accounting drift {counts}")
    swap.g16_end_session()

    summary={
        "b2_direct_abs_total_residual":b2fail,
        "b2_g21k_largest_fail":low,
        "b2_g21k_smallest_pass":high,
        "b2_threshold_cross_validation":"PASS",
        "b1_status6_max_abs_residual":float(rows["B1_STATUS6"]["residual_max_abs"]),
        "b1_status6_max_index":int(rows["B1_STATUS6"]["max_index"]),
        "b1_status6_nonconverged_balance_count":int(rows["B1_STATUS6"]["nonconverged_balance_count"]),
        "b1_status0_max_abs_residual":float(rows["B1_STATUS0"]["residual_max_abs"]),
        "b1_direct_untouched_path_observation":"PASS",
        "saved_config_postprobe_status_vector":post,
        "saved_config_postprobe_g16_counts":list(counts),
        "accepted_state_ledger_mutation":0,
        "participant_candidate_leakage":0,
        "production_source_change":"NONE",
    }
    print("FGC44_G21L_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G21L_B2_THRESHOLD_CROSSCHECK=PASS")
    print("GC_FIXED_INTERFACE_G21L_B1_DIRECT_RESIDUAL=PASS")
    print("GC_FIXED_INTERFACE_G21L_DIAGNOSTIC_NON_AUTHORITY=PASS")
    print("GC_FIXED_INTERFACE_G21L_EXECUTION=PASS")

if __name__=="__main__":
    main()
