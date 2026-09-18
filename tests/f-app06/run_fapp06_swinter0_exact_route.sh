#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fapp06-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_APP06_FAIL $*" >&2; exit 1; }

SRC=src/process/mod_pmdirect_swetr0_process.f90
FIX=tests/f-app06/fixtures/hupsel_swinter0_b111_oracle.csv.gz
TEST=tests/f-app06/test_swinter0_exact_trace.f90
test "$(git hash-object "$SRC")" = c89f69ae0a90a14cb98a741126597497520e2d46 || fail "PMdirect candidate blob drift"
test "$(sha256sum "$FIX" | awk '{print $1}')" = eeda2dff5fae1776833045a4090603961472c12ebce995213808868847900fdf || fail "fixture gzip drift"
python3 - "$FIX" "$BUILD/oracle.csv" <<'PY'
import gzip,hashlib,sys
raw=gzip.open(sys.argv[1],"rb").read()
assert hashlib.sha256(raw).hexdigest()=="f29d42dd1a32dba8aabedbc6dd91c208577f1ca4f72f0e0665845dbc770bd4f0"
open(sys.argv[2],"wb").write(raw)
PY

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SRC" -o "$OUT/pmdirect.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" "$BUILD/oracle.csv" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "exact trace O$opt"; }
  grep -Fq 'F_APP06_EXACT_B111_RECORDS=3505' "$OUT/output.txt" || fail "record count O$opt"
  grep -Fq 'F_APP06_SWINTER0_EXACT_TRACE=PASS' "$OUT/output.txt" || fail "trace marker O$opt"
  echo "F_APP06_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 trace drift"; }

# Preserve exact previously admitted PMdirect routes.
for opt in 0 2; do
  OUT="$BUILD/reg-o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$SRC" -o "$OUT/pmdirect.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_fapp03_pmdirect_swetr0_process.f90 -o "$OUT/fapp03.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/fapp03.o" -o "$OUT/fapp03"
  "$OUT/fapp03" > "$OUT/fapp03.txt" 2>&1 || { cat "$OUT/fapp03.txt" >&2; fail "F-APP03 regression O$opt"; }
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c tests/f-app05/test_hupsel_swcf2_pmdirect_daily.f90 -o "$OUT/fapp05.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/fapp05.o" -o "$OUT/fapp05"
  "$OUT/fapp05" > "$OUT/fapp05.txt" 2>&1 || { cat "$OUT/fapp05.txt" >&2; fail "F-APP05 regression O$opt"; }
done
cmp -s "$BUILD/reg-o0/fapp03.txt" "$BUILD/reg-o2/fapp03.txt" || fail "F-APP03 O0/O2 drift"
cmp -s "$BUILD/reg-o0/fapp05.txt" "$BUILD/reg-o2/fapp05.txt" || fail "F-APP05 O0/O2 drift"
cat "$BUILD/o0/output.txt"
echo "F_APP06_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'F_APP06_FAPP03_REGRESSION=PASS'
echo 'F_APP06_FAPP05_REGRESSION=PASS'
echo 'F_APP06_OWNER_QUALIFICATION=PASS'
