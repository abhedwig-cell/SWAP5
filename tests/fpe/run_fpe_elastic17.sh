#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="\${RUNNER_TEMP:-\${TMPDIR:-/tmp}}/swap5-elastic17-\${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC17_FAIL $*" >&2; exit 1; }

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic17_layer_node_mapping.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "mapping oracle O$opt"
  }
  for marker in \
    'F_PE_ELASTIC17_A1_SINGLE_HORIZON=PASS' \
    'F_PE_ELASTIC17_A2_ALIGNED_BOUNDARY=PASS' \
    'F_PE_ELASTIC17_A3_STRADDLE_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC17_A4_HORIZON_VALIDATION=PASS' \
    'F_PE_ELASTIC17_A5_COVERAGE_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC17_A6_NONFINITE_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC17_A7_DESCRIPTOR_BIT_IDENTITY=PASS' \
    'F_PE_ELASTIC17_A8_ELASTIC16_COMPOSITION=PASS' \
    'F_PE_ELASTIC17_A9_PEAT_PRESERVED_AND_REJECTED=PASS' \
    'F_PE_ELASTIC17_MAPPING_ORACLE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
  echo "F_PE_ELASTIC17_O\${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 output drift"
}
echo "F_PE_ELASTIC17_A10_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/adapter/mod_fmr_elastic_storage_horizon_node_mapper.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC17_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC17_A11_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC17=PASS"
