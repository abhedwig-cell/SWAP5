from __future__ import annotations

import ast
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PREREG=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G18_PREREGISTRATION.json"
G11=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G11_RESULT.json"
G17=ROOT/"integration"/"research"/"GC_FIXED_INTERFACE_G17_RESULT.json"
SESSION=ROOT/"src"/"adapter"/"modflow6_prepared_solve_session.py"
FGC39=ROOT/"docs"/"integration"/"F-GC39_PREPARED_SOLVE_COUPLING_SERVICE_CONTRACT.md"


def require(cond:bool,msg:str)->None:
    if not cond:
        raise AssertionError(msg)


def class_methods(tree:ast.AST,class_name:str)->dict[str,ast.FunctionDef]:
    for node in ast.walk(tree):
        if isinstance(node,ast.ClassDef) and node.name==class_name:
            return {x.name:x for x in node.body if isinstance(x,ast.FunctionDef)}
    raise AssertionError(f"missing class {class_name}")


def called_attributes(fn:ast.FunctionDef)->set[str]:
    out=set()
    for node in ast.walk(fn):
        if isinstance(node,ast.Call) and isinstance(node.func,ast.Attribute):
            out.add(node.func.attr)
    return out


def assigned_self_attributes(fn:ast.FunctionDef)->set[str]:
    out=set()
    for node in ast.walk(fn):
        targets=[]
        if isinstance(node,(ast.Assign,ast.AnnAssign,ast.AugAssign)):
            if isinstance(node,ast.Assign):
                targets=node.targets
            else:
                targets=[node.target]
        for target in targets:
            if isinstance(target,ast.Attribute) and isinstance(target.value,ast.Name) and target.value.id=="self":
                out.add(target.attr)
    return out


def main()->None:
    prereg=json.loads(PREREG.read_text())
    require(prereg["work_unit"]=="GC-FIXED-INTERFACE-G18","wrong G18 preregistration")
    require(prereg["status"]=="PREREGISTERED_BEFORE_EXECUTION","G18 preregistration not frozen")

    g11=json.loads(G11.read_text())
    g17=json.loads(G17.read_text())
    p4=next(x for x in g11["policy_results"] if x["policy"]=="P4_E3")
    first=p4["trace"][0]

    frozen=prereg["frozen_g11_transition"]
    current=float(first["current_head_m"])
    raw=float(first["raw_head_m"])
    accepted=float(first["accepted_head_m"])
    alpha=(accepted-current)/(raw-current)
    require(int(first["raw_status"])==int(frozen["raw_participant_status"])==6,"G18 raw status authority drift")
    require(math.isclose(current,float(frozen["current_head_m"]),rel_tol=0.0,abs_tol=1e-15),"G18 current head drift")
    require(math.isclose(raw,float(frozen["raw_head_m"]),rel_tol=0.0,abs_tol=1e-15),"G18 raw head drift")
    require(math.isclose(accepted,float(frozen["first_accepted_head_m"]),rel_tol=0.0,abs_tol=1e-15),"G18 accepted head drift")
    require(int(first["cumulative_contractions"])==int(frozen["contraction_count"])==2,"G18 contraction count drift")
    require(math.isclose(alpha,float(frozen["expected_head_fraction_from_current_to_raw"]),rel_tol=0.0,abs_tol=1e-12),
            f"G18 first accepted head is not the frozen factor-1/2 twice contraction: alpha={alpha}")

    require(int(g17["safeguard_path"]["first_raw_status"])==6,"G18 G17 raw status drift")
    require(math.isclose(float(g17["safeguard_path"]["first_raw_dh_m"]),float(g11["summary"]["first_raw_dh_m"]),rel_tol=0.0,abs_tol=1e-15),
            "G18 G17/G11 raw proposal mismatch")
    require(int(g17["safeguard_path"]["total_contractions"])==2,"G18 G17 contraction count drift")

    source=SESSION.read_text()
    tree=ast.parse(source)
    methods=class_methods(tree,"Modflow6PreparedSolveSession")
    expected_public={
        "acquire_after_prepare_time_step","open_prepared_solve","publish_and_solve_iteration",
        "finalize_prepared_solve","timestep_ready_for_finalize","finalize_time_step_once",
        "invalidate_without_finalize",
    }
    missing=sorted(expected_public-set(methods))
    require(not missing,f"G18 F-GC38 prepared-solve surface missing expected methods {missing}")

    forbidden_public={
        "restore_previous_x","restore_iterate","rollback_solve","rollback_iteration",
        "set_head","set_current_head","set_x","prescribe_head","clone_open_prepared_solve",
        "restart_from_xold","rewind_solve",
    }
    actual_forbidden=sorted(forbidden_public & set(methods))
    require(not actual_forbidden,f"G18 found an admitted state-control primitive unexpectedly: {actual_forbidden}")

    invalidate=methods["invalidate_without_finalize"]
    calls=called_attributes(invalidate)
    assigns=assigned_self_attributes(invalidate)
    require("_invalidate" in calls,"G18 invalidate_without_finalize does not invalidate the session")
    require(not ({"head","xold","accepted_xold"} & assigns),"G18 invalidate unexpectedly rewrites groundwater state")

    finalize=methods["finalize_time_step_once"]
    finalize_source=ast.get_source_segment(source,finalize) or ""
    require("not advertised as rollback-safe" in finalize_source.lower(),"G18 missing F-GC38 irreversible finalize warning")

    doc=FGC39.read_text()
    required_doc=(
        "do **not** rollback or discard MODFLOW `X`",
        "update only the affine reference",
        "There is **no groundwater discard between coupling iterations**",
        "Whole-window abandonment/retry and final timestep publication remain separate capabilities.",
    )
    for token in required_doc:
        require(token in doc,f"G18 missing F-GC39 ownership statement: {token}")

    contracted_gap=abs(raw-accepted)
    require(contracted_gap>1e-12,"G18 frozen safeguard contraction is numerically trivial")

    result={
        "current_head_m":current,
        "raw_head_m":raw,
        "first_accepted_head_m":accepted,
        "head_fraction_alpha":alpha,
        "raw_minus_contracted_head_m":raw-accepted,
        "contractions":int(first["cumulative_contractions"]),
        "raw_status":int(first["raw_status"]),
        "prepared_solve_expected_public_methods":sorted(expected_public),
        "prepared_solve_forbidden_state_control_methods_present":actual_forbidden,
        "invalidate_calls":sorted(calls),
        "invalidate_state_assignments":sorted(assigns),
        "fgc39_continuous_x_no_rollback":"CONFIRMED",
        "exact_head_reposition_required_after_raw_iterate":True,
        "admitted_exact_head_reposition_primitive":False,
        "classification":"EXACT_HEAD_SPACE_P4_NOT_REPRESENTABLE_UNDER_CURRENT_FGC38_FGC39_PREPARED_SOLVE_CONTRACT",
    }
    print("FGC44_G18_RECONCILIATION_JSON="+json.dumps(result,sort_keys=True,separators=(",",":")))
    print("GC_FIXED_INTERFACE_G18_PREPARED_SOLVE_OWNERSHIP_AUDIT=PASS")
    print("GC_FIXED_INTERFACE_G18_EXACT_P4_COMPATIBILITY=FALSIFIED")
    print("GC_FIXED_INTERFACE_G18_EXECUTION=PASS")


if __name__=="__main__":
    main()
