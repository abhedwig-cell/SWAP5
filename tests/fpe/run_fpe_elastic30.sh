#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic30-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f elastic30-valid.cfg' EXIT

fail(){ echo "F_PE_ELASTIC30_FAIL $*" >&2; exit 1; }
LONG_PATH="$(python3 - <<'PY'
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
    --target tests/fpe/test_fpe_elastic30_cli_source.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"

  : > "$OUT/output.txt"
  "$OUT/rom0_test" absent >> "$OUT/output.txt" 2>&1 || fail "absent O$opt"
  "$OUT/rom0_test" present --elastic-storage-config=elastic30-valid.cfg >> "$OUT/output.txt" 2>&1 || fail "present O$opt"
  "$OUT/rom0_test" unrelated --other=value >> "$OUT/output.txt" 2>&1 || fail "unrelated O$opt"
  "$OUT/rom0_test" duplicate --elastic-storage-config=a.cfg --elastic-storage-config=b.cfg >> "$OUT/output.txt" 2>&1 || fail "duplicate O$opt"
  "$OUT/rom0_test" empty --elastic-storage-config= >> "$OUT/output.txt" 2>&1 || fail "empty O$opt"
  "$OUT/rom0_test" toolong "--elastic-storage-config=$LONG_PATH" >> "$OUT/output.txt" 2>&1 || fail "toolong O$opt"
  "$OUT/rom0_test" conflict --elastic-storage-config=cli.cfg >> "$OUT/output.txt" 2>&1 || fail "conflict O$opt"

  for marker in \
    'F_PE_ELASTIC30_A1_ABSENT_INACTIVE=PASS' \
    'F_PE_ELASTIC30_A2_PRESENT_IDENTITY=PASS' \
    'F_PE_ELASTIC30_A3_UNRELATED_IGNORED=PASS' \
    'F_PE_ELASTIC30_A4_DUPLICATE_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC30_A5_EMPTY_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC30_A6_TOO_LONG_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC30_A7_REQUEST_COMPOSITION=PASS' \
    'F_PE_ELASTIC30_A8_CONFLICT_PRESERVED=PASS'; do
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
echo "F_PE_ELASTIC30_A9_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/adapter/mod_fmr_elastic_storage_cli_source.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC30_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC30_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC30_RUN=PASS"
