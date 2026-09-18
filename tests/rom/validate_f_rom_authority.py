#!/usr/bin/env python3
"""Static qualification for the F-ROM proposition and ROM-0 authority."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

BASELINE = "0c7a76bafeab1b1e1c57f5615340178d45bec268"

ALLOWED_PREFIXES = (
    "docs/science/F-ROM",
    "integration/f-rom/F-ROM",
    "tests/rom/validate_f_rom_authority.py",
    ".github/workflows/f-rom-authority.yml",
)

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()

def load_json(path: str):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(msg)

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidate-head", required=True)
    args = ap.parse_args()

    candidate = args.candidate_head
    require(git("merge-base", "--is-ancestor", BASELINE, candidate) == "", "unexpected merge-base output")

    changed = [
        line for line in git("diff", "--name-only", f"{BASELINE}...{candidate}").splitlines()
        if line
    ]
    bad = [p for p in changed if not p.startswith(ALLOWED_PREFIXES)]
    require(not bad, f"out-of-scope F-ROM authority changes: {bad}")

    production_changed = [
        p for p in changed if p.startswith("src/") or p.startswith("reference/")
    ]
    require(not production_changed, f"production/reference mutation present: {production_changed}")

    proposition = Path("docs/science/F-ROM_RESEARCH_PROPOSITION.md").read_text(encoding="utf-8")
    romp_doc = Path("docs/science/F-ROMP_PROPOSITION_QUALIFICATION.md").read_text(encoding="utf-8")
    rom0_doc = Path("docs/science/F-ROM0_ACCEPTED_FULL_ORDER_AUTHORITY.md").read_text(encoding="utf-8")
    supersession = load_json("integration/f-rom/F-ROM_EARLY_PILOT_SUPERSESSION.json")
    romp = load_json("integration/f-rom/F-ROMP_STATUS.json")
    rom0 = load_json("integration/f-rom/F-ROM0_STATUS.json")
    ross24 = load_json("integration/f-ross/F-ROSS24_TIERED_CHARACTERIZATION_RESULT.json")

    require("A third soil-water solver is an allowed outcome, not the required outcome." in proposition,
            "solver-outcome boundary missing")
    require("State first, closure second" in proposition, "state/closure separation missing")
    require("accepted SWAP5 Reference-Richards trajectories" in proposition,
            "accepted-trajectory authority missing")
    require("spatially coarsened Richards" in proposition, "coarse-Richards comparator missing")
    require("OUTSIDE_QUALIFIED_DOMAIN" in proposition, "validity/fail-closed principle missing")

    require("pure one-column soil-water hydraulics" in romp_doc, "ROM-P initial capability drift")
    require("does not set an arbitrary 1%, 5%" in romp_doc, "ROM-P threshold rule drift")
    require("accepted trajectory produced by the canonical runtime/transaction lifecycle" in rom0_doc,
            "ROM-0 accepted lifecycle correction missing")
    require("does not search for collisions" in rom0_doc, "ROM-0/ROM-1 scope separation missing")

    require(supersession["decision"] == "SUPERSEDE_EARLY_F_ROM01_DIRECT_SOLVER_PILOT",
            "supersession decision drift")
    require(supersession["superseded_work"]["pull_request"] == 252, "superseded PR drift")
    require(supersession["observed_pilot_sequence"]["scientific_interpretation"] == "NONE",
            "superseded pilot acquired scientific interpretation")

    require(romp["phase"] == "CLOSED_PROCEED_TO_ROM0", "ROM-P not closed to ROM-0")
    require(romp["decision"] == "PROCEED_TO_ROM0", "ROM-P decision drift")
    require(romp["production_solver_authorized"] is False, "ROM-P production solver unexpectedly authorized")
    require(rom0["phase"] == "DESIGN_AUTHORITY_OPEN_IMPLEMENTATION_PENDING", "ROM-0 phase drift")
    require(rom0["required_reference_route"] == "CANONICAL_ACCEPTED_REFERENCE_RICHARDS_TRAJECTORY",
            "ROM-0 reference route drift")
    require(rom0["production_solver_authorized"] is False, "ROM-0 production solver unexpectedly authorized")

    require(ross24["phase"] == "CLOSED", "F-ROSS24 authority not closed")
    agg = ross24["performance_screening"]["aggregate"]
    require(agg["outcome"] == "SCREENING_ROSSFAST_FASTER", "F-ROSS24 screening direction drift")
    require(abs(float(agg["rossfast_over_reference_cpu_ratio_mean"]) - 0.8228088245864688) < 1e-12,
            "F-ROSS24 solver ratio authority drift")
    require(agg["formal_performance_claim"] is False, "F-ROSS24 screening promoted to formal claim")

    print(f"F_ROM_AUTHORITY_BASELINE={BASELINE}")
    print(f"F_ROM_AUTHORITY_CANDIDATE={candidate}")
    print("F_ROM_PRODUCTION_REFERENCE_DELTA=NONE")
    print("F_ROM_EARLY_PILOT=SUPERSEDED")
    print("F_ROMP_DECISION=PROCEED_TO_ROM0")
    print("F_ROM0_AUTHORITY=ACCEPTED_TRAJECTORY_PLUS_REFERENCE_FLOOR")
    print("F_ROM_AUTHORITY_GATE=PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
