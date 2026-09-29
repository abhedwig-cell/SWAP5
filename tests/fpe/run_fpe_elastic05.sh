#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic05-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
CSV="tests/fpe/data/fpe_elastic05_staringreeks_2018.csv"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for OPT in 0 2; do
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic05_provider.f90 \
    --build "$BUILD/provider-O$OPT" --opt "$OPT"
  python3 tests/fpe/run_fpe_elastic05_provider.py "$BUILD/provider-O$OPT/rom0_test" "$CSV" | tee "$BUILD/provider-O$OPT.out"

  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic05_case.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$BUILD/prod-O$OPT" --opt "$OPT"

  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic05_legacy_case.f90 \
    --external-source tests/fpe/mod_fpe_elastic05_legacy_oracle.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$BUILD/legacy-O$OPT" --opt "$OPT"

  python3 tests/fpe/run_fpe_elastic05_dynamic.py \
    "$BUILD/prod-O$OPT/rom0_test" "$BUILD/legacy-O$OPT/rom0_test" "$CSV" | tee "$BUILD/dynamic-O$OPT.out"
done

cmp "$BUILD/provider-O0.out" "$BUILD/provider-O2.out"
cmp "$BUILD/dynamic-O0.out" "$BUILD/dynamic-O2.out"

python3 - <<'PY'
import subprocess
base="a5f127e2f42329914826a835d760102be6fee71f"
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/solver/mod_b110_default_mvg_directional_provider.f90","src/solver/mod_b110_default_mvg_provider.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC05_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC05_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC05_O0_O2=PASS"
echo "F_PE_ELASTIC05_QUALIFICATION=PASS"
