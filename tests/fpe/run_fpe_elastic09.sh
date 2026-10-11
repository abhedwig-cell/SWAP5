#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic09-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC09_FAIL $*" >&2; exit 1; }

# A2: preserve the existing production application bootstrap authority.
bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh > "$BUILD/ppa-wu01.txt" 2>&1 || {
  cat "$BUILD/ppa-wu01.txt" >&2
  fail "PPA-WU01 preservation"
}
grep -Fq 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS' "$BUILD/ppa-wu01.txt" || {
  cat "$BUILD/ppa-wu01.txt" >&2
  fail "missing PPA-WU01 preservation marker"
}
echo "F_PE_ELASTIC09_A2_DEFAULT_OFF=PASS"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stub.f90"     --target tests/fpe/test_fpe_elastic09_application.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "focused application oracle O$opt"
  }
  for marker in     'F_PE_ELASTIC09_A1_BOOTSTRAP=PASS'     'F_PE_ELASTIC09_A3_HETEROGENEOUS=PASS'     'F_PE_ELASTIC09_A4_FAIL_CLOSED=PASS'     'F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
  echo "F_PE_ELASTIC09_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 output drift"
}
echo "F_PE_ELASTIC09_O0_O2=PASS"

python3 - <<'PY'
import subprocess
canonical="origin/integration/f-ci-canonical"
base=subprocess.check_output(["git","merge-base","HEAD",canonical],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/runtime/mod_fmr_production_application_bootstrap.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC09_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC09_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC09=PASS"
