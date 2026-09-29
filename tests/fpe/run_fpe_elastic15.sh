#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic15-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fpe/_generated_fpe_elastic15_application.f90"' EXIT

fail(){ echo "F_PE_ELASTIC15_FAIL $*" >&2; exit 1; }

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/bind_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic15_binding.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "binding oracle O$opt"
  }
  for marker in \
    'F_PE_ELASTIC15_A1_DEFAULT_OFF=PASS' \
    'F_PE_ELASTIC15_A2_HETEROGENEOUS_BINDING=PASS' \
    'F_PE_ELASTIC15_A3_EXPLICIT_CONFLICT=PASS' \
    'F_PE_ELASTIC15_A4_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC15_A5_CACHE_INVALIDATION=PASS' \
    'F_PE_ELASTIC15_BINDING_ORACLE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
  echo "F_PE_ELASTIC15_BINDING_O${opt}=PASS"
done

cmp -s "$BUILD/bind_o0/output.txt" "$BUILD/bind_o2/output.txt" || {
  diff -u "$BUILD/bind_o0/output.txt" "$BUILD/bind_o2/output.txt" >&2 || true
  fail "binding O0/O2 drift"
}
echo "F_PE_ELASTIC15_A7_BINDING_O0_O2=PASS"

bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh > "$BUILD/ppa-wu01.txt" 2>&1 || {
  cat "$BUILD/ppa-wu01.txt" >&2
  fail "PPA-WU01 preservation"
}
grep -Fq 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS' "$BUILD/ppa-wu01.txt" || {
  cat "$BUILD/ppa-wu01.txt" >&2
  fail "missing PPA-WU01 preservation marker"
}
echo "F_PE_ELASTIC15_A1_PPA_DEFAULT_OFF=PASS"

python3 - <<'PY'
from pathlib import Path
src=Path("tests/fpe/test_fpe_elastic09_application.f90").read_text()

src=src.replace(
"  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n",
"  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n"
"  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, materialize_fmr_elastic_storage_prior, &\n"
"       FMR_ELAS_PRIOR_OK, FMR_ELAS_REGIME_MINERAL\n"
"  use mod_fmr_elastic_storage_prior_application_binding, only: fmr_elastic_storage_prior_binding_diagnostics_t, &\n"
"       fmr_bind_generated_elastic_storage_priors, FMR_ELAS_PRIOR_BIND_OK\n"
)

src=src.replace(
"    type(b110_default_mvg_provider_t) :: provider\n",
"    type(b110_default_mvg_provider_t) :: provider\n"
"    type(fmr_elastic_storage_prior_t) :: generated_priors(numnod)\n"
"    type(fmr_b110_physical_parameters_t) :: bound_parameters\n"
"    type(fmr_elastic_storage_prior_binding_diagnostics_t) :: bind_diag\n"
"    integer :: j, prior_status\n",
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
"      call materialize_fmr_elastic_storage_prior(1.40_real64+0.002_real64*real(j,real64),0.36_real64, &\n"
"           FMR_ELAS_REGIME_MINERAL,generated_priors(j),prior_status)\n"
"      call require(prior_status==FMR_ELAS_PRIOR_OK.and.generated_priors(j)%available,'A6 prior materialize')\n"
"    end do\n"
"    call fmr_bind_generated_elastic_storage_priors(value%tiles(1)%parameters,.true.,generated_priors, &\n"
"         bound_parameters,bind_diag)\n"
"    call require(bind_diag%status==FMR_ELAS_PRIOR_BIND_OK.and.bind_diag%generated_prior_applied,'A6 prior bind')\n"
"    value%tiles(1)%parameters=bound_parameters\n"
)
if needle not in src:
    raise SystemExit("F_PE_ELASTIC15_GENERATOR_FAIL initialize_parameters needle")
src=src.replace(needle,replacement,1)

src=src.replace(
"  write(*,'(A)')'F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS'\n",
"  write(*,'(A)')'F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS'\n"
"  write(*,'(A)')'F_PE_ELASTIC15_A6_APPLICATION_IDENTITY=PASS'\n"
)
Path("tests/fpe/_generated_fpe_elastic15_application.f90").write_text(src)
PY

for opt in 0 2; do
  OUT="$BUILD/app_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/_generated_fpe_elastic15_application.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "application oracle O$opt"
  }
  grep -Fq 'F_PE_ELASTIC15_A6_APPLICATION_IDENTITY=PASS' "$OUT/output.txt" || {
    cat "$OUT/output.txt" >&2
    fail "missing A6 O$opt marker"
  }
  grep -Fq 'F_PE_ELASTIC09_A4_FAIL_CLOSED=PASS' "$OUT/output.txt" || {
    cat "$OUT/output.txt" >&2
    fail "ELASTIC09 fail-closed preservation O$opt"
  }
  cat "$OUT/output.txt"
  echo "F_PE_ELASTIC15_APPLICATION_O${opt}=PASS"
done

cmp -s "$BUILD/app_o0/output.txt" "$BUILD/app_o2/output.txt" || {
  diff -u "$BUILD/app_o0/output.txt" "$BUILD/app_o2/output.txt" >&2 || true
  fail "application O0/O2 drift"
}
echo "F_PE_ELASTIC15_A7_APPLICATION_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/runtime/mod_fmr_elastic_storage_prior_application_binding.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC15_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC15_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC15=PASS"
