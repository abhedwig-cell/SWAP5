#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=38559be9288e2fe5a7f0d9b202e9611c3d33de33
PREREG=integration/f-rom/F-ROMV2_D7_PREREGISTRATION.json
PREREG_BLOB=4416e44b458b1796fb0d9169eaf6a53bc9692eee
PREFLIGHT=tests/rom/preflight_f_romv2_d7_finite_domain_manifold.py
REF_TEST=tests/rom/test_f_romv2_d7_r16_reference.f90
ANALYZER=tests/rom/analyze_f_romv2_d7_quasi_steady_manifold.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d7-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D7_EVIDENCE_DIR:-$ROOT/F-ROMV2-D7-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D7_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D7 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "candidate not descendant of D7 canonical base"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D7 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D7 preregistration blob drift"

python3 "$PREFLIGHT" --prereg "$PREREG" --output "$EVIDENCE/F-ROMV2_D7_PREFLIGHT_RESULT.json" \
  | tee "$EVIDENCE/preflight.txt"
grep -Fq '"decision": "D7_FINITE_DOMAIN_SEARCH_PREFLIGHT_PASS"' "$EVIDENCE/F-ROMV2_D7_PREFLIGHT_RESULT.json" \
  || fail "D7 preflight no-go; trajectory execution prohibited"

stub="$BUILD/stubs_n16.f90"
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16 --dz-cm 10
for opt in 0 2; do
  outdir="$BUILD/ref_o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$REF_TEST" \
    --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
  "$outdir/rom0_test" > "$EVIDENCE/R16_o$opt.txt" 2>&1 || {
    tail -n 500 "$EVIDENCE/R16_o$opt.txt" >&2
    fail "D7 R16 O$opt"
  }
  grep -Fq 'F_ROMV2_D7_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/R16_o$opt.txt" || fail "missing R16 completion O$opt"
  [[ "$(grep -c 'F_ROMV2_D7_REF_STATE|' "$EVIDENCE/R16_o$opt.txt")" -eq 768 ]] || fail "expected 768 R16 states O$opt"
done
cmp "$EVIDENCE/R16_o0.txt" "$EVIDENCE/R16_o2.txt" || fail "D7 R16 O0/O2 drift"

python3 "$ANALYZER" --reference "$EVIDENCE/R16_o2.txt" --prereg "$PREREG" \
  --preflight "$EVIDENCE/F-ROMV2_D7_PREFLIGHT_RESULT.json" \
  --output "$EVIDENCE/F-ROMV2_D7_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE/R16_o0.txt" "$EVIDENCE/R16_o2.txt" \
  "$EVIDENCE/F-ROMV2_D7_PREFLIGHT_RESULT.json" "$EVIDENCE/F-ROMV2_D7_RESULT.json" \
  "$EVIDENCE/preflight.txt" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"

echo "F_ROMV2_D7_DYNAMIC_DISCRIMINATOR=PASS"
