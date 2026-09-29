#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic47-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC47_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic47.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --work-dir "$BUILD/work" \
  --fixture "$BUILD/test_fpe_elastic47.f90" \
  --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"

grep -Fq 'F_PE_ELASTIC47_PREP=' "$BUILD/prepare.txt" || fail "prepare marker"

python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --geometry-json "$BUILD/geometry.json" \
  --output "$BUILD/stub.f90"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target "$BUILD/test_fpe_elastic47.f90" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
done

env -u SWAP5_ELASTIC_STORAGE_CONFIG python3 tests/fpe/run_fpe_elastic47.py \
  --o0 "$BUILD/o0/rom0_test" \
  --o2 "$BUILD/o2/rom0_test" | tee "$BUILD/result.txt"

for marker in \
  'F_PE_ELASTIC47_A7_O0_O2=PASS' \
  'F_PE_ELASTIC47_A2_MATRIX=PASS' \
  'F_PE_ELASTIC47_A3_MASS=PASS' \
  'F_PE_ELASTIC47_A4_THRESHOLD=PASS' \
  'F_PE_ELASTIC47_A5_NO_TUNING=PASS' \
  'F_PE_ELASTIC47_A6_MATCHED_TIMING=PASS' \
  'F_PE_ELASTIC47=PASS'; do
  grep -Fq "$marker" "$BUILD/result.txt" || fail "missing marker $marker"
done

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC47_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC47_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC47_RUN=PASS"
