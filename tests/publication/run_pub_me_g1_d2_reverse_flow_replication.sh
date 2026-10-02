#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-me-g1-d2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "PUB_ME_G1_D2_GATE_FAIL $*" >&2; exit 221; }

BASE=7b864853ca22baa73141b2dec9ed2f3915ef520d

# Replication is publication-only and must not modify production/reference source.
git diff --quiet "$BASE"..HEAD -- src reference || fail 'production/reference source changed'
git diff --quiet -- src reference || fail 'dirty src/reference before G1 D2'
echo 'PUB_ME_G1_D2_PRODUCTION_REFERENCE_UNCHANGED=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=("${COMMON[@]}" -Werror)

python3 tests/publication/pub_me_g1_d2_fortran_closure.py > "$BUILD/module_src.list"
grep -Fq 'tests/publication/pub_me_d2_directional_service_stub.f90' "$BUILD/module_src.list" || fail 'directional stub missing from closure'
if grep -Fq 'src/adapter/mod_reference_richards_accepted_step_directional_service.f90' "$BUILD/module_src.list"; then
  fail 'real non-requested directional service entered G1 D2 closure'
fi
echo 'PUB_ME_G1_D2_CURRENT_BACKEND_MODULE_CLOSURE=PASS'

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()

  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    obj="$OUT/$(echo "${source%.*}" | tr '/.' '__').o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done < "$BUILD/module_src.list"

  headcalc_obj="$OUT/src__legacy__b1_10_port__headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/legacy/b1_10_port/headcalc.f90 -o "$headcalc_obj"
  objects+=("$headcalc_obj")

  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/publication/test_pub_me_g1_d2_reverse_flow_replication.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

  "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "G1 D2 executable O$opt"
  }

  for marker in \
    'PUB_ME_G1_D2_B1_FINAL_ACCEPTED_TOTAL_REGRESSION=DETECTED' \
    'PUB_ME_G1_D2_B2_RETRY_ENTRY_AUTHORITY=DETECTED' \
    'PUB_ME_G1_D2_CLASSIFICATION=REPLICATED_EARLIER_DETECTION' \
    'PUB_ME_G1_D2_REVERSE_FLOW_REPLICATION=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done

  grep -Fq 'PUB_ME_G1_D2_REJECTED_BINF_CM=' "$OUT/output.txt" || fail "missing rejected Binf O$opt"
  grep -Fq 'PUB_ME_G1_D2_ACCEPTED_BINF_CM=' "$OUT/output.txt" || fail "missing accepted Binf O$opt"

  cat "$OUT/output.txt"
  echo "PUB_ME_G1_D2_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 semantic drift'
}

sha256sum "$BUILD/o0/output.txt" | awk '{print "PUB_ME_G1_D2_OUTPUT_SHA256="$1}'
echo 'PUB_ME_G1_D2_O0_O2_IDENTITY=PASS'

git diff --quiet -- src reference || fail 'G1 D2 mutated production/reference source'
git diff --check -- \
  tests/publication/test_pub_me_g1_d2_reverse_flow_replication.f90 \
  tests/publication/run_pub_me_g1_d2_reverse_flow_replication.sh \
  tests/publication/pub_me_g1_d2_fortran_closure.py \
  docs/publications/PUB-ME_G1_D2_REPLICATION_CHECKPOINT.md \
  docs/publications/PUB-ME_G1_D2_REPLICATION_PREREGISTRATION.md

echo 'PUB_ME_G1_D2_REPLICATION_GATE=PASS'
