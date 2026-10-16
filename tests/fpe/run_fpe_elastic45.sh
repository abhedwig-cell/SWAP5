#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic45-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC45_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic45.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --work-dir "$BUILD/work" \
  --fixture "$BUILD/test_fpe_elastic45.f90" | tee "$BUILD/prepare.txt"

grep -Fq 'F_PE_ELASTIC45_PREP=PASS' "$BUILD/prepare.txt" || fail "prepare marker"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target "$BUILD/test_fpe_elastic45.f90" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"

  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "normal O$opt"
  }
  for marker in \
    'F_PE_ELASTIC45_A1_INACTIVE_NO_PREPROCESS=PASS' \
    'F_PE_ELASTIC45_A2_EXACT_CALLBACK_ARGUMENTS=PASS' \
    'F_PE_ELASTIC45_A3_REAL_ELASTIC41=PASS' \
    'F_PE_ELASTIC45_A4_REAL_ELASTIC44_BINDING=PASS' \
    'F_PE_ELASTIC45_A6_PREPROCESS_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC45_A7_BINDING_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC45_A8_EXPLICIT_OWNER_PRESERVED=PASS' \
    'F_PE_ELASTIC45_A9_REPEAT_DETERMINISM=PASS' \
    'F_PE_ELASTIC45=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done

  CFG="$BUILD/work/request.cfg"
  SWAP5_ELASTIC_STORAGE_CONFIG="$CFG" "$OUT/rom0_test" conflict > "$OUT/conflict.txt" 2>&1 || {
    cat "$OUT/conflict.txt" >&2
    fail "conflict O$opt"
  }
  grep -Fq 'F_PE_ELASTIC45_A5_SOURCE_CONFLICT=PASS' "$OUT/conflict.txt" || {
    cat "$OUT/conflict.txt" >&2
    fail "missing conflict marker O$opt"
  }
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "normal O0/O2 drift"
}
cmp -s "$BUILD/o0/conflict.txt" "$BUILD/o2/conflict.txt" || {
  diff -u "$BUILD/o0/conflict.txt" "$BUILD/o2/conflict.txt" >&2 || true
  fail "conflict O0/O2 drift"
}
echo "F_PE_ELASTIC45_A9_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
allowed={"src/adapter/mod_fmr_elastic_storage_rd_application_host.f90"}
bad=[p for p in names if p.startswith("src/") and p not in allowed]
if bad:
    raise SystemExit("F_PE_ELASTIC45_SOURCE_SCOPE_FAIL="+repr(bad))
print("F_PE_ELASTIC45_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC45_RUN=PASS"
