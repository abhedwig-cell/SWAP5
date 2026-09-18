#!/usr/bin/env python3
"""Static preservation gate for the F-ROM proposition and ROM-0 authority."""

from __future__ import annotations
import argparse, json, subprocess
from pathlib import Path

BASELINE="47430b68ed46a24ca05b29b46de2dd4f7e29762b"
ALLOWED_PREFIXES=(
    "docs/science/F-ROM",
    "integration/f-rom/F-ROM",
    "tests/rom/",
    ".github/workflows/f-rom",
)

def git(*args):
    return subprocess.check_output(["git",*args],text=True).strip()

def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def require(cond,msg):
    if not cond:
        raise SystemExit(msg)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--candidate-head",required=True)
    args=ap.parse_args()
    candidate=args.candidate_head
    git("merge-base","--is-ancestor",BASELINE,candidate)

    changed=[x for x in git("diff","--name-only",f"{BASELINE}...{candidate}").splitlines() if x]
    bad=[p for p in changed if not p.startswith(ALLOWED_PREFIXES)]
    require(not bad,f"out-of-scope F-ROM changes: {bad}")
    require(not [p for p in changed if p.startswith(("src/","reference/"))],
            "production/reference mutation present")

    proposition=Path("docs/science/F-ROM_RESEARCH_PROPOSITION.md").read_text()
    romp_doc=Path("docs/science/F-ROMP_PROPOSITION_QUALIFICATION.md").read_text()
    rom0_doc=Path("docs/science/F-ROM0_ACCEPTED_FULL_ORDER_AUTHORITY.md").read_text()
    supersession=load("integration/f-rom/F-ROM_EARLY_PILOT_SUPERSESSION.json")
    romp=load("integration/f-rom/F-ROMP_STATUS.json")
    rom0=load("integration/f-rom/F-ROM0_STATUS.json")
    path_recon=load("integration/f-rom/F-ROM0_RUNTIME_PATH_RECONCILIATION.json")
    prereg=load("integration/f-rom/F-ROM0_PREREGISTRATION.json")
    traj_schema=load("integration/f-rom/F-ROM0_TRAJECTORY_SCHEMA.json")
    ross24=load("integration/f-ross/F-ROSS24_TIERED_CHARACTERIZATION_RESULT.json")

    require("A third soil-water solver is an allowed outcome, not the required outcome." in proposition,
            "solver-outcome boundary missing")
    require("State first, closure second" in proposition,"state/closure separation missing")
    require("accepted SWAP5 Reference-Richards trajectories" in proposition,
            "accepted-trajectory authority missing")
    require("spatially coarsened Richards" in proposition,"coarse-Richards comparator missing")
    require("OUTSIDE_QUALIFIED_DOMAIN" in proposition,"validity principle missing")
    require("pure one-column soil-water hydraulics" in romp_doc,"ROM-P capability drift")
    require("does not set an arbitrary 1%, 5%" in romp_doc,"ROM-P threshold rule drift")
    require("accepted trajectory produced by the canonical runtime/transaction lifecycle" in rom0_doc,
            "ROM-0 lifecycle correction missing")
    require("does not search for collisions" in rom0_doc,"ROM-0/ROM-1 separation missing")

    require(supersession["decision"]=="SUPERSEDE_EARLY_F_ROM01_DIRECT_SOLVER_PILOT",
            "early-pilot supersession drift")
    require(supersession["observed_pilot_sequence"]["scientific_interpretation"]=="NONE",
            "superseded pilot acquired scientific interpretation")
    require(romp["phase"]=="CLOSED_PROCEED_TO_ROM0" and romp["decision"]=="PROCEED_TO_ROM0",
            "ROM-P decision drift")
    require(romp["production_solver_authorized"] is False,"ROM-P production solver authorized")

    require(rom0["phase"] in {
        "PREREGISTERED_IMPLEMENTATION_PENDING",
        "IMPLEMENTED_QUALIFICATION_PENDING",
        "QUALIFIED_PROCEED_TO_ROM1A",
        "QUALIFIED_EXPAND_REFERENCE_FLOOR",
        "QUALIFIED_EXPAND_ACCEPTED_TRAJECTORY_DOMAIN",
    },"ROM-0 phase drift")
    require(rom0["required_reference_route"]=="CANONICAL_ACCEPTED_REFERENCE_RICHARDS_TRAJECTORY",
            "ROM-0 reference route drift")
    require(rom0["materials"]==["B01","B14"],"ROM-0 material pair drift")
    require(rom0["production_solver_authorized"] is False,"ROM-0 production solver authorized")
    require(rom0.get("production_source_mutation","NONE")=="NONE","ROM-0 production mutation marker drift")

    require(path_recon["decision"]=="PATH_SUFFICIENT_FOR_ROM0_PREREGISTRATION",
            "runtime-path decision drift")
    require(path_recon.get("production_source_mutation","NONE")=="NONE",
            "runtime-path mutation marker drift")
    symbols=[x["symbol"] for x in path_recon["accepted_path"]]
    for symbol in (
        "fmr_trial_from_checkpoint","kernel_executor_t%advance_interval","run_canonical_interval",
        "execute_reference_interval","fmr_commit_candidate","kernel_executor_t%commit_candidate",
    ):
        require(symbol in symbols,f"missing accepted path symbol {symbol}")

    require(prereg["phase"]=="PREREGISTERED_BEFORE_EXECUTION","preregistration phase drift")
    require(prereg["production_mutation_allowed"] is False,"prereg production mutation enabled")
    require([x["id"] for x in prereg["materials"]]==["B01","B14"],"prereg materials drift")
    require(prereg["observation_interval_day"]["base"]==0.0016,"base interval drift")
    require(prereg["observation_interval_day"]["refined"]==0.0008,"refined interval drift")
    require(prereg["threshold_retuning_after_execution_allowed"] is False,"retuning enabled")
    require([e["id"] for e in prereg["experiment_families"]]==[
        "E0_HOLD","E1_NOMINAL_FLUX","E2_DRYING_FLUX","E3_BOTTOM_HEAD_RISE",
        "E4_BOTTOM_HEAD_FALL","E5_DIRECTION_REVERSAL"
    ],"experiment-family drift")

    require(traj_schema["record_type"]=="ACCEPTED_REFERENCE_TRAJECTORY_POINT","trajectory schema drift")
    require("committed_revision" in traj_schema["required_identity"],"committed revision missing")
    require(traj_schema["rejected_attempt_rule"].startswith(
        "Rejected/candidate physical states are never encoded"),"accepted/rejected boundary drift")

    require(ross24["phase"]=="CLOSED","F-ROSS24 authority not closed")
    agg=ross24["performance_screening"]["aggregate"]
    require(agg["outcome"]=="SCREENING_ROSSFAST_FASTER","F-ROSS24 direction drift")
    require(abs(float(agg["rossfast_over_reference_cpu_ratio_mean"])-0.8228088245864688)<1e-12,
            "F-ROSS24 ratio drift")
    require(agg["formal_performance_claim"] is False,"F-ROSS24 screening promoted")

    print(f"F_ROM_AUTHORITY_BASELINE={BASELINE}")
    print(f"F_ROM_AUTHORITY_CANDIDATE={candidate}")
    print("F_ROM_PRODUCTION_REFERENCE_DELTA=NONE")
    print("F_ROM_EARLY_PILOT=SUPERSEDED")
    print("F_ROMP_DECISION=PROCEED_TO_ROM0")
    print("F_ROM0_RUNTIME_PATH=RECONCILED")
    print("F_ROM0_PREREGISTRATION=FROZEN")
    print("F_ROM_AUTHORITY_GATE=PASS")

if __name__=="__main__":
    main()