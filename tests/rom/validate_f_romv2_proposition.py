#!/usr/bin/env python3
from __future__ import annotations
import json, pathlib, subprocess, sys

BASE = "4cb575c51e0e9135f5a97357c4b94cebc77647b7"
PREDECESSOR = {
    "integration/f-rom/F-ROMV_STATUS.json": "4ba4b9f59af4a2469e5734efc63519e9ae9432d7",
    "integration/f-rom/F-ROMV_MDE_STAGE1_RESULT.json": "340685ea0cfb782b7d5ecbcff8a64ee1991f7911",
    "integration/f-rom/F-ROM1_STATUS.json": "1c3116eaab4521681e5b5b35971ffa0317ad59a6",
    "integration/f-ross/F-ROSS24_TIERED_CHARACTERIZATION_RESULT.json": "340447a1f6fff46be19c8c3a4c0008d55fa75530",
}
ALLOWED = (
    "docs/science/F-ROMV2_",
    "integration/f-rom/F-ROMV2_",
    "tests/rom/validate_f_romv2_proposition.py",
    ".github/workflows/f-romv2-purpose-dependent-fidelity.yml",
)

def git(*a: str) -> str:
    return subprocess.check_output(["git", *a], text=True).strip()

def req(c: bool, m: str) -> None:
    if not c:
        raise SystemExit(m)

git("merge-base", "--is-ancestor", BASE, "HEAD")
changed=[x for x in git("diff","--name-only",f"{BASE}...HEAD").splitlines() if x]
req(all(p.startswith(ALLOWED) for p in changed), f"F-ROMV2 out-of-scope paths: {changed}")
req(not any(p.startswith(("src/","reference/")) for p in changed), "F-ROMV2 production/reference mutation")

for path, sha in PREDECESSOR.items():
    actual=git("rev-parse",f"HEAD:{path}")
    req(actual==sha, f"immutable predecessor drift: {path} {actual} != {sha}")

status=json.loads(pathlib.Path("integration/f-rom/F-ROMV2_STATUS.json").read_text())
accept=json.loads(pathlib.Path("integration/f-rom/F-ROMV2_ACCEPTANCE_FRAMEWORK.json").read_text())
prop=pathlib.Path("docs/science/F-ROMV2_PURPOSE_DEPENDENT_FIDELITY_PROPOSITION.md").read_text()

req(status["predecessor"]["decision"]=="CLOSED_NO_GO_UNDER_CURRENT_PROPOSITION","predecessor decision drift")
req(status["predecessor"]["reclassified"] is False,"predecessor reclassified")
req(status["numerical_equivalence_to_reference_required"] is False,"solver-equivalence rule drift")
req(status["current_authority"]["production_rom_authorized"] is False,"production ROM unexpectedly authorized")
req(status["exploratory_post_terminal_evidence"]["local_table_C2"]=="FEASIBILITY_ONLY_NOT_CONFIRMATORY","exploratory evidence promoted")
req(accept["threshold_policy"].startswith("No universal percentage tolerance"),"threshold policy drift")
req(accept["stage_boundary"]["old_exposed_histories_may_be_blind_validation"] is False,"old heldout reused")
req(accept["stage_boundary"]["new_validation_must_be_generated_after_preregistration"] is True,"new validation ordering drift")
req("NOT A RECLASSIFICATION OF F-ROMV" in prop,"historical firewall missing")
req("computational-cost versus hydrological-fidelity frontier" in prop,"cost-fidelity objective missing")

print(f"F_ROMV2_BASE={BASE}")
print("F_ROMV_PREDECESSOR_IMMUTABLE=PASS")
print("F_ROMV2_PRODUCTION_REFERENCE_DELTA=NONE")
print("F_ROMV2_PURPOSE_DEPENDENT_AUTHORITY=PASS")
