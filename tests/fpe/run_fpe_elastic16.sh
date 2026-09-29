#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="\${RUNNER_TEMP:-\${TMPDIR:-/tmp}}/swap5-elastic16-\${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fpe/_generated_fpe_elastic16_application.f90"' EXIT

fail(){ echo "F_PE_ELASTIC16_FAIL $*" >&2; exit 1; }

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/adapter_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic16_resolved_input.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "adapter oracle O$opt"
  }
  for marker in \
    'F_PE_ELASTIC16_A1_DEFAULT_OFF=PASS' \
    'F_PE_ELASTIC16_A2_COMPOSITION_IDENTITY=PASS' \
    'F_PE_ELASTIC16_A3_EXPLICIT_CONFLICT=PASS' \
    'F_PE_ELASTIC16_A4_MIXED_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC16_A5_INPUT_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC16_ADAPTER_ORACLE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
  echo "F_PE_ELASTIC16_ADAPTER_O\${opt}=PASS"
done

cmp -s "$BUILD/adapter_o0/output.txt" "$BUILD/adapter_o2/output.txt" || {
  diff -u "$BUILD/adapter_o0/output.txt" "$BUILD/adapter_o2/output.txt" >&2 || true
  fail "adapter O0/O2 drift"
}
echo "F_PE_ELASTIC16_A9_ADAPTER_O0_O2=PASS"

bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh > "$BUILD/ppa-wu01.txt" 2>&1 || {
  cat "$BUILD/ppa-wu01.txt" >&2
  fail "PPA-WU01 preservation"
}
grep -Fq 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS' "$BUILD/ppa-wu01.txt" || {
  cat "$BUILD/ppa-wu01.txt" >&2
  fail "missing PPA-WU01 preservation marker"
}
echo "F_PE_ELASTIC16_A8_DEFAULT_OFF=PASS"

python3 - <<'PY'
from pathlib import Path
src=Path("tests/fpe/test_fpe_elastic09_application.f90").read_text()
src=src.replace(
"  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n",
"  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n"
"  use mod_fmr_elastic_storage_resolved_input_adapter, only: fmr_elastic_storage_input_diagnostics_t, &\n"
"       fmr_apply_resolved_elastic_storage_inputs, FMR_ELAS_INPUT_OK\n"
"  use mod_fmr_elastic_storage_prior_policy, only: FMR_ELAS_REGIME_MINERAL\n"
)
src=src.replace(
"    type(b110_default_mvg_provider_t) :: provider\n",
"    type(b110_default_mvg_provider_t) :: provider\n"
"    type(fmr_b110_physical_parameters_t) :: bound_parameters\n"
"    type(fmr_elastic_storage_input_diagnostics_t) :: input_diag\n"
"    real(real64) :: rho_dry(numnod), theta_ref(numnod)\n"
"    integer :: regimes(numnod), j\n",
1
)
src=src.replace(
"      p%cofgen(24,i)=2.0e-7_real64+real(i,real64)*1.0e-7_real64\n",
"      p%cofgen(24,i)=0.0_real64\n"
)
src=src.replace(
"    p%elasticity_active=.true.\n",
"    p%elasticity_active=.false.\n"
)
needle="    call initialize_parameters(value%tiles(1)%parameters)\n"
replacement=needle + (
"    do j=1,numnod\n"
"      rho_dry(j)=1.40_real64+0.002_real64*real(j,real64)\n"
"      theta_ref(j)=0.36_real64\n"
"      regimes(j)=FMR_ELAS_REGIME_MINERAL\n"
"    end do\n"
"    call fmr_apply_resolved_elastic_storage_inputs(value%tiles(1)%parameters,.true.,rho_dry,theta_ref,regimes, &\n"
"         bound_parameters,input_diag)\n"
"    call require(input_diag%status==FMR_ELAS_INPUT_OK.and.input_diag%binding_applied,'A7 resolved input apply')\n"
"    value%tiles(1)%parameters=bound_parameters\n"
)
if needle not in src:
    raise SystemExit("F_PE_ELASTIC16_GENERATOR_FAIL initialize_parameters needle")
src=src.replace(needle,replacement,1)
src=src.replace(
"  write(*,'(A)')'F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS'\n",
"  write(*,'(A)')'F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS'\n"
"  write(*,'(A)')'F_PE_ELASTIC16_A7_APPLICATION_IDENTITY=PASS'\n"
"  write(*,'(A)')'F_PE_ELASTIC16_A6_PREPARATION_IDENTITY=PASS'\n"
)
Path("tests/fpe/_generated_fpe_elastic16_application.f90").write_text(src)
PY

for opt in 0 2; do
  OUT="$BUILD/app_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/_generated_fpe_elastic16_application.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "application oracle O$opt"
  }
  for marker in \
    'F_PE_ELASTIC16_A6_PREPARATION_IDENTITY=PASS' \
    'F_PE_ELASTIC16_A7_APPLICATION_IDENTITY=PASS' \
    'F_PE_ELASTIC09_A4_FAIL_CLOSED=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing application O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
  echo "F_PE_ELASTIC16_APPLICATION_O\${opt}=PASS"
done

cmp -s "$BUILD/app_o0/output.txt" "$BUILD/app_o2/output.txt" || {
  diff -u "$BUILD/app_o0/output.txt" "$BUILD/app_o2/output.txt" >&2 || true
  fail "application O0/O2 drift"
}
echo "F_PE_ELASTIC16_A9_APPLICATION_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/adapter/mod_fmr_elastic_storage_resolved_input_adapter.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC16_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC16_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC16=PASS"
