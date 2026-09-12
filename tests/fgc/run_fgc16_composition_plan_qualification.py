#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

BASE = "e537baf521e633c432a9f33de495fab9f18e918d"
ROOT = Path(__file__).resolve().parents[2]
FGC = ROOT / "integration" / "f-gc"


def load(name):
    with (FGC / name).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


pre = load("F-GC16_PRE_REGISTRATION.json")
profile = load("F-GC16_MINIMAL_RESTRICTED_PRODUCTION_PROFILE.json")
plan = load("F-GC16_DEPENDENCY_ORDERED_IMPLEMENTATION_PLAN.json")
audit = load("F-GC16_ARCHITECTURE_INVARIANT_AUDIT.json")

require(pre["work_unit"] == "F-GC16", "wrong work unit")
require(pre["live_base"]["sha"] == BASE, "base authority drift inside preregistration")
require(pre["hard_scope"]["production_source_changes"] is False, "production source change allowed")
require(pre["hard_scope"]["mass_conservation_relaxed"] is False, "mass relaxation allowed")
require(len(pre["authority_chain"]) == 15, "F-GC01..F-GC15 authority chain incomplete")
require(pre["authority_chain"]["F_GC15"] == "95ab51e6a9d4d9288af2e8ac371b4aec37268954", "F-GC15 authority mismatch")
require(pre["post_F_GC15_reconciliation"]["GC15_G01_rule"].startswith("DO_NOT_DUPLICATE"), "G01 ownership duplicated")

require(profile["profile_id"] == "RESTRICTED_DIRECT_GROUNDWATER_COUPLING_V1", "wrong restricted profile")
require(profile["scope"]["supported_SWAP_bottom_boundary"].startswith("prescribed lower-boundary head"), "bottom boundary not restricted")
require(profile["interface_quantities"]["target_flux"] == "r_q = 0 by exact opposite assignment", "flux identity weakened")
require(profile["interface_quantities"]["mass_tolerance"] == "NONE", "mass tolerance introduced")
require(profile["coupling_window"]["calendar_boundary_required"] is False, "calendar coupling introduced")
require(profile["bounded_cost_policy"]["normal_full_SWAP_trajectories_per_window"] == 2, "normal path is not predictor+corrector")
require(profile["bounded_cost_policy"]["max_corrector_iterations_per_window_attempt"] == 1, "corrector count unbounded")
require(profile["bounded_cost_policy"]["automatic_same_window_coupling_retry"] == 0, "same-window retry loop introduced")
require(profile["bounded_cost_policy"]["structural_6_to_9_full_SWAP_runs"] is False, "structural 6-9 run path allowed")
require(profile["accuracy_policy"]["H_interface_tol"].endswith("no default"), "implicit interface tolerance allowed")
require(profile["deep_vadose_seam"]["SWAP_kernel_component"] is False, "deep vadose moved into kernel")

ids = [unit["id"] for unit in plan["owner_workunits"]]
require(ids == [f"F-GC{i}" for i in range(17, 28)], "owner workunit sequence is not F-GC17..F-GC27")
require(plan["entry_gate"]["id"] == "P0_F_CI49", "F-CI49 is not the entry gate")
require(plan["entry_gate"]["status_at_F_GC16_preregistration"] == "OPEN_NOT_YET_CANONICAL_ADMITTED", "F-CI49 status misrepresented")
known = {"P0_F_CI49"}
for unit in plan["owner_workunits"]:
    for dependency in unit["dependency"]:
        require(dependency in known, f"{unit['id']} depends on unknown or forward dependency {dependency}")
    known.add(unit["id"])
require(plan["owner_workunits"][-1]["dependency"] == ["F-GC23", "F-GC24", "F-GC25", "F-GC26"], "final admission dependencies incomplete")

require(audit["result"] == "PASS_WITH_EXPLICIT_DOWNSTREAM_GATES", "architecture audit did not pass")
for number in range(1, 31):
    require(any(key.startswith(f"{number}_") for key in audit["invariants"]), f"missing invariant {number}")

changed = subprocess.check_output(
    ["git", "diff", "--name-only", f"{BASE}...HEAD"], cwd=ROOT, text=True
).splitlines()
require(changed, "no F-GC16 artifacts found")
require(not any(path.startswith("src/") for path in changed), f"production source delta detected: {changed}")
allowed_prefixes = ("integration/f-gc/", "tests/fgc/", ".github/workflows/")
require(all(path.startswith(allowed_prefixes) for path in changed), f"unexpected path in F-GC16 delta: {changed}")

print("F-GC16 composition plan qualification: PASS")
print(f"validated changed paths: {len(changed)}")
print("production src delta: NONE")
print("normal coupling path target: predictor + one corrector")
print("mass tolerance: NONE")
print("deep-vadose kernel ownership: FALSE")
