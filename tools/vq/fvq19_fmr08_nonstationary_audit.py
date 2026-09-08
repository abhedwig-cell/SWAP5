#!/usr/bin/env python3
from __future__ import annotations

from decimal import Decimal
from pathlib import Path
import re
import subprocess

CANDIDATE = "439432ad91d64353e70afda4ff0837f69521a9e5"
EXPECTED_TREE = "6fb99c994ab88435a3eaf675d6d9e945cc3a9d79"
FMR06_CANDIDATE = "ffab7d705928170db3e76a5d346caafeb560e605"
SMOKE = Path("tests/fmr/test_fmr06_snow_smoke.f90")
BACKEND = Path("src/runtime/mod_fmr_serialized_reference_backend.f90")


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def parameter(text: str, name: str) -> Decimal:
    number = r"[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"
    match = re.search(
        rf"real\(real64\),\s*parameter\s*::\s*{re.escape(name)}\s*=\s*({number})_real64",
        text,
        flags=re.IGNORECASE,
    )
    require(match is not None, f"missing real64 parameter {name}")
    return Decimal(match.group(1))


candidate_tree = git("rev-parse", f"{CANDIDATE}^{{tree}}")
require(candidate_tree == EXPECTED_TREE, f"candidate tree mismatch: {candidate_tree}")
require(git("merge-base", "--is-ancestor", FMR06_CANDIDATE, CANDIDATE) == "", "F-MR06 candidate is not ancestor")

changed = git("diff", "--name-status", f"{FMR06_CANDIDATE}..{CANDIDATE}").splitlines()
require(changed, "expected additive F-MR07/F-MR08 governance/runtime-view delta")
for line in changed:
    status = line.split("\t", 1)[0]
    require(status == "A", f"pre-existing F-MR06 candidate file changed or deleted: {line}")

expected_blobs = {
    "tests/fmr/test_fmr06_snow_smoke.f90": "4f45bb0623fef3fb6d091579e8f435563c858a69",
    "src/process/mod_snow_process.f90": "54702d71b4c84dce2842813549bd14c57301a383",
    "src/runtime/mod_fmr_serialized_reference_backend.f90": "202ab846cbd30d149d0d450249b3d517e333994f",
    "src/runtime/mod_fmr_serialized_multiswap_runtime.f90": "1bb0c6d4683db2729d48de31babcea72bc1a6caf",
}
for path, expected in expected_blobs.items():
    candidate_blob = git("rev-parse", f"{CANDIDATE}:{path}")
    fmr06_blob = git("rev-parse", f"{FMR06_CANDIDATE}:{path}")
    head_blob = git("hash-object", path)
    require(candidate_blob == expected, f"candidate blob mismatch for {path}: {candidate_blob}")
    require(fmr06_blob == expected, f"F-MR06 blob mismatch for {path}: {fmr06_blob}")
    require(head_blob == expected, f"F-VQ19 working-tree evidence blob mismatch for {path}: {head_blob}")

smoke = SMOKE.read_text()
backend = BACKEND.read_text()

t0 = parameter(smoke, "t0")
t1 = parameter(smoke, "t1")
initial_snow = parameter(smoke, "initial_snow")
snowfall = parameter(smoke, "snowfall")
hard_mass_gate = parameter(smoke, "hard_mass_gate")

require(t0 == Decimal("1400.25"), f"unexpected t0 {t0}")
require(t1 == Decimal("1401.25"), f"unexpected t1 {t1}")
require(t1 - t0 == Decimal("1.00"), "fixture is not one-call daily duration")
require(t0 != t0.to_integral_value(), "fixture start unexpectedly aligned to integer day")
require(initial_snow == Decimal("0.10"), f"unexpected initial snow {initial_snow}")
require(snowfall == Decimal("0.02"), f"unexpected snowfall {snowfall}")
require(snowfall > 0, "fixture is not nonstationary")
expected_committed = initial_snow + snowfall
require(expected_committed == Decimal("0.12"), f"unexpected derived committed snow {expected_committed}")
require(expected_committed != initial_snow, "persistent SNOW state does not change")
require(hard_mass_gate == Decimal("1.0e-12"), f"unexpected hard mass gate {hard_mass_gate}")

required_smoke_tokens = [
    "cfg%transaction%temporal_tolerance = 0.0_real64",
    "candidate_snow_state(candidate, initial_snow + snowfall, .true., t0)",
    "committed_snow_state(committed, initial_snow + snowfall, .true., t0)",
    "committed_fingerprint(committed) == committed_before",
    "result%mass%complete",
    "result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE",
    "abs(result%mass%residual) <= hard_mass_gate",
    "replay_fp == candidate_fp",
]
for token in required_smoke_tokens:
    require(token in smoke, f"missing locked fixture contract token: {token}")

lower_backend = backend.lower()
start = lower_backend.find("function fmr_serialized_temporal_identity(")
require(start >= 0, "missing fmr_serialized_temporal_identity definition")
end = lower_backend.find("end function fmr_serialized_temporal_identity", start)
require(end > start, "unterminated fmr_serialized_temporal_identity")
comparator = lower_backend[start:end]
require("real(real64)" in lower_backend[max(0, start - 32):start], "unexpected temporal comparator result type")
for field in ["snow_water_storage", "liquid_water_storage", "event_applied", "event_t0"]:
    require(field in comparator, f"active SNOW field absent from exact temporal comparator: {field}")
require("value = 0.0_real64" in comparator, "exact temporal comparator missing zero acceptance value")
require("value = huge(0.0_real64)" in comparator, "exact temporal comparator missing fail-closed mismatch value")

print("FVQ19_CANDIDATE_TREE_LOCK=PASS")
print("FVQ19_CURRENT_EVIDENCE_BLOB_LOCK=PASS")
print("FVQ19_PREEXISTING_FMR06_FILES_UNCHANGED=PASS")
print("FVQ19_NON_MIDNIGHT_ONE_CALL_DAILY_INTERVAL=PASS")
print(f"FVQ19_INITIAL_SNOW={initial_snow}")
print(f"FVQ19_DERIVED_COMMITTED_SNOW={expected_committed}")
print(f"FVQ19_DERIVED_SNOW_DELTA={snowfall}")
print("FVQ19_NONSTATIONARY_PERSISTENT_SNOW_STATE=PASS")
print("FVQ19_ZERO_TEMPORAL_TOLERANCE=PASS")
print("FVQ19_ACTIVE_SNOW_IN_EXACT_TEMPORAL_COMPARATOR=PASS")
print("FVQ19_EXACT_COMPARATOR_FAIL_CLOSED=PASS")
print("FVQ19_HARD_MASS_AND_TRANSACTION_CONTRACT=PASS")
print("FVQ19_INDEPENDENT_SOURCE_AUDIT PASS")
