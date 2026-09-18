#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASELINE=0e68a716f655f9bba3a0962cf35ccb724b5184c3
CONTRACT=integration/f-rom/F-ROM01_REFERENCE_HISTORY_PILOT_CONTRACT.json
TEST=tests/rom/test_f_rom01_reference_histories.f90
ANALYZER=tests/rom/analyze_f_rom01_reference_histories.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom01-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE_DIR="${F_ROM01_EVIDENCE_DIR:-$ROOT/F-ROM01_EVIDENCE}"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$EVIDENCE_DIR"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "F_ROM01_GATE_FAIL $*" >&2; exit 1; }

[[ -f "$CONTRACT" ]] || fail "missing pilot contract"
[[ -f "$TEST" ]] || fail "missing pilot test"
[[ -f "$ANALYZER" ]] || fail "missing pilot analyzer"

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_HEAD_REF:-}" ]]; then
  CANDIDATE_HEAD="$(git rev-parse "origin/$GITHUB_HEAD_REF")"
else
  CANDIDATE_HEAD="$(git rev-parse HEAD)"
fi
git merge-base --is-ancestor "$BASELINE" "$CANDIDATE_HEAD" || fail "canonical pilot baseline is not an ancestor of the workstream head"
git diff --quiet "$BASELINE...$CANDIDATE_HEAD" -- src reference || fail "F-ROM01 workstream mutated production/reference source"
echo "F_ROM01_CANDIDATE_HEAD=$CANDIDATE_HEAD"
echo "F_ROM01_PRODUCTION_REFERENCE_DELTA=NONE"

python3 - "$CONTRACT" "$BASELINE" "$TEST" <<'PY'
import json, pathlib, subprocess, sys
contract_path, baseline, test_path = sys.argv[1:]
c = json.loads(pathlib.Path(contract_path).read_text(encoding="utf-8"))
assert c["phase"] == "PREREGISTERED_BEFORE_REFERENCE_HISTORY_EXECUTION"
assert c["canonical_baseline"] == baseline
assert c["production_mutation_allowed"] is False
assert c["threshold_retuning_after_execution_allowed"] is False
assert c["research_fixture"]["material_id"] == "B01"
assert c["geometry"]["active_nodes"] == 16
assert c["geometry"]["root_zone_nodes"] == 4
assert c["histories"]["phase_steps"] == 48
assert c["continuation"]["steps"] == 24
assert c["continuation"]["observation_steps"] == [1, 8, 24]
for path, expected in c["source_locks"].items():
    base_blob = subprocess.check_output(["git", "rev-parse", f"{baseline}:{path}"], text=True).strip()
    head_blob = subprocess.check_output(["git", "rev-parse", f"HEAD:{path}"], text=True).strip()
    if base_blob != expected or head_blob != expected:
        raise SystemExit(f"source lock drift for {path}: base={base_blob} head={head_blob} expected={expected}")

src = pathlib.Path(test_path).read_text(encoding="utf-8")
fixture = c["research_fixture"]
required = [
    f"theta_r = {fixture['theta_r']}_real64",
    f"theta_s = {fixture['theta_s']}_real64",
    f"alpha_per_cm = {fixture['alpha_per_cm']}_real64",
    f"vg_n = {fixture['n']}_real64",
    f"ksatfit_cm_per_day = {fixture['ksatfit_cm_per_day']}_real64",
    f"lambda_mvg = {fixture['lambda']}_real64",
    "phase_steps = 48",
    "continuation_steps = 24",
    "dt_day = 0.0016_real64",
    "collision_storage_tol_cm = 1.0e-8_real64",