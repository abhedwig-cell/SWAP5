#!/usr/bin/env python3
"""Stage-aware static qualification for the governed F-ROM research authority."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

FOUNDATION_BASELINE = "0c7a76bafeab1b1e1c57f5615340178d45bec268"

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


def validate_foundation() -> None:
    proposition = Path("docs/science/F-ROM_RESEARCH_PROPOSITION.md").read_text(encoding="utf-8")
    romp_doc = Path("docs/science/F-ROMP_PROPOSITION_QUALIFICATION.md").read_text(encoding="utf-8")
    rom0_doc = Path("docs/science/F-ROM0_ACCEPTED_FULL_ORDER_AUTHORITY.md").read_text(encoding="utf-8")
    supersession = load_json("integration/f-rom/F-ROM_EARLY_PILOT_SUPERSESSION.json")
    romp = load_json("integration/f-rom/F-ROMP_STATUS.json")
    path_recon = load_json("integration/f-rom/F-ROM0_RUNTIME_PATH_RECONCILIATION.json")
    prereg = load_json("integration/f-rom/F-ROM0_PREREGISTRATION.json")
    traj_schema = load_json("integration/f-rom/F-ROM0_TRAJECTORY_SCHEMA.json")
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

    require(path_recon["decision"] == "PATH_SUFFICIENT_FOR_ROM0_PREREGISTRATION",
            "ROM-0 runtime-path decision drift")
    mutation = path_recon.get("production_source_mutation", "NONE")
    require(mutation in (False, "NONE"), "ROM-0 path reconciliation mutation marker drift")
    symbols = [step["symbol"] for step in path_recon["accepted_path"]]
    for symbol in (
        "fmr_trial_from_checkpoint",
        "kernel_executor_t%advance_interval",
        "run_canonical_interval",
        "execute_reference_interval",
        "fmr_commit_candidate",
        "kernel_executor_t%commit_candidate",
    ):
        require(symbol in symbols, f"missing accepted path symbol: {symbol}")

    require(prereg["phase"] == "PREREGISTERED_BEFORE_EXECUTION", "ROM-0 preregistration phase drift")
    require(prereg["production_mutation_allowed"] is False, "ROM-0 production mutation enabled")
    require([m["id"] for m in prereg["materials"]] == ["B01", "B14"], "preregistered materials drift")
    require(prereg["observation_interval_day"]["base"] == 0.0016, "base interval drift")
    require(prereg["observation_interval_day"]["refined"] == 0.0008, "refined interval drift")
    require(prereg["threshold_retuning_after_execution_allowed"] is False,
            "ROM-0 threshold retuning unexpectedly allowed")
    families = [e["id"] for e in prereg["experiment_families"]]
    require(families == [
        "E0_HOLD",
        "E1_NOMINAL_FLUX",
        "E2_DRYING_FLUX",
        "E3_BOTTOM_HEAD_RISE",
        "E4_BOTTOM_HEAD_FALL",
        "E5_DIRECTION_REVERSAL",
    ], "ROM-0 experiment-family drift")

    require(traj_schema["record_type"] == "ACCEPTED_REFERENCE_TRAJECTORY_POINT",
            "trajectory record type drift")
    require("committed_revision" in traj_schema["required_identity"], "committed revision missing")
    require(traj_schema["rejected_attempt_rule"].startswith("Rejected/candidate physical states are never encoded"),
            "accepted/rejected trajectory boundary drift")

    require(ross24["phase"] == "CLOSED", "F-ROSS24 authority not closed")
    agg = ross24["performance_screening"]["aggregate"]
    require(agg["outcome"] == "SCREENING_ROSSFAST_FASTER", "F-ROSS24 screening direction drift")
    require(abs(float(agg["rossfast_over_reference_cpu_ratio_mean"]) - 0.8228088245864688) < 1e-12,
            "F-ROSS24 solver ratio authority drift")
    require(agg["formal_performance_claim"] is False, "F-ROSS24 screening promoted to formal claim")


def validate_rom0_current() -> str:
    rom0 = load_json("integration/f-rom/F-ROM0_STATUS.json")
    if rom0["phase"] == "PREREGISTERED_IMPLEMENTATION_PENDING":
        require(rom0["required_reference_route"] == "CANONICAL_ACCEPTED_REFERENCE_RICHARDS_TRAJECTORY",
                "ROM-0 reference route drift")
        require(rom0["materials"] == ["B01", "B14"], "ROM-0 material pair drift")
        require(rom0["production_solver_authorized"] is False,
                "ROM-0 production solver unexpectedly authorized")
        return "PREREGISTERED_IMPLEMENTATION_PENDING"

    require(rom0["phase"] == "CLOSED_PROCEED_TO_ROM1A_UNDER_SUCCESSOR_RESEARCH_REFERENCE_AUTHORITY",
            "unexpected ROM-0 terminal phase")
    require(rom0["decision"] == "PROCEED_TO_ROM1A", "ROM-0 terminal decision drift")
    require(rom0["historical_fixed_control_decision"] == "NO_GO_REFERENCE_AUTHORITY",
            "historical ROM-0 no-go not retained")
    require(rom0["historical_decision_reclassified"] is False,
            "historical ROM-0 result was reclassified")
    require(rom0["rom1a_authorized"] is True, "ROM-1A not authorized by terminal ROM-0")
    require(rom0["production_solver_authorized"] is False,
            "ROM-0 terminal authority unexpectedly authorizes production solver")
    require(rom0["source_semantics"]["production_reference_fallback_admitted"] is False,
            "research Reference fallback promoted to production")

    closeout = load_json("integration/f-rom/F-ROM0_SUCCESSOR_CLOSEOUT.json")
    require(closeout["decision"] == "PROCEED_TO_ROM1A", "ROM-0 successor closeout decision drift")
    require(closeout["historical_fixed_control_closeout"]["reclassified"] is False,
            "historical fixed-control closeout reclassified")
    require(closeout["canonical_admission_scope"]["kind"] == "EVIDENCE_AND_RESEARCH_AUTHORITY_ONLY",
            "ROM-0 canonical closeout scope drift")
    require(closeout["canonical_admission_scope"]["src_changes"] == 0,
            "ROM-0 canonical closeout claims source mutation")
    require(closeout["canonical_admission_scope"]["reference_changes"] == 0,
            "ROM-0 canonical closeout claims reference mutation")
    require(closeout["production_reduced_solver_authorized"] is False,
            "ROM-0 successor closeout authorizes production ROM")
    return "CLOSED_PROCEED_TO_ROM1A"


def validate_rom1_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROM1_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    status = load_json(str(status_path))
    closeout = load_json("integration/f-rom/F-ROM1_CLOSEOUT.json")
    final_doc = Path("docs/science/F-ROM1_FINAL_STATE_SUFFICIENCY_RECONCILIATION.md").read_text(encoding="utf-8")

    require(status["phase"] == "CLOSED_MATERIAL_SPECIFIC_ONLY", "ROM-1 terminal phase drift")
    require(status["decision"] == "MATERIAL_SPECIFIC_ONLY", "ROM-1 terminal decision drift")
    require(status["B01"]["state_sufficiency_gate"] == "PASS_WITHIN_B01_SCOPE",
            "B01 material-specific state sufficiency missing")
    require(status["B14_transfer"]["material_transfer_admitted"] is False,
            "B14 transfer unexpectedly admitted")
    require(status["B14_transfer"]["cross_material_transition_gate_passed"] is False,
            "cross-material transition gate unexpectedly passed")
    require(status["ROM2"]["authorized"] is False, "ROM-2 unexpectedly authorized")
    require(status["production_rom_authorized"] is False, "production ROM unexpectedly authorized")

    require(closeout["decision"] == "MATERIAL_SPECIFIC_ONLY", "ROM-1 closeout decision drift")
    require(closeout["gate_adjudication"]["B14_cross_material_transfer"] == "FAIL_NOT_ADMITTED",
            "ROM-1 closeout B14 gate drift")
    require(closeout["gate_adjudication"]["ROM2_transition_under_current_proposition"] == "FAIL",
            "ROM-1 closeout ROM2 gate drift")
    require(closeout["scope"]["production_ROM"] == "NOT_AUTHORIZED",
            "ROM-1 closeout production scope drift")

    require("**Final decision: MATERIAL_SPECIFIC_ONLY.**" in final_doc,
            "final ROM-1 scientific adjudication missing")
    require("ROM-2 is **not authorized under the current F-ROM proposition**." in final_doc,
            "ROM-2 prohibition missing from final reconciliation")

    manifest_path = Path("integration/f-rom/F-ROM1_CANONICAL_EVIDENCE_MANIFEST.json")
    if manifest_path.exists():
        manifest = load_json(str(manifest_path))
        require(manifest["final_adjudication"]["decision"] == "MATERIAL_SPECIFIC_ONLY",
                "canonical evidence manifest decision drift")
        require(manifest["final_adjudication"]["ROM2_authorized"] is False,
                "canonical evidence manifest authorizes ROM-2")
        require(manifest["final_adjudication"]["production_ROM_authorized"] is False,
                "canonical evidence manifest authorizes production ROM")
        require(set(manifest["non_imported_surfaces"]) == {
            "src/**", "reference/**", "tests/**", ".github/workflows/**"
        }, "canonical evidence non-import boundary drift")

    return "CLOSED_MATERIAL_SPECIFIC_ONLY"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidate-head", required=True)
    ap.add_argument("--base-head", default=FOUNDATION_BASELINE)
    args = ap.parse_args()

    candidate = args.candidate_head
    base = args.base_head

    git("merge-base", "--is-ancestor", FOUNDATION_BASELINE, candidate)
    git("merge-base", "--is-ancestor", FOUNDATION_BASELINE, base)
    git("merge-base", "--is-ancestor", base, candidate)

    changed = [
        line for line in git("diff", "--name-only", f"{base}...{candidate}").splitlines()
        if line
    ]
    bad = [p for p in changed if not p.startswith(ALLOWED_PREFIXES)]
    require(not bad, f"out-of-scope F-ROM authority changes: {bad}")
    require(not [p for p in changed if p.startswith("src/") or p.startswith("reference/")],
            "production/reference mutation present")

    validate_foundation()
    rom0_phase = validate_rom0_current()
    rom1_phase = validate_rom1_if_present()

    print(f"F_ROM_FOUNDATION_BASELINE={FOUNDATION_BASELINE}")
    print(f"F_ROM_VALIDATION_BASE={base}")
    print(f"F_ROM_AUTHORITY_CANDIDATE={candidate}")
    print("F_ROM_PRODUCTION_REFERENCE_DELTA=NONE")
    print("F_ROM_EARLY_PILOT=SUPERSEDED")
    print("F_ROMP_DECISION=PROCEED_TO_ROM0")
    print(f"F_ROM0_PHASE={rom0_phase}")
    print(f"F_ROM1_PHASE={rom1_phase}")
    print("F_ROM_AUTHORITY_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
