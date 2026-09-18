#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=3403b36924ff6ea7fd7813cf21e36fbfff1e2292
PREREG=integration/f-rom/F-ROM0TA3_PREREGISTRATION.json
TEST=tests/rom/test_f_rom0ta3_reference_floor_sample.f90
ANALYZER=tests/rom/analyze_f_rom0ta3_reference_floor_sample.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom0ta3-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0TA3_EVIDENCE_DIR:-$ROOT/F-ROM0TA3_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0TA3_GATE_FAIL $*" >&2; exit 1; }

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_HEAD_REF:-}" ]]; then
  CANDIDATE="$(git rev-parse "origin/$GITHUB_HEAD_REF")"
else
  CANDIDATE="$(git rev-parse HEAD)"
fi

git merge-base --is-ancestor "$PREREG_COMMIT" "$CANDIDATE" || fail "TA3 preregistration is not ancestor"
mapfile -t src_delta < <(git diff --name-only "$PREREG_COMMIT"..."$CANDIDATE" -- src | sort)
expected=$'src/kernel/mod_kernel_transactions.f90\nsrc/runtime/mod_fmr_serialized_reference_backend.f90'
[[ "$(printf '%s\n' "${src_delta[@]}")" == "$expected" ]] || {
  printf 'unexpected TA3 source delta:\n%s\n' "$(printf '%s\n' "${src_delta[@]}")" >&2
  fail "source allowlist violated"
}
git diff --quiet "$PREREG_COMMIT"..."$CANDIDATE" -- reference || fail "reference source changed after preregistration"
git diff --quiet "$PREREG_COMMIT"..."$CANDIDATE" -- src/solver src/transaction   src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 ||   fail "TA3 denylisted production source changed"
echo "F_ROM0TA3_SOURCE_SCOPE=PASS"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_SOURCE_MUTATION"
assert p["architecture_decision"]=="SEPARATE_KERNEL_REFERENCE_FLOOR_SAMPLE_PATH_NOT_NEW_TX_TEMPORAL_MODE"
assert p["first_qualification_domain"]["materials"]==["B01","B14"]
assert p["first_qualification_domain"]["temporal_resolution_day"]==[0.0016,0.0008,0.0004]
assert p["first_qualification_domain"]["common_perturbation_horizon_day"]==0.0128
assert p["first_qualification_domain"]["perturbation"]["epsilon_fraction_of_k0"]==0.01
assert p["production_application_admission"] is False
assert p["rom1a_authorized"] is False
print("F_ROM0TA3_PREREGISTRATION_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/rom0ta3_stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/rom0ta3_stubs_n16.f90"   --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

"$BUILD/o2/rom0_test" >"$EVIDENCE/raw.txt" 2>&1 || {
  cat "$EVIDENCE/raw.txt" >&2
  fail "TA3 executable failed structurally"
}
"$BUILD/o2/rom0_test" >"$EVIDENCE/repeat.txt" 2>&1 || {
  cat "$EVIDENCE/repeat.txt" >&2
  fail "TA3 repeat executable failed structurally"
}
cat "$EVIDENCE/raw.txt"

python3 "$ANALYZER" --input "$EVIDENCE/raw.txt" --repeat "$EVIDENCE/repeat.txt"   --output "$EVIDENCE/F-ROM0TA3_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE/raw.txt" "$EVIDENCE/repeat.txt" "$EVIDENCE/F-ROM0TA3_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
cat "$EVIDENCE/F-ROM0TA3_RESULT.json"
echo "F_ROM0TA3_EVIDENCE_PRESERVED=PASS"
