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


def validate_romv2_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROMV2_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    predecessor_status = load_json("integration/f-rom/F-ROMV_STATUS.json")
    predecessor_result = load_json("integration/f-rom/F-ROMV_MDE_STAGE1_RESULT.json")
    status = load_json(str(status_path))
    acceptance = load_json("integration/f-rom/F-ROMV2_ACCEPTANCE_FRAMEWORK.json")
    proposition = Path("docs/science/F-ROMV2_PURPOSE_DEPENDENT_FIDELITY_PROPOSITION.md").read_text(encoding="utf-8")

    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV_STATUS.json")
            == "4ba4b9f59af4a2469e5734efc63519e9ae9432d7",
            "historical F-ROMV terminal status blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV_MDE_STAGE1_RESULT.json")
            == "340685ea0cfb782b7d5ecbcff8a64ee1991f7911",
            "historical F-ROMV Stage-1 result blob drift")
    require(predecessor_status["phase"] == "CLOSED_NO_GO_UNDER_CURRENT_PROPOSITION",
            "F-ROMV predecessor no longer terminal no-go")
    require(predecessor_result["decision"] == "STOP_SIMPLE_TEMPLATE_LOCAL_ROM",
            "F-ROMV Stage-1 negative result drift")

    require(status["phase"] == "PROPOSITION_OPEN", "F-ROMV2 proposition phase drift")
    require(status["predecessor"]["reclassified"] is False, "F-ROMV predecessor reclassified")
    require(status["numerical_equivalence_to_reference_required"] is False,
            "F-ROMV2 reduced-model equivalence rule drift")
    require(status["exploratory_post_terminal_evidence"]["local_table_C2"]
            == "FEASIBILITY_ONLY_NOT_CONFIRMATORY",
            "post-terminal exploratory evidence promoted to qualification")
    require(status["current_authority"]["production_rom_authorized"] is False,
            "F-ROMV2 production ROM unexpectedly authorized")
    require(status["current_authority"]["blind_validation_authorized"] is False,
            "F-ROMV2 blind validation unexpectedly authorized at proposition stage")

    require(acceptance["integrity_is_application_independent"] is True,
            "F-ROMV2 integrity rule drift")
    require(acceptance["threshold_policy"].startswith("No universal percentage tolerance"),
            "F-ROMV2 threshold policy drift")
    require(acceptance["stage_boundary"]["old_exposed_histories_may_be_blind_validation"] is False,
            "F-ROMV2 attempts to reuse exposed H01-H04 as blind validation")
    require(acceptance["stage_boundary"]["new_validation_must_be_generated_after_preregistration"] is True,
            "F-ROMV2 validation-order firewall drift")
    require("NOT A RECLASSIFICATION OF F-ROMV" in proposition,
            "F-ROMV2 historical-result firewall missing")
    require("computational-cost versus hydrological-fidelity frontier" in proposition,
            "F-ROMV2 cost-fidelity objective missing")

    return "PROPOSITION_OPEN"


def validate_romv2_v1_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROMV2_V1_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_V1_PREREGISTRATION.json")
            == "91069b15c64fafedbced5b5f1c02d24468490022",
            "F-ROMV2-V1 preregistration blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_V1_RESULT.json")
            == "db5939c7591b17f21a2b5a5291e4faa8041638c3",
            "F-ROMV2-V1 result summary blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_V1_STATUS.json")
            == "96774ca5abb9551923981ed37dbdb8d41af8e2d5",
            "F-ROMV2-V1 status blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_V1_CANONICAL_EVIDENCE_MANIFEST.json")
            == "cc242ac1b5aa4f8c67d54fedeb38a76c243b42d7",
            "F-ROMV2-V1 evidence manifest blob drift")

    prereg = load_json("integration/f-rom/F-ROMV2_V1_PREREGISTRATION.json")
    result = load_json("integration/f-rom/F-ROMV2_V1_RESULT.json")
    status = load_json("integration/f-rom/F-ROMV2_V1_STATUS.json")
    manifest = load_json("integration/f-rom/F-ROMV2_V1_CANONICAL_EVIDENCE_MANIFEST.json")
    doc = Path("docs/science/F-ROMV2_V1_BLIND_HYDRAULIC_ADJUDICATION.md").read_text(encoding="utf-8")

    require(prereg["phase"] == "PREREGISTERED_BEFORE_CURRENT_CANONICAL_TRAJECTORY_GENERATION",
            "F-ROMV2-V1 preregistration phase drift")
    require(prereg["frozen_state"]["id"] == "C2" and prereg["frozen_state"]["dimension"] == 2,
            "F-ROMV2-V1 frozen C2 identity drift")
    require(prereg["closure"]["family"] == "FORCING_SPECIFIC_ONE_NEAREST_NEIGHBOR_TRANSITION_TABLE",
            "F-ROMV2-V1 closure family drift")
    require(prereg["ood_gate"]["distance_threshold"] is False,
            "F-ROMV2-V1 distance threshold unexpectedly introduced")
    require(prereg["firewalls"][0] == "NO_H01_H04_BLIND_REUSE",
            "F-ROMV2-V1 exposed-history firewall drift")

    require(result["decision"] == "V2_V1_C2_BLIND_HYDRAULIC_FEASIBILITY_PASS",
            "F-ROMV2-V1 blind decision drift")
    require(result["adjudication"]
            == "BLIND_HYDRAULIC_FEASIBILITY_PASS_WITH_DOMAIN_COVERAGE_LIMITING_COMPUTATIONAL_VALUE",
            "F-ROMV2-V1 adjudication drift")
    require(result["integrity"]["pass"] is True, "F-ROMV2-V1 integrity gate drift")
    require(result["integrity"]["v04_failclosed"] is True, "F-ROMV2-V1 V04 fail-closed drift")
    require(result["blind_value_screen_V01_V03"]["C2_beats_shared_fallback_forcing_only_on_both_preregistered_balance_metrics"] is True,
            "F-ROMV2-V1 state-information value gate drift")
    require(abs(float(result["fallback_imposed_ideal_speedup_ceiling"]["pooled_V01_V03"]["ideal_upper_bound_speedup"]) - 1.6875) < 1e-12,
            "F-ROMV2-V1 fallback speed ceiling drift")
    require(result["production_rom_authorized"] is False,
            "F-ROMV2-V1 unexpectedly authorizes production ROM")

    require(status["phase"] == "CLOSED_BLIND_HYDRAULIC_FEASIBILITY_PASS_DOMAIN_COVERAGE_LIMITING",
            "F-ROMV2-V1 terminal phase drift")
    require(status["decision"] == "V2_V1_C2_BLIND_HYDRAULIC_FEASIBILITY_PASS",
            "F-ROMV2-V1 status decision drift")
    require(status["current_authority"]["production_rom_authorized"] is False,
            "F-ROMV2-V1 status authorizes production ROM")
    require(status["current_authority"]["performance_frontier_authorized"] is False,
            "F-ROMV2-V1 status prematurely authorizes performance frontier")
    require(status["current_authority"]["C2_ood_retuning_authorized"] is False,
            "F-ROMV2-V1 status authorizes post-blind OOD retuning")

    require(manifest["canonical_import_scope"] == "EVIDENCE_ONLY",
            "F-ROMV2-V1 import scope drift")
    require(manifest["source_execution"]["pull_request_merged"] is False,
            "F-ROMV2-V1 execution branch unexpectedly treated as canonical")
    require(manifest["production_source_changed"] is False
            and manifest["reference_source_changed"] is False,
            "F-ROMV2-V1 evidence import claims production/reference mutation")
    require(manifest["old_H01_H04_imported_as_blind_validation"] is False,
            "F-ROMV2-V1 reuses exposed H01-H04")
    require(manifest["predecessor_F_ROMV_reclassified"] is False,
            "F-ROMV2-V1 reclassifies terminal predecessor")
    require(manifest["production_rom_authorized"] is False,
            "F-ROMV2-V1 manifest authorizes production ROM")

    require("DOMAIN COVERAGE LIMITS CURRENT COMPUTATIONAL VALUE" in doc,
            "F-ROMV2-V1 domain-coverage adjudication missing")
    require("Production ROM remains unauthorized." in doc,
            "F-ROMV2-V1 production prohibition missing")

    return "CLOSED_BLIND_HYDRAULIC_FEASIBILITY_PASS_DOMAIN_COVERAGE_LIMITING"


def validate_romv2_d2_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROMV2_D2_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D2_PREREGISTRATION.json")
            == "e06f3a8d691c930befad8cc7a6d348a659f30ea2",
            "F-ROMV2-D2 preregistration blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D2_RESULT.json")
            == "702f2a875be96f1ebc9efccf77d9020e05761108",
            "F-ROMV2-D2 result summary blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D2_STATUS.json")
            == "8507a1821e8b26f6b159178bd82eb3fd65e90a97",
            "F-ROMV2-D2 status blob drift")

    prereg = load_json("integration/f-rom/F-ROMV2_D2_PREREGISTRATION.json")
    result = load_json("integration/f-rom/F-ROMV2_D2_RESULT.json")
    status = load_json("integration/f-rom/F-ROMV2_D2_STATUS.json")
    manifest = load_json("integration/f-rom/F-ROMV2_D2_CANONICAL_EVIDENCE_MANIFEST.json")
    doc = Path("docs/science/F-ROMV2_D2_COARSE_RICHARDS_ADJUDICATION.md").read_text(encoding="utf-8")

    require(prereg["phase"] == "PREREGISTERED_BEFORE_EXECUTION",
            "F-ROMV2-D2 preregistration phase drift")
    require(prereg["scientific_role"]["blind_confirmation"] is False,
            "F-ROMV2-D2 unexpectedly claims blind confirmation")
    require(prereg["decisions"]["no_application_thresholds"] is True,
            "F-ROMV2-D2 application threshold unexpectedly introduced")
    require("NO_C2_OOD_RETUNING" in prereg["firewalls"],
            "F-ROMV2-D2 C2 retuning firewall missing")

    require(result["decision"] == "COARSE_RICHARDS_REMAINS_SERIOUS_PHYSICAL_REDUCTION_CANDIDATE",
            "F-ROMV2-D2 decision drift")
    require(result["adjudication"]
            == "R8_BALANCE_REDUCTION_CANDIDATE_EVENT_FIDELITY_WEAK_R4_R2_NUMERICAL_AUTHORITY_NO_GO",
            "F-ROMV2-D2 adjudication drift")
    require(result["R8"]["status"] == "COMPLETE" and result["R8"]["integrity_pass"] is True,
            "F-ROMV2-D2 R8 completion/integrity drift")
    require(result["R4"]["status"] == "FROZEN_REFERENCE_POLICY_NO_GO"
            and result["R2"]["status"] == "FROZEN_REFERENCE_POLICY_NO_GO",
            "F-ROMV2-D2 R4/R2 numerical-authority classification drift")
    require(result["purpose_dependent_interpretation"]["long_term_regional_balance"]
            == "R8_REMAINS_PLAUSIBLE_NOT_QUALIFIED",
            "F-ROMV2-D2 balance interpretation drift")
    require(result["purpose_dependent_interpretation"]["fast_event_threshold"]
            == "R8_NOT_QUALIFIED_IN_D2",
            "F-ROMV2-D2 event interpretation drift")
    require(result["production_rom_authorized"] is False,
            "F-ROMV2-D2 unexpectedly authorizes production ROM")

    require(status["phase"] == "CLOSED_ARCHITECTURE_SCREEN_SPLIT_RESULT",
            "F-ROMV2-D2 status phase drift")
    require(status["retained_candidate"] == "R8",
            "F-ROMV2-D2 retained candidate drift")
    require(status["application_acceptance"] is False
            and status["performance_claim"] is False
            and status["production_rom_authorized"] is False,
            "F-ROMV2-D2 status overclaims authority")

    require(manifest["canonical_import_scope"] == "EVIDENCE_ONLY",
            "F-ROMV2-D2 import scope drift")
    require(manifest["source_execution"]["pull_request_merged"] is False,
            "F-ROMV2-D2 execution PR unexpectedly treated as canonical")
    require(manifest["production_source_changed"] is False
            and manifest["reference_source_changed"] is False,
            "F-ROMV2-D2 evidence import claims production/reference mutation")
    require(manifest["R4_R2_hydrological_invalidity_claimed"] is False,
            "F-ROMV2-D2 wrongly promotes numerical-policy failure to hydrological invalidity")
    require(manifest["production_rom_authorized"] is False,
            "F-ROMV2-D2 manifest authorizes production ROM")

    require("R4 and R2 are not hydrological no-go results" in doc,
            "F-ROMV2-D2 purpose-dependent R4/R2 distinction missing")
    require("Production ROM remains unauthorized." in doc,
            "F-ROMV2-D2 production prohibition missing")

    return "CLOSED_ARCHITECTURE_SCREEN_SPLIT_RESULT"


def validate_romv2_d3_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROMV2_D3_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D3_PREREGISTRATION.json")
            == "76b1e90c915ebca6c703bd4745922c7c30e7a3a8",
            "F-ROMV2-D3 preregistration blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D3_RESULT.json")
            == "d0450b802ff4a1db7884bf3efe06b0fa52447d0c",
            "F-ROMV2-D3 result blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D3_STATUS.json")
            == "7b2d730bbb7ad6c1ddc76b89e29bcb80f3a82035",
            "F-ROMV2-D3 status blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D3_CANONICAL_EVIDENCE_MANIFEST.json")
            == "f0a2758a9c076fb88c34d6dab6ed9d374784f695",
            "F-ROMV2-D3 evidence manifest blob drift")

    prereg = load_json("integration/f-rom/F-ROMV2_D3_PREREGISTRATION.json")
    result = load_json("integration/f-rom/F-ROMV2_D3_RESULT.json")
    status = load_json("integration/f-rom/F-ROMV2_D3_STATUS.json")
    manifest = load_json("integration/f-rom/F-ROMV2_D3_CANONICAL_EVIDENCE_MANIFEST.json")
    doc = Path("docs/science/F-ROMV2_D3_REPRESENTATION_POLICY_ADJUDICATION.md").read_text(encoding="utf-8")

    require(prereg["phase"] == "PREREGISTERED_BEFORE_EXECUTION",
            "F-ROMV2-D3 preregistration phase drift")
    require(prereg["reduced_model_numerical_policy"]["id"]
            == "STRICT_FIRST_PROSPECTIVE_REPRESENTATION_AWARE_REATTEMPT",
            "F-ROMV2-D3 frozen policy drift")
    require("NO_D2_RESIDUAL_FITTING" in prereg["firewalls"]
            and "NO_POST_RESULT_TOLERANCE_RETUNING" in prereg["firewalls"],
            "F-ROMV2-D3 anti-tuning firewall drift")

    require(result["decision"] == "REPRESENTATION_AWARE_PROSPECTIVE_POLICY_NO_GO",
            "F-ROMV2-D3 decision drift")
    require(result["adjudication"] == "NUMERICAL_POLICY_NO_GO_NOT_HYDROLOGICAL_INVALIDITY",
            "F-ROMV2-D3 adjudication drift")
    require(result["scientific_interpretation"]["hydrological_invalidity_established"] is False,
            "F-ROMV2-D3 incorrectly claims hydrological invalidity")
    require(result["scientific_interpretation"]["R8_D2_hydrological_evidence_reclassified"] is False,
            "F-ROMV2-D3 reclassifies D2 R8 evidence")
    require(all(v["status"] == "REPRESENTATION_AWARE_POLICY_NO_GO"
                for v in result["geometry_outcomes"].values()),
            "F-ROMV2-D3 geometry policy classification drift")
    require(result["production_rom_authorized"] is False,
            "F-ROMV2-D3 authorizes production ROM")

    require(status["phase"] == "CLOSED_NUMERICAL_POLICY_NO_GO",
            "F-ROMV2-D3 terminal phase drift")
    require(status["post_result_retuning_authorized"] is False,
            "F-ROMV2-D3 status permits post-result retuning")
    require(status["hydrological_invalidity_established"] is False,
            "F-ROMV2-D3 status claims hydrological invalidity")
    require(status["production_rom_authorized"] is False,
            "F-ROMV2-D3 status authorizes production ROM")

    require(manifest["canonical_import_scope"] == "EVIDENCE_ONLY",
            "F-ROMV2-D3 import scope drift")
    require(manifest["source_execution"]["pull_request_merged"] is False,
            "F-ROMV2-D3 execution PR unexpectedly treated as canonical")
    require(manifest["D3_threshold_retuned_after_result"] is False,
            "F-ROMV2-D3 threshold retuned after result")
    require(manifest["hydrological_invalidity_claimed"] is False,
            "F-ROMV2-D3 manifest claims hydrological invalidity")
    require(manifest["production_source_changed"] is False
            and manifest["reference_source_changed"] is False,
            "F-ROMV2-D3 evidence import claims production/reference mutation")

    require("falsifies the proposed **prospective representation-bound policy**" in doc,
            "F-ROMV2-D3 policy no-go adjudication missing")
    require("D3 does **not** establish that R16, R8, R4 or R2 are hydrologically invalid." in doc,
            "F-ROMV2-D3 hydrological nonclaim missing")
    require("Production ROM remains unauthorized." in doc,
            "F-ROMV2-D3 production prohibition missing")

    return "CLOSED_NUMERICAL_POLICY_NO_GO"


def validate_romv2_d4_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROMV2_D4_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D4_PREREGISTRATION.json")
            == "d47d62c11bc75edce78c28f749ac6e4575e87b17",
            "F-ROMV2-D4 preregistration blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D4_RESULT.json")
            == "898a0be774d495a58821573543335b766a6e90a6",
            "F-ROMV2-D4 result blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D4_STATUS.json")
            == "538d46694929f0cb3245c558307255780f07fc3d",
            "F-ROMV2-D4 status blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D4_CANONICAL_EVIDENCE_MANIFEST.json")
            == "574a6fa87524bcc59040ac00b7d14b9c622a2b6d",
            "F-ROMV2-D4 evidence manifest blob drift")

    prereg = load_json("integration/f-rom/F-ROMV2_D4_PREREGISTRATION.json")
    result = load_json("integration/f-rom/F-ROMV2_D4_RESULT.json")
    status = load_json("integration/f-rom/F-ROMV2_D4_STATUS.json")
    manifest = load_json("integration/f-rom/F-ROMV2_D4_CANONICAL_EVIDENCE_MANIFEST.json")
    doc = Path("docs/science/F-ROMV2_D4_INTEGRATED_MASS_COARSE_RICHARDS_ADJUDICATION.md").read_text(encoding="utf-8")

    require(prereg["phase"] == "PREREGISTERED_BEFORE_EXECUTION",
            "F-ROMV2-D4 preregistration phase drift")
    require(prereg["research_numerical_policy"]["id"]
            == "STRICT_FIRST_INTEGRATED_WATER_DEPTH_REATTEMPT",
            "F-ROMV2-D4 policy identity drift")
    require(prereg["research_numerical_policy"]["depth_budget"]["epsilon_depth_cm"] == 1e-12,
            "F-ROMV2-D4 integrated depth budget drift")
    require("NO_D2_OR_D3_RESIDUAL_MAGNITUDE_FITTING" in prereg["firewalls"]
            and "NO_POST_RESULT_POLICY_RETUNING" in prereg["firewalls"],
            "F-ROMV2-D4 anti-tuning firewall drift")

    require(result["decision"]
            == "STRONGLY_COARSE_RICHARDS_HYDROLOGICALLY_MEASURABLE_UNDER_INTEGRATED_MASS_POLICY",
            "F-ROMV2-D4 decision drift")
    require(result["adjudication"]
            == "R8_R4_R2_RETAINED_AS_BALANCE_FIDELITY_COST_FRONTIER_CANDIDATES_EVENT_FIDELITY_WEAK",
            "F-ROMV2-D4 adjudication drift")
    require(all(result["candidates"][g]["integrity_pass"] for g in ("R8","R4","R2")),
            "F-ROMV2-D4 coarse integrity drift")
    require(result["candidates"]["R8"]["bottom_flux_sign_error_count"] == 136
            and result["candidates"]["R4"]["bottom_flux_sign_error_count"] == 136
            and result["candidates"]["R2"]["bottom_flux_sign_error_count"] == 136,
            "F-ROMV2-D4 lower-boundary event evidence drift")
    require(result["purpose_dependent_interpretation"]["LONG_TERM_REGIONAL_WATER_BALANCE"]
            == "R8_R4_R2_REMAIN_CANDIDATES_NOT_QUALIFIED",
            "F-ROMV2-D4 balance interpretation drift")
    require(result["purpose_dependent_interpretation"]["FAST_EVENT_THRESHOLD"]
            == "NOT_QUALIFIED",
            "F-ROMV2-D4 event nonqualification drift")
    require(result["formal_performance_claim"] is False
            and result["production_rom_authorized"] is False,
            "F-ROMV2-D4 overclaims performance/production authority")

    require(status["phase"] == "CLOSED_STRONGLY_COARSE_HYDROLOGICALLY_MEASURABLE",
            "F-ROMV2-D4 status phase drift")
    require(status["retained_development_candidates"] == ["R8","R4","R2"],
            "F-ROMV2-D4 retained candidate set drift")
    require(status["coarse_richards_numerical_policy_escalation_closed"] is True,
            "F-ROMV2-D4 leaves numerical-policy escalation open")
    require(status["production_reference_policy_changed"] is False
            and status["production_rom_authorized"] is False,
            "F-ROMV2-D4 status mutates production authority")

    require(manifest["canonical_import_scope"] == "EVIDENCE_ONLY",
            "F-ROMV2-D4 import scope drift")
    require(manifest["source_execution"]["pull_request_merged"] is False,
            "F-ROMV2-D4 execution PR unexpectedly treated as canonical")
    require(manifest["production_source_changed"] is False
            and manifest["reference_source_changed"] is False
            and manifest["production_reference_policy_changed"] is False,
            "F-ROMV2-D4 evidence import claims production/reference mutation")
    require(manifest["post_result_policy_retuning"] is False,
            "F-ROMV2-D4 policy retuned after execution")

    require("D4 closes numerical-policy escalation for coarse Richards." in doc,
            "F-ROMV2-D4 coarse-policy closure missing")
    require("Production ROM remains unauthorized." in doc,
            "F-ROMV2-D4 production prohibition missing")

    return "CLOSED_STRONGLY_COARSE_HYDROLOGICALLY_MEASURABLE"


def validate_romv2_d5_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROMV2_D5_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D5_PREREGISTRATION.json")
            == "eab62b17b15b5fb414535b604e2e7c9b24f56300",
            "F-ROMV2-D5 preregistration blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D5_RESULT.json")
            == "e4322a3658dd549410088ca6dd6180f05dd9f535",
            "F-ROMV2-D5 result blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D5_STATUS.json")
            == "95f8ec285273cde751acec02ed19aac464552535",
            "F-ROMV2-D5 status blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D5_CANONICAL_EVIDENCE_MANIFEST.json")
            == "ce4ccd4353151ac9043eff3d609fd92f8233b403",
            "F-ROMV2-D5 evidence manifest blob drift")

    prereg = load_json("integration/f-rom/F-ROMV2_D5_PREREGISTRATION.json")
    result = load_json("integration/f-rom/F-ROMV2_D5_RESULT.json")
    status = load_json("integration/f-rom/F-ROMV2_D5_STATUS.json")
    manifest = load_json("integration/f-rom/F-ROMV2_D5_CANONICAL_EVIDENCE_MANIFEST.json")
    doc = Path("docs/science/F-ROMV2_D5_TWO_LAYER_PHYSICAL_REDUCTION_ADJUDICATION.md").read_text(encoding="utf-8")

    require(prereg["phase"] == "PREREGISTERED_BEFORE_EXECUTION",
            "F-ROMV2-D5 preregistration phase drift")
    require(prereg["candidate"]["id"] == "L2_IMC"
            and prereg["candidate"]["state_dimension"] == 2,
            "F-ROMV2-D5 candidate identity drift")
    require(prereg["candidate"]["training_required"] is False
            and prereg["candidate"]["fallback_to_Richards"] is False
            and prereg["candidate"]["clipping_allowed"] is False
            and prereg["candidate"]["adaptive_substepping_allowed"] is False,
            "F-ROMV2-D5 simplicity firewall drift")
    require("NO_POST_RESULT_EQUATION_RETUNING" in prereg["firewalls"],
            "F-ROMV2-D5 equation-retuning firewall missing")

    require(result["decision"] == "L2_IMC_NOT_COMPETITIVE_OR_NOT_ROBUST_IN_EXPOSED_B01_DOMAIN",
            "F-ROMV2-D5 decision drift")
    require(result["adjudication"]
            == "INTEGRITY_PASS_BUT_DOMINATED_BY_PREEXISTING_R2_ON_BALANCE_AND_TRANSIENT_DEVELOPMENT_VIEWS",
            "F-ROMV2-D5 adjudication drift")
    require(result["integrity"]["pass"] is True,
            "F-ROMV2-D5 integrity result drift")
    require(result["development_frontier"]["balance_view_pass"] is False
            and result["development_frontier"]["transient_view_pass"] is False
            and result["development_frontier"]["non_dominated_on_at_least_one_preregistered_view"] is False,
            "F-ROMV2-D5 comparative-frontier no-go drift")
    require(result["candidate"]["training_required"] is False
            and result["candidate"]["full_order_fallback_used"] is False
            and result["candidate"]["adaptive_substepping_used"] is False
            and result["candidate"]["clipping_used"] is False,
            "F-ROMV2-D5 execution simplicity drift")
    require(result["application_acceptance"] is False
            and result["formal_performance_claim"] is False
            and result["production_rom_authorized"] is False,
            "F-ROMV2-D5 overclaims authority")

    require(status["phase"] == "CLOSED_PHYSICAL_REDUCTION_ARCHITECTURE_NO_GO",
            "F-ROMV2-D5 terminal phase drift")
    require(status["comparative_frontier_retained"] is False,
            "F-ROMV2-D5 status incorrectly retains candidate")
    require(status["post_result_equation_retuning_authorized"] is False,
            "F-ROMV2-D5 status permits equation retuning")
    require(status["production_rom_authorized"] is False,
            "F-ROMV2-D5 status authorizes production ROM")

    require(manifest["canonical_import_scope"] == "EVIDENCE_ONLY",
            "F-ROMV2-D5 import scope drift")
    require(manifest["source_execution"]["pull_request_merged"] is False,
            "F-ROMV2-D5 execution PR unexpectedly treated as canonical")
    require(manifest["production_source_changed"] is False
            and manifest["reference_source_changed"] is False
            and manifest["post_result_equation_retuning"] is False,
            "F-ROMV2-D5 evidence manifest mutation/retuning drift")
    require(manifest["production_rom_authorized"] is False,
            "F-ROMV2-D5 manifest authorizes production ROM")

    require("Almost the entire total-storage error therefore arises in the lower 80 cm." in doc,
            "F-ROMV2-D5 lower-zone diagnosis missing")
    require("Production ROM remains unauthorized." in doc,
            "F-ROMV2-D5 production prohibition missing")

    return "CLOSED_PHYSICAL_REDUCTION_ARCHITECTURE_NO_GO"


def validate_romv2_d6_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROMV2_D6_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D6_PREREGISTRATION.json")
            == "5defbcfaae3b9cdb49a9ef0bb21d3cf91f7447dc",
            "F-ROMV2-D6 preregistration blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D6_RESULT.json")
            == "17bda19419aff94a3b01c06f34a1ac3a2e9d5cef",
            "F-ROMV2-D6 result blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D6_STATUS.json")
            == "e2fefa30fe544fa80eeda81557977de70e222932",
            "F-ROMV2-D6 status blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D6_CANONICAL_EVIDENCE_MANIFEST.json")
            == "b6c7e8d708b0f76979e2d214e0be8d30315b2461",
            "F-ROMV2-D6 evidence manifest blob drift")

    prereg = load_json("integration/f-rom/F-ROMV2_D6_PREREGISTRATION.json")
    result = load_json("integration/f-rom/F-ROMV2_D6_RESULT.json")
    status = load_json("integration/f-rom/F-ROMV2_D6_STATUS.json")
    manifest = load_json("integration/f-rom/F-ROMV2_D6_CANONICAL_EVIDENCE_MANIFEST.json")
    doc = Path("docs/science/F-ROMV2_D6_MANIFOLD_PREFLIGHT_ADJUDICATION.md").read_text(encoding="utf-8")

    require(prereg["phase"] == "PREREGISTERED_BEFORE_EXECUTION",
            "F-ROMV2-D6 preregistration phase drift")
    require(prereg["candidate"]["id"] == "QS1"
            and prereg["candidate"]["dynamic_state_dimension"] == 1,
            "F-ROMV2-D6 candidate identity drift")
    require(prereg["manifold_evaluation"]["prescribed_bottom_head"]["q_bracket_cm_per_day"]
            == "[-Ksat,+Ksat]",
            "F-ROMV2-D6 fixed q bracket drift")
    require(prereg["manifold_evaluation"]["root_requirement"].startswith("bracket endpoints must be finite"),
            "F-ROMV2-D6 finite endpoint contract drift")
    require("NO_POST_RESULT_BRACKET_WIDENING" in prereg["firewalls"],
            "F-ROMV2-D6 bracket anti-tuning firewall missing")

    require(result["decision"] == "D6_FIXED_ENDPOINT_BRACKET_NO_GO_BEFORE_TRAJECTORY_EXPOSURE",
            "F-ROMV2-D6 decision drift")
    require(result["adjudication"] == "ROOT_SEARCH_DESIGN_NO_GO_NOT_MANIFOLD_HYDROLOGY_NO_GO",
            "F-ROMV2-D6 adjudication drift")
    require(result["trajectory_evidence_consumed"] is False,
            "F-ROMV2-D6 unexpectedly consumed trajectory evidence")
    require(result["endpoint_finite_contract_pass"] is False
            and result["opposite_residual_sign_contract_pass"] is False,
            "F-ROMV2-D6 endpoint failure evidence drift")
    require(result["endpoint_evidence"]["equilibrium_q_control"]["finite"] is True,
            "F-ROMV2-D6 equilibrium control drift")
    require(result["post_result_bracket_widening_or_narrowing_authorized"] is False,
            "F-ROMV2-D6 permits post-result bracket retuning")
    require(result["application_acceptance"] is False
            and result["formal_performance_claim"] is False
            and result["production_rom_authorized"] is False,
            "F-ROMV2-D6 overclaims authority")

    require(status["phase"] == "CLOSED_PREFLIGHT_ROOT_SEARCH_DESIGN_NO_GO",
            "F-ROMV2-D6 terminal phase drift")
    require(status["trajectory_evidence_consumed"] is False
            and status["manifold_hydrology_adjudicated"] is False,
            "F-ROMV2-D6 status overstates hydrological evidence")
    require(status["bracket_retuning_authorized"] is False,
            "F-ROMV2-D6 status permits bracket retuning")
    require(status["production_rom_authorized"] is False,
            "F-ROMV2-D6 status authorizes production ROM")

    require(manifest["canonical_import_scope"] == "EVIDENCE_ONLY",
            "F-ROMV2-D6 import scope drift")
    require(manifest["source_execution"]["pull_request_merged"] is False,
            "F-ROMV2-D6 execution PR unexpectedly treated as canonical")
    require(manifest["trajectory_evidence_consumed"] is False,
            "F-ROMV2-D6 manifest claims trajectory consumption")
    require(manifest["production_source_changed"] is False
            and manifest["reference_source_changed"] is False
            and manifest["post_result_bracket_retuning"] is False,
            "F-ROMV2-D6 mutation/retuning drift")
    require(manifest["production_rom_authorized"] is False,
            "F-ROMV2-D6 manifest authorizes production ROM")

    require("root-search-design no-go" in doc,
            "F-ROMV2-D6 root-search adjudication missing")
    require("No dynamic forcing sequence was evaluated" in doc,
            "F-ROMV2-D6 no-trajectory boundary missing")
    require("Production ROM remains unauthorized." in doc,
            "F-ROMV2-D6 production prohibition missing")

    return "CLOSED_PREFLIGHT_ROOT_SEARCH_DESIGN_NO_GO"


def validate_romv2_d7_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROMV2_D7_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D7_PREREGISTRATION.json")
            == "b5338c41c74272c674b3bdd171fc867cd651491b",
            "F-ROMV2-D7 preregistration blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D7_RESULT.json")
            == "a9c5f5085797e111d2f7dc1d2375635e12e7e75c",
            "F-ROMV2-D7 result blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D7_STATUS.json")
            == "8526bda418d04dadbc35de7755db54152f5cdeff",
            "F-ROMV2-D7 status blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D7_CANONICAL_EVIDENCE_MANIFEST.json")
            == "dde8651b2f1e8c7216167582682e2ba369eb3da9",
            "F-ROMV2-D7 evidence manifest blob drift")

    prereg = load_json("integration/f-rom/F-ROMV2_D7_PREREGISTRATION.json")
    result = load_json("integration/f-rom/F-ROMV2_D7_RESULT.json")
    status = load_json("integration/f-rom/F-ROMV2_D7_STATUS.json")
    manifest = load_json("integration/f-rom/F-ROMV2_D7_CANONICAL_EVIDENCE_MANIFEST.json")
    doc = Path("docs/science/F-ROMV2_D7_QS1_ADJUDICATION.md").read_text(encoding="utf-8")

    require(prereg["phase"] == "PREREGISTERED_BEFORE_PREFLIGHT",
            "F-ROMV2-D7 preregistration phase drift")
    require(prereg["candidate"]["id"] == "QS1"
            and prereg["candidate"]["dynamic_state_dimension"] == 1,
            "F-ROMV2-D7 candidate identity drift")
    require(prereg["predecessor"]["D6_trajectory_evidence_consumed"] is False
            and prereg["predecessor"]["D6_manifold_hydrology_adjudicated"] is False,
            "F-ROMV2-D7 D6 boundary drift")
    require(prereg["root_search"]["no_D6_residual_or_endpoint_magnitude_used_to_set_new_limits"] is True,
            "F-ROMV2-D7 search anti-tuning drift")
    require("NO_POST_RESULT_EQUATION_RETUNING" in prereg["firewalls"],
            "F-ROMV2-D7 equation-retuning firewall missing")

    require(result["decision"] == "QS1_NOT_WORTH_TABULATING_IN_EXPOSED_B01_DOMAIN",
            "F-ROMV2-D7 decision drift")
    require(result["adjudication"] == "ONE_STATE_QUASI_STEADY_MANIFOLD_INTEGRITY_PASS_BUT_DOMINATED_BY_R2",
            "F-ROMV2-D7 adjudication drift")
    require(result["preflight"]["decision"] == "D7_ADMISSIBLE_ROOT_SEARCH_PREFLIGHT_PASS",
            "F-ROMV2-D7 preflight result drift")
    require(result["integrity"]["pass"] is True,
            "F-ROMV2-D7 integrity drift")
    require(result["comparative_interpretation"]["QS1_improves_over_R2_balance"] is False
            and result["comparative_interpretation"]["QS1_improves_over_R2_transient"] is False
            and result["comparative_interpretation"]["retained"] is False,
            "F-ROMV2-D7 comparative frontier drift")
    require(result["physical_diagnosis"]["implication"].startswith("The next distinct reduction requires explicit dynamic profile memory"),
            "F-ROMV2-D7 dynamic-memory diagnosis drift")
    require(result["application_acceptance"] is False
            and result["formal_performance_claim"] is False
            and result["production_rom_authorized"] is False,
            "F-ROMV2-D7 overclaims authority")

    require(status["phase"] == "CLOSED_ONE_STATE_QUASI_STEADY_MANIFOLD_NO_GO",
            "F-ROMV2-D7 terminal phase drift")
    require(status["QS1_tabulation_authorized"] is False
            and status["post_result_root_retuning_authorized"] is False
            and status["post_result_equation_retuning_authorized"] is False,
            "F-ROMV2-D7 status permits post-result escalation")
    require(status["production_rom_authorized"] is False,
            "F-ROMV2-D7 status authorizes production ROM")

    require(manifest["canonical_import_scope"] == "EVIDENCE_ONLY",
            "F-ROMV2-D7 import scope drift")
    require(manifest["source_execution"]["pull_request_merged"] is False,
            "F-ROMV2-D7 execution PR unexpectedly treated as canonical")
    require(manifest["source_execution"]["primary_implementation"] == "PURE_PYTHON_RK4",
            "F-ROMV2-D7 primary implementation provenance drift")
    require(manifest["production_source_changed"] is False
            and manifest["reference_source_changed"] is False
            and manifest["post_result_QS1_retuning"] is False,
            "F-ROMV2-D7 evidence mutation/retuning drift")
    require(manifest["production_rom_authorized"] is False,
            "F-ROMV2-D7 manifest authorizes production ROM")

    require("D7 closes the **one-state quasi-steady manifold**." in doc,
            "F-ROMV2-D7 architecture closure missing")
    require("dynamic profile memory" in doc,
            "F-ROMV2-D7 dynamic-memory consequence missing")
    require("Production ROM remains unauthorized." in doc,
            "F-ROMV2-D7 production prohibition missing")

    return "CLOSED_ONE_STATE_QUASI_STEADY_MANIFOLD_NO_GO"


def validate_romv2_d8_if_present() -> str:
    status_path = Path("integration/f-rom/F-ROMV2_D8_STATUS.json")
    if not status_path.exists():
        return "NOT_PRESENT"

    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D8_PREREGISTRATION.json")
            == "72f683bec3fb8c2ddfe57f793db0a58b5c13ccc8",
            "F-ROMV2-D8 preregistration blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D8_RESULT.json")
            == "76659c70c3369e7a0381a1ffdb1ba21aee600089",
            "F-ROMV2-D8 result blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D8_STATUS.json")
            == "020c4d5c2c8419948675a1fcb325891f2cfc0a62",
            "F-ROMV2-D8 status blob drift")
    require(git("rev-parse", "HEAD:integration/f-rom/F-ROMV2_D8_CANONICAL_EVIDENCE_MANIFEST.json")
            == "0103d18c04853a85c312e2e220efa59dcb7b2688",
            "F-ROMV2-D8 evidence manifest blob drift")

    prereg = load_json("integration/f-rom/F-ROMV2_D8_PREREGISTRATION.json")
    result = load_json("integration/f-rom/F-ROMV2_D8_RESULT.json")
    status = load_json("integration/f-rom/F-ROMV2_D8_STATUS.json")
    manifest = load_json("integration/f-rom/F-ROMV2_D8_CANONICAL_EVIDENCE_MANIFEST.json")
    doc = Path("docs/science/F-ROMV2_D8_QS2_COMPOSITE_ADJUDICATION.md").read_text(encoding="utf-8")

    require(prereg["phase"] == "PREREGISTERED_BEFORE_PREFLIGHT",
            "F-ROMV2-D8 preregistration phase drift")
    require(prereg["candidate"]["id"] == "QS2_COMPOSITE"
            and prereg["candidate"]["dynamic_state_dimension"] == 2,
            "F-ROMV2-D8 candidate identity drift")
    require(prereg["candidate"]["training_required"] is False
            and prereg["candidate"]["full_order_fallback"] is False
            and prereg["candidate"]["clipping_allowed"] is False
            and prereg["candidate"]["adaptive_dynamic_substepping"] is False,
            "F-ROMV2-D8 candidate firewall drift")
    require(prereg["segment_profile_equations"]["RK4_subintervals_per_80cm_segment"] == 512,
            "F-ROMV2-D8 frozen segment integration drift")
    require("NO_POST_RESULT_EQUATION_RETUNING" in prereg["firewalls"],
            "F-ROMV2-D8 equation-retuning firewall missing")

    require(result["decision"] == "QS2_COMPOSITE_NOT_COMPETITIVE_OR_NOT_ROBUST_IN_EXPOSED_B01_DOMAIN",
            "F-ROMV2-D8 decision drift")
    require(result["adjudication"]
            == "DYNAMIC_TWO_SEGMENT_COMPOSITE_IMPROVES_QS1_BUT_REMAINS_DOMINATED_BY_R2",
            "F-ROMV2-D8 adjudication drift")
    require(result["preflight"]["decision"] == "D8_QS2_COMPOSITE_PREFLIGHT_PASS"
            and result["preflight"]["all_synthetic_cases_pass"] is True,
            "F-ROMV2-D8 preflight evidence drift")
    require(result["integrity"]["pass"] is True,
            "F-ROMV2-D8 integrity drift")
    require(result["comparative_interpretation"]["QS2_improves_over_QS1_balance"] is True
            and result["comparative_interpretation"]["QS2_improves_over_D5_balance"] is True,
            "F-ROMV2-D8 predecessor-improvement evidence drift")
    require(result["comparative_interpretation"]["QS2_improves_over_R2_balance"] is False
            and result["comparative_interpretation"]["QS2_improves_over_R2_transient"] is False
            and result["comparative_interpretation"]["retained"] is False,
            "F-ROMV2-D8 R2 frontier decision drift")
    require(result["application_acceptance"] is False
            and result["formal_performance_claim"] is False
            and result["production_rom_authorized"] is False,
            "F-ROMV2-D8 overclaims authority")

    require(status["phase"] == "CLOSED_TWO_SEGMENT_COMPOSITE_MANIFOLD_NO_GO",
            "F-ROMV2-D8 terminal phase drift")
    require(status["tabulation_authorized"] is False
            and status["post_result_search_retuning_authorized"] is False
            and status["post_result_equation_retuning_authorized"] is False
            and status["post_result_segmentation_retuning_authorized"] is False,
            "F-ROMV2-D8 status permits post-result escalation")
    require(status["production_rom_authorized"] is False,
            "F-ROMV2-D8 status authorizes production ROM")

    require(manifest["canonical_import_scope"] == "EVIDENCE_ONLY",
            "F-ROMV2-D8 import scope drift")
    require(manifest["source_execution"]["pull_request_merged"] is False,
            "F-ROMV2-D8 execution PR unexpectedly treated as canonical")
    require(manifest["production_source_changed"] is False
            and manifest["reference_source_changed"] is False
            and manifest["post_result_search_retuning"] is False
            and manifest["post_result_equation_retuning"] is False
            and manifest["post_result_segmentation_retuning"] is False,
            "F-ROMV2-D8 evidence mutation/retuning drift")
    require(manifest["production_rom_authorized"] is False,
            "F-ROMV2-D8 manifest authorizes production ROM")

    require("The sequence D5 → D7 → D8 shows monotonic improvement" in doc,
            "F-ROMV2-D8 monotonic architecture evidence missing")
    require("Further segmentation is plausible but should not be invented" in doc,
            "F-ROMV2-D8 literature-reconciliation boundary missing")
    require("Production ROM remains unauthorized." in doc,
            "F-ROMV2-D8 production prohibition missing")

    return "CLOSED_TWO_SEGMENT_COMPOSITE_MANIFOLD_NO_GO"


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
    romv2_phase = validate_romv2_if_present()
    romv2_v1_phase = validate_romv2_v1_if_present()
    romv2_d2_phase = validate_romv2_d2_if_present()
    romv2_d3_phase = validate_romv2_d3_if_present()
    romv2_d4_phase = validate_romv2_d4_if_present()
    romv2_d5_phase = validate_romv2_d5_if_present()
    romv2_d6_phase = validate_romv2_d6_if_present()
    romv2_d7_phase = validate_romv2_d7_if_present()
    romv2_d8_phase = validate_romv2_d8_if_present()

    print(f"F_ROM_FOUNDATION_BASELINE={FOUNDATION_BASELINE}")
    print(f"F_ROM_VALIDATION_BASE={base}")
    print(f"F_ROM_AUTHORITY_CANDIDATE={candidate}")
    print("F_ROM_PRODUCTION_REFERENCE_DELTA=NONE")
    print("F_ROM_EARLY_PILOT=SUPERSEDED")
    print("F_ROMP_DECISION=PROCEED_TO_ROM0")
    print(f"F_ROM0_PHASE={rom0_phase}")
    print(f"F_ROM1_PHASE={rom1_phase}")
    print(f"F_ROMV2_PHASE={romv2_phase}")
    print(f"F_ROMV2_V1_PHASE={romv2_v1_phase}")
    print(f"F_ROMV2_D2_PHASE={romv2_d2_phase}")
    print(f"F_ROMV2_D3_PHASE={romv2_d3_phase}")
    print(f"F_ROMV2_D4_PHASE={romv2_d4_phase}")
    print(f"F_ROMV2_D5_PHASE={romv2_d5_phase}")
    print(f"F_ROMV2_D6_PHASE={romv2_d6_phase}")
    print(f"F_ROMV2_D7_PHASE={romv2_d7_phase}")
    print(f"F_ROMV2_D8_PHASE={romv2_d8_phase}")
    print("F_ROM_AUTHORITY_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
