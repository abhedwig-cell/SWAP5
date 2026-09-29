#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic29-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f elastic29-valid.cfg' EXIT

fail(){ echo "F_PE_ELASTIC29_FAIL $*" >&2; exit 1; }
LONG_VALUE="$(python3 - <<'PY'
print('x'*513)
PY
)"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic29_environment_source.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"

  : > "$OUT/output.txt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" absent >> "$OUT/output.txt" 2>&1 || fail "absent O$opt"
  env SWAP5_ELASTIC_STORAGE_CONFIG=elastic29-valid.cfg "$OUT/rom0_test" present >> "$OUT/output.txt" 2>&1 || fail "present O$opt"
  env SWAP5_ELASTIC_STORAGE_CONFIG=env.cfg "$OUT/rom0_test" conflict >> "$OUT/output.txt" 2>&1 || fail "conflict O$opt"
  env SWAP5_ELASTIC_STORAGE_CONFIG= "$OUT/rom0_test" empty >> "$OUT/output.txt" 2>&1 || fail "empty O$opt"
  env SWAP5_ELASTIC_STORAGE_CONFIG="$LONG_VALUE" "$OUT/rom0_test" toolong >> "$OUT/output.txt" 2>&1 || fail "toolong O$opt"

  for marker in \
    'F_PE_ELASTIC29_A1_ABSENT_INACTIVE=PASS' \
    'F_PE_ELASTIC29_A2_PRESENT_IDENTITY=PASS' \
    'F_PE_ELASTIC29_A3_ARBITRATION=PASS' \
    'F_PE_ELASTIC29_A4_CONFLICT_PRESERVED=PASS' \
    'F_PE_ELASTIC29_A5_EMPTY_INACTIVE=PASS' \
    'F_PE_ELASTIC29_A6_TOO_LONG_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC29_A7_REQUEST_COMPOSITION=PASS' \
    'F_PE_ELASTIC29_A8_DEFAULT_OFF=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 drift"
}
echo "F_PE_ELASTIC29_A9_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/adapter/mod_fmr_elastic_storage_environment_source.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC29_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC29_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC29_RUN=PASS"
