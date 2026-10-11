#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic44-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC44_FAIL $*" >&2; exit 1; }

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic44_application_host_binding.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"

  : > "$OUT/all-output.txt"

  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" inactive | tee "$OUT/inactive.txt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" explicit | tee "$OUT/explicit.txt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" cli \
    --elastic-storage-config=elastic44-request.cfg | tee "$OUT/cli.txt"
  SWAP5_ELASTIC_STORAGE_CONFIG=elastic44-request.cfg "$OUT/rom0_test" environment | tee "$OUT/environment.txt"
  SWAP5_ELASTIC_STORAGE_CONFIG=elastic44-request.cfg "$OUT/rom0_test" conflict | tee "$OUT/conflict.txt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" bad-config | tee "$OUT/bad-config.txt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" missing-row | tee "$OUT/missing-row.txt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" explicit-owner | tee "$OUT/explicit-owner.txt"

  cat "$OUT"/inactive.txt "$OUT"/explicit.txt "$OUT"/cli.txt "$OUT"/environment.txt \
      "$OUT"/conflict.txt "$OUT"/bad-config.txt "$OUT"/missing-row.txt \
      "$OUT"/explicit-owner.txt > "$OUT/all-output.txt"

  for marker in \
    'F_PE_ELASTIC44_A1_INACTIVE_IDENTITY=PASS' \
    'F_PE_ELASTIC44_A2_EXPLICIT_DIRECT_IDENTITY=PASS' \
    'F_PE_ELASTIC44_A3_CLI_COMPOSITION=PASS' \
    'F_PE_ELASTIC44_A3_ENVIRONMENT_COMPOSITION=PASS' \
    'F_PE_ELASTIC44_A4_SOURCE_CONFLICT_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC44_A5_REQUEST_REJECTION_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC44_A6_ROW_REJECTION_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC44_A7_EXPLICIT_OWNER_PRESERVED=PASS'; do
    grep -Fq "$marker" "$OUT/all-output.txt" || fail "missing O$opt marker $marker"
  done
done

cmp -s "$BUILD/o0/all-output.txt" "$BUILD/o2/all-output.txt" || {
  diff -u "$BUILD/o0/all-output.txt" "$BUILD/o2/all-output.txt" >&2 || true
  fail "O0/O2 drift"
}
echo "F_PE_ELASTIC44_A8_O0_O2=PASS"

tests/runtime/run_fapp01_minimal_soil_water_application_host.sh > "$BUILD/fapp01.txt" 2>&1 || {
  cat "$BUILD/fapp01.txt" >&2
  fail "F-APP01 preservation"
}
grep -Fq 'FAPP01_MINIMAL_APPLICATION_HOST_CONTRACT=PASS' "$BUILD/fapp01.txt" \
  || fail "missing F-APP01 preservation marker"
echo "F_PE_ELASTIC44_A9_FAPP01_PRESERVED=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(
    ["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True
).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
forbidden=[
    p for p in names
    if p.startswith("src/solver/")
    or p.startswith("src/process/")
    or p.startswith("src/legacy/")
]
if forbidden:
    raise SystemExit("F_PE_ELASTIC44_SCOPE_FAIL="+repr(forbidden))
print("F_PE_ELASTIC44_A10_SCOPE=PASS")
PY

echo "F_PE_ELASTIC44_RUN=PASS"
