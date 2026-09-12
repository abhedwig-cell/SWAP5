#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

BASE = "eba90d79010b095b6556e93bd8b77a8c28d25560"
FTB09 = "fe3545c4537b11cefd0186aa401048d4f4b10eb9"
FVQ28 = "d8bcb1c90e897812ae8b91295be98e58023e10fb"
FVQ34 = "df9b1123ba33ece022ce6649e70dcb538e44837f"
FGC22 = "c50f3770ae8e4bee7c276a080be00156218944f1"
CASE_ID = "SWAP5-TB09-DRAIN-BOTTOM-003-v1"


def run(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def load(path: str):
    return json.loads(Path(path).read_text())


def show_json(commit: str, path: str):
    return json.loads(run("git", "show", f"{commit}:{path}"))


def require(condition: bool, label: str):
    if not condition:
        raise SystemExit(f"FTB10_BLOCKED_CLOSEOUT_FAIL {label}")


head = run("git", "rev-parse", "HEAD")
require(subprocess.call(["git", "merge-base", "--is-ancestor", BASE, head]) == 0,
        "HEAD is not descended from frozen canonical base")

src_delta = run("git", "diff", "--name-only", f"{BASE}..{head}", "--", "src")
ref_delta = run("git", "diff", "--name-only", f"{BASE}..{head}", "--", "reference")
require(src_delta == "", "production src delta is forbidden")
require(ref_delta == "", "reference delta is forbidden")
print("FTB10_BLOCKED_PRODUCTION_SOURCE_UNCHANGED=PASS")
print("FTB10_BLOCKED_REFERENCE_UNCHANGED=PASS")

status = load("integration/f-tb/F-TB10_QUALIFICATION_STATUS.json")
contract = load("integration/f-tb/F-TB10_WORK_UNIT_CONTRACT.json")
blocker = load("integration/f-tb/F-TB10_BLOCKER_EVIDENCE.json")
handoff = load("integration/f-tb/F-TB10_OWNER_HANDOFF.json")
audit = load("integration/f-tb/F-TB10_INVARIANT_AUDIT.json")

require(status["status"] == "BLOCKED_OWNER_TEMPORAL_ACCEPTANCE_POLICY_REQUIRED", "blocked status")
require(status["decision"] == "NOT_QUALIFIED_TB09_003_NONSTATIONARY_TEMPORAL_POLICY_GAP", "blocked decision")
require(status["state"]["scientific_result_qualified"] is False, "scientific result remains unqualified")
require(status["state"]["production_source_changed"] is False, "status source immutability")
require(status["state"]["reference_changed"] is False, "status reference immutability")
require(contract["exit_target"] == "BLOCKED_OWNER_TEMPORAL_ACCEPTANCE_POLICY_REQUIRED", "contract blocked target")
require(contract["decision"] == status["decision"], "contract/status decision identity")
require(contract["mass_contract"]["hard"] is True, "hard mass contract")
require(blocker["classification"] == "BLOCKED_NONSTATIONARY_TEMPORAL_ACCEPTANCE_POLICY_REQUIRED", "blocker classification")
require(blocker["decision"] == status["decision"], "blocker/status decision identity")
require(blocker["scientific_qualification_attained"] is False, "blocker not qualification")
require(blocker["production_defect_proven"] is False, "no production defect overclaim")
require(blocker["mass_conservation_relaxation_allowed"] is False, "no mass relaxation")
require(handoff["handoff_class"] == "TEMPORAL_ACCEPTANCE_POLICY_OWNER_REQUIRED", "owner handoff class")
require("arbitrary positive temporal_tolerance" in handoff["forbidden_shortcuts"], "forbid local temporal tolerance invention")
require("arbitrary H_budget" in handoff["forbidden_shortcuts"], "forbid local H_budget invention")
require(audit["overall"] == "30_OF_30_NO_ADVERSE_DELTA", "architecture result")
require(audit["hard_mass_conservation"] == "ENFORCED_UNCHANGED_WHILE_BLOCKED", "architecture hard mass")
require(len(audit["invariants"]) == 30, "30 invariant entries")
require(sorted(x["id"] for x in audit["invariants"]) == list(range(1, 31)), "invariant ID coverage")
print("FTB10_BLOCKED_LOCAL_CONTRACTS=PASS")

ftb09 = show_json(FTB09, "testbank/manifests/F-TB09_INTEGRATED_COLUMN_PHYSICS_CASES.json")
case = next(x for x in ftb09["cases"] if x["stable_id"] == CASE_ID)
require(case["qualification_state"] == "CATALOGED_NOT_PHYSICS_QUALIFIED", "F-TB09 case remains unqualified")
require(case["execution_state"] == "CATALOG_SPEC_OWNER_EXECUTOR_REQUIRED", "F-TB09 owner executor requirement")
require(case["water_balance"]["required"] is True, "F-TB09 hard water balance required")
require(case["water_balance"]["soft_tolerance_tradeoff_allowed"] is False, "F-TB09 no soft mass tradeoff")
print("FTB10_BLOCKED_FTB09_AUTHORITY=PASS")

fvq28 = show_json(FVQ28, "integration/f-vq/F-VQ28_STATUS.json")
require(fvq28["status"] == "COMPLETE_FAIL_CLOSED_EXISTING_TRANSACTION_SHAPE_NOT_ADMITTED", "F-VQ28 negative authority")
require(fvq28["state"]["production_profile_admitted"] is False, "F-VQ28 no production profile")
require(fvq28["state"]["production_metric_selected"] is False, "F-VQ28 no production metric")
require(fvq28["state"]["production_tolerance_selected"] is False, "F-VQ28 no production tolerance")
require(fvq28["qualified_interpretation"]["universal_absolute_tolerance_admitted"] is False, "F-VQ28 no universal tolerance")
require(fvq28["holds"]["production_temporal_tolerance"] == "NOT_SELECTED", "F-VQ28 tolerance hold")
require(fvq28["holds"]["mass_gate_relaxation"] == "NOT_ALLOWED_AND_NOT_PERFORMED", "F-VQ28 mass hold")
require("separate owner/runtime-policy workunit" in fvq28["next_action"], "F-VQ28 owner handoff wording")
print("FTB10_BLOCKED_FVQ28_NEGATIVE_AUTHORITY=PASS")

fvq34 = show_json(FVQ34, "integration/f-vq/F-VQ34_CLOSEOUT.json")
require(fvq34["qualified_semantics"]["formula"] == "C_h=B_inf/H_budget", "F-VQ34 formula")
require(fvq34["qualified_semantics"]["default_H_budget"] is None, "F-VQ34 no default H_budget")
require(fvq34["qualified_semantics"]["hard_mass_before_certificate"] is True, "F-VQ34 hard mass precedence")
require(fvq34["qualified_semantics"]["certificate_can_override_mass_failure"] is False, "F-VQ34 no mass override")
require("must supply an explicit finite positive H_budget" in fvq34["downstream_handoff"]["remaining_policy_dependency"],
        "F-VQ34 explicit budget provenance dependency")
print("FTB10_BLOCKED_FVQ34_CERTIFICATE_BOUNDARY=PASS")

fci44 = show_json(BASE, "integration/f-ci/F-CI44_STATUS.json")
fci46 = show_json(BASE, "integration/f-ci/F-CI46_STATUS.json")
require(fci44["state"]["numeric_application_policy_added"] is False, "F-CI44 no numeric policy")
require("no numeric H_app" in fci44["hard_holds"], "F-CI44 H_app hold")
require("no numeric A_temporal" in fci44["hard_holds"], "F-CI44 A_temporal hold")
require("no project H_budget" in fci44["hard_holds"], "F-CI44 H_budget hold")
require(fci46["state"]["numeric_application_policy_added"] is False, "F-CI46 no numeric policy")
require("no numeric H_app" in fci46["hard_holds"], "F-CI46 H_app hold")
require("no numeric A_temporal" in fci46["hard_holds"], "F-CI46 A_temporal hold")
require("no real-project temporal head-error budget" in fci46["hard_holds"], "F-CI46 real-project budget hold")
print("FTB10_BLOCKED_CURRENT_CANONICAL_ACCURACY_TRANSPORT_ONLY=PASS")

fgc22 = show_json(FGC22, "integration/f-gc/F-GC22_STATUS.json")
fgc22_pre = show_json(FGC22, "integration/f-gc/F-GC22_PRE_REGISTRATION.json")
require(fgc22["qualified"] is True, "F-GC22 branch capability qualified")
require(fgc22["canonical_admission"] is False, "F-GC22 not canonical")
require(fgc22["production_coupling_admission"] is False, "F-GC22 not production coupling admitted")
require("Direct Groundwater Coupling" in fgc22["title"], "F-GC22 direct-groundwater scope")
require("no universal numeric H_app" in fgc22["hard_nonclaims"], "F-GC22 no universal H_app")
require("no universal numeric temporal or interface allocation" in fgc22["hard_nonclaims"], "F-GC22 no universal allocation")
require("no selection of H_app" in fgc22_pre["hard_nonclaims"], "F-GC22 no H_app selection")
require("no selection of A_temporal" in fgc22_pre["hard_nonclaims"], "F-GC22 no temporal allocation selection")
require("groundwater-head QoI only" in " ".join(fgc22_pre["required_semantics"]), "F-GC22 QoI restriction")
print("FTB10_BLOCKED_FGC22_CROSS_SCOPE_REJECTED=PASS")

runlog = Path("integration/f-tb/RUNLOG_F-TB10.md").read_text()
doc = Path("docs/testbank/F-TB10_DRAIN_BOTTOM_INTERACTION_QUALIFICATION.md").read_text()
for text, label in [(runlog, "runlog"), (doc, "documentation")]:
    require("NOT_QUALIFIED_TB09_003_NONSTATIONARY_TEMPORAL_POLICY_GAP" in text, f"{label} decision")
    require("34680289804" in text, f"{label} failed physical run provenance")
    require("F-GC22" in text, f"{label} F-GC22 scope reconciliation")
print("FTB10_BLOCKED_DOCUMENTATION_RECONCILED=PASS")

print("FTB10_BLOCKED_CLOSEOUT_VALIDATOR=PASS")
