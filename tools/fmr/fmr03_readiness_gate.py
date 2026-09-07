#!/usr/bin/env python3
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
MR = ROOT / "integration" / "f-mr"


def load(name):
    with (MR / name).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def require(condition, message, errors):
    if not condition:
        errors.append(message)


deps = load("F-MR03_DEPENDENCIES.json")
ready = load("F-MR03_ADMISSION_READINESS.json")
status = load("F-MR03_STATUS.json")
errors = []

require(ready.get("candidate_backend") == "serialized physical reference runtime",
        "candidate backend must remain serialized physical reference runtime", errors)
require(ready.get("current_decision") == "HOLD_FAIL_CLOSED",
        "readiness decision must remain HOLD_FAIL_CLOSED", errors)
for flag in ("implementation_allowed_now", "source_composition_allowed_now",
             "physical_backend_admission_allowed_now", "parallel_backend_admission_allowed_now"):
    require(ready.get(flag) is False, f"{flag} must remain false", errors)

gates = {gate["id"]: gate for gate in ready.get("gates", [])}
for gate_id in [f"MR03-G{i:02d}" for i in range(1, 11)]:
    require(gate_id in gates, f"missing readiness gate {gate_id}", errors)
if "MR03-G01" in gates:
    require(gates["MR03-G01"].get("status") == "QUALIFIED", "G01 must preserve qualified F-MR02", errors)
if "MR03-G04" in gates:
    require(gates["MR03-G04"].get("status") != "QUALIFIED",
            "G04 must not be qualified while formal F-SI09 closeout is absent", errors)
if "MR03-G05" in gates:
    require(gates["MR03-G05"].get("status", "").startswith("BLOCKED_"),
            "G05 process-provider closure must remain blocked", errors)
if "MR03-G06" in gates:
    require(gates["MR03-G06"].get("status") == "NOT_AVAILABLE",
            "G06 joint executable postimage must remain unavailable", errors)
if "MR03-G07" in gates:
    require(gates["MR03-G07"].get("status") == "NOT_IMPLEMENTED",
            "G07 serialized physical route must remain unimplemented", errors)
if "MR03-G10" in gates:
    require("NOT_ADMITTED" in gates["MR03-G10"].get("status", ""),
            "parallel reference execution must remain not admitted", errors)

fsi09 = deps.get("live_dependencies", {}).get("f_si09_default_mvg", {})
require(fsi09.get("source_consumed_by_f_mr03") is False,
        "F-SI09 source must not be consumed before formal qualification", errors)
require(fsi09.get("qualification_artifact_qualified") is False,
        "pinned F-SI09 qualification artifact must still be recorded as unqualified", errors)
require(fsi09.get("production_b110_constitutive_provider_admitted") is False,
        "production constitutive provider admission must remain false", errors)
require(fsi09.get("production_b110_source_sink_provider_admitted") is False,
        "production source/sink provider admission must remain false", errors)

policy = deps.get("source_consumption_policy", {})
for key in ("consume_tested_but_not_formally_qualified_f_si09_source",
            "duplicate_f_si_or_f_pm_provider_logic_in_f_mr",
            "change_swap_physics_in_f_mr",
            "change_f_kt_transaction_semantics_in_f_mr",
            "admit_parallel_reference_backend",
            "admit_physical_reference_backend_before_joint_executable_qualification"):
    require(policy.get(key) is False, f"source-consumption policy {key} must be false", errors)

ownership = deps.get("ownership_resolution", {})
require("runtime" in ownership.get("f_mr", "").lower(), "F-MR runtime ownership missing", errors)
require("transaction" in ownership.get("f_kt", "").lower(), "F-KT transaction ownership missing", errors)
require("solver" in ownership.get("f_si", "").lower(), "F-SI solver/provider ownership missing", errors)
require("process" in ownership.get("f_pm_or_process_owner", "").lower(), "process-physics ownership missing", errors)

require(status.get("source_changes") is False, "F-MR03 must not contain production source changes", errors)
require(status.get("production_source_consumed") == [], "F-MR03 must not consume production dependency source", errors)
require(status.get("physical_backend_implemented", False) is False,
        "physical backend implementation must remain false", errors)
require(status.get("physical_backend_admitted", False) is False,
        "physical backend admission must remain false", errors)
require(status.get("parallel_backend_admitted", False) is False,
        "parallel backend admission must remain false", errors)

# F-MR must route through F-KT/common interfaces, never schedule HeadCalc or a
# concrete B1.10 provider directly. Check actual F-MR production modules only.
for path in sorted((ROOT / "src" / "runtime").glob("mod_fmr_*.f90")):
    text = path.read_text(encoding="utf-8")
    require(re.search(r"^\s*use\s+mod_b110_default_mvg_provider\b", text, re.I | re.M) is None,
            f"direct B1.10 provider import forbidden in {path.relative_to(ROOT)}", errors)
    require(re.search(r"\bcall\s+headcalc\b", text, re.I) is None,
            f"direct HeadCalc call forbidden in {path.relative_to(ROOT)}", errors)

if errors:
    for item in errors:
        print(f"F-MR03_READINESS_GATE FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print("F-MR03_READINESS_GATE PASS")
print("physical_backend_admitted=false")
print("parallel_backend_admitted=false")
print("decision=HOLD_FAIL_CLOSED")
