#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic46-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/work"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC46_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic46.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --work-dir "$BUILD/work" \
  --fixture "$BUILD/test_fpe_elastic46.f90" | tee "$BUILD/prepare.txt"

grep -Fq 'F_PE_ELASTIC46_PREP=' "$BUILD/prepare.txt" || fail "prepare marker"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target "$BUILD/test_fpe_elastic46.f90" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"

  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "experiment O$opt"
  }
  cat "$OUT/output.txt"

  for marker in \
    'F_PE_ELASTIC46_A1_GENERATED_PREPARATION=PASS' \
    'F_PE_ELASTIC46_A2_BANK_EXECUTED=PASS' \
    'F_PE_ELASTIC46_A3_MASS_GATE=PASS' \
    'F_PE_ELASTIC46_A5_COUNTERS=PASS' \
    'F_PE_ELASTIC46_A6_TIMING=PASS' \
    'F_PE_ELASTIC46=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing O$opt marker $marker"
  done

  grep -v '^ELASTIC46_TIMING|' "$OUT/output.txt" > "$OUT/non-timing.txt"
done

cmp -s "$BUILD/o0/non-timing.txt" "$BUILD/o2/non-timing.txt" || {
  diff -u "$BUILD/o0/non-timing.txt" "$BUILD/o2/non-timing.txt" >&2 || true
  fail "O0/O2 non-timing drift"
}
echo "F_PE_ELASTIC46_A7_O0_O2=PASS"

python3 - "$BUILD/o2/output.txt" <<'PY'
import re,statistics,sys
text=open(sys.argv[1],encoding="utf-8").read().splitlines()
vals={}
for line in text:
    if not line.startswith("ELASTIC46_TIMING|"):
        continue
    parts=dict(part.split("=",1) for part in line.split("|")[1:])
    vals.setdefault(parts["regime"],[]).append(float(parts["ns_per_interval"]))
for regime in ("OFF","FIXED_1E6","GENERATED"):
    x=vals.get(regime,[])
    if len(x)!=5:
        raise SystemExit(f"F_PE_ELASTIC46_FAIL timing replicas {regime}={len(x)}")
    med=statistics.median(x)
    print(f"ELASTIC46_TIMING_MEDIAN|regime={regime}|ns_per_interval={med:.9f}")
off=statistics.median(vals["OFF"])
fixed=statistics.median(vals["FIXED_1E6"])
gen=statistics.median(vals["GENERATED"])
print(f"ELASTIC46_TIMING_RATIO|FIXED_1E6_over_OFF={fixed/off:.9f}")
print(f"ELASTIC46_TIMING_RATIO|GENERATED_over_OFF={gen/off:.9f}")
print(f"ELASTIC46_TIMING_RATIO|GENERATED_over_FIXED_1E6={gen/fixed:.9f}")
print("F_PE_ELASTIC46_TIMING_SUMMARY=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC46_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC46_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC46_RUN=PASS"
