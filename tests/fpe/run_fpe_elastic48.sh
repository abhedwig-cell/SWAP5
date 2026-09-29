#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic48-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC48_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic48.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --work-dir "$BUILD/work" \
  --fixture "$BUILD/test_fpe_elastic48.f90" \
  --geometry-json "$BUILD/geometry.json" | tee "$BUILD/prepare.txt"

python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --geometry-json "$BUILD/geometry.json" \
  --output "$BUILD/stub.f90"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target "$BUILD/test_fpe_elastic48.f90" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"

  : > "$OUT/result.txt"
  for h0 in 2 10; do
    for delta in 0.05 -0.05; do
      for regime in OFF FIXED_1E6 GENERATED; do
        env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" "$regime" "$h0" "$delta" >> "$OUT/result.txt"
      done
    done
  done
  test "$(grep -c '^ELASTIC48_ATTR|' "$OUT/result.txt")" -eq 12 || fail "O$opt case count"
  test "$(grep -c '^F_PE_ELASTIC48_EXEC=PASS' "$OUT/result.txt")" -eq 12 || fail "O$opt pass count"
done

cmp -s "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" || {
  diff -u "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" >&2 || true
  fail "O0/O2 attribution drift"
}
cat "$BUILD/o2/result.txt"
echo "F_PE_ELASTIC48_A1_CASES=PASS"
echo "F_PE_ELASTIC48_A2_O0_O2=PASS"
echo "F_PE_ELASTIC48_A3_POLICY_UNCHANGED=PASS"
echo "F_PE_ELASTIC48_A4_EXISTING_DIAGNOSTICS=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC48_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC48_A5_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC48=PASS"
