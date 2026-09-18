#!/usr/bin/env python3
import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

EXPECTED_MANIFEST = "24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2"
EXPECTED_METEO = "99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f"

def require(cond, msg):
    if not cond:
        raise SystemExit(f"PPA_WU04_FAIL {msg}")

def text(path):
    return (ROOT / path).read_text()

def load(path):
    return json.loads(text(path))

def changed_src():
    subprocess.run(["git", "fetch", "origin", "integration/f-ci-canonical", "--quiet"], cwd=ROOT, check=True)
    base = subprocess.check_output(
        ["git", "merge-base", "HEAD", "origin/integration/f-ci-canonical"], cwd=ROOT, text=True
    ).strip()
    names = subprocess.check_output(
        ["git", "diff", "--name-only", base, "HEAD", "--", "src"], cwd=ROOT, text=True
    ).splitlines()
    return [n for n in names if n.strip()]

def authority_checks():
    manifest = text("reference/swap-4.3.1/b1-manifest.yml")
    snap = text("reference/swap-4.3.1/snapshots/B1.11.yml")
    sw6 = text("reference/swap-4.3.1/patches/SWAP-006/fix.patch")
    readiness = text("integration/f-pm/F-PM06_ET_MIGRATION_READINESS.md")
    legacy = load("integration/f-pm/F-PM06_LEGACY_VARIABLE_CLASSIFICATION.json")
    contract = load("integration/audits/PPA_WU04_STATEFUL_ET_INTERCEPTION_CONTRACT.json")

    require('snapshot: "B1.11"' in manifest, "B1.11 is not current reference snapshot")
    require(EXPECTED_MANIFEST in manifest, "B1.11 member manifest identity drift")
    require('ordered_preimage_snapshot: "B1.10"' in snap, "B1.11 predecessor not pinned to B1.10")
    for target in ("SWAP/MOD_MvG_functions.f90", "SWAP/WC_K_models_04_11.f90", "SWAP/MOD_RIA.f90"):
        require(target in snap, f"missing SWAP-011 target {target}")
    for forbidden in ("ETpot", "interception_daily", "reduceva", "VonHHBraden", "Gash", "Rutter"):
        require(forbidden not in sw6, f"SWAP-006 unexpectedly touches {forbidden}")
    require("@@ -260,13 +260,12 @@" in sw6, "SWAP-006 source window drift")

    require(re.search(r"SWINTER=1.{0,30}or.{0,20}2", readiness, re.DOTALL) is not None and
            "interception_daily" in readiness, "F-PM06 interception trace missing")
    require("persistent `ldwet`" in readiness.lower(), "F-PM06 LDWET authority missing")
    require("persistent `spev` and `saev`" in readiness.lower(), "F-PM06 SPEV/SAEV authority missing")
    require("before the SoilWater nonconvergence retry loop" in readiness, "legacy pre-retry hazard missing")
    require("must **not** copy this mutation pattern" in readiness, "target rollback rule missing")
    require("source-window aggregate" in readiness, "interception aggregate authority missing")

    minimal = legacy["persistent_state_minimality"]
    require(minimal["SWINTER_0_1_2"] == [], "SWINTER1/2 physical state must be empty")
    require(minimal["SWREDU_1"] == ["ldwet"], "SWREDU1 state drift")
    require(minimal["SWREDU_2"] == ["spev", "saev"], "SWREDU2 state drift")

    require(contract["authority"]["member_manifest_sha256"] == EXPECTED_MANIFEST, "contract manifest mismatch")
    require(contract["authority"]["relevant_b1_11_member_identities"]["SWAP/MOD_meteo.f90"] == EXPECTED_METEO,
            "contract meteo identity mismatch")
    require(contract["authority"]["b1_11_delta_from_b1_10"]["et_interception_reduction_semantics_changed"] is False,
            "contract incorrectly claims B1.11 ET semantic delta")
    require(contract["review_verdict"] == "SCIENTIFIC_TRANSACTION_AUTHORITY_FROZEN_IMPLEMENTATION_HELD",
            "review verdict drift")
    require(changed_src() == [], f"production source delta not allowed: {changed_src()}")

    print("PPA_WU04_B111_AUTHORITY_BINDING=PASS")
    print("PPA_WU04_FPM06_SOURCE_TRACE_RECONCILED=PASS")
    print("PPA_WU04_NO_PRODUCTION_SOURCE_DELTA=PASS")

def independent_checks():
    contract = load("integration/audits/PPA_WU04_STATEFUL_ET_INTERCEPTION_CONTRACT.json")
    doc = text("docs/audits/PPA_WU04_STATEFUL_ET_INTERCEPTION_SCIENTIFIC_REVIEW.md")
    options = contract["options"]

    for key in ("SWINTER_1", "SWINTER_2"):
        opt = options[key]
        require(opt["persistent_physical_state"] == [], f"{key} must have no physical storage state")
        require(opt["accepted_process_aggregate"] == ["aintc"], f"{key} aggregate authority drift")
        require(opt["restart"]["physical_process_state"] == "NONE", f"{key} restart state drift")
        require(opt["production_status"] == "NOT_IMPLEMENTED", f"{key} production overclaim")
        require("source_window_id/provenance" in opt["restart"]["required_runtime_continuation"],
                f"{key} missing source-window provenance")
    require("Independent Gash formula evaluation" in options["SWINTER_2"]["retry_rollback"]["forbidden"],
            "SWINTER2 nonlinear retry prohibition missing")

    require(options["SWREDU_1"]["persistent_physical_state"] == ["ldwet"], "SWREDU1 state mismatch")
    require(options["SWREDU_2"]["persistent_physical_state"] == ["spev", "saev"], "SWREDU2 state mismatch")
    require(options["SWREDU_2"]["restart"]["pair_is_atomic"] is True, "SWREDU2 restart pair not atomic")
    for key in ("SWREDU_1", "SWREDU_2"):
        opt = options[key]
        require(opt["restart"]["reconstruction_from_hydraulic_profile_allowed"] is False,
                f"{key} illegal state reconstruction")
        require(opt["mass"]["empreva_is_mass_sink"] is False, f"{key} demand incorrectly ledgered")
        require(opt["production_status"] == "NOT_IMPLEMENTED", f"{key} production overclaim")

    require(contract["invariants"]["rejected_trial_may_mutate_committed_et_state"] is False,
            "rejected trial mutation allowed")
    require(contract["invariants"]["retry_must_restart_from_same_committed_process_state"] is True,
            "retry checkpoint rule missing")
    require(len(contract["migration_slices"]) == 4, "migration slice count drift")
    require([x["id"] for x in contract["migration_slices"]] ==
            ["PPA-WU04-A","PPA-WU04-B","PPA-WU04-C","PPA-WU04-D"],
            "migration slice ordering drift")

    for phrase in (
        "SWINTER=1/2 have no physical process storage",
        "A rejected candidate can never become hidden history",
        "SPEV/SAEV",
        "source-window identity and bounds",
        "No production claim follows from this review",
    ):
        require(phrase in doc, f"narrative/contract mismatch: {phrase}")

    print("PPA_WU04_INTERCEPTION_AGGREGATE_OWNERSHIP=PASS")
    print("PPA_WU04_SWREDU_STATE_MINIMALITY=PASS")
    print("PPA_WU04_RESTART_ROLLBACK_CONTRACT=PASS")
    print("PPA_WU04_MASS_OWNER_SEPARATION=PASS")
    print("PPA_WU04_MIGRATION_SLICING=PASS")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=("authority","independent"), required=True)
    args = ap.parse_args()
    if args.mode == "authority":
        authority_checks()
    else:
        independent_checks()
    print(f"PPA_WU04_{args.mode.upper()}_REVIEW=PASS")

if __name__ == "__main__":
    main()
