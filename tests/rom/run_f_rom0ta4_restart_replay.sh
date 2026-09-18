#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=3c36bd45b4d1681ab20d4ca20b5e1d4d72ef41a6
PREREG=integration/f-rom/F-ROM0TA4_PREREGISTRATION.json
TEST=tests/rom/test_f_rom0ta4_restart_replay.f90
ANALYZER=tests/rom/analyze_f_rom0ta4_restart_replay.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom0ta4-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0TA4_EVIDENCE_DIR:-$ROOT/F-ROM0TA4_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0TA4_GATE_FAIL $*" >&2; exit 1; }

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_HEAD_REF:-}" ]]; then
  CANDIDATE="$(git rev-parse "origin/$GITHUB_HEAD_REF")"
else
  CANDIDATE="$(git rev-parse HEAD)"
fi

git merge-base --is-ancestor "$PREREG_COMMIT" "$CANDIDATE" || fail "TA4 preregistration is not ancestor"
git diff --quiet "$PREREG_COMMIT"..."$CANDIDATE" -- src reference || fail "TA4 changed production/reference source"
echo "F_ROM0TA4_SOURCE_FREEZE=PASS"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert p["refined_candidate"]["dt_day"]==0.0008
assert p["refined_candidate"]["selection_authority_precedes_TA3_results"] is True
assert p["domain"]["materials"]==["B01","B14"]
assert p["domain"]["perturbation"]["cases"]==["TOP_PLUS","TOP_MINUS"]
assert p["domain"]["perturbation_intervals"]==16
assert p["domain"]["restart_split_after_perturbation_intervals"]==8
assert p["source_policy"]["production_or_reference_source_mutation_allowed"] is False
assert p["rom1a_authorized"] is False
print("F_ROM0TA4_PREREGISTRATION_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/rom0ta4_stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/rom0ta4_stubs_n16.f90"   --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

"$BUILD/o2/rom0_test" >"$EVIDENCE/raw.txt" 2>&1 || {
  cat "$EVIDENCE/raw.txt" >&2
  fail "TA4 executable failed structurally"
}
"$BUILD/o2/rom0_test" >"$EVIDENCE/repeat.txt" 2>&1 || {
  cat "$EVIDENCE/repeat.txt" >&2
  fail "TA4 repeat executable failed structurally"
}
cat "$EVIDENCE/raw.txt"
python3 "$ANALYZER" --input "$EVIDENCE/raw.txt" --repeat "$EVIDENCE/repeat.txt"   --output "$EVIDENCE/F-ROM0TA4_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
sha256sum "$EVIDENCE/raw.txt" "$EVIDENCE/repeat.txt" "$EVIDENCE/F-ROM0TA4_RESULT.json"   "$EVIDENCE/analyzer.txt" >"$EVIDENCE/sha256.txt"
cat "$EVIDENCE/F-ROM0TA4_RESULT.json"
echo "F_ROM0TA4_EVIDENCE_PRESERVED=PASS"
