#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic59-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC59_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator materialize"

python3 tests/fpe/prepare_fpe_elastic59.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --work-dir "$BUILD/work"   --fixture "$BUILD/test_fpe_elastic59.f90"   --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"
grep -Fq 'F_PE_ELASTIC59_PREP=PASS' "$BUILD/prepare.txt" || fail "prepare"

python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$BUILD/geometry.json"   --output "$BUILD/stub.f90"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub "$BUILD/stub.f90"     --target "$BUILD/test_fpe_elastic59.f90"     --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
done

python3 tests/fpe/run_fpe_elastic59.py   --o0 "$BUILD/o0/rom0_test"   --o2 "$BUILD/o2/rom0_test" | tee "$BUILD/result.txt"

for marker in   'F_PE_ELASTIC59_A1_CONVERGENCE=PASS'   'F_PE_ELASTIC59_A2_CERTIFICATE_COST_SHAPE=PASS'   'F_PE_ELASTIC59_A3_O0_O2=PASS'   'F_PE_ELASTIC59_A4_TIMING_REPLICAS=PASS'   'F_PE_ELASTIC59=PASS'; do
  grep -Fq "$marker" "$BUILD/result.txt" || fail "missing marker $marker"
done

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC59_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC59_A5_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC59_RUN=PASS"
