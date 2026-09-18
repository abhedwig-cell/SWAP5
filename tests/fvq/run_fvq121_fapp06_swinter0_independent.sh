#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq121-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_VQ121_FAIL $*" >&2; exit 1; }

SUBJECT=1d70cc07b3baf7d4680d739b87355f809396d7fa
SRC=src/process/mod_pmdirect_swetr0_process.f90
BIND=src/runtime/mod_fmr_pmdirect_swinter0_dynamic_top_binding.f90
TEST=tests/fvq/test_fvq121_fapp06_swinter0_independent.f90
EXACT=tests/fvq/test_fvq121_fapp06_exact_b111.f90
FIX=tests/f-app06/fixtures/hupsel_swinter0_b111_exact.csv.gz

[[ "$(git rev-parse HEAD:$SRC)" == 3eb23d075a56ba1158f4758f75a8d94c94e09b39 ]] || fail "candidate process drift"
[[ "$(git rev-parse HEAD:$BIND)" == 7d76af48cac085d6f4b5653987d75bfc54fb7692 ]] || fail "candidate binding drift"
[[ -z "$(git diff --name-only "$SUBJECT"..HEAD -- src)" ]] || fail "qualification mutated production source"
test "$(git hash-object "$FIX")" = 344c00d49717374a20772aa006edef720432d387 || fail "fixture blob drift"
python3 - "$FIX" "$BUILD/exact.csv" <<'PY'
import hashlib,sys,zlib
data=open(sys.argv[1],"rb").read()
assert data[:3] == b"\x1f\x8b\x08"
assert data[3] == 0, "unexpected gzip flags"
# The repository blob's gzip trailer was corrupted during binary transport.
# Recover only the DEFLATE payload, then authenticate the exact raw oracle.
raw=zlib.decompress(data[10:-8], -zlib.MAX_WBITS)
assert hashlib.sha256(raw).hexdigest()=="e802cf68da69075fd91985046d2e52fcecb0ae52ffacd42b437340fc783a86a0"
open(sys.argv[2],"wb").write(raw)
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -Werror -pedantic-errors -O"$opt" -J "$OUT" -I "$OUT" -c "$SRC" -o "$OUT/pmdirect.o"
  gfortran "${COMMON[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/swcontract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_restricted_surface_evaporation.f90 -o "$OUT/evap.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/dyntop.o"
  gfortran "${COMMON[@]}" -Werror -pedantic-errors -O"$opt" -J "$OUT" -I "$OUT" -c "$BIND" -o "$OUT/binding.o"

  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/swcontract.o" "$OUT/mvg.o" "$OUT/evap.o" "$OUT/dyntop.o" "$OUT/binding.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "generic runtime O$opt"; }
  for m in F_VQ121_GENERIC_IDENTITY_SWEEP=PASS F_VQ121_DYNAMIC_TOP_PRESERVATION=PASS F_VQ121_FAIL_CLOSED=PASS; do
    grep -Fq "$m" "$OUT/output.txt" || fail "missing O$opt marker $m"
  done

  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c "$EXACT" -o "$OUT/exact.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/swcontract.o" "$OUT/mvg.o" "$OUT/evap.o" "$OUT/dyntop.o" "$OUT/binding.o" "$OUT/exact.o" -o "$OUT/exact"
  "$OUT/exact" "$BUILD/exact.csv" > "$OUT/exact-output.txt" 2>&1 || { cat "$OUT/exact-output.txt" >&2; fail "exact B1.11 runtime O$opt"; }
  grep -Fq 'F_VQ121_EXACT_B111_RECORDS=3505' "$OUT/exact-output.txt" || fail "exact record count O$opt"
  grep -Fq 'F_VQ121_EXACT_3505_PROCESS_AND_BINDING=PASS' "$OUT/exact-output.txt" || fail "exact marker O$opt"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "generic O0/O2 drift"; }
cmp -s "$BUILD/o0/exact-output.txt" "$BUILD/o2/exact-output.txt" || { diff -u "$BUILD/o0/exact-output.txt" "$BUILD/o2/exact-output.txt" >&2 || true; fail "exact O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
cat "$BUILD/o0/exact-output.txt"
echo "F_VQ121_GENERIC_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "F_VQ121_EXACT_SHA256=$(sha256sum "$BUILD/o0/exact-output.txt" | awk '{print $1}')"
echo 'F_VQ121_FAPP06_INDEPENDENT=PASS'
