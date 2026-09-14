#!/usr/bin/env python3
import json
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATUS = ROOT / "integration/f-rg/F-RG05_STATUS.json"
SNAPSHOT = ROOT / "integration/f-rg/F-RG05_DOMAIN_SNAPSHOT.json"
RECON = ROOT / "integration/f-rg/F-RG05_SCORE_RECONCILIATION.json"
EXECUTION = ROOT / "integration/f-rg/F-RG05_EXECUTION_WAVE.json"
INVARIANTS = ROOT / "integration/f-rg/F-RG05_ARCHITECTURE_INVARIANT_REVIEW.json"

BASE_SHA = "24b02660a7924323d1587b4adf77a160c9ef7d04"
FIXED_DENOMINATOR_SHA = "56b86e29e0960e396059caf47c193440d571b709"
EXPECTED_DOMAINS = {
    "D01": (8.0, 100.0), "D02": (7.0, 100.0), "D03": (8.0, 100.0),
    "D04": (5.0, 100.0), "D05": (6.0, 100.0), "D06": (5.0, 100.0),
    "D07": (5.0, 100.0), "D08": (3.0, 100.0), "D09": (5.0, 40.0),
    "D10": (4.0, 100.0), "D11": (4.0, 79.375), "D12": (4.0, 100.0),
    "D13": (10.0, 82.0), "D14": (5.0, 53.0), "D15": (7.0, 83.928571428571),
    "D16": (6.0, 51.666666666667), "D17": (5.0, 9.090909090909), "D18": (3.0, 85.0),
}
ALLOWED_DELTA = {
    ".github/workflows/frg05-current-canonical-program-rebaseline.yml",
    "docs/governance/F-RG05_CURRENT_CANONICAL_PROGRAM_REBASELINE.md",
    "integration/f-rg/F-RG05_ARCHITECTURE_INVARIANT_REVIEW.json",
    "integration/f-rg/F-RG05_DOMAIN_SNAPSHOT.json",
    "integration/f-rg/F-RG05_EXECUTION_WAVE.json",
    "integration/f-rg/F-RG05_SCORE_RECONCILIATION.json",
    "integration/f-rg/F-RG05_STATUS.json",
    "tools/governance/validate_frg05_program_rebaseline.py",
}

def load(path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)

def close(a, b, tol=1e-10):
    return math.isclose(float(a), float(b), rel_tol=0.0, abs_tol=tol)

status = load(STATUS)
snapshot = load(SNAPSHOT)
recon = load(RECON)
execution = load(EXECUTION)
invariants = load(INVARIANTS)

assert status["work_unit"] == "F-RG05"
assert status["current_canonical"]["sha"] == BASE_SHA
assert status["governance_authorities"]["F_RG01C"]["sha"] == FIXED_DENOMINATOR_SHA
assert status["frozen_denominator"]["unchanged"] is True
assert status["frozen_denominator"]["weights_changed"] is False
assert status["frozen_denominator"]["scope_changed"] is False
assert status["frozen_denominator"]["energy_balance_weight"] == 0.0
assert status["frozen_denominator"]["RossFast_weight"] == 0.0
assert status["score_result"]["changed_since_F_RG03"] is False

assert snapshot["canonical"]["sha"] == BASE_SHA
assert snapshot["fixed_denominator_authority"]["sha"] == FIXED_DENOMINATOR_SHA
assert snapshot["fixed_denominator_authority"]["unchanged"] is True

rows = {row["id"]: row for row in snapshot["domains"]}
assert set(rows) == set(EXPECTED_DOMAINS)
assert len(rows) == 18
for did, (weight, completion) in EXPECTED_DOMAINS.items():
    row = rows[did]
    assert close(row["weight"], weight)
    assert close(row["completion_percent"], completion)
    expected_earned = weight * completion / 100.0
    assert close(row["earned_weight"], expected_earned, 1e-9), (did, row["earned_weight"], expected_earned)

technical_ids = [f"D{i:02d}" for i in range(1, 15)]
technical_weight = sum(rows[d]["weight"] for d in technical_ids)
technical_earned = sum(rows[d]["earned_weight"] for d in technical_ids)
technical_pct = 100.0 * technical_earned / technical_weight
overall_weight = sum(row["weight"] for row in rows.values())
overall_earned = sum(row["earned_weight"] for row in rows.values())

assert close(technical_weight, 79.0)
assert close(technical_earned, 71.025, 1e-9)
assert close(technical_pct, 89.905063291139, 1e-9)
assert close(overall_weight, 100.0)
assert close(overall_earned, 83.004545454545, 1e-9)
assert close(snapshot["technical_engine"]["measured_percent"], technical_pct, 1e-9)
assert close(snapshot["technical_engine"]["reported_percent"], 89.0)
assert close(snapshot["overall"]["measured_percent"], overall_earned, 1e-9)
assert close(status["program_measurements"]["B_technical_engine_measured_percent"], technical_pct, 1e-9)
assert close(status["program_measurements"]["B_reported_percent"], 89.0)
assert close(status["program_measurements"]["C_overall_frozen_v1_percent"], overall_earned, 1e-9)

assert recon["result"]["changed_since_F_RG03"] is False
assert close(recon["result"]["technical_measured_percent"], technical_pct, 1e-9)
assert close(recon["result"]["overall_percent"], overall_earned, 1e-9)
assert all(float(item.get("score_delta", 0.0)) == 0.0 for item in recon["changes"])

assert invariants["all_30_checked"] is True
assert invariants["adverse_delta_introduced"] is False
inv_rows = invariants["results"]
assert len(inv_rows) == 30
assert {row["invariant"] for row in inv_rows} == set(range(1, 31))
assert all(row["status"] == "PASS_NO_ADVERSE_DELTA" for row in inv_rows)
assert all(value is False for value in invariants["hard_boundaries"].values())

lanes = {lane["lane"]: lane for lane in execution["lanes"]}
assert set(lanes) == {"L1_MACROPORE_PARENT_CLOSURE", "L2_BOUNDED_COST_AND_BATCH_ISOLATION", "L3_GROUNDWATER_G05_COMPOSITION", "L4_TESTBANK_DOCUMENTATION_STATUS_A"}
assert lanes["L1_MACROPORE_PARENT_CLOSURE"]["next_number_observed_free"] == "F-SI39"
assert lanes["L2_BOUNDED_COST_AND_BATCH_ISOLATION"]["recommended_workunit"] == "F-PE12"
assert lanes["L4_TESTBANK_DOCUMENTATION_STATUS_A"]["recommended_workunit"] == "F-DOC20"
assert all(track["track"] in {"RossFast", "Energy Balance"} for track in execution["isolated_zero_weight_tracks"])

subprocess.run(["git", "merge-base", "--is-ancestor", BASE_SHA, "HEAD"], cwd=ROOT, check=True)
changed = subprocess.check_output(["git", "diff", "--name-only", BASE_SHA, "HEAD"], cwd=ROOT, text=True).splitlines()
unexpected = sorted(set(changed) - ALLOWED_DELTA)
missing = sorted(ALLOWED_DELTA - set(changed))
assert not unexpected, f"Unexpected F-RG05 delta: {unexpected}"
assert not missing, f"Missing F-RG05 deliverables from delta: {missing}"
assert not any(p.startswith("src/") or p.startswith("reference/") for p in changed)

print("F-RG05 validation PASS")
print(f"technical_measured={technical_pct:.12f}")
print("technical_reported=89.000000000000")
print(f"overall={overall_earned:.12f}")
print("score_delta_from_F_RG03=0")
