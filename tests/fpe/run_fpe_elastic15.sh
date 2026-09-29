#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="\${RUNNER_TEMP:-\${TMPDIR:-/tmp}}/swap5-elastic15-\${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fpe/_generated_fpe_elastic15_application.f90"' EXIT

fail(){ echo "F_PE_ELASTIC15_FAIL $*" >&2; exit 1; }

for opt in 0 2; do
  gfortran -std=f2008 -Wall -Wextra -pedantic -O"$opt" \
    src/runtime/mod_fmr_elastic_storage_prior_policy.f90 \
    src/runtime/mod_fmr_elastic_storage_source_selection.f90 \
    tests/fpe/test_fpe_elastic15_source_selection.f90 \
    -J"$BUILD" -o "$BUILD/policy_o$opt"
  "$BUILD/policy_o$opt" > "$BUILD/policy_o$opt.txt" 2>&1 || {
    cat "$BUILD/policy_o$opt.txt" >&2
    fail "policy oracle O$opt"
  }
  for marker in \
    'F_PE_ELASTIC15_A1_DEFAULT_OFF=PASS' \
    'F_PE_ELASTIC15_A2_USER=PASS' \
    'F_PE_ELASTIC15_A3_USER_OVERRIDE=PASS' \
    'F_PE_ELASTIC15_A4_INVALID_USER_NO_FALLBACK=PASS' \
    'F_PE_ELASTIC15_A5_GENERATED=PASS' \
    'F_PE_ELASTIC15_A6_GENERATED_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC15_POLICY_ORACLE=PASS'; do
    grep -Fq "$marker" "$BUILD/policy_o$opt.txt" || {
      cat "$BUILD/policy_o$opt.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  cat "$BUILD/policy_o$opt.txt"
  echo "F_PE_ELASTIC15_POLICY_O\${opt}=PASS"
done

cmp -s "$BUILD/policy_o0.txt" "$BUILD/policy_o2.txt" || {
  diff -u "$BUILD/policy_o0.txt" "$BUILD/policy_o2.txt" >&2 || true
  fail "policy O0/O2 drift"
}
echo "F_PE_ELASTIC15_A9_POLICY_O0_O2=PASS"

# A7: merely linking source-selection policy must preserve default-off application authority.
bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh > "$BUILD/ppa-wu01.txt" 2>&1 || {
  cat "$BUILD/ppa-wu01.txt" >&2
  fail "PPA-WU01 preservation"
}
grep -Fq 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS' "$BUILD/ppa-wu01.txt" || {
  cat "$BUILD/ppa-wu01.txt" >&2
  fail "missing PPA-WU01 preservation marker"
}
echo "F_PE_ELASTIC15_A7_DEFAULT_OFF=PASS"

# A8: reuse admitted ELASTIC09 application/direct-runtime oracle and source row24
# through ELASTIC14 prior + ELASTIC15 source selection. The test caller explicitly
# performs the row24 write and activation.
python3 - <<'PY'
from pathlib import Path
src=Path("tests/fpe/test_fpe_elastic09_application.f90").read_text()
src=src.replace(
"  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n",
"  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n"
"  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, materialize_fmr_elastic_storage_prior, &\n"
"       FMR_ELAS_PRIOR_OK, FMR_ELAS_REGIME_MINERAL\n"
"  use mod_fmr_elastic_storage_source_selection, only: fmr_elastic_storage_selection_t, select_fmr_elastic_storage_source, &\n"
"       FMR_ELAS_SELECT_OK, FMR_ELAS_SOURCE_GENERATED_MINERAL\n"
)
src=src.replace(
"    integer :: i\n",
"    integer :: i, prior_status, selection_status\n"
"    type(fmr_elastic_storage_prior_t) :: generated_prior\n"
"    type(fmr_elastic_storage_selection_t) :: selected_elas\n",
1
)
src=src.replace(
"    do i=1,numnod\n",
"    call materialize_fmr_elastic_storage_prior(1.454_real64,0.36_real64,FMR_ELAS_REGIME_MINERAL,generated_prior,prior_status)\n"
"    call require(prior_status==FMR_ELAS_PRIOR_OK.and.generated_prior%available,'A8 generated prior')\n"
"    call select_fmr_elastic_storage_source(.false.,0.0_real64,.true.,generated_prior,selected_elas,selection_status)\n"
"    call require(selection_status==FMR_ELAS_SELECT_OK.and.selected_elas%activate,'A8 generated selection')\n"
"    call require(selected_elas%source==FMR_ELAS_SOURCE_GENERATED_MINERAL,'A8 generated source')\n"
"    do i=1,numnod\n",
1
)
src=src.replace(
"      p%cofgen(24,i)=2.0e-7_real64+real(i,real64)*1.0e-7_real64\n",
"      p%cofgen(24,i)=selected_elas%value_cm_inv\n"
)
src=src.replace(
"  write(*,'(A)')'F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS'\n",
"  write(*,'(A)')'F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS'\n"
"  write(*,'(A)')'F_PE_ELASTIC15_A8_BRIDGE_IDENTITY=PASS'\n"
)
Path("tests/fpe/_generated_fpe_elastic15_application.f90").write_text(src)
PY

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/app_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/_generated_fpe_elastic15_application.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "source-selection application oracle O$opt"
  }
  grep -Fq 'F_PE_ELASTIC15_A8_BRIDGE_IDENTITY=PASS' "$OUT/output.txt" || {
    cat "$OUT/output.txt" >&2
    fail "missing A8 O$opt marker"
  }
  grep -Fq 'F_PE_ELASTIC09_A4_FAIL_CLOSED=PASS' "$OUT/output.txt" || {
    cat "$OUT/output.txt" >&2
    fail "ELASTIC09 fail-closed preservation O$opt"
  }
  cat "$OUT/output.txt"
  echo "F_PE_ELASTIC15_APPLICATION_O\${opt}=PASS"
done

cmp -s "$BUILD/app_o0/output.txt" "$BUILD/app_o2/output.txt" || {
  diff -u "$BUILD/app_o0/output.txt" "$BUILD/app_o2/output.txt" >&2 || true
  fail "application O0/O2 drift"
}
echo "F_PE_ELASTIC15_A9_APPLICATION_O0_O2=PASS"

python3 - <<'PY'
import subprocess
canonical="origin/integration/f-ci-canonical"
base=subprocess.check_output(["git","merge-base","HEAD",canonical],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/runtime/mod_fmr_elastic_storage_source_selection.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC15_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC15_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC15=PASS"
