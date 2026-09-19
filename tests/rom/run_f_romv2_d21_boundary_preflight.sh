#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=277bf86d79a1ac13cbc9ede7c934aa661f915b6f
PREREG=integration/f-rom/F-ROMV2_D21_PREREGISTRATION.json
PREREG_BLOB=234ba54bbdde1e1bac22893743efa318ad8cffd6
TARGET=tests/rom/test_f_romv2_d21_dynamic_top_provider_preflight.f90
ANALYZER=tests/rom/analyze_f_romv2_d21_boundary_preflight.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d21-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D21_EVIDENCE_DIR:-$ROOT/F-ROMV2-D21-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D21_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D21 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "candidate not descendant of D21 base"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D21 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D21 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_BOUNDARY_PREFLIGHT"
assert p["scientific_role"]["R16_R2_trajectory_evidence_consumed"] is False
assert p["future_stage2_boundary"]["authorized_now"] is False
assert "NO_R16_R2_TRAJECTORY_EVIDENCE_IN_STAGE1" in p["firewalls"]
assert "NO_RAINFALL_LADDER_RETUNING" in p["firewalls"]
assert "NO_PONDING_MAX_RETUNING" in p["firewalls"]
assert "NO_RUNOFF_RESISTANCE_RETUNING" in p["firewalls"]
print("F_ROMV2_D21_PREREGISTRATION_LOCK=PASS")
PY

stub="$BUILD/stubs_n16.f90"
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16 --dz-cm 10
for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TARGET" --build "$out" --opt "$opt"
  "$out/rom0_test" > "$EVIDENCE/provider_o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/provider_o$opt.txt" >&2
    fail "dynamic-top provider preflight O$opt"
  }
  grep -Fq 'F_ROMV2_D21_PROVIDER_PREFLIGHT=PASS' "$EVIDENCE/provider_o$opt.txt" || fail "missing provider pass O$opt"
done
cmp "$EVIDENCE/provider_o0.txt" "$EVIDENCE/provider_o2.txt" || fail "provider O0/O2 drift"

python3 "$ANALYZER" --prereg "$PREREG" --provider "$EVIDENCE/provider_o2.txt" \
  --output "$EVIDENCE/F-ROMV2_D21_PREFLIGHT_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE/provider_o0.txt" "$EVIDENCE/provider_o2.txt" \
  "$EVIDENCE/F-ROMV2_D21_PREFLIGHT_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D21_BOUNDARY_PREFLIGHT=PASS"
