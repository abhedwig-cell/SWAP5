from __future__ import annotations
import ctypes
import itertools
import json
import math
import os
import sys
from decimal import Decimal, localcontext
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"research"))

from fgc44_real_swap_ctypes import Fgc44RealSwap
from test_gc_fixed_interface_fgc44_safeguarded_newton_g08 import initialize_case

PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21M_PREREGISTRATION.json"
G21L=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G21L_RESULT.json"
BASE=1.0e-12
DURATION=3.90625e-5

def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)

def seq_sum(values)->float:
    out=0.0
    for x in values:
        out += float(x)
    return out

def exact_decimal(values)->Decimal:
    with localcontext() as ctx:
        ctx.prec=120
        total=Decimal(0)
        for x in values:
            total += Decimal.from_float(float(x))
        return +total

def arithmetic(values:list[float])->dict[str,object]:
    perms=[seq_sum(p) for p in itertools.permutations(values)]
    forward=seq_sum(values)
    reverse=seq_sum(list(reversed(values)))
    asc=seq_sum(sorted(values,key=abs))
    desc=seq_sum(sorted(values,key=abs,reverse=True))
    fsum=math.fsum(values)
    exact=exact_decimal(values)
    threshold=Decimal.from_float(BASE)
    exact_fail=abs(exact)>threshold
    float_values=perms+[forward,reverse,asc,desc,fsum]
    fail_flags=[abs(v)>BASE for v in float_values]
    invariant=(all(fail_flags) and exact_fail) or ((not any(fail_flags)) and (not exact_fail))
    abs_sum=math.fsum(abs(x) for x in values)
    denom=abs(float(exact))
    cancellation=math.inf if denom==0.0 else abs_sum/denom
    return {
        "forward":forward,"reverse":reverse,"magnitude_ascending":asc,"magnitude_descending":desc,
        "math_fsum":fsum,"exact_decimal":str(exact),
        "permutation_min":min(perms),"permutation_max":max(perms),
        "permutation_unique_count":len(set(perms)),
        "criterion_fail_any":any(fail_flags) or exact_fail,
        "criterion_fail_all":all(fail_flags) and exact_fail,
        "criterion_invariant":invariant,
        "exact_criterion_fail":exact_fail,
        "sum_abs":abs_sum,"cancellation_ratio":cancellation,
    }

def bind_snapshot(swap:Fgc44RealSwap):
    fn=swap.lib.gc_g21m_snapshot_c
    fn.restype=ctypes.c_int
    fn.argtypes=[*([ctypes.POINTER(ctypes.c_int)]*5),*([ctypes.POINTER(ctypes.c_double)]*12)]
    return fn

def snapshot(fn)->dict[str,object]:
    ints=[ctypes.c_int() for _ in range(5)]
    vals=[ctypes.c_double() for _ in range(12)]
    status=fn(*[ctypes.byref(x) for x in ints],*[ctypes.byref(x) for x in vals])
    require(status==0 and ints[0].value==1,f"G21M snapshot unavailable status={status}")
    return {
        "n":int(ints[1].value),"iteration":int(ints[2].value),"backtracking":int(ints[3].value),
        "node4_terms_available":bool(ints[4].value),
        "residual":[float(vals[i].value) for i in range(4)],
        "native_sum":float(vals[4].value),"native_fmax":float(vals[5].value),
        "node4_terms":[float(vals[i].value) for i in range(6,12)],
    }

def main()->None:
    p=json.loads(PREREG.read_text())
    l=json.loads(G21L.read_text())
    require(p["status"]=="PREREGISTERED_BEFORE_IMPLEMENTATION","G21M preregistration drift")
    require(l["decision"]=="QUALIFIED_DIRECT_BOUNDARY_SPECIFIC_RESIDUAL_STATE","G21M G21L parent drift")
    frozen={row["id"]:row for row in l["cases"]}

    lib=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
    require(lib.is_file(),"G21M missing FGC44 research library")
    swap=Fgc44RealSwap(lib)
    fn=bind_snapshot(swap)
    _,_,_,origin,_=initialize_case(swap,0.01,1.0e-6)
    require(origin==(0,0.0,0,0.0),"G21M dirty origin")

    rows={}
    for case in p["frozen_cases"]:
        cid=str(case["id"])
        raw=swap.g21i_solver_prefix(float(case["head_m"]),DURATION,int(case["max_iterations"]))
        backend=swap.g21g_backend_observation()
        snap=snapshot(fn)
        require(int(backend["solver_status"])==int(case["expected_solver_status"]),f"G21M solver drift {cid}")
        require(int(backend["backtracking_attempts"])==int(case["expected_backtracking"]),f"G21M backtracking drift {cid}")
        require(snap["n"]==4,f"G21M node count drift {cid}: {snap['n']}")
        require(snap["iteration"]==int(case["max_iterations"]),f"G21M final iteration drift {cid}: {snap}")
        require(snap["backtracking"]==int(case["expected_backtracking"]),f"G21M observer backtracking drift {cid}")
        require(snap["node4_terms_available"],f"G21M node4 term snapshot unavailable {cid}")
        parent=frozen[cid]
        require(snap["native_sum"]==float(parent["residual_sum"]),f"G21M native sum mismatch G21L {cid}")
        require(snap["native_fmax"]==float(parent["residual_max_abs"]),f"G21M native fmax mismatch G21L {cid}")
        require(max(range(4),key=lambda i:abs(snap["residual"][i]))+1==int(parent["max_index"]),
                f"G21M max index mismatch G21L {cid}")
        vector_arith=arithmetic(snap["residual"])
        term_arith=arithmetic(snap["node4_terms"])
        row={
            "id":cid,"head_m":float(case["head_m"]),"solver_status":int(backend["solver_status"]),
            "backtracking":int(backend["backtracking_attempts"]),"raw_result_status":int(raw["result_status"]),
            **snap,"vector_arithmetic":vector_arith,"node4_term_arithmetic":term_arith,
            "node4_native_residual":snap["residual"][3],
            "node4_terms_forward_minus_native":term_arith["forward"]-snap["residual"][3],
            "node4_terms_fsum_minus_native":term_arith["math_fsum"]-snap["residual"][3],
        }
        rows[cid]=row
        require(swap.state()==origin and not swap.g15_has_live_candidate(),f"G21M authority drift {cid}")
        require(not swap.swap_preflight() and not swap.ledger_preflight(),f"G21M publication authority {cid}")
        print("FGC44_G21M_CASE_JSON="+json.dumps(row,sort_keys=True,separators=(",",":"),allow_nan=True))

    b2_ok=rows["B2_STATUS0"]["vector_arithmetic"]
    b2_fail=rows["B2_STATUS6"]["vector_arithmetic"]
    b2_robust=bool(b2_ok["criterion_invariant"] and b2_fail["criterion_invariant"] and
                   not b2_ok["exact_criterion_fail"] and b2_fail["exact_criterion_fail"])
    b2_class="AGGREGATION_ORDER_NOT_CAUSAL_AT_CAPTURED_TERM_LEVEL" if b2_robust else "AGGREGATION_ORDER_SENSITIVE"

    b1_fail=rows["B1_STATUS6"]["node4_term_arithmetic"]
    b1_control=rows["B1_STATUS0"]["node4_term_arithmetic"]
    b1_native_fail=abs(float(rows["B1_STATUS6"]["node4_native_residual"]))>BASE
    b1_native_control=abs(float(rows["B1_STATUS0"]["node4_native_residual"]))>BASE
    b1_invariant=bool(b1_fail["criterion_invariant"] and b1_control["criterion_invariant"] and
                      b1_fail["exact_criterion_fail"]==b1_native_fail and
                      b1_control["exact_criterion_fail"]==b1_native_control)
    b1_class="AGGREGATION_ORDER_NOT_CAUSAL_AT_CAPTURED_TERM_LEVEL" if b1_invariant else "AGGREGATION_ORDER_SENSITIVE"

    swap.g16_begin_session()
    post=[]
    expected_status={"B1_STATUS6":6,"B1_STATUS0":0,"B2_STATUS0":0,"B2_STATUS6":6}
    for case in p["frozen_cases"]:
        obs=swap.g16_observe_head(float(case["head_m"]))
        status=int(obs["participant_status"])
        require(status==expected_status[str(case["id"])],f"G21M G16 topology drift {case['id']}")
        require(swap.state()==origin and not swap.g15_has_live_candidate(),f"G21M G16 authority drift {case['id']}")
        post.append(status)
    counts=swap.g16_counts()
    require(counts==(4,4,0,4),f"G21M G16 accounting drift {counts}")
    swap.g16_end_session()

    summary={
        "b2_classification":b2_class,
        "b2_status0_cancellation_ratio":b2_ok["cancellation_ratio"],
        "b2_status6_cancellation_ratio":b2_fail["cancellation_ratio"],
        "b1_node4_classification":b1_class,
        "b1_status6_term_cancellation_ratio":b1_fail["cancellation_ratio"],
        "b1_status0_term_cancellation_ratio":b1_control["cancellation_ratio"],
        "saved_config_postprobe_status_vector":post,
        "saved_config_postprobe_g16_counts":list(counts),
        "accepted_state_ledger_mutation":0,"participant_candidate_leakage":0,
        "production_source_change":"NONE","production_arithmetic_change":"NONE",
    }
    print("FGC44_G21M_SUMMARY_JSON="+json.dumps(summary,sort_keys=True,separators=(",",":"),allow_nan=True))
    print("GC_FIXED_INTERFACE_G21M_EXECUTION=PASS")

if __name__=="__main__":
    main()
