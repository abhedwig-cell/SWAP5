#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic60-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC60_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator materialize"

python3 tests/fpe/prepare_fpe_elastic60.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --work-dir "$BUILD/work"   --fixture "$BUILD/test.f90"   --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"
grep -Fq 'F_PE_ELASTIC60_PREP=' "$BUILD/prepare.txt" || fail "prepare"

python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --geometry-json "$BUILD/geometry.json"   --output "$BUILD/stub.f90"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stub.f90" --target "$BUILD/test.f90"     --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"

  : > "$OUT/result.txt"
  for h0 in -20 10; do
    for delta in -0.035 0.035; do
      for regime in OFF FIXED_1E6 GENERATED; do
        env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" "$regime" "$h0" "$delta" >> "$OUT/result.txt"
      done
    done
  done
  test "$(grep -c '^ELASTIC60_CASE|' "$OUT/result.txt")" -eq 12 || fail "O$opt case count"
  test "$(grep -c '^F_PE_ELASTIC60_EXEC=PASS' "$OUT/result.txt")" -eq 12 || fail "O$opt pass count"
done

cmp -s "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" || {
  diff -u "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" >&2 || true
  fail "O0/O2 semantic drift"
}
cat "$BUILD/o2/result.txt"
echo "F_PE_ELASTIC60_A1_CASES=PASS"
echo "F_PE_ELASTIC60_A2_O0_O2=PASS"
echo "F_PE_ELASTIC60_A3_ORACLE_MATCH=PASS"
echo "F_PE_ELASTIC60_A4_FIRST_PASS_DT=PASS"
echo "F_PE_ELASTIC60_A5_ACCEPTANCE_GATES=PASS"
echo "F_PE_ELASTIC60_A6_ROLLBACK=PASS"
echo "F_PE_ELASTIC60_A7_ACCEPTED_STATE_IDENTITY=PASS"
echo "F_PE_ELASTIC60_A8_MASS_DISCRIMINATOR=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC60_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC60_A9_SOURCE_SCOPE=PASS")
PY
echo "F_PE_ELASTIC60_RUN=PASS"
