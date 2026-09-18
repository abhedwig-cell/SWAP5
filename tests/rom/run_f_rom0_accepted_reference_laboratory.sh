#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=47430b68ed46a24ca05b29b46de2dd4f7e29762b
TEST=tests/rom/test_f_rom0_accepted_reference_laboratory.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
ANALYZER=tests/rom/analyze_f_rom0_accepted_reference_laboratory.py
PREREG=integration/f-rom/F-ROM0_PREREGISTRATION.json
SUPPLEMENT=integration/f-rom/F-ROM0_NUMERICAL_CONTROLS_SUPPLEMENT.json
PROBE_CORRECTION=integration/f-rom/F-ROM0_BOUNDARY_PROBE_PREFLIGHT_CORRECTION.json
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom0-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0_EVIDENCE_DIR:-$ROOT/F-ROM0_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE/cases"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_ROM0_GATE_FAIL $*" >&2; exit 1; }

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_HEAD_REF:-}" ]]; then
  CANDIDATE="$(git rev-parse "origin/$GITHUB_HEAD_REF")"
else
  CANDIDATE="$(git rev-parse HEAD)"
fi

git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail "ROM-0 base is not ancestor"
git diff --quiet "$BASE...$CANDIDATE" -- src reference || fail "ROM-0 branch mutated src/reference"
echo "F_ROM0_PRODUCTION_REFERENCE_DELTA=NONE"

python3 - "$PREREG" "$SUPPLEMENT" "$PROBE_CORRECTION" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
s=json.load(open(sys.argv[2]))
c=json.load(open(sys.argv[3]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert [x["id"] for x in p["materials"]]==["B01","B14"]
assert p["observation_interval_day"]["base"]==0.0016
assert p["observation_interval_day"]["refined"]==0.0008
assert p["threshold_retuning_after_execution_allowed"] is False
assert s["phase"]=="FROZEN_BEFORE_FIRST_EXECUTION"
assert s["transaction"]["temporal_mode"]=="TX_TEMPORAL_EXTERNAL_FULL_HALF"
assert s["transaction"]["temporal_tolerance"]==1e-6
assert s["transaction"]["max_retries"]==8
assert s["transaction"]["retry_scale"]==0.5
assert s["transaction"]["mass_tolerance_cm"]==1e-12
assert s["canonical"]["max_committed_substeps"]==128
assert s["tuning_after_execution_allowed"] is False
assert c["phase"]=="FROZEN_BEFORE_FIRST_EXECUTION"
assert c["execution_evidence_seen_before_correction"] is False
assert c["corrected_probe"]["rise"]=="hbot = h0 + 2 * dz_cm"
assert c["corrected_probe"]["fall"]=="hbot = h0 - 2 * dz_cm"
assert c["post_execution_retuning_allowed"] is False
print("F_ROM0_PREREGISTRATION_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/rom0_stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/rom0_stubs_n32.f90" --nodes 32 --dz-cm 5

python3 "$COMPILER" \
  --root "$ROOT" \
  --stub "$BUILD/rom0_stubs_n16.f90" \
  --target "$TEST" \
  --build "$BUILD/o2_n16" \
  --opt 2
python3 "$COMPILER" \
  --root "$ROOT" \
  --stub "$BUILD/rom0_stubs_n32.f90" \
  --target "$TEST" \
  --build "$BUILD/o2_n32" \
  --opt 2

EXE16="$BUILD/o2_n16/rom0_test"
EXE32="$BUILD/o2_n32/rom0_test"
[[ -x "$EXE16" && -x "$EXE32" ]] || fail "missing geometry-bound ROM-0 executable"

cases=(
  'B01|16|10|0.0016|E0_HOLD'
  'B01|16|10|0.0016|E1_NOMINAL_FLUX'
  'B01|16|10|0.0016|E2_DRYING_FLUX'
  'B01|16|10|0.0016|E3_BOTTOM_HEAD_RISE'
  'B01|16|10|0.0016|E4_BOTTOM_HEAD_FALL'
  'B01|16|10|0.0016|E5_DIRECTION_REVERSAL'
  'B14|16|10|0.0016|E0_HOLD'
  'B14|16|10|0.0016|E1_NOMINAL_FLUX'
  'B14|16|10|0.0016|E2_DRYING_FLUX'
  'B14|16|10|0.0016|E3_BOTTOM_HEAD_RISE'
  'B14|16|10|0.0016|E4_BOTTOM_HEAD_FALL'
  'B14|16|10|0.0016|E5_DIRECTION_REVERSAL'
  'B01|16|10|0.0008|E1_NOMINAL_FLUX'
  'B01|16|10|0.0008|E2_DRYING_FLUX'
  'B14|16|10|0.0008|E1_NOMINAL_FLUX'
  'B14|16|10|0.0008|E2_DRYING_FLUX'
  'B01|32|5|0.0016|E1_NOMINAL_FLUX'
  'B14|32|5|0.0016|E2_DRYING_FLUX'
)

failures=0
for spec in "${cases[@]}"; do
  IFS='|' read -r material nodes dz dt experiment <<<"$spec"
  tag="${material}_${experiment}_n${nodes}_dz${dz}_dt${dt}"
  out="$EVIDENCE/cases/${tag}.txt"
  echo "F_ROM0_RUN_CASE=$tag"
  if [[ "$nodes" == "16" ]]; then
    exe="$EXE16"
  elif [[ "$nodes" == "32" ]]; then
    exe="$EXE32"
  else
    fail "unregistered geometry nodes=$nodes"
  fi
  if ! "$exe" "$material" "$nodes" "$dz" "$dt" "$experiment" >"$out" 2>&1; then
    cat "$out" >&2
    failures=$((failures+1))
  else
    grep -Fq 'F_ROM0_CASE_PASS|' "$out" || { cat "$out" >&2; failures=$((failures+1)); }
  fi
done

"$EXE16" B01 16 10 0.0016 E1_NOMINAL_FLUX >"$BUILD/replay.txt" 2>&1 || fail "reproducibility replay runtime"
cmp -s "$EVIDENCE/cases/B01_E1_NOMINAL_FLUX_n16_dz10_dt0.0016.txt" "$BUILD/replay.txt" || {
  diff -u "$EVIDENCE/cases/B01_E1_NOMINAL_FLUX_n16_dz10_dt0.0016.txt" "$BUILD/replay.txt" >&2 || true
  fail "accepted trajectory exact replay drift"
}
echo "F_ROM0_EXACT_REPLAY=PASS"

if [[ "$failures" -ne 0 ]]; then
  printf '{"schema":"swap5.f-rom0.execution-summary.v1","case_failures":%d,"decision":"EXPAND_ACCEPTED_TRAJECTORY_DOMAIN_OR_CLASSIFY"}\n' "$failures" \
    >"$EVIDENCE/F-ROM0_EXECUTION_SUMMARY.json"
  fail "$failures preregistered cases failed"
fi

python3 "$ANALYZER" \
  --cases "$EVIDENCE/cases" \
  --prereg "$PREREG" \
  --output "$EVIDENCE/F-ROM0_RESULT.json"

sha256sum "$EVIDENCE"/cases/*.txt "$EVIDENCE/F-ROM0_RESULT.json" >"$EVIDENCE/sha256.txt"
cat "$EVIDENCE/F-ROM0_RESULT.json"

echo "F_ROM0_ACCEPTED_TRAJECTORY_GATE=PASS"